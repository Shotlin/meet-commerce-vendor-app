import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Five-tab bottom navigation per the blueprint design system §6:
/// Home · Requests · Active · History · Profile. Notifications live in the
/// app bar, not a sixth tab.
class VendorShell extends ConsumerWidget {
  const VendorShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Destination(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home', route: '/home'),
    _Destination(icon: Icons.inbox_outlined, selectedIcon: Icons.inbox, label: 'Requests', route: '/requests'),
    _Destination(icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping, label: 'Active', route: '/active'),
    _Destination(icon: Icons.history_outlined, selectedIcon: Icons.history, label: 'History', route: '/history'),
    _Destination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile', route: '/profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final selectedIndex = _destinations.indexWhere((d) => currentRoute.startsWith(d.route));

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == selectedIndex,
        ),
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon, color: AppColors.brandRed),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}
