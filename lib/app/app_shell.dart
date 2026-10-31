import 'package:arah/app/record_sheet.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigasi utama. Ponsel: Beranda · Portofolio · Catat (+) · Kekayaan · Lainnya; AI Chat dibuka dari tombol
/// "Tanya AI" di header (cabang ke-3 tetap ada supaya percakapan bertahan). Tablet: rail + tombol Catat.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Indeks cabang router (lihat `router.dart`): 0 Beranda, 1 Portofolio, 2 AI Chat, 3 Kekayaan, 4 Lainnya.
  static const _railDestinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Beranda'),
    (icon: Icons.show_chart, selected: Icons.show_chart, label: 'Portofolio'),
    (icon: Icons.auto_awesome_outlined, selected: Icons.auto_awesome, label: 'AI Chat'),
    (icon: Icons.account_balance_wallet_outlined, selected: Icons.account_balance_wallet, label: 'Kekayaan'),
    (icon: Icons.grid_view_outlined, selected: Icons.grid_view_rounded, label: 'Lainnya'),
  ];

  void _select(int branch) => shell.goBranch(branch, initialLocation: branch == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 840;
    // HP landscape (mis. 873×393): lebar seperti tablet tapi pendek → navigasi samping ringkas.
    final short = size.height < 560;
    if (wide) {
      return Scaffold(
        body: Row(
          // Navigasi samping setinggi layar (latar putih penuh), isinya mulai dari atas lalu bisa digulir.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SideNav(
              extended: !short,
              current: shell.currentIndex,
              destinations: _railDestinations,
              onSelect: _select,
              onRecord: () => showRecordSheet(context),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    final current = shell.currentIndex;
    Widget item(int branch, IconData icon, IconData selected, String label) => Expanded(
      child: _NavItem(
        icon: current == branch ? selected : icon,
        label: label,
        selected: current == branch,
        onTap: () => _select(branch),
      ),
    );
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                item(0, Icons.home_outlined, Icons.home, 'Beranda'),
                item(1, Icons.show_chart, Icons.show_chart, 'Portofolio'),
                Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Catat transaksi',
                      child: Material(
                        color: AppColors.primary,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => showRecordSheet(context),
                          child: const SizedBox.square(
                            dimension: 56,
                            child: Icon(Icons.add, size: 28, color: AppColors.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                item(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Kekayaan'),
                item(4, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Lainnya'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigasi samping (tablet & HP landscape). Seluruh isi — logo, tombol Catat, semua tujuan — ada di dalam
/// satu scroll view, jadi tetap terjangkau walau layar pendek / teks diperbesar (NavigationRail hanya
/// menggulir tujuan, logo & tombol di atas ikut terpotong).
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.extended,
    required this.current,
    required this.destinations,
    required this.onSelect,
    required this.onRecord,
  });

  final bool extended;
  final int current;
  final List<({IconData icon, IconData selected, String label})> destinations;
  final ValueChanged<int> onSelect;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('side-nav'),
      color: AppColors.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: extended ? 232 : 92,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: extended ? 24 : 12, horizontal: extended ? 16 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (extended) ...[
                  const Center(child: Image(image: AssetImage('assets/images/arah-logo.png'), width: 96)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRecord,
                    style: FilledButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Catat'),
                  ),
                ] else
                  // Ringkas: logo aplikasi di atas Beranda; Catat jadi item di akhir daftar.
                  const Center(
                    child: Image(image: AssetImage('assets/images/arah-logo.png'), width: 56, semanticLabel: 'Arah'),
                  ),
                SizedBox(height: extended ? 16 : 8),
                for (final (i, d) in destinations.indexed)
                  _SideItem(
                    icon: current == i ? d.selected : d.icon,
                    label: d.label,
                    selected: current == i,
                    extended: extended,
                    onTap: () => onSelect(i),
                  ),
                if (!extended)
                  _SideItem(
                    icon: Icons.add_circle_outline,
                    label: 'Catat',
                    selected: false,
                    extended: false,
                    onTap: onRecord,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final style = TextStyle(
      fontSize: extended ? 14 : 11,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      color: color,
    );
    final indicator = BoxDecoration(
      color: selected ? AppColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(extended ? 14 : 999),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: extended
              ? Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: indicator,
                  child: Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label, style: style, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 32,
                        decoration: indicator,
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(height: 4),
                      Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
