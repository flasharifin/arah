import 'package:arah/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Membatasi lebar konten 720 px di tablet dan memberi margin layar 20.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.padded = true});

  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: SizedBox(
          width: double.infinity,
          child: padded ? Padding(padding: AppSpacing.screen, child: child) : child,
        ),
      ),
    );
  }
}

/// Judul bagian dengan aksi opsional di kanan ("Lihat →").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (actionLabel != null)
            TextButton.icon(
              onPressed: onAction,
              label: Text(actionLabel!),
              icon: const Icon(Icons.arrow_forward, size: 16),
              iconAlignment: IconAlignment.end,
            ),
        ],
      ),
    );
  }
}

/// Baris label–nilai untuk detail (kepemilikan, ringkasan).
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }
}
