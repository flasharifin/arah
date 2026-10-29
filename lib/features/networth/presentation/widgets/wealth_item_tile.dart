import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:flutter/material.dart';

class WealthItemTile extends StatelessWidget {
  const WealthItemTile({super.key, required this.item});

  final WealthItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: text.labelLarge),
                Text(
                  item.isAutomatic ? '${item.category.label} · otomatis' : item.category.label,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AmountText(item.value),
        ],
      ),
    );
  }
}
