import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/presentation/bloc/cash_movements_cubit.dart';
import 'package:arah/features/cashflow/presentation/widgets/cash_widgets.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

enum _Flow { all, incoming, outgoing }

/// Riwayat mutasi kas: pilih aset, grafik saldo harian, total masuk/keluar, daftar per tanggal.
/// Tekan mutasi → batalkan (saldo dikembalikan; transaksi sumbernya tidak berubah).
class CashMovementsPage extends StatefulWidget {
  const CashMovementsPage({super.key});

  @override
  State<CashMovementsPage> createState() => _CashMovementsPageState();
}

class _CashMovementsPageState extends State<CashMovementsPage> {
  var _flow = _Flow.all;

  Future<void> _confirmReverse(CashMovement m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Batalkan mutasi?'),
        content: Text(
          '${m.title} (${Fmt.money(m.amount, signed: true)}) dikembalikan ke saldo ${m.assetName}. '
          'Transaksi aslinya (posisi, dividen, dsb.) tidak berubah.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Batalkan mutasi')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await context.read<CashMovementsCubit>().reverse(m.id);
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
      (_) => refreshCash(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CashMovementsCubit>();
    final text = Theme.of(context).textTheme;
    final assets = cashAssetsOf(context.watch<NetWorthCubit?>()?.state.data);
    return Scaffold(
      appBar: AppBar(title: const Text('Mutasi kas')),
      body: BlocBuilder<CashMovementsCubit, ViewState<CashMovementPage>>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            PageBody(
              child: ChoiceChipBar<String?>(
                options: [null, for (final a in assets) a.id],
                selected: cubit.assetId,
                labelOf: (id) => id == null ? 'Semua' : assets.firstWhere((a) => a.id == id).name,
                onSelected: (id) => cubit.select(assetId: id),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ViewStateBuilder<CashMovementPage>(
              state: state,
              onRetry: cubit.load,
              // Di dalam ListView: kerangka bawaan (daftar yang bisa digulir) tidak boleh bersarang.
              skeleton: const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              builder: (context, page) {
                final items = page.items
                    .where(
                      (m) => switch (_flow) {
                        _Flow.all => true,
                        _Flow.incoming => m.amount.amount > 0,
                        _Flow.outgoing => m.amount.amount < 0,
                      },
                    )
                    .toList();
                final groups = <DateTime, List<CashMovement>>{};
                for (final m in items) {
                  groups.putIfAbsent(DateTime(m.date.year, m.date.month, m.date.day), () => []).add(m);
                }
                return PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BalanceCard(
                        page: page,
                        onDays: (d) => cubit.select(assetId: cubit.assetId, days: d),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              label: 'Masuk ${page.days} hari',
                              value: PnlText(amount: Money(page.totalIn, page.currency)),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: StatTile(
                              label: 'Keluar ${page.days} hari',
                              value: PnlText(amount: Money(-page.totalOut, page.currency)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<_Flow>(
                        segments: const [
                          ButtonSegment(value: _Flow.all, label: Text('Semua')),
                          ButtonSegment(value: _Flow.incoming, label: Text('Masuk')),
                          ButtonSegment(value: _Flow.outgoing, label: Text('Keluar')),
                        ],
                        selected: {_flow},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => setState(() => _flow = s.first),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (items.isEmpty) Text('Belum ada mutasi di rentang ini.', style: text.bodySmall),
                      for (final MapEntry(key: day, value: rows) in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xs,
                            AppSpacing.sm,
                            AppSpacing.xs,
                            AppSpacing.xs,
                          ),
                          child: Text(DateFormat('EEEE, d MMM', 'id').format(day), style: text.labelLarge),
                        ),
                        AppCard(
                          child: Column(
                            children: [
                              for (final m in rows)
                                CashMovementTile(
                                  movement: m,
                                  showBalance: true,
                                  onTap: m.canReverse ? () => _confirmReverse(m) : null,
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (page.truncated) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Menampilkan 300 mutasi terbaru.', style: text.bodySmall),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Transaksi dengan Sumber dana tercatat otomatis. Saldo yang diubah di Kekayaan muncul sebagai '
                        '"Penyesuaian manual" — di Arus kas selisih ini terbaca sebagai pengeluaran (atau pemasukan lain).',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.page, required this.onDays});
  final CashMovementPage page;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hidden = context.select<PrivacyCubit, bool>((c) => c.state);
    final axis = text.labelSmall?.copyWith(color: AppColors.textSecondary);
    final points = page.balance;
    final last = points.isEmpty ? 0.0 : points.last.value;
    final first = points.isEmpty ? 0.0 : points.first.value;
    final label = DateFormat('d MMM', 'id');
    final step = (points.length / 3).ceilToDouble().clamp(1, double.infinity).toDouble();
    return ModuleCard(
      title: 'Saldo ${page.assetName ?? 'semua kas'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceChipBar<int>(
            options: const [30, 90, 365],
            selected: page.days,
            labelOf: (d) => switch (d) {
              30 => '1B',
              90 => '3B',
              _ => '1T',
            },
            onSelected: onDays,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              AmountText(Money(last, page.currency), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              PnlText(amount: Money(last - first, page.currency)),
            ],
          ),
          if (page.assetName == null) Text('Setara rupiah (USD dengan kurs hari ini)', style: text.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          ExcludeSemantics(
            child: SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (final (i, p) in points.indexed) FlSpot(i.toDouble(), p.value)],
                      color: AppColors.series[0],
                      barWidth: 2,
                      isStepLineChart: true, // saldo berubah per mutasi, bukan bergerak halus
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
                        showTitles: !hidden,
                        reservedSize: 48,
                        minIncluded: false,
                        maxIncluded: false,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(Fmt.moneyCompact(Money(v, page.currency)), style: axis),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: step,
                        maxIncluded: false,
                        getTitlesWidget: (v, meta) => v >= points.length
                            ? const SizedBox.shrink()
                            : SideTitleWidget(
                                meta: meta,
                                child: Text(label.format(points[v.toInt()].date), style: axis),
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
                            '${label.format(points[s.x.toInt()].date)}\n${hidden ? '••••' : Fmt.money(Money(s.y, page.currency))}',
                            const TextStyle(color: AppColors.surface, fontSize: 12),
                          ),
                      ],
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
