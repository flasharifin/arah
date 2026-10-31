import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Kartu dasar: putih, border tipis, radius 20. Bisa di-tap.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Kartu utama hijau hutan (datar) untuk nilai ringkasan: net worth, target.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.hero),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Modul kartu berjudul dengan aksi kanan opsional ("Lihat posisi", "Tambah aset"): satu kartu = satu topik.
class ModuleCard extends StatelessWidget {
  const ModuleCard({super.key, required this.title, required this.child, this.action, this.trailing});

  final String title;
  final Widget child;

  /// Tombol teks kanan; atau [trailing] untuk isi bebas (mis. angka utama).
  /// `onPressed: null` = tombol nonaktif (mis. sedang menyimpan).
  final ({String label, VoidCallback? onPressed, IconData? icon})? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              ),
              ?trailing,
              if (action != null)
                TextButton.icon(
                  onPressed: action.onPressed,
                  icon: action.icon == null ? const SizedBox.shrink() : Icon(action.icon, size: 18),
                  label: Text(action.label),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Kotak statistik kecil: label kecil di atas, nilai tebal di bawah (di dalam kartu putih atau hero).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.caption, this.onHero = false});

  final String label;
  final Widget value;
  final String? caption;

  /// Di atas [HeroCard]: kotak hijau gelap, teks terang.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: onHero ? AppColors.heroTile : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: onHero ? AppColors.heroMuted : null)),
          const SizedBox(height: 2),
          DefaultTextStyle.merge(
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: onHero ? Colors.white : AppColors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: value,
          ),
          if (caption != null)
            Text(
              caption!,
              style: text.labelSmall?.copyWith(color: onHero ? AppColors.heroMuted : AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
