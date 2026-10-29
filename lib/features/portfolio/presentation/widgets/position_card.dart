import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter/material.dart';

class PositionCard extends StatelessWidget {
  const PositionCard({super.key, required this.position, this.onTap});

  final Position position;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = position;
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Detail ${p.symbol}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.symbol, style: text.titleMedium),
                Text(
                  [p.exchange.label, if (p.broker.isNotEmpty) p.broker].join(' · '),
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('${Fmt.number(p.quantity)} ${p.exchange.quantityLabel}', style: text.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(p.marketValue),
              PnlText(percent: p.unrealizedPercent, style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
