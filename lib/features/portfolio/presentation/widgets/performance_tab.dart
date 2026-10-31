import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/presentation/bloc/performance_cubit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Satu garis grafik: return kumulatif per hari dalam periode.
typedef _Series = ({String label, Color color, List<double> values});

// Kategori tetap (lolos uji CVD dataviz): urutan & warna mengikuti entitas, bukan peringkat.
const _portfolioColor = Color(0xFF2A78D6);
const _ihsgColor = Color(0xFFEB6834);
const _sp500Color = Color(0xFF1BAF7A);
const _btcColor = Color(0xFFEDA100);

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
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                PageBody(
                  child: ChoiceChipBar<PerformancePeriod>(
                    options: PerformancePeriod.values,
                    selected: _period,
                    labelOf: (p) => p.label,
                    onSelected: (p) => setState(() => _period = p),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PageBody(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Return kumulatif', style: text.titleSmall),
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
                const SizedBox(height: AppSpacing.lg),
                PageBody(child: _DailySummary(rows: rows)),
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
                reservedSize: 48,
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
    final text = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 3, color: s.color),
              const SizedBox(width: AppSpacing.xs),
              Text('${s.label} ${Fmt.percent(s.values.last)}', style: text),
            ],
          ),
      ],
    );
  }
}

/// Total & rincian PnL harian dalam periode (juga jadi tampilan tabel dari grafik).
class _DailySummary extends StatelessWidget {
  const _DailySummary({required this.rows});
  final List<DailyPerformance> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final up = rows.where((r) => r.pnl.amount > 0).length;
    final down = rows.where((r) => r.pnl.amount < 0).length;
    DailyPerformance? best, worst;
    for (final r in rows) {
      if (best == null || r.pnl.amount > best.pnl.amount) best = r;
      if (worst == null || r.pnl.amount < worst.pnl.amount) worst = r;
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PnL harian', style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(
            label: 'Total periode',
            value: PnlText(amount: Money.idr(rows.fold(0, (s, r) => s + r.pnl.amount))),
          ),
          InfoRow(label: 'Hari naik / turun', value: Text('$up / $down')),
          if (best != null && best.pnl.amount > 0)
            InfoRow(
              label: 'Terbaik · ${Fmt.date(best.date)}',
              value: PnlText(amount: best.pnl),
            ),
          if (worst != null && worst.pnl.amount < 0)
            InfoRow(
              label: 'Terburuk · ${Fmt.date(worst.date)}',
              value: PnlText(amount: worst.pnl),
            ),
          const Divider(height: AppSpacing.xxl),
          for (final r in rows.reversed)
            InfoRow(
              label: Fmt.date(r.date),
              value: PnlText(amount: r.pnl, percent: r.pnlPercent),
            ),
        ],
      ),
    );
  }
}
