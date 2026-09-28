import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/notifications/presentation/widgets/procurement_alert_listener.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Must be registered before runApp — FCM needs this handle to exist for
  // the whole app lifetime to invoke it on a background/terminated push.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService.initialize();
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
      // Mounted once, above the Router, so it stays alive across every
      // screen — connects the real-time Socket.IO session to the login
      // state and turns a new-requirement event into a loud alert. See
      // ProcurementAlertListener's own doc comment for why it reaches back
      // into rootNavigatorKey instead of using this builder's own context.
      builder: (context, child) => ProcurementAlertListener(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
