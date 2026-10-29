import 'package:arah/core/error/failure.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Merender [ViewState] secara seragam: skeleton → error/empty → konten.
/// Saat refresh atau gagal dengan data lama, konten tetap tampil.
class ViewStateBuilder<T> extends StatelessWidget {
  const ViewStateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.skeleton = const SkeletonList(),
  });

  final ViewState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget skeleton;

  @override
  Widget build(BuildContext context) {
    final data = state.data;
    if (data == null) {
      final failure = state.failure;
      if (failure != null) return ErrorView(failure: failure, onRetry: onRetry);
      return skeleton;
    }
    if (empty != null && (isEmpty?.call(data) ?? false)) return empty!;
    return builder(context, data);
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(message!, style: text.bodySmall, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: failure.code == FailureCode.network ? Icons.wifi_off_outlined : Icons.error_outline,
      title: 'Gagal memuat data',
      message: failure.message,
      actionLabel: failure.isRetryable ? 'Coba lagi' : null,
      onAction: onRetry,
    );
  }
}

/// Error sebaris untuk satu kartu; bagian lain layar tetap bisa dipakai.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.negative, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(failure.message, style: Theme.of(context).textTheme.bodySmall)),
        if (failure.isRetryable && onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    );
  }
}

/// Blok skeleton statis tanpa kilatan, sesuai pedoman transisi.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = AppRadius.field});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.itemHeight = 88});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Memuat',
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.screen.copyWith(top: AppSpacing.lg),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, _) => SkeletonBox(height: itemHeight, radius: AppRadius.card),
      ),
    );
  }
}
