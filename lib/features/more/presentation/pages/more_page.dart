import 'package:arah/core/state/privacy_cubit.dart';
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
                MenuGroup(title: 'Rencanakan', children: tiles(_plan)),
                MenuGroup(title: 'Pahami', children: tiles(_understand)),
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
                    MenuTile(
                      icon: Icons.logout,
                      title: 'Keluar',
                      destructive: true,
                      onTap: () => _confirmLogout(context),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Data akun di perangkat ini akan dibersihkan.'),
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
