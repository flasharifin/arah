import 'package:arah/app/di.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';
import 'package:arah/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Yang bisa diatur: cara kirim dan jenis yang masuk sebagai push. Riwayat dan Telegram tidak terpengaruh.
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  static const _hints = {
    NotificationGroup.important: 'Selalu dikirim sebagai push tersendiri.',
    NotificationGroup.daily: 'Bisa digabung jadi satu push pagi.',
    NotificationGroup.report: 'Bisa digabung jadi satu push pagi.',
  };

  Future<void> _save(BuildContext context, NotificationPrefs prefs) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await context.read<NotificationPrefsCubit>().save(prefs);
    if (result is! Success<void>) {
      messenger.showSnackBar(const SnackBar(content: Text('Pengaturan belum tersimpan. Coba lagi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationPrefsCubit>();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan notifikasi')),
      body: BlocBuilder<NotificationPrefsCubit, ViewState<NotificationPrefs>>(
        builder: (context, state) => ViewStateBuilder<NotificationPrefs>(
          state: state,
          onRetry: cubit.load,
          builder: (context, prefs) => ListView(
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    const _PermissionCard(),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Cara kirim', style: text.titleMedium),
                          RadioGroup<NotificationMode>(
                            groupValue: prefs.mode,
                            onChanged: (mode) => mode == null ? null : _save(context, prefs.withMode(mode)),
                            child: const Column(
                              children: [
                                RadioListTile<NotificationMode>(
                                  contentPadding: EdgeInsets.zero,
                                  value: NotificationMode.separate,
                                  title: Text('Kirim terpisah'),
                                  subtitle: Text('Satu push per pesan, sebagian masuk sekitar 00.00 WIB'),
                                ),
                                RadioListTile<NotificationMode>(
                                  contentPadding: EdgeInsets.zero,
                                  value: NotificationMode.combined,
                                  title: Text('Gabung jadi satu push pagi'),
                                  subtitle: Text('Masuk sekitar 08.00 WIB. Yang penting tetap langsung dikirim'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(AppRadius.field),
                            ),
                            child: Text(
                              prefs.maxDailyPushes == 0
                                  ? 'Tidak ada push rutin harian'
                                  : 'Maksimal ${prefs.maxDailyPushes} push rutin di hari biasa, '
                                        'ditambah laporan dan yang penting kalau ada',
                              style: text.labelLarge?.copyWith(color: AppColors.onAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final group in NotificationGroup.values) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(group.label, style: text.titleMedium),
                            Text(_hints[group]!, style: text.bodySmall),
                            for (final type in NotificationType.values.where((t) => t.group == group))
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(type.label),
                                subtitle: Text(type.hint),
                                value: prefs.isEnabled(type),
                                onChanged: (on) => _save(context, prefs.withType(type, enabled: on)),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Yang dimatikan hanya tidak masuk sebagai push. Isinya tetap tersimpan di daftar Notifikasi, '
                      'dan pesan Telegram tidak ikut berubah.',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatefulWidget {
  const _PermissionCard();

  @override
  State<_PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<_PermissionCard> {
  final _push = sl<PushNotificationService>();
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final granted = await _push.isPermissionGranted();
    if (mounted) setState(() => _granted = granted);
  }

  Future<void> _request() async {
    await _push.requestPermissionAndRegister();
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final granted = _granted;
    if (granted == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: granted ? AppColors.primarySoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(
            granted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            color: granted ? AppColors.primary : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(granted ? 'Izin notifikasi aktif' : 'Izin notifikasi mati', style: text.titleSmall),
                Text(
                  granted ? 'Push bisa masuk ke HP ini' : 'Kalau tidak muncul pilihan, aktifkan dari pengaturan HP',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (!granted) TextButton(onPressed: _request, child: const Text('Izinkan')),
        ],
      ),
    );
  }
}
