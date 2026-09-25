import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FreshCutsVendorApp()));
}

class FreshCutsVendorApp extends ConsumerStatefulWidget {
  const FreshCutsVendorApp({super.key});

  @override
  ConsumerState<FreshCutsVendorApp> createState() => _FreshCutsVendorAppState();
}

class _FreshCutsVendorAppState extends ConsumerState<FreshCutsVendorApp> {
  @override
  void initState() {
    super.initState();
    // 401 anywhere → force logout (session cleared, router redirects to login).
    final api = ref.read(apiClientProvider);
    api.setForceLogout(() {
      ref.read(authProvider.notifier).logout();
    });
    // Session bootstrap: restore token and resolve vendor context.
    Future.microtask(() => ref.read(authProvider.notifier).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FreshCuts Vendor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
