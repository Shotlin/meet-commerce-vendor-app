import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/alert_sound_player.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../routing/app_router.dart' show rootNavigatorKey;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../requests/presentation/providers/request_list_provider.dart';
import 'new_requirement_alert_dialog.dart';

/// Mounted once, at the app root (see `main.dart`'s `MaterialApp.router`
/// `builder`), so it stays alive across every route and tab.
///
/// Wires the Socket.IO connection to the auth session (connect on login,
/// disconnect on logout) and turns a real-time `request_published` event
/// into a hard-to-miss alert: a looping sound (like a ride-hailing driver
/// app's new-job alert) plus a full-screen dialog, instead of the vendor
/// only finding out a requirement exists next time they happen to reopen
/// the app. Other procurement events (awarded/cancelled/etc.) get a
/// lighter toast — same socket pipe, no siren.
class ProcurementAlertListener extends ConsumerStatefulWidget {
  const ProcurementAlertListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProcurementAlertListener> createState() => _ProcurementAlertListenerState();
}

class _ProcurementAlertListenerState extends ConsumerState<ProcurementAlertListener>
    with WidgetsBindingObserver {
  StreamSubscription<ProcurementSocketEvent>? _eventSub;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSub = ref.read(socketServiceProvider).procurementEvents.listen(_handleEvent);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The OS can silently drop the socket while the app is backgrounded;
      // reconnection settings alone don't always resume promptly on
      // resume, so force a check the moment the vendor comes back.
      SecureStorageService.accessToken.then((token) {
        if (token != null && token.isNotEmpty) {
          ref.read(socketServiceProvider).ensureConnected(token);
        }
      });
    }
  }

  void _handleEvent(ProcurementSocketEvent event) {
    if (!mounted) return;

    // Refresh whichever request-inbox filters are currently instantiated
    // so the list behind the alert is already up to date the moment the
    // vendor dismisses it or navigates in — never stale until a manual
    // pull-to-refresh.
    for (final filter in const ['NEW', 'RESPONDED', 'CLOSED']) {
      final notifier = ref.read(requestListProvider(filter).notifier);
      notifier.load(filter: filter);
    }

    if (event.event == 'request_published') {
      _ringAndShowAlert(event);
    } else {
      _showLightToast(event);
    }
  }

  Future<void> _ringAndShowAlert(ProcurementSocketEvent event) async {
    if (_dialogShowing) return;
    // Use the root Navigator's own context, not this widget's — this
    // widget is mounted above the Router (see app_router.dart's
    // rootNavigatorKey doc comment), so its own `context` has no
    // Navigator ancestor for showDialog to find.
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) return;
    _dialogShowing = true;
    final player = ref.read(alertSoundPlayerProvider);
    unawaited(player.playLoop());
    try {
      await showNewRequirementAlert(dialogContext, event);
    } finally {
      await player.stop();
      _dialogShowing = false;
    }
  }

  void _showLightToast(ProcurementSocketEvent event) {
    final toastContext = rootNavigatorKey.currentContext;
    if (toastContext == null) return;
    final messenger = ScaffoldMessenger.maybeOf(toastContext);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(event.body.isNotEmpty ? event.body : event.title),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Connect/disconnect the socket in lockstep with the session — the
    // idiomatic Riverpod way to run a side effect off state changes from
    // inside build() (a fresh call each build, deduped by the framework).
    ref.listen<AuthState>(authProvider, (previous, next) {
      final socket = ref.read(socketServiceProvider);
      if (next.status == AuthStatus.authenticated) {
        SecureStorageService.accessToken.then((token) {
          if (token != null && token.isNotEmpty) socket.connect(token);
        });
        // Closes the app-is-fully-closed gap Socket.IO can't cover — see
        // PushNotificationService's own doc comment. Fire-and-forget: a
        // registration failure must never block login.
        unawaited(PushNotificationService.registerToken(ref.read(apiClientProvider)));
      } else if (previous?.status == AuthStatus.authenticated) {
        socket.disconnect();
      }
    });

    return widget.child;
  }
}
