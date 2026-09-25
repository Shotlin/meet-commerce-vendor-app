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
import '../features/profile/presentation/screens/performance_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/requests/presentation/screens/requests_screen.dart';
import '../features/shell/presentation/vendor_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final status = auth.status;
      final loggingIn = state.uri.path == '/phone' || state.uri.path.startsWith('/otp');
      final loggingOut = status == AuthStatus.unauthenticated || status == AuthStatus.unreachable;

      if (status == AuthStatus.booting) return '/phone';
      if (loggingOut && !loggingIn) return '/phone';
      if (status == AuthStatus.authenticated && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/phone',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/performance',
        builder: (context, state) => const PerformanceScreen(),
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
