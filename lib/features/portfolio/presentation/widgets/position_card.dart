import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter/material.dart';

/// Kartu posisi: lencana bursa, kode + broker, nilai + PnL bertumpuk; baris bawah Jumlah · Rata-rata · Terakhir
/// (kolom sendiri supaya angka panjang seperti 0,0178 unit tidak terpotong).
class PositionCard extends StatelessWidget {
  const PositionCard({super.key, required this.position, this.onTap});

  final Position position;
  final VoidCallback? onTap;

  static ({Color bg, Color fg}) _badge(Exchange e) => switch (e) {
    Exchange.idx => (bg: AppColors.primarySoft, fg: AppColors.primary),
    Exchange.us => (bg: const Color(0xFFE3EEFB), fg: const Color(0xFF1C4F8F)),
    Exchange.crypto => (bg: const Color(0xFFFFF1D6), fg: AppColors.warning),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = position;
    final badge = _badge(p.exchange);
    final small = text.bodySmall;
    final meta = [if (p.broker.isNotEmpty) p.broker, if ((p.sector ?? '').isNotEmpty) p.sector!].join(' · ');
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Detail ${p.symbol}',
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: badge.bg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  p.exchange == Exchange.crypto ? 'CRY' : p.exchange.code,
                  style: text.labelSmall?.copyWith(color: badge.fg, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (meta.isNotEmpty) Text(meta, style: small, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AmountText(
                        p.marketValue ?? p.costBasis,
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (p.unrealizedPnl == null)
                      Text('Modal · harga belum ada', style: small, textAlign: TextAlign.end)
                    else
                      PnlText(
                        amount: p.unrealizedPnl,
                        percent: p.unrealizedPercent,
                        stacked: true,
                        style: text.labelMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _fact(context, 'Jumlah', Text('${Fmt.quantity(p.quantity)} ${p.exchange.quantityLabel}')),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _fact(context, 'Rata-rata', AmountText(p.avgPrice))),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _fact(context, 'Terakhir', AmountText(p.lastPrice), end: true)),
            ],
          ),
        ],
      ),
    );
  }

  /// Label kecil + nilai satu baris yang mengecil bila panjang (tidak terpotong "…").
  static Widget _fact(BuildContext context, String label, Widget value, {bool end = false}) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall?.copyWith(color: AppColors.textSecondary)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: DefaultTextStyle.merge(
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            child: value,
          ),
        ),
      ],
    );
  }
}
