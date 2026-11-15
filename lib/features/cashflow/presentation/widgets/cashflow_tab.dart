import 'dart:math' as math;

import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/presentation/bloc/cashflow_cubit.dart';
import 'package:arah/features/cashflow/presentation/widgets/cash_widgets.dart';
import 'package:arah/features/cashflow/presentation/widgets/cashflow_settings_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _income = Color(0xFF2A78D6); // AppColors.series[0]
const _expense = Color(0xFFEB6834); // AppColors.series[1]

/// Kekayaan › Arus kas (opsi A): pemasukan otomatis (gaji tetap, dividen), investasi dari Sumber dana,
/// pengeluaran = perkiraan dari perubahan saldo kas. Data bulanan dari `/api/cashflow`.
class CashflowTab extends StatelessWidget {
  const CashflowTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CashflowCubit>();
    return BlocBuilder<CashflowCubit, ViewState<CashflowOverview>>(
      builder: (context, state) => ViewStateBuilder<CashflowOverview>(
        state: state,
        onRetry: cubit.load,
        builder: (context, data) => RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xxl),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MonthSwitcher(data: data),
                    const SizedBox(height: AppSpacing.sm),
                    if (!data.settings.hasSalary) ...[const _SetupCard(), const SizedBox(height: AppSpacing.md)],
                    _Hero(data: data),
                    const SizedBox(height: AppSpacing.md),
                    _Waterfall(month: data.summary),
                    const SizedBox(height: AppSpacing.md),
                    _IncomeExpense(series: data.series),
                    if (data.assets.isNotEmpty) ...[const SizedBox(height: AppSpacing.md), _CashBalances(data: data)],
                    const SizedBox(height: AppSpacing.md),
                    _EmergencyCard(fund: data.emergency),
                    const SizedBox(height: AppSpacing.md),
                    _Recent(items: data.recent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.data});
  final CashflowOverview data;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CashflowCubit>();
    final text = Theme.of(context).textTheme;
    final since = data.dataSince;
    return Row(
      children: [
        IconButton(
          tooltip: 'Bulan sebelumnya',
          onPressed: () => cubit.shiftMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(DateFormat('MMMM yyyy', 'id').format(data.month), style: text.titleMedium),
              Text(
                since == null ? 'Belum ada mutasi kas' : 'Tercatat sejak ${Fmt.date(since)}',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Bulan berikutnya',
          onPressed: cubit.isCurrentMonth ? null : () => cubit.shiftMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Atur gaji tetap', style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Gaji masuk otomatis ke aset kas pilihanmu tiap tanggal gajian. Pengeluaran tidak perlu dicatat: '
            'dihitung dari perubahan saldo kas.',
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: () => showCashflowSettings(context), child: const Text('Atur sekarang')),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});
  final CashflowOverview data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = data.summary;
    final plan = data.plan;
    Widget tile(String label, Widget value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(color: AppColors.heroTile, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelSmall?.copyWith(color: AppColors.heroMuted)),
            DefaultTextStyle.merge(
              style: text.titleSmall?.copyWith(color: Colors.white),
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ditabung & diinvestasikan', style: text.bodySmall?.copyWith(color: AppColors.heroMuted)),
                  AmountText(Money.idr(s.saved), style: AppTypography.amountLarge.copyWith(color: Colors.white)),
                ],
              ),
              // Pemasukan sangat kecil → persen ekstrem (mis. −22.000%) yang tidak bermakna: tidak ditampilkan.
              if (s.savingsRatePercent case final r? when r >= -100 && r <= 100)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '${r.round()}% dari pemasukan',
                    style: text.labelMedium?.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              tile('Pemasukan', AmountText(Money.idr(s.totalIncome), compact: true)),
              const SizedBox(width: AppSpacing.sm),
              tile('Pengeluaran*', AmountText(Money.idr(s.expense), compact: true)),
              const SizedBox(width: AppSpacing.sm),
              tile(
                'vs rencana',
                plan == null ? const Text('—') : PnlText(amount: Money.idr(s.saved - plan), onDark: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '*Perkiraan: pemasukan − diinvestasikan − kenaikan kas'
            '${plan == null ? '' : '. Rencana setoran Target ${Fmt.moneyCompact(Money.idr(plan))}/bln'}.',
            style: text.bodySmall?.copyWith(color: AppColors.heroMuted),
          ),
        ],
      ),
    );
  }
}

