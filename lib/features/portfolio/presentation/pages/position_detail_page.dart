import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/theme/app_typography.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/portfolio/presentation/widgets/purchase_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// S04 — Detail posisi.
class PositionDetailPage extends StatelessWidget {
  const PositionDetailPage({super.key, required this.positionId});

  final String positionId;

  @override
  Widget build(BuildContext context) {
    final position = context.select<PortfolioBloc, Position?>((b) => b.state.positionById(positionId));
    if (position == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(title: 'Posisi tidak ditemukan'),
      );
    }
    final text = Theme.of(context).textTheme;
    final unit = position.exchange.quantityLabel;

    return Scaffold(
      appBar: AppBar(title: Text(position.symbol)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Harga terakhir', style: text.bodySmall),
                AmountText(position.lastPrice, style: AppTypography.amountLarge),
                Text('${position.exchange.label} · ${position.currency.name.toUpperCase()}', style: text.bodySmall),
                const SectionHeader('Kepemilikan'),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow(label: 'Jumlah', value: Text('${Fmt.number(position.quantity)} $unit')),
                      InfoRow(label: 'Harga rata-rata', value: AmountText(position.avgPrice)),
                      InfoRow(label: 'Modal', value: AmountText(position.costBasis)),
                      InfoRow(label: 'Nilai pasar', value: AmountText(position.marketValue)),
                      InfoRow(
                        label: 'Unrealized PnL',
                        value: PnlText(amount: position.unrealizedPnl, percent: position.unrealizedPercent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    // Form penjualan belum dibuat; tombol nonaktif agar tidak mengklaim fitur aktif.
                    const Expanded(child: OutlinedButton(onPressed: null, child: Text('Catat penjualan'))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => showPurchaseForm(
                          context,
                          symbol: position.symbol,
                          exchange: position.exchange,
                          broker: position.broker,
                        ),
                        child: const Text('Catat pembelian'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => context.go(
                    Uri(
                      path: '/assistant',
                      queryParameters: {'symbol': position.symbol, 'exchange': position.exchange.code},
                    ).toString(),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined),
                      SizedBox(width: AppSpacing.md),
                      Expanded(child: Text('Tanyakan posisi ini ke AI')),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
