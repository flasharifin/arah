import 'package:arah/app/di.dart';
import 'package:arah/core/security/biometric_lock.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_spacing.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Entri menu fitur pendukung. Setiap `slug` dibuka di `/more/<slug>`.
typedef _MenuEntry = ({IconData icon, String title, String subtitle, String slug});

/// S08 — Lainnya.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static const _plan = <_MenuEntry>[
    (
      icon: Icons.visibility_outlined,
      title: 'Watchlist',
      subtitle: 'Saham yang sedang kamu amati',
      slug: 'watchlist',
    ),
    (icon: Icons.event_repeat_outlined, title: 'DCA', subtitle: 'Rencana beli berkala', slug: 'dca'),
    (
      icon: Icons.payments_outlined,
      title: 'Dividen',
      subtitle: 'Jadwal dan dividen diterima',
      slug: 'dividends',
    ),
  ];

  static const _understand = <_MenuEntry>[
    (
      icon: Icons.shield_outlined,
      title: 'Analisis risiko',
      subtitle: 'Konsentrasi, korelasi, stress test',
      slug: 'analysis',
    ),
    (
      icon: Icons.calculate_outlined,
      title: 'Kalkulator',
      subtitle: 'Lot, position sizing, BEP',
      slug: 'calculator',
    ),
    (icon: Icons.edit_note_outlined, title: 'Jurnal', subtitle: 'Catatan dan PnL harian', slug: 'journal'),
    (
      icon: Icons.mail_outline,
      title: 'Surat investor',
      subtitle: 'Laporan mingguan',
      slug: 'investor-letter',
    ),
  ];

  static const _account = <_MenuEntry>[
    (
      icon: Icons.settings_outlined,
      title: 'Pengaturan',
      subtitle: 'Akun, target, Telegram',
      slug: 'settings',
    ),
    (icon: Icons.help_outline, title: 'Panduan', subtitle: 'Istilah dan cara pakai', slug: 'help'),
  ];

  /// Judul fitur untuk halaman `/more/<slug>`.
  static String titleOf(String slug) =>
      [..._plan, ..._understand, ..._account].where((e) => e.slug == slug).firstOrNull?.title ?? 'Fitur';

  @override
  Widget build(BuildContext context) {
    List<Widget> tiles(List<_MenuEntry> entries) => [
      for (final e in entries)
        MenuTile(
          icon: e.icon,
          title: e.title,
          subtitle: e.subtitle,
          onTap: () => context.go('/more/${e.slug}'),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ruang keuanganmu')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                Text('Semua kebutuhan, satu tempat.', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                const Text('Pantau investasi, susun rencana, dan pahami keputusanmu.'),
                for (final group in [
                  (title: 'Rencanakan', entries: _plan),
                  (title: 'Pahami', entries: _understand),
                ]) ...[
                  SectionHeader(group.title),
                  FeatureMenu(
                    children: [
                      for (final e in group.entries)
                        FeatureTile(
                          icon: e.icon,
                          title: e.title,
                          subtitle: e.subtitle,
                          onTap: () => context.go('/more/${e.slug}'),
                        ),
                    ],
                  ),
                ],
                MenuGroup(
                  title: 'Akun',
                  children: [
                    ...tiles(_account),
                    BlocBuilder<PrivacyCubit, bool>(
                      builder: (context, hidden) => SwitchListTile(
                        title: const Text('Sembunyikan nominal'),
                        value: hidden,
                        onChanged: (_) => context.read<PrivacyCubit>().toggle(),
                      ),
                    ),
                    const _BiometricLockTile(),
                    MenuTile(
                      icon: Icons.logout,
                      title: 'Keluar',
                      destructive: true,
                      onTap: () => _confirmLogout(context),
                    ),
                    MenuTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Hapus akun',
                      subtitle: 'Hapus akun dan semua data secara permanen',
                      destructive: true,
                      onTap: () =>
                          showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final lockOnly = await sl<BiometricLock>().isEnabled();
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: Text(
          lockOnly
              ? 'Masuk lagi cukup dengan ${BiometricLock.name}. Untuk menghapus data akun dari perangkat '
                    'ini, matikan "Kunci dengan ${BiometricLock.name}" dulu.'
              : 'Data akun di perangkat ini akan dibersihkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }
}

/// Aktif/nonaktif kunci sidik jari; setiap perubahan dikonfirmasi biometrik dulu.
class _BiometricLockTile extends StatefulWidget {
  const _BiometricLockTile();

  @override
  State<_BiometricLockTile> createState() => _BiometricLockTileState();
}

class _BiometricLockTileState extends State<_BiometricLockTile> {
  final _lock = sl<BiometricLock>();
  bool _available = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await _lock.isAvailable();
    final enabled = await _lock.isEnabled();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
    });
  }

  Future<void> _toggle(bool value) async {
    if (!await _lock.authenticate()) return;
    await _lock.setEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text('Kunci dengan ${BiometricLock.name}'),
      subtitle: Text(
        _available
            ? 'Masuk dengan ${BiometricLock.name}, juga setelah keluar'
            : 'Daftarkan ${BiometricLock.name} di pengaturan perangkat dulu',
      ),
      value: _enabled,
      onChanged: _available ? _toggle : null,
    );
  }
}

/// Konfirmasi hapus akun dengan password (syarat App Store / Play Store: hapus akun dari dalam app).
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  // AuthState.failure juga dipakai halaman masuk; tampilkan hanya error dari percobaan di dialog ini.
  bool _submitted = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitted = true);
    context.read<AuthBloc>().add(AuthDeleteAccountRequested(_password.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) => current.status == AuthStatus.unauthenticated,
      listener: (context, _) => Navigator.of(context).pop(), // router lalu mengarahkan ke layar masuk
      builder: (context, state) => AlertDialog(
        scrollable: true,
        title: const Text('Hapus akun permanen?'),
        content: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Semua datamu — portofolio, riwayat jual & DCA, dividen, aset, utang, target, jurnal, '
                'dan watchlist — dihapus dari server dan tidak bisa dikembalikan.',
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _password,
                label: 'Password untuk konfirmasi',
                validator: (v) => (v ?? '').isEmpty ? 'Password wajib diisi' : null,
              ),
              if (_submitted && state.failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    state.failure!.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.negative),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: state.isSubmitting ? null : _submit,
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: state.isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Menghapus akun'),
                  )
                : const Text('Hapus permanen'),
          ),
        ],
      ),
    );
  }
}