/// "Ke mana uangnya": gaji → dividen & lain → investasi → pengeluaran → sisa di kas.
class _Waterfall extends StatelessWidget {
  const _Waterfall({required this.month});
  final CashflowMonth month;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final m = month;
    final other = m.dividends + m.otherIncome;
    final levels = [0.0, m.salary, m.salary + other, m.salary + other - m.invested, m.cashDelta];
    final steps = [
      (label: 'Gaji', from: levels[0], to: levels[1], color: _income),
      (label: 'Dividen\n& lain', from: levels[1], to: levels[2], color: _income),
      (label: 'Investasi', from: levels[2], to: levels[3], color: _expense),
      (label: 'Keluar*', from: levels[3], to: levels[4], color: _expense),
      (label: 'Sisa kas', from: 0.0, to: m.cashDelta, color: AppColors.primary),
    ];
    final axis = text.labelSmall?.copyWith(color: AppColors.textSecondary);
    return ModuleCard(
      title: 'Ke mana uangnya',
      child: !m.hasData
          ? Text('Belum ada mutasi kas di bulan ini.', style: text.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label:
                      'Gaji ${Fmt.money(Money.idr(m.salary))}, dividen dan lain ${Fmt.money(Money.idr(other))}, '
                      'diinvestasikan ${Fmt.money(Money.idr(m.invested))}, pengeluaran ${Fmt.money(Money.idr(m.expense))}, '
                      'sisa kas ${Fmt.money(Money.idr(m.cashDelta), signed: true)}',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: 170,
                      child: BarChart(
                        BarChartData(
                          barGroups: [
                            for (final (i, s) in steps.indexed)
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    fromY: math.min(s.from, s.to),
                                    // Langkah nol tetap terlihat sebagai garis tipis.
                                    toY: math.max(s.from, s.to) + (s.from == s.to ? 1 : 0),
                                    color: s.color,
                                    width: 28,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
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
                                showTitles: !hidden,
                                reservedSize: 44,
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
                                reservedSize: 32,
                                getTitlesWidget: (v, meta) => SideTitleWidget(
                                  meta: meta,
                                  child: Text(steps[v.toInt()].label, style: axis, textAlign: TextAlign.center),
                                ),
                              ),
                            ),
                          ),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => AppColors.text,
                              fitInsideHorizontally: true,
                              getTooltipItem: (group, _, _, _) {
                                final s = steps[group.x];
                                final v = s.label == 'Sisa kas' ? s.to : s.to - s.from;
                                return BarTooltipItem(
                                  '${s.label.replaceAll('\n', ' ')}\n${hidden ? '••••' : Fmt.money(Money.idr(v), signed: true)}',
                                  const TextStyle(color: AppColors.surface, fontSize: 12),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _Legend(items: [('Masuk', _income), ('Keluar', _expense), ('Sisa di kas', AppColors.primary)]),
              ],
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (label, color) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: text.bodySmall),
            ],
          ),
      ],
    );
  }
}

/// Pemasukan vs pengeluaran (batang berpasangan) + tingkat tabungan (grafik terpisah, satu sumbu masing-masing).
class _IncomeExpense extends StatefulWidget {
  const _IncomeExpense({required this.series});
  final List<CashflowMonth> series;

  @override
  State<_IncomeExpense> createState() => _IncomeExpenseState();
}

