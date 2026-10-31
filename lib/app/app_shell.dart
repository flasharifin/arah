import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Lima tujuan tetap: tab di ponsel, rail di tablet.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
    NavigationDestination(
      icon: Icon(Icons.pie_chart_outline),
      selectedIcon: Icon(Icons.pie_chart),
      label: 'Portofolio',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome),
      label: 'AI Chat',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Kekayaan',
    ),
    NavigationDestination(icon: Icon(Icons.menu), label: 'Lainnya'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    void select(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Image(image: AssetImage('assets/images/arah-logo.png'), width: 96),
              ),
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: destination.icon,
                    selectedIcon: destination.selectedIcon,
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        destinations: _destinations,
        // Tap tab aktif kembali ke layar akar tab tersebut.
        onDestinationSelected: select,
      ),
    );
  }
}
