import 'dart:math';

import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dividends/presentation/bloc/dividends_cubit.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/presentation/bloc/performance_cubit.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Satu garis grafik: return kumulatif per hari dalam periode.
typedef _Series = ({String label, Color color, List<double> values});

// Kategori tetap (lolos uji CVD dataviz): urutan & warna mengikuti entitas, bukan peringkat.
final _portfolioColor = AppColors.series[0];
final _ihsgColor = AppColors.series[1];
final _sp500Color = AppColors.series[2];
final _btcColor = AppColors.series[3];

/// S03 Kinerja: periode → grafik return kumulatif vs IHSG & S&P 500 → ringkasan teks → PnL harian.
class PerformanceTab extends StatefulWidget {
  const PerformanceTab({super.key});

  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab> {
  var _period = PerformancePeriod.month;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PerformanceCubit>();
    return BlocBuilder<PerformanceCubit, ViewState<List<DailyPerformance>>>(
      builder: (context, state) => ViewStateBuilder<List<DailyPerformance>>(
        state: state,
        onRetry: cubit.load,
        isEmpty: (rows) => rows.isEmpty,
        empty: const EmptyView(
          icon: Icons.show_chart,
          title: 'Belum ada data kinerja',
          message: 'PnL portofolio dicatat setiap malam. Grafik muncul setelah ada catatan harian.',
        ),
        builder: (context, all) {
          final rows = _period.filter(all, (r) => r.date, DateTime.now());
          final series = <_Series>[
            (label: 'Portofolio', color: _portfolioColor, values: cumulativeReturn(rows.map((r) => r.pnlPercent))),
            if (rows.any((r) => r.ihsgChange != null))
              (label: 'IHSG', color: _ihsgColor, values: cumulativeReturn(rows.map((r) => r.ihsgChange))),
            if (rows.any((r) => r.sp500Change != null))
              (label: 'S&P 500', color: _sp500Color, values: cumulativeReturn(rows.map((r) => r.sp500Change))),
            if (rows.any((r) => r.btcChange != null))
              (label: 'BTC', color: _btcColor, values: cumulativeReturn(rows.map((r) => r.btcChange))),
          ];
          final text = Theme.of(context).textTheme;
          return RefreshIndicator(
            onRefresh: () async {
              context.read<PortfolioBloc>().add(const PortfolioRequested());
              await Future.wait([cubit.load(), context.read<SalesCubit>().load(), context.read<DividendsCubit>().load()]);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                PageBody(
                  child: Row(
                    children: [
                      for (final (i, p) in PerformancePeriod.values.indexed) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _PeriodButton(
                            label: p.label,
                            selected: p == _period,
                            onTap: () => setState(() => _period = p),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PageBody(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Return kumulatif · ${_period.label}', style: text.titleSmall)),
                            if (rows.isNotEmpty)
                              Text(
                                Fmt.percent(series.first.values.last),
                                style: text.titleLarge?.copyWith(
                                  color: series.first.values.last >= 0 ? AppColors.positive : AppColors.negative,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (rows.length < 2)
                          Text('Belum cukup data untuk periode ini.', style: text.bodySmall)
                        else ...[
                          ExcludeSemantics(
                            child: _ReturnChart(dates: [for (final r in rows) r.date], series: series),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _Legend(series: series),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        if (rows.isNotEmpty) Text(_summary(series, _period), style: text.bodyMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Return majemuk harian (TWR): tidak terpengaruh setoran atau penarikan modal.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                // Empat kartu ini selalu memakai seluruh riwayat, bukan pilihan 7H–1T.
                const SizedBox(height: AppSpacing.lg),
                const PageBody(child: _TotalReturnCard()),
                const SizedBox(height: AppSpacing.lg),
                PageBody(child: _PerformanceSummary(rows: all)),
                const SizedBox(height: AppSpacing.lg),
                PageBody(child: _PnlCalendar(rows: all)),
                const SizedBox(height: AppSpacing.lg),
                PageBody(child: _PortfolioValue(rows: all)),
                const SizedBox(height: AppSpacing.lg),
                PageBody(child: _DailySummary(rows: rows, period: _period)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Ringkasan teks grafik (grafik tidak boleh jadi satu-satunya sumber informasi).
  static String _summary(List<_Series> series, PerformancePeriod period) {
    final porto = series.first.values.last;
    final parts = [
      for (final b in series.skip(1))
        '${porto >= b.values.last ? 'unggul' : 'tertinggal'} '
            '${Fmt.percent((porto - b.values.last).abs(), signed: false)} dari ${b.label} (${Fmt.percent(b.values.last)})',
    ];
    final base = 'Portofolio ${Fmt.percent(porto)} dalam ${period.label}';
    return parts.isEmpty ? '$base. Data benchmark belum tersedia.' : '$base, ${parts.join(' dan ')}.';
  }
}

class _ReturnChart extends StatelessWidget {
  const _ReturnChart({required this.dates, required this.series});
  final List<DateTime> dates;
  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    final axis = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);
    final label = DateFormat('d MMM', 'id');
    final step = (dates.length / 4).ceilToDouble(); // ±4 label tanggal, tidak bertumpuk di 360 px
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            for (final s in series)
              LineChartBarData(
                spots: [for (var i = 0; i < s.values.length; i++) FlSpot(i.toDouble(), s.values[i])],
                color: s.color,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
          ],
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                // Hanya garis bantu bulat; nilai min/max (mis. 14,62%) tidak dicetak supaya tidak bertumpuk.
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(Fmt.percent(v, signed: false), style: axis),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: step,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => v >= dates.length
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(label.format(dates[v.toInt()]), style: axis),
                      ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.text,
              fitInsideHorizontally: true,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.barIndex == 0 ? '${label.format(dates[s.x.toInt()])}\n' : ''}'
                    '${series[s.barIndex].label} ${Fmt.percent(s.y)}',
                    const TextStyle(color: AppColors.surface, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.series});
  final List<_Series> series;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget tile(_Series s, {required bool main}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              s.label,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(fontWeight: main ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          // Teks memakai warna teks, bukan warna garis (warna hanya identitas).
          Text(Fmt.percent(s.values.last), style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < series.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(child: tile(series[i], main: i == 0)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: i + 1 < series.length ? tile(series[i + 1], main: false) : const SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Semantics(
      selected: selected,
      child: selected
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: shape),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: shape,
                foregroundColor: AppColors.text,
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: Color(0xFFD5DED2)),
              ),
              child: Text(label),
            ),
    );
  }
}

/// Total untung per mata uang. Tampil hanya bila posisi, penjualan, dan dividen semuanya termuat,
/// karena total dari data yang belum lengkap akan menyesatkan.
class _TotalReturnCard extends StatelessWidget {
  const _TotalReturnCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final portfolioState = context.watch<PortfolioBloc>().state.data;
    final salesState = context.watch<SalesCubit>().state;
    final dividendsState = context.watch<DividendsCubit>().state;
    final portfolio = portfolioState.data;
    final sales = salesState.data;
    final dividends = dividendsState.data;

    Widget body;
    if (portfolio == null || sales == null || dividends == null) {
      final failed = [portfolioState.failure, salesState.failure, dividendsState.failure].any((f) => f != null);
      body = failed
          ? Row(
              children: [
                Expanded(child: Text('Total return belum bisa dimuat.', style: text.bodySmall)),
                TextButton(
                  onPressed: () {
                    context.read<PortfolioBloc>().add(const PortfolioRequested());
                    context.read<SalesCubit>().load();
                    context.read<DividendsCubit>().load();
                  },
                  child: const Text('Coba lagi'),
                ),
              ],
            )
          : Text('Memuat total return…', style: text.bodySmall);
    } else {
      final totals = totalReturns(portfolio, sales, dividends, DateTime.now());
      final unpriced = portfolio.unpriced;
      Widget line(String label, Money amount) => InfoRow(label: label, value: PnlText(amount: amount));
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (totals.isEmpty) Text('Belum ada posisi, penjualan, atau dividen.', style: text.bodySmall),
          for (final t in totals)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.currency == Currency.idr ? 'Rupiah' : 'Dolar AS', style: text.bodySmall),
                  PnlText(
                    amount: t.total,
                    percent: t.percent,
                    stacked: true,
                    align: CrossAxisAlignment.start,
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  line('Posisi yang masih dipegang', t.unrealized),
                  line('Saham yang sudah dijual', t.realized),
                  line('Dividen diterima', t.dividends),
                ],
              ),
            ),
          if (unpriced.isNotEmpty) ...[
            Text(
              '${unpriced.map((p) => p.symbol).join(', ')} belum punya harga terbaru — tidak masuk total di atas.',
              style: text.bodySmall?.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            'Dihitung dari harga beli rata-rata, persen terhadap seluruh modal yang pernah dipakai. Rupiah dan dolar '
            'tidak dijumlah, jadi tidak terpengaruh kurs. Bisa berbeda dari batang PnL, yang hanya mencatat '
            'pergerakan harga harian sejak pencatatan dimulai.',
            style: text.bodySmall,
          ),
        ],
      );
    }
    return ModuleCard(title: 'Total return', child: body);
  }
}

/// Streak, hari untung, jarak dari puncak, dan drawdown seluruh riwayat. Hanya persen & jumlah hari, tanpa nominal.
class _PerformanceSummary extends StatelessWidget {
  const _PerformanceSummary({required this.rows});
  final List<DailyPerformance> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = performanceStats(rows);
    final winRate = s.winRatePercent;
    final trough = s.troughDate;
    Widget pair(Widget a, Widget b) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: a),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: b),
          ],
        ),
      ),
    );
    return ModuleCard(
      title: 'Ringkasan kinerja',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pair(
            StatTile(
              label: 'Streak',
              value: s.streakDays == 0
                  ? const Text(Fmt.missing)
                  : Text(
                      '${s.streakDays} hari',
                      style: TextStyle(color: s.streakIsProfit ? AppColors.positive : AppColors.negative),
                    ),
              caption: s.streakDays == 0 ? 'Belum ada pergerakan' : 'Berturut-turut ${s.streakIsProfit ? 'untung' : 'rugi'}',
            ),
            StatTile(
              label: 'Hari untung',
              value: Text(winRate == null ? Fmt.missing : '${Fmt.number(winRate.round())}%'),
              caption: '${s.profitDays} dari ${s.movedDays} hari bergerak',
            ),
          ),
          pair(
            StatTile(
              label: 'Jarak dari puncak',
              value: s.fromPeakPercent == 0 ? const Text('Di puncak') : PnlText(percent: s.fromPeakPercent),
              caption: 'Puncak ${Fmt.date(s.peakDate)}',
            ),
            StatTile(
              label: 'Max drawdown',
              value: trough == null ? Text(Fmt.percent(0, signed: false)) : PnlText(percent: s.maxDrawdownPercent),
              caption: trough == null ? 'Belum pernah turun' : 'Terdalam ${Fmt.date(trough)}',
            ),
          ),
          Text(
            'Sejak ${Fmt.date(rows.first.date)}. Puncak & drawdown memakai return TWR, jadi top up dan penjualan '
            'saham tidak memengaruhinya. Angkanya bisa berbeda dari web, yang memakai nilai rupiah 30 hari terakhir.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

const _calendarCell = 21.0; // termasuk celah antar kotak; seluruhnya area ketuk

DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Kalender PnL seluruh riwayat, gaya riwayat commit GitHub: terbaru di kanan, digeser ke kiri untuk yang lama.
class _PnlCalendar extends StatefulWidget {
  const _PnlCalendar({required this.rows});
  final List<DailyPerformance> rows;

  @override
  State<_PnlCalendar> createState() => _PnlCalendarState();
}

class _PnlCalendarState extends State<_PnlCalendar> {
  DateTime? _selected;

  static Color _colorOf(DailyPerformance r) {
    if (r.pnl.amount == 0) return AppColors.segment;
    final pct = r.pnlPercent.abs();
    final level = pct < 0.5 ? 0 : (pct < 2 ? 1 : 2);
    return (r.pnl.amount > 0 ? AppColors.heatPositive : AppColors.heatNegative)[level];
  }

  /// Tanda minus: untung/rugi tetap terbaca tanpa mengandalkan warna.
  static Widget _lossMark(Color color) => Center(
    child: Container(width: 8, height: 2, color: color),
  );

  static Widget _swatch(Color color, {bool loss = false}) => Container(
    width: 14,
    height: 14,
    margin: const EdgeInsets.only(right: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    child: loss ? _lossMark(color == AppColors.negative ? AppColors.surface : AppColors.onNegativeSoft) : null,
  );

  Widget _cell(DateTime day, DailyPerformance? r, DateTime selected) {
    final isLoss = r != null && r.pnl.amount < 0;
    final color = r == null ? AppColors.surfaceMuted : _colorOf(r);
    return Semantics(
      container: true, // satu node per kotak, supaya pembaca layar tidak menggabungkan label antar hari
      selected: day == selected,
      label: '${Fmt.date(day)}, ${r == null ? 'tidak ada catatan' : Fmt.percent(r.pnlPercent)}',
      child: InkWell(
        onTap: () => setState(() => _selected = day),
        child: SizedBox(
          height: _calendarCell,
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: day == selected
                    ? Border.all(color: AppColors.text, width: 2)
                    : (r == null ? Border.all(color: AppColors.border) : null),
              ),
              child: isLoss ? _lossMark(color == AppColors.negative ? AppColors.surface : AppColors.onNegativeSoft) : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final text = Theme.of(context).textTheme;
    final axis = text.labelSmall?.copyWith(color: AppColors.textSecondary);
    final up = rows.where((r) => r.pnl.amount > 0).length;
    final down = rows.where((r) => r.pnl.amount < 0).length;
    final byDate = {for (final r in rows) r.date: r};
    final first = rows.first.date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = rows.last.date.isAfter(today) ? rows.last.date : today;
    final lastMonday = _mondayOf(last);
    // Dibulatkan, bukan inDays: pergantian DST di perangkat bisa menggeser selisih satu jam.
    final weeks = (lastMonday.difference(_mondayOf(first)).inHours / (7 * 24)).round() + 1;
    final selected = _selected ?? rows.last.date;
    final selectedRow = byDate[selected];
    final labelHeight = MediaQuery.textScalerOf(context).scale(18);

    Widget count(String label, int days) => Expanded(
      child: StatTile(label: label, value: Text('$days hari')),
    );

    return ModuleCard(
      title: 'Kalender PnL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              count('Untung', up),
              const SizedBox(width: AppSpacing.sm),
              count('Rugi', down),
              const SizedBox(width: AppSpacing.sm),
              count('Datar', rows.length - up - down),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Sejak ${Fmt.date(first)} · ${rows.length} hari tercatat', style: text.bodySmall),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: labelHeight + 7 * _calendarCell,
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      SizedBox(height: labelHeight),
                      for (final (i, day) in const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].indexed)
                        SizedBox(
                          height: _calendarCell,
                          child: i.isEven
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(day, style: axis)),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: weeks,
                    itemExtent: _calendarCell,
                    itemBuilder: (context, i) {
                      final monday = DateTime(lastMonday.year, lastMonday.month, lastMonday.day - 7 * i);
                      final older = DateTime(monday.year, monday.month, monday.day - 7);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: labelHeight,
                            child: i == weeks - 1 || older.month != monday.month
                                ? Text(
                                    DateFormat(monday.month == 1 ? 'MMM yy' : 'MMM', 'id').format(monday),
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    style: axis,
                                  )
                                : null,
                          ),
                          for (var d = 0; d < 7; d++)
                            () {
                              final day = DateTime(monday.year, monday.month, monday.day + d);
                              return day.isBefore(first) || day.isAfter(last)
                                  ? const SizedBox(height: _calendarCell)
                                  : _cell(day, byDate[day], selected);
                            }(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(
            label: Fmt.date(selected),
            value: selectedRow == null
                ? Text('Tidak ada catatan', style: text.bodySmall)
                : PnlText(amount: selectedRow.pnl, percent: selectedRow.pnlPercent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Text('Rugi', style: axis),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in AppColors.heatNegative.reversed) _swatch(c, loss: true),
                  _swatch(AppColors.segment),
                  for (final c in AppColors.heatPositive) _swatch(c),
                ],
              ),
              Text('Untung', style: axis),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Warna makin pekat = perubahan makin besar (0,5% dan 2%). Kotak kosong = tidak ada catatan, '
            'mis. akhir pekan tanpa aset kripto. Ketuk kotak untuk melihat detail.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

const _valueAxisWidth = 72.0; // sama di kedua grafik supaya area plotnya sejajar

/// Garis nilai harian + PnL per bulan/kuartal/tahun, dengan daftar sebagai tampilan tabel dari grafik.
class _PortfolioValue extends StatefulWidget {
  const _PortfolioValue({required this.rows});
  final List<DailyPerformance> rows;

  @override
  State<_PortfolioValue> createState() => _PortfolioValueState();
}

class _PortfolioValueState extends State<_PortfolioValue> {
  var _granularity = PerformanceGranularity.month;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final periods = groupByPeriod(widget.rows, _granularity);
    return ModuleCard(
      title: 'Nilai portofolio',
      trailing: AmountText(widget.rows.last.portfolioValue, compact: true, style: text.titleSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.rows.length < 2)
            Text('Grafik nilai muncul setelah ada dua catatan harian.', style: text.bodySmall)
          else
            ExcludeSemantics(child: _ValueLine(rows: widget.rows)),
          const SizedBox(height: AppSpacing.md),
          // Di bawah garis: pilihan ini hanya mengatur batang & daftar, garis selalu harian.
          Row(
            children: [
              for (final (i, g) in PerformanceGranularity.values.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PeriodButton(
                    label: g.label,
                    selected: g == _granularity,
                    onTap: () => setState(() => _granularity = g),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text('PnL per ${_granularity.label.toLowerCase()}', style: text.titleSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: _PeriodPnlBars(
              granularity: _granularity,
              // 12 batang terakhir supaya tetap terbaca di ponsel; periode lama tetap ada di daftar bawah.
              periods: periods.sublist(periods.length > 12 ? periods.length - 12 : 0),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final p in periods.reversed)
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_granularity.labelOf(p.start), style: text.bodySmall),
                              AmountText(p.endValue, style: text.titleSmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: PnlText(amount: p.pnl, percent: p.returnPercent, stacked: true),
                          ),
                        ),
                      ],
                    ),
                    if (_versusIndex(p) case final versus?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(versus, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Garis nilai bisa melonjak karena top up. Batang PnL & return (TWR) hanya dari pergerakan harga, '
            'jadi lonjakan garis tanpa batang PnL yang setara berarti top up. Periode pertama dan berjalan belum penuh. '
            '"vs" = selisih return terhadap indeks; plus berarti unggul.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  /// `vs IHSG +0,43% · S&P 500 −0,27%`; `null` bila belum ada data indeks.
  static String? _versusIndex(PeriodPerformance p) {
    final parts = [
      if (p.ihsgReturn case final b?) 'IHSG ${Fmt.percent(p.returnPercent - b)}',
      if (p.sp500Return case final b?) 'S&P 500 ${Fmt.percent(p.returnPercent - b)}',
      if (p.btcReturn case final b?) 'BTC ${Fmt.percent(p.returnPercent - b)}',
    ];
    return parts.isEmpty ? null : 'vs ${parts.join(' · ')}';
  }
}

/// Nilai porto harian. Sumbu X mengikuti tanggal, jadi hari tanpa catatan tetap terlihat sebagai jarak.
class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.rows});
  final List<DailyPerformance> rows;

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final axis = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);
    final first = rows.first.date;
    final origin = DateTime.utc(first.year, first.month, first.day); // UTC: selisih hari kebal DST perangkat
    final spots = [
      for (final r in rows)
        FlSpot(
          DateTime.utc(r.date.year, r.date.month, r.date.day).difference(origin).inDays.toDouble(),
          r.portfolioValue.amount,
        ),
    ];
    final values = spots.map((s) => s.y);
    final low = values.reduce(min);
    final high = values.reduce(max);
    // Garis boleh tidak mulai dari nol; nilai yang datar tetap butuh rentang supaya sumbu terbentuk.
    final pad = high > low ? (high - low) * 0.1 : max(high.abs() * 0.01, 1.0);
    final format = DateFormat(spots.last.x > 180 ? 'MMM yy' : 'd MMM', 'id');
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: low - pad,
          maxY: high + pad,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: _portfolioColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: !hidden, // mode privasi: nominal sumbu tidak ditampilkan
                reservedSize: _valueAxisWidth,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(Fmt.moneyCompact(Money.idr(v)), style: axis),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (spots.last.x / 3).ceilToDouble(),
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(format.format(DateTime(first.year, first.month, first.day + v.toInt())), style: axis),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.text,
              fitInsideHorizontally: true,
              getTooltipItems: (touched) => [
                for (final s in touched)
                  LineTooltipItem(
                    '${Fmt.date(rows[s.spotIndex].date)}\n'
                    '${hidden ? Fmt.hidden : Fmt.money(rows[s.spotIndex].portfolioValue)}',
                    const TextStyle(color: AppColors.surface, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PnL per periode: untung ke atas, rugi ke bawah dari garis nol. Top up tidak ikut terhitung.
class _PeriodPnlBars extends StatelessWidget {
  const _PeriodPnlBars({required this.granularity, required this.periods});
  final PerformanceGranularity granularity;
  final List<PeriodPerformance> periods;

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final axis = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);
    final step = (periods.length / 3).ceil(); // ±3 label agar tidak bertabrakan; dihitung dari batang terbaru
    const corner = Radius.circular(4);
    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: periods.every((p) => p.pnl.amount == 0) ? 1 : null, // semua nol tetap butuh rentang sumbu
          barGroups: [
            for (final (i, p) in periods.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: p.pnl.amount,
                    color: p.pnl.amount < 0 ? AppColors.negative : AppColors.positive,
                    width: 16,
                    // fl_chart memakai sudut apa adanya: batang rugi membulat di ujung bawahnya.
                    borderRadius: p.pnl.amount < 0
                        ? const BorderRadius.vertical(bottom: corner)
                        : const BorderRadius.vertical(top: corner),
                  ),
                ],
              ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [HorizontalLine(y: 0, color: AppColors.textSecondary, strokeWidth: 1)],
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: !hidden, // mode privasi: nominal sumbu tidak ditampilkan
                reservedSize: _valueAxisWidth,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(Fmt.moneyCompact(Money.idr(v)), style: axis),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) => (periods.length - 1 - v.toInt()) % step != 0
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(granularity.labelOf(periods[v.toInt()].start), style: axis),
                      ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.text,
              fitInsideHorizontally: true,
              getTooltipItem: (group, _, _, _) {
                final p = periods[group.x];
                return BarTooltipItem(
                  '${granularity.labelOf(p.start)}\n'
                  '${hidden ? Fmt.hidden : Fmt.money(p.pnl, signed: true)} (${Fmt.percent(p.returnPercent)})',
                  const TextStyle(color: AppColors.surface, fontSize: 12),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Total & rincian PnL harian dalam periode (juga jadi tampilan tabel dari grafik); 5 hari terakhir dulu.
class _DailySummary extends StatefulWidget {
  const _DailySummary({required this.rows, required this.period});
  final List<DailyPerformance> rows;
  final PerformancePeriod period;

  @override
  State<_DailySummary> createState() => _DailySummaryState();
}

class _DailySummaryState extends State<_DailySummary> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final up = rows.where((r) => r.pnl.amount > 0).length;
    final down = rows.where((r) => r.pnl.amount < 0).length;
    DailyPerformance? best, worst;
    for (final r in rows) {
      if (best == null || r.pnl.amount > best.pnl.amount) best = r;
      if (worst == null || r.pnl.amount < worst.pnl.amount) worst = r;
    }
    final recent = rows.reversed.take(_all ? rows.length : 5).toList();
    Widget pair(Widget a, Widget b) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: b),
        ],
      ),
    );
    return ModuleCard(
      title: 'PnL harian · ${widget.period.label}', // pemilih periodenya jauh di atas kartu ini
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pair(
            StatTile(
              label: 'Total periode',
              value: PnlText(amount: Money.idr(rows.fold(0, (s, r) => s + r.pnl.amount))),
            ),
            StatTile(label: 'Hari naik / turun', value: Text('$up / $down')),
          ),
          if ((best != null && best.pnl.amount > 0) || (worst != null && worst.pnl.amount < 0))
            pair(
              best != null && best.pnl.amount > 0
                  ? StatTile(
                      label: 'Terbaik · ${Fmt.date(best.date)}',
                      value: PnlText(amount: best.pnl),
                    )
                  : const SizedBox.shrink(),
              worst != null && worst.pnl.amount < 0
                  ? StatTile(
                      label: 'Terburuk · ${Fmt.date(worst.date)}',
                      value: PnlText(amount: worst.pnl),
                    )
                  : const SizedBox.shrink(),
            ),
          for (final r in recent)
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: InfoRow(
                label: Fmt.date(r.date),
                value: PnlText(amount: r.pnl, percent: r.pnlPercent, stacked: true),
              ),
            ),
          if (rows.length > 5)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _all = !_all),
                child: Text(_all ? 'Tampilkan 5 hari terakhir' : 'Lihat semua ${rows.length} hari'),
              ),
            ),
        ],
      ),
    );
  }
}