class _IncomeExpenseState extends State<_IncomeExpense> {
  var _months = 12;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final series = widget.series.sublist(widget.series.length - _months);
    final axis = text.labelSmall?.copyWith(color: AppColors.textSecondary);
    final label = DateFormat('MMM', 'id');
    // Persen ekstrem (pemasukan sangat kecil) jadi celah, supaya sumbu tidak tertarik ke −22.000%.
    final rates = [
      for (final m in series)
        switch (m.savingsRatePercent) {
          final r? when r >= -100 && r <= 100 => r,
          _ => null,
        },
    ];
    final avg = rates.whereType<double>().toList();
    Widget bottom(double v, TitleMeta meta) => SideTitleWidget(
      meta: meta,
      child: Text(label.format(series[v.toInt()].month).substring(0, _months == 12 ? 1 : 3), style: axis),
    );
    return ModuleCard(
      title: 'Pemasukan vs pengeluaran',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Di bawah judul, bukan di baris judul: teks diperbesar membuat judul + pilihan meluber.
          ChoiceChipBar<int>(
            options: const [6, 12],
            selected: _months,
            labelOf: (m) => '$m bulan',
            onSelected: (m) => setState(() => _months = m),
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  barGroups: [
                    for (final (i, m) in series.indexed)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 2,
                        barRods: [
                          BarChartRodData(
                            toY: m.totalIncome,
                            color: _income,
                            width: _months == 12 ? 8 : 12,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                          BarChartRodData(
                            toY: m.expense,
                            color: _expense,
                            width: _months == 12 ? 8 : 12,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ],
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
                        showTitles: !hidden,
                        reservedSize: 44,
                        minIncluded: false,
                        maxIncluded: false,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(Fmt.moneyCompact(Money.idr(v)), style: axis),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: bottom)),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.text,
                      fitInsideHorizontally: true,
                      getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                        '${DateFormat('MMM yyyy', 'id').format(series[group.x].month)}\n'
                        '${rodIndex == 0 ? 'Masuk' : 'Keluar'} ${hidden ? '••••' : Fmt.moneyCompact(Money.idr(rod.toY))}',
                        const TextStyle(color: AppColors.surface, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _Legend(items: [('Pemasukan', _income), ('Pengeluaran*', _expense)]),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: Text('Tingkat tabungan', style: text.titleSmall)),
              if (avg.isNotEmpty)
                Text('rata-rata ${(avg.reduce((a, b) => a + b) / avg.length).round()}%', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label:
                'Tingkat tabungan per bulan, terakhir ${rates.last == null ? 'belum ada' : '${rates.last!.round()} persen'}',
            child: ExcludeSemantics(
              child: SizedBox(
                height: 110,
                child: LineChart(
                  LineChartData(
                    minY: math.min(0, avg.isEmpty ? 0 : avg.reduce(math.min)),
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (final (i, r) in rates.indexed) r == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), r),
                        ],
                        color: AppColors.primary,
                        barWidth: 2,
                        dotData: FlDotData(checkToShowDot: (spot, bar) => spot.x == rates.length - 1),
                      ),
                    ],
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: 25,
                          getTitlesWidget: (v, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text('${v.round()}%', style: axis),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: bottom)),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AppColors.text,
                        fitInsideHorizontally: true,
                        getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem(
                              '${DateFormat('MMM yyyy', 'id').format(series[s.x.toInt()].month)}\n${s.y.round()}%',
                              const TextStyle(color: AppColors.surface, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Saldo akhir bulan tiap aset kas (setara rupiah), 6 bulan.
class _CashBalances extends StatelessWidget {
  const _CashBalances({required this.data});
  final CashflowOverview data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final assets = data.assets;
    final months = assets.first.balances.map((b) => b.month).toList();
    final axis = text.labelSmall?.copyWith(color: AppColors.textSecondary);
    // Maks 4 garis berwarna tetap; aset ke-5 dst. digabung "Lainnya" (warna tidak diputar ulang).
    final shown = assets.take(3).toList();
    final rest = assets.skip(3).toList();
    final lines = [
      for (final (i, a) in shown.indexed)
        (name: a.name, color: AppColors.series[i], values: [for (final b in a.balances) b.valueIdr]),
      if (rest.isNotEmpty)
        (
          name: 'Lainnya',
          color: AppColors.series[3],
          values: [
            for (var m = 0; m < months.length; m++)
              rest.every((a) => a.balances[m].valueIdr == null)
                  ? null
                  : rest.fold(0.0, (s, a) => s + (a.balances[m].valueIdr ?? 0)),
          ],
        ),
    ];
    final cashDelta = data.summary.cashDelta;
    return ModuleCard(
      title: 'Saldo kas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              AmountText(Money.idr(data.totalCashIdr), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              PnlText(amount: Money.idr(cashDelta)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineBarsData: [
                    for (final l in lines)
                      LineChartBarData(
                        spots: [
                          for (final (i, v) in l.values.indexed) v == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), v),
                        ],
                        color: l.color,
                        barWidth: 2,
                        dotData: FlDotData(
                          checkToShowDot: (spot, _) => spot.x == l.values.lastIndexWhere((v) => v != null),
                        ),
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
                        showTitles: !hidden,
                        reservedSize: 44,
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
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(DateFormat('MMM', 'id').format(months[v.toInt()]), style: axis),
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
                            '${lines[s.barIndex].name} ${hidden ? '••••' : Fmt.moneyCompact(Money.idr(s.y))}',
                            const TextStyle(color: AppColors.surface, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Legenda + nilai sekarang (label langsung, bukan warna saja).
          for (final (i, a) in shown.indexed)
            InfoRow(
              label: a.name,
              value: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: AppColors.series[i], borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(child: AmountText(a.value)),
                ],
              ),
            ),
          if (rest.isNotEmpty)
            InfoRow(
              label: 'Lainnya (${rest.length} aset)',
              value: AmountText(Money.idr(rest.fold(0.0, (s, a) => s + a.valueIdr))),
            ),
          Text('${months.length} bulan, setara rupiah — aset USD dengan kurs hari ini.', style: text.bodySmall),
        ],
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.fund});
  final EmergencyFund fund;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final covered = fund.coveredMonths;
    final ratio = covered == null ? 0.0 : (covered / fund.targetMonths).clamp(0.0, 1.0);
    // Tombol aksi di bawah, bukan di baris judul: teks diperbesar membuat judul + tombol meluber.
    return ModuleCard(
      title: 'Dana darurat',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          covered == null
              ? Text(
                  'Muncul setelah ada perkiraan pengeluaran (mutasi kas minimal sebulan). '
                  'Target ${fund.targetMonths} bulan pengeluaran.',
                  style: text.bodySmall,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          covered.toStringAsFixed(1).replaceAll('.', ','),
                          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text('dari ${fund.targetMonths} bulan pengeluaran', style: text.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 12,
                        color: AppColors.positive,
                        backgroundColor: AppColors.divider,
                        semanticsLabel: 'Dana darurat',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Kurang',
                            value: AmountText(Money.idr(fund.shortfall ?? 0), compact: true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(
                            label: 'Penuh dalam',
                            value: Text(switch (fund.monthsToFull) {
                              0 => 'Sudah penuh',
                              final n? => '±$n bulan',
                              null => '—',
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Semua aset kas ÷ pengeluaran rata-rata ${fund.basisMonths} bulan terakhir '
                      '(${Fmt.moneyCompact(Money.idr(fund.avgExpense ?? 0))}/bln).',
                      style: text.bodySmall,
                    ),
                  ],
                ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showCashflowSettings(context),
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Atur target & gaji'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.items});
  final List<CashMovement> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    void open() => context.go('/wealth/cash-movements');
    return ModuleCard(
      title: 'Mutasi kas terbaru',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Text(
              'Belum ada. Pilih "Sumber dana" saat mencatat beli/jual/DCA/dividen, atau ubah saldo kas di tab Kekayaan.',
              style: text.bodySmall,
            )
          else
            for (final m in items) CashMovementTile(movement: m, onTap: open),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: open,
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('Lihat semua mutasi'),
            ),
          ),
        ],
      ),
    );
  }
}
