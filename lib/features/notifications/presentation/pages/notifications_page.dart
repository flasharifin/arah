import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';
import 'package:arah/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Lonceng di header Beranda dengan jumlah belum dibaca.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<UnreadNotificationsCubit>().state;
    return IconButton.outlined(
      tooltip: count > 0 ? 'Notifikasi, $count belum dibaca' : 'Notifikasi',
      onPressed: () => context.go('/home/notifications'),
      style: IconButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        minimumSize: const Size.square(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_none, size: 20),
      ),
    );
  }
}

/// Riwayat notifikasi. Ketuk untuk membaca isi lengkap, karena push di HP hanya versi terpotong.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationGroup? _filter;

  Future<void> _markRead(String? id) async {
    final unread = context.read<UnreadNotificationsCubit>();
    await context.read<NotificationsCubit>().markRead(id);
    await unread.load();
  }

  void _open(AppNotification notification) {
    if (!notification.isRead) _markRead(notification.id);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _NotificationDetail(notification)));
  }

  static String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
    return switch (days) {
      0 => 'Hari ini',
      1 => 'Kemarin',
      _ => Fmt.date(date),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan notifikasi',
            onPressed: () => context.go('/home/notifications/settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, ViewState<List<AppNotification>>>(
        builder: (context, state) => ViewStateBuilder<List<AppNotification>>(
          state: state,
          onRetry: cubit.load,
          builder: (context, items) {
            if (items.isEmpty) {
              return const EmptyView(
                title: 'Belum ada notifikasi',
                message: 'Briefing, sinyal, dan alert akan tersimpan di sini.',
              );
            }
            final shown = items.where((n) => _filter == null || n.type.group == _filter).toList();
            final unread = shown.where((n) => !n.isRead).length;
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                children: [
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        ChoiceChipBar<NotificationGroup?>(
                          options: const [null, ...NotificationGroup.values],
                          selected: _filter,
                          labelOf: (g) => g?.label ?? 'Semua',
                          onSelected: (g) => setState(() => _filter = g),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                unread > 0 ? '$unread belum dibaca' : 'Semua sudah dibaca',
                                style: text.bodySmall,
                              ),
                            ),
                            TextButton(
                              onPressed: items.any((n) => !n.isRead) ? () => _markRead(null) : null,
                              child: const Text('Tandai semua dibaca'),
                            ),
                          ],
                        ),
                        if (shown.isEmpty) Text('Belum ada notifikasi di kategori ini.', style: text.bodyMedium),
                        for (final (i, n) in shown.indexed) ...[
                          if (i == 0 || _dayLabel(shown[i - 1].createdAt) != _dayLabel(n.createdAt))
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                              child: Text(_dayLabel(n.createdAt), style: text.labelMedium),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _NotificationCard(notification: n, onTap: () => _open(n)),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

IconData _iconOf(NotificationType type) => switch (type) {
  NotificationType.priceAlert => Icons.track_changes,
  NotificationType.drawdown => Icons.trending_down,
  NotificationType.milestone => Icons.flag_outlined,
  NotificationType.briefing => Icons.wb_sunny_outlined,
  NotificationType.dailySummary => Icons.account_balance_wallet_outlined,
  NotificationType.signals => Icons.show_chart,
  NotificationType.weekly || NotificationType.periodic => Icons.description_outlined,
  NotificationType.dca => Icons.autorenew,
};

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = notification;
    final important = n.type.group == NotificationGroup.important;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: important ? AppColors.warningSoft : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Icon(_iconOf(n.type), size: 20, color: important ? AppColors.warning : AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: text.titleSmall?.copyWith(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(Fmt.time(n.createdAt), style: text.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text(n.body.replaceAll('\n', ' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(n.type.group.label, style: text.labelSmall),
                    if (!n.isRead) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                        child: Text('Baru', style: text.labelSmall?.copyWith(color: AppColors.onAccent)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationDetail extends StatelessWidget {
  const _NotificationDetail(this.notification);
  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = notification;
    final route = PushNotificationService.safeRoute(n.route);
    return Scaffold(
      appBar: AppBar(title: Text(n.type.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
        children: [
          Text(n.title, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(Fmt.dateTime(n.createdAt), style: text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          for (final line in n.body.split('\n'))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              // Baris berakhiran titik dua adalah judul bagian dari pesan aslinya.
              child: SelectableText(line, style: line.endsWith(':') ? text.titleSmall : text.bodyMedium),
            ),
        ],
      ),
      bottomNavigationBar: route == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
                child: PrimaryButton(
                  label: 'Buka di aplikasi',
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(route);
                  },
                ),
              ),
            ),
    );
  }
}
