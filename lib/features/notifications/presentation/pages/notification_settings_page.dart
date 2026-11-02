import 'package:arah/app/di.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';
import 'package:arah/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:arah/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Pengaturan akun dari sini: back kembali ke Pengaturan notifikasi, bukan ke tab Lainnya.
const accountSettingsRoute = '/home/notifications/settings/account';

/// Yang bisa diatur: cara kirim dan jenis yang masuk sebagai push. Riwayat dan Telegram tidak terpengaruh.
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  static const _hints = {
    NotificationGroup.important: 'Selalu masuk sebagai push tersendiri.',
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
                          const SizedBox(height: AppSpacing.md),
                          _ModeOption(
                            label: 'Gabung jadi satu push pagi',
                            hint: 'Isi lengkap tiap notifikasi tetap ada di daftar',
                            selected: prefs.mode == NotificationMode.combined,
                            onTap: () => _save(context, prefs.copyWith(mode: NotificationMode.combined)),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ModeOption(
                            label: 'Kirim terpisah',
                            hint: 'Satu push untuk tiap pesan',
                            selected: prefs.mode == NotificationMode.separate,
                            onTap: () => _save(context, prefs.copyWith(mode: NotificationMode.separate)),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _PushEstimate(prefs),
                          const SizedBox(height: AppSpacing.xs),
                          _SwitchRow(
                            label: 'Tahan push tengah malam',
                            hint: 'Yang dicek sekitar 00.00 WIB baru masuk ke HP sekitar 08.00 WIB',
                            value: prefs.holdNight,
                            onChanged: (on) => _save(context, prefs.copyWith(holdNight: on)),
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
                            const SizedBox(height: AppSpacing.xs),
                            for (final type in NotificationType.values.where((t) => t.group == group)) ...[
                              const Divider(height: 1, color: AppColors.divider),
                              if (type == NotificationType.drawdown)
                                _DrawdownRow(
                                  value: prefs.isEnabled(type),
                                  onChanged: (on) => _save(context, prefs.withType(type, enabled: on)),
                                )
                              else
                                _SwitchRow(
                                  label: type.label,
                                  hint: type.hint,
                                  value: prefs.isEnabled(type),
                                  onChanged: (on) => _save(context, prefs.withType(type, enabled: on)),
                                ),
                            ],
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

/// Satu pilihan cara kirim: kartu kecil dengan titik pilihan.
class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.label, required this.hint, required this.selected, required this.onTap});
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.field);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: AppColors.primary, width: 6)
                          : Border.all(color: AppColors.textSecondary, width: 2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text(hint, style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Perkiraan jumlah push yang langsung berubah mengikuti pilihan di layar ini.
class _PushEstimate extends StatelessWidget {
  const _PushEstimate(this.prefs);
  final NotificationPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final base = prefs.mode == NotificationMode.combined
        ? 'push gabungan pagi di hari biasa'
        : 'push maksimal di hari biasa';
    final importantOn = NotificationType.values.any((t) => t.group == NotificationGroup.important && prefs.isEnabled(t));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.field)),
      child: Row(
        children: [
          Text(
            '${prefs.maxDailyPushes}',
            style: text.headlineMedium?.copyWith(
              color: AppColors.onAccent,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              importantOn ? '$base, ditambah Penting kalau terjadi' : base,
              style: text.labelLarge?.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.hint, required this.value, required this.onChanged});
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    Text(hint, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saklar drawdown dengan ambang yang berlaku dan pintasan untuk mengubahnya.
class _DrawdownRow extends StatelessWidget {
  const _DrawdownRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  static String _percent(double v) => (v == v.roundToDouble() ? v.toInt().toString() : '$v').replaceAll('.', ',');

  Future<void> _openSettings(BuildContext context) async {
    final settings = context.read<SettingsCubit>();
    await context.push(accountSettingsRoute);
    await settings.load();
  }

  @override
  Widget build(BuildContext context) {
    final threshold = context.select<SettingsCubit, double?>((c) => c.state.data?.drawdownThreshold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SwitchRow(
          label: NotificationType.drawdown.label,
          hint: threshold == null ? NotificationType.drawdown.hint : 'Saat porto turun ${_percent(threshold)}% dari puncak',
          value: value,
          onChanged: onChanged,
        ),
        TextButton.icon(
          onPressed: () => _openSettings(context),
          // Tema memberi lebar minimum tak hingga; tombol ini cukup selebar isinya.
          style: TextButton.styleFrom(minimumSize: const Size(0, 44), padding: EdgeInsets.zero),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right, size: 20),
          label: const Text('Ubah ambang'),
        ),
      ],
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
  // Izin diubah di luar app: cek lagi saat pengguna kembali dari pengaturan HP.
  late final _lifecycle = AppLifecycleListener(onResume: _check);
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final granted = await _push.isPermissionGranted();
    if (mounted) setState(() => _granted = granted);
  }

  Future<void> _openSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _push.openNotificationSettings();
    } on Exception catch (e) {
      debugPrint('[push] buka pengaturan gagal: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka pengaturan. Buka manual: Pengaturan HP → Aplikasi → Arah → Notifikasi.')),
      );
    }
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: granted ? AppColors.primary : AppColors.warning,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Icon(
              granted ? Icons.notifications_none : Icons.notifications_off_outlined,
              size: 20,
              color: AppColors.surface,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(granted ? 'Izin notifikasi aktif' : 'Izin notifikasi mati', style: text.titleSmall),
                Text(granted ? 'Diatur dari pengaturan HP' : 'Aktifkan dari pengaturan HP', style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          OutlinedButton(
            onPressed: _openSettings,
            // Tema memberi lebar minimum tak hingga; di dalam Row tombol ini harus selebar isinya.
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
            ),
            child: const Text('Buka', semanticsLabel: 'Buka pengaturan notifikasi HP'),
          ),
        ],
      ),
    );
  }
}
