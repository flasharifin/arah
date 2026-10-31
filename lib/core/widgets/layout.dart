import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// TabBar bergaya kontrol segmen (wadah abu, tab aktif putih). Dipakai di `AppBar.bottom`.
class SegmentedTabBar extends StatelessWidget implements PreferredSizeWidget {
  const SegmentedTabBar({super.key, required this.tabs, this.controller});

  final List<String> tabs;
  final TabController? controller;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(color: AppColors.segment, borderRadius: BorderRadius.circular(14)),
        child: TabBar(
          controller: controller,
          tabs: [for (final t in tabs) Tab(text: t, height: 40)],
        ),
      ),
    );
  }
}

/// Tombol "Tanya AI" di header tab utama (AI Chat tidak lagi di navigasi bawah).
class AskAiButton extends StatelessWidget {
  const AskAiButton({super.key, this.compact = false});

  /// Ikon saja (header yang sudah punya tombol utama lain).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void open() => GoRouter.of(context).go('/assistant');
    if (compact) {
      return IconButton.outlined(
        tooltip: 'Tanya AI',
        onPressed: open,
        style: IconButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
          minimumSize: const Size.square(44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.auto_awesome_outlined, size: 20),
      );
    }
    return FilledButton.icon(
      onPressed: open,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.text,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.auto_awesome, size: 18),
      label: const Text('Tanya AI'),
    );
  }
}
