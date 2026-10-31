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

/// Entri menu fitur pendukung. Setiap `slug` dibuka di `/more/<slug>` (kecuali `assistant` → `/assistant`).
typedef _MenuEntry = ({IconData icon, String title, String subtitle, String slug});

/// S08 — Lainnya: cari fitur → Rencanakan → Pahami (tile 2 kolom) → Akun.
class MorePage extends StatefulWidget {
  const MorePage({super.key});

  static const _plan = <_MenuEntry>[
    (icon: Icons.visibility_outlined, title: 'Watchlist', subtitle: 'Saham yang kamu amati', slug: 'watchlist'),
    (icon: Icons.event_repeat_outlined, title: 'DCA', subtitle: 'Rencana beli berkala', slug: 'dca'),
    (icon: Icons.payments_outlined, title: 'Dividen', subtitle: 'Jadwal dan diterima', slug: 'dividends'),
    (icon: Icons.edit_note_outlined, title: 'Jurnal', subtitle: 'Catatan dan PnL harian', slug: 'journal'),
  ];

  static const _understand = <_MenuEntry>[
    (
      icon: Icons.shield_outlined,
      title: 'Analisis risiko',
      subtitle: 'Konsentrasi, korelasi, stress test',
      slug: 'analysis',
    ),
    (icon: Icons.calculate_outlined, title: 'Kalkulator', subtitle: 'Lot, sizing, BEP, FI', slug: 'calculator'),
    (icon: Icons.mail_outline, title: 'Surat investor', subtitle: 'Ringkasan 7 hari', slug: 'investor-letter'),
    // AI Chat tidak lagi di navigasi bawah.
    (icon: Icons.auto_awesome_outlined, title: 'AI Chat', subtitle: 'Tanya soal portofoliomu', slug: 'assistant'),
  ];

  static const _account = <_MenuEntry>[
    (
      icon: Icons.settings_outlined,
      title: 'Pengaturan',
      subtitle: 'Profil, Telegram, alert drawdown',
      slug: 'settings',
    ),
    (icon: Icons.help_outline, title: 'Panduan', subtitle: 'Istilah dan cara pakai', slug: 'help'),
  ];

  /// Judul fitur untuk halaman `/more/<slug>`.
  static String titleOf(String slug) =>
      [..._plan, ..._understand, ..._account].where((e) => e.slug == slug).firstOrNull?.title ?? 'Fitur';

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  String _query = '';

  static String _path(_MenuEntry e) => e.slug == 'assistant' ? '/assistant' : '/more/${e.slug}';

  bool _match(_MenuEntry e) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty || e.title.toLowerCase().contains(q) || e.subtitle.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final groups = [
      (title: 'Rencanakan', entries: MorePage._plan.where(_match).toList(), tint: AppColors.primarySoft),
      (title: 'Pahami', entries: MorePage._understand.where(_match).toList(), tint: AppColors.accent),
    ];
    final account = MorePage._account.where(_match).toList();
    final searching = _query.trim().isNotEmpty;
    Widget heading(String title) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm, left: AppSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: text.labelMedium?.copyWith(color: AppColors.textSecondary, letterSpacing: 0.7),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ruang keuanganmu')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari fitur: DCA, dividen, kalkulator…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (q) => setState(() => _query = q),
                ),
                for (final group in groups)
                  if (group.entries.isNotEmpty) ...[
                    heading(group.title),
                    FeatureMenu(
                      children: [
                        for (final e in group.entries)
                          FeatureTile(
                            icon: e.icon,
                            title: e.title,
                            subtitle: e.subtitle,
                            tint: group.tint,
                            onTap: () => context.go(_path(e)),
                          ),
                      ],
                    ),
                  ],
                if (searching && account.isEmpty && groups.every((g) => g.entries.isEmpty))
                  const EmptyView(icon: Icons.search_off, title: 'Tidak ada fitur cocok'),
                if (!searching || account.isNotEmpty) ...[
                  heading('Akun'),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final e in account)
                          MenuTile(
                            icon: e.icon,
                            title: e.title,
                            subtitle: e.subtitle,
                            onTap: () => context.go(_path(e)),
                          ),
                        if (!searching) ...[
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
                        ],
                      ],
                    ),
                  ),
                  if (!searching)
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog()),
                        style: TextButton.styleFrom(foregroundColor: AppColors.onNegativeSoft),
                        child: const Text('Hapus akun dan semua data'),
                      ),
                    ),
                ],
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
