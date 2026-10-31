import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:flutter/material.dart';

class WealthItemTile extends StatelessWidget {
  const WealthItemTile({super.key, required this.item, this.onTap});

  final WealthItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: text.labelLarge),
                Text(
                  // Sama dengan web: "Kategori · catatan".
                  [
                    item.category.label,
                    if (item.isAutomatic) 'otomatis',
                    if (item.entry?.note case final note? when note.isNotEmpty) note, // ignore: use_null_aware_elements
                  ].join(' · '),
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
