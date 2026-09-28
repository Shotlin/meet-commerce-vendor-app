import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:freshcuts_vendor_app/core/audio/alert_sound_player.dart';
import 'package:freshcuts_vendor_app/core/network/api_client.dart';
import 'package:freshcuts_vendor_app/core/socket/socket_service.dart';
import 'package:freshcuts_vendor_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:freshcuts_vendor_app/features/notifications/presentation/widgets/procurement_alert_listener.dart';
import 'package:freshcuts_vendor_app/routing/app_router.dart' show rootNavigatorKey;

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _FakeSocketService extends SocketService {
  final _fakeController = StreamController<ProcurementSocketEvent>.broadcast();
  final List<String> connectCalls = [];
  int disconnectCalls = 0;

  @override
  Stream<ProcurementSocketEvent> get procurementEvents => _fakeController.stream;

  @override
  void connect(String accessToken) => connectCalls.add(accessToken);

  @override
  void ensureConnected(String accessToken) {}

  @override
  void disconnect() => disconnectCalls++;

  void emit(ProcurementSocketEvent event) => _fakeController.add(event);

  @override
  void dispose() => _fakeController.close();
}

class _FakeAlertSoundPlayer extends AlertSoundPlayer {
  int playLoopCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> playLoop() async => playLoopCalls++;

  @override
  Future<void> stop() async => stopCalls++;
}

// AuthNotifier's constructor only stores the ApiClient — never calls any
// of its methods unless bootstrap()/sendOtp()/etc. are invoked, none of
// which this fake notifier ever calls, so a real (but otherwise unused)
// ApiClient built from the override's own Riverpod ref is safe here.
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.api);

  void setStatus(AuthStatus status) {
    state = AuthState(status: status);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final publishedEvent = const ProcurementSocketEvent(
    title: 'New procurement requirement',
    body: 'FreshCuts — Kolkata published PRQ-20260927-0001 — respond before the deadline.',
    event: 'request_published',
    requestId: 'req-live-check',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _secureStorageChannel,
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _secureStorageChannel,
      null,
    );
  });

  Widget buildHarness(GoRouter router) {
    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => ProcurementAlertListener(child: child ?? const SizedBox.shrink()),
    );
  }

  GoRouter buildRouter() => GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const Scaffold(body: Text('home-screen'))),
          GoRoute(
            path: '/requests/:id',
            builder: (c, s) => Scaffold(body: Text('request-detail-${s.pathParameters['id']}')),
          ),
          GoRoute(path: '/requests', builder: (c, s) => const Scaffold(body: Text('requests-list'))),
        ],
      );

  testWidgets(
    'a request_published socket event rings the looping sound and shows the full-screen alert',
    (tester) async {
      final fakeSocket = _FakeSocketService();
      final fakePlayer = _FakeAlertSoundPlayer();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socketServiceProvider.overrideWithValue(fakeSocket),
            alertSoundPlayerProvider.overrideWithValue(fakePlayer),
          ],
          child: buildHarness(buildRouter()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Requirement'), findsNothing);
      expect(fakePlayer.playLoopCalls, 0);

      fakeSocket.emit(publishedEvent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('New Requirement'), findsOneWidget, reason: 'the alert dialog must actually appear');
      expect(find.textContaining('PRQ-20260927-0001'), findsOneWidget);
      expect(fakePlayer.playLoopCalls, 1, reason: 'the looping alert sound must actually start playing');

      await tester.tap(find.text('View Requirement'));
      await tester.pumpAndSettle();

      expect(find.text('New Requirement'), findsNothing, reason: 'dialog closes on View Requirement');
      expect(fakePlayer.stopCalls, 1, reason: 'the sound must stop once the alert is acted on');
      expect(find.text('request-detail-req-live-check'), findsOneWidget, reason: 'View Requirement must navigate to the real request');
    },
  );

  testWidgets('tapping Dismiss stops the sound without navigating', (tester) async {
    final fakeSocket = _FakeSocketService();
    final fakePlayer = _FakeAlertSoundPlayer();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socketServiceProvider.overrideWithValue(fakeSocket),
          alertSoundPlayerProvider.overrideWithValue(fakePlayer),
        ],
        child: buildHarness(buildRouter()),
      ),
    );
    await tester.pumpAndSettle();

    fakeSocket.emit(publishedEvent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('New Requirement'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('New Requirement'), findsNothing);
    expect(fakePlayer.stopCalls, 1);
    expect(find.text('home-screen'), findsOneWidget, reason: 'Dismiss must not navigate away');
  });

  testWidgets('a non-request_published procurement event shows a plain toast, no sound, no alert dialog', (tester) async {
    final fakeSocket = _FakeSocketService();
    final fakePlayer = _FakeAlertSoundPlayer();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socketServiceProvider.overrideWithValue(fakeSocket),
          alertSoundPlayerProvider.overrideWithValue(fakePlayer),
        ],
        child: buildHarness(buildRouter()),
      ),
    );
    await tester.pumpAndSettle();

    fakeSocket.emit(const ProcurementSocketEvent(
      title: 'Offer accepted — supply order created',
      body: 'You won PRQ-1. Supply order SUP-1 is now active.',
      event: 'offer_awarded',
      requestId: 'req-2',
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('New Requirement'), findsNothing);
    expect(fakePlayer.playLoopCalls, 0);
    expect(find.textContaining('Supply order SUP-1 is now active'), findsOneWidget);
  });

  testWidgets(
    'survives a router recreation (the app rebuilds GoRouter whenever authProvider changes) — the alert still fires afterward',
    (tester) async {
      final fakeSocket = _FakeSocketService();
      final fakePlayer = _FakeAlertSoundPlayer();

      // Mirrors app_router.dart's real routerProvider shape — a Provider
      // that rebuilds (and hands MaterialApp.router a BRAND NEW GoRouter
      // object) every time authProvider's state changes. Reproduced here,
      // rather than reusing the app's real routerProvider + real screens,
      // to isolate exactly the one property under test: does
      // ProcurementAlertListener's socket subscription and its use of
      // rootNavigatorKey survive that recreation, without dragging in
      // every real screen's own network calls.
      final testRouterProvider = Provider<GoRouter>((ref) {
        ref.watch(authProvider);
        return buildRouter();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socketServiceProvider.overrideWithValue(fakeSocket),
            alertSoundPlayerProvider.overrideWithValue(fakePlayer),
            authProvider.overrideWith((ref) => _FakeAuthNotifier(ref.watch(apiClientProvider))),
          ],
          child: Consumer(
            builder: (context, ref, _) => buildHarness(ref.watch(testRouterProvider)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final authNotifier = ProviderScope.containerOf(
        tester.element(find.byType(Consumer)),
      ).read(authProvider.notifier) as _FakeAuthNotifier;

      // Trigger the exact recreation this app performs on every login/logout.
      authNotifier.setStatus(AuthStatus.authenticated);
      await tester.pumpAndSettle();
      authNotifier.setStatus(AuthStatus.unauthenticated);
      await tester.pumpAndSettle();
      authNotifier.setStatus(AuthStatus.authenticated);
      await tester.pumpAndSettle();

      fakeSocket.emit(publishedEvent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('New Requirement'),
        findsOneWidget,
        reason: 'the alert must still fire after the router has been recreated by an auth transition',
      );
      expect(fakePlayer.playLoopCalls, 1);
    },
  );
}
