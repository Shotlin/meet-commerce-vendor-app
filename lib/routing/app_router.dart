import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/active/presentation/screens/active_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/otp_verify_screen.dart';
import '../features/auth/presentation/screens/phone_entry_screen.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/active/presentation/screens/supply_detail_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/requests/presentation/screens/quote_form_screen.dart';
import '../features/requests/presentation/screens/request_detail_screen.dart';
import '../features/profile/presentation/screens/business_info_screen.dart';
import '../features/profile/presentation/screens/categories_screen.dart';
import '../features/profile/presentation/screens/documents_screen.dart';
import '../features/profile/presentation/screens/notification_settings_screen.dart';
import '../features/profile/presentation/screens/performance_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/store_allotment_screen.dart';
import '../features/profile/presentation/screens/tax_licenses_screen.dart';
import '../features/requests/presentation/screens/requests_screen.dart';
import '../features/shell/presentation/vendor_shell.dart';
import '../features/splash/presentation/screens/splash_screen.dart';

/// Root Navigator key, exposed so app-root widgets that sit ABOVE the
/// Router in the tree (e.g. `ProcurementAlertListener`, mounted via
/// `MaterialApp.router`'s own `builder`) can still reach a real Navigator
/// context to show a dialog/snackbar in response to a socket event —
/// `builder`'s own context has no Navigator ancestor (the Navigator is a
/// descendant, built by the `child` it's handed), so `Navigator.of()`/
/// `showDialog()` from there would throw "No Navigator found".
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pure decision function behind the router's `redirect` — pulled out so
/// the actual auth-state → destination logic can be unit-tested directly,
/// without needing a full widget tree, a real GoRouter, or real screens.
/// Returns the path to redirect to, or `null` to stay where the caller is.
///
/// While `booting` (session restore in flight), this always sends the
/// caller to `/splash` and nowhere else — regardless of `initialLocation`
/// or whatever the caller was trying to open — so a genuinely logged-in
/// vendor never sees a real flash of the login screen on cold start while
/// `AuthNotifier.bootstrap()`'s network round trip is still in flight; a
/// genuinely logged-out one never sees a flash of the home screen either.
String? resolveAuthRedirect(AuthStatus status, String path) {
  final onSplash = path == '/splash';
  final onAuthScreen = path == '/phone' || path.startsWith('/otp');

  if (status == AuthStatus.booting) {
    return onSplash ? null : '/splash';
  }
  if (status == AuthStatus.authenticated) {
    return (onSplash || onAuthScreen) ? '/home' : null;
  }
  // unauthenticated or unreachable
  return onAuthScreen ? null : '/phone';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    // Cold start always opens here, never on '/home' or '/phone' directly —
    // which one is actually correct isn't known yet (the session restore
    // that decides it, AuthNotifier.bootstrap(), hasn't run its first
    // network round trip). Landing on '/phone' by default (the previous
    // behaviour) meant a genuinely logged-in vendor saw a real flash of the
    // login screen on every cold start, for exactly as long as that
    // request took — this neutral screen is what closes that gap; see
    // resolveAuthRedirect's own doc comment for how it's enforced
    // regardless of this value.
    initialLocation: '/splash',
    redirect: (context, state) => resolveAuthRedirect(auth.status, state.uri.path),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/phone',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/performance',
        builder: (context, state) => const PerformanceScreen(),
      ),
      GoRoute(
        path: '/profile/business-info',
        builder: (context, state) => const BusinessInfoScreen(),
      ),
      GoRoute(
        path: '/profile/tax-licenses',
        builder: (context, state) => const TaxLicensesScreen(),
      ),
      GoRoute(
        path: '/profile/documents',
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: '/profile/store-allotment',
        builder: (context, state) => const StoreAllotmentScreen(),
      ),
      GoRoute(
        path: '/profile/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/profile/notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/otp/:phone',
        builder: (context, state) => OtpVerifyScreen(phone: state.pathParameters['phone'] ?? ''),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => VendorShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/requests', builder: (context, state) => const RequestsScreen()),
            GoRoute(
              path: '/requests/:requestId',
              builder: (context, state) =>
                  RequestDetailScreen(requestId: state.pathParameters['requestId'] ?? ''),
            ),
            GoRoute(
              path: '/requests/:requestId/quote',
              builder: (context, state) =>
                  QuoteFormScreen(requestId: state.pathParameters['requestId'] ?? ''),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/active', builder: (context, state) => const ActiveScreen()),
            GoRoute(
              path: '/supplies/:supplyId',
              builder: (context, state) =>
                  SupplyDetailScreen(supplyId: state.pathParameters['supplyId'] ?? ''),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (context, state) => const HistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen())]),
        ],
      ),
    ],
  );
});
