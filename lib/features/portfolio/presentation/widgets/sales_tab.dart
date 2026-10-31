import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/presentation/bloc/performance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// S03 Riwayat: transaksi jual per periode + total realized PnL per mata uang (tidak dicampur).
class SalesTab extends StatefulWidget {
  const SalesTab({super.key});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  PerformancePeriod? _period; // null = semua

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SalesCubit>();
    return BlocBuilder<SalesCubit, ViewState<List<SaleRecord>>>(
      builder: (context, state) => ViewStateBuilder<List<SaleRecord>>(
        state: state,
        onRetry: cubit.load,
        isEmpty: (sales) => sales.isEmpty,
        empty: const EmptyView(
          icon: Icons.history,
          title: 'Belum ada penjualan',
          message: 'Transaksi jual dan realized PnL akan tampil di sini.',
        ),
        builder: (context, all) {
          final sales = _period?.filter(all, (s) => s.date, DateTime.now()) ?? all;
          final text = Theme.of(context).textTheme;
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                PageBody(
                  child: ChoiceChipBar<PerformancePeriod?>(
                    options: const [null, ...PerformancePeriod.values],
                    selected: _period,
                    labelOf: (p) => p?.label ?? 'Semua',
                    onSelected: (p) => setState(() => _period = p),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PageBody(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Realized PnL · ${sales.length} transaksi', style: text.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        for (final c in Currency.values)
                          if (sales.any((s) => s.currency == c))
                            InfoRow(
                              label: c == Currency.idr ? 'Rupiah' : 'Dolar AS',
                              value: PnlText(
                                amount: Money(
                                  sales.where((s) => s.currency == c).fold(0, (sum, s) => sum + s.realizedPnl.amount),
                                  c,
                                ),
                              ),
                            ),
                        if (sales.isEmpty) Text('Tidak ada penjualan di periode ini.', style: text.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final s in sales)
                  PageBody(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _SaleCard(sale: s),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale});
  final SaleRecord sale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = sale;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.symbol, style: text.titleMedium)),
              Text(Fmt.date(s.date), style: text.bodySmall),
            ],
          ),
          Text([s.exchange.label, if (s.broker.isNotEmpty) s.broker].join(' · '), style: text.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          InfoRow(label: 'Jual ${Fmt.number(s.quantity)} ${s.exchange.quantityLabel}', value: AmountText(s.salePrice)),
          InfoRow(label: 'Hasil jual', value: AmountText(s.proceeds)),
          InfoRow(
            label: 'Realized PnL',
            value: PnlText(amount: s.realizedPnl, percent: s.realizedPercent),
          ),
          if (s.note case final note? when note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
