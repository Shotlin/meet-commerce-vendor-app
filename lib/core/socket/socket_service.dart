import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/api_constants.dart';

/// Real-time connection status, mirrored for anything that wants to show
/// a "reconnecting…" indicator later.
enum SocketConnectionStatus { disconnected, connecting, connected, error }

/// A parsed `notification` socket event as the backend's
/// `NotificationsService.sendNotification` / `fastify.emitNotification`
/// shape it: `{id, title, body, type, data, is_read, created_at}`, where
/// `data` carries the procurement-specific payload
/// (`ProcurementNotifier`'s `{event, request_id, request_number, ...}`).
class ProcurementSocketEvent {
  const ProcurementSocketEvent({
    required this.title,
    required this.body,
    required this.event,
    this.requestId,
  });

  final String title;
  final String body;
  final String event;
  final String? requestId;

  static ProcurementSocketEvent? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['type'] != 'procurement') return null;
    final data = map['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final event = dataMap['event']?.toString();
    if (event == null || event.isEmpty) return null;
    return ProcurementSocketEvent(
      title: map['title']?.toString() ?? 'FreshCuts Vendor',
      body: map['body']?.toString() ?? '',
      event: event,
      requestId: dataMap['request_id']?.toString(),
    );
  }
}

/// Socket.IO client for the vendor app — the vendor-scoped counterpart of
/// the customer app's `core/socket/socket_service.dart`. The backend
/// already emits a real-time `notification` event to `user:{userId}` the
/// moment a procurement requirement is published to an eligible vendor
/// (`ProcurementNotifier.requestPublished` → `NotificationsService`), but
/// nothing in this app was ever listening for it — vendors only saw a new
/// requirement after manually reopening the app. This wires that up.
class SocketService {
  io.Socket? _socket;

  final _notificationController = StreamController<ProcurementSocketEvent>.broadcast();
  final _statusController = StreamController<SocketConnectionStatus>.broadcast();

  Stream<ProcurementSocketEvent> get procurementEvents => _notificationController.stream;
  Stream<SocketConnectionStatus> get statusStream => _statusController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String accessToken) {
    if (accessToken.trim().isEmpty) return;
    // Already holding a live connection for this exact token — a repeat
    // call (e.g. app-resume reconnect check) should not tear down and
    // rebuild a perfectly healthy socket.
    if (_socket != null && _socket!.connected && _lastToken == accessToken) return;

    _disposeSocket();
    _lastToken = accessToken;
    _statusController.add(SocketConnectionStatus.connecting);

    _socket = io.io(
      ApiConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .setAuth(<String, dynamic>{'token': accessToken})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(1000)
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!
      ..onConnect((_) => _statusController.add(SocketConnectionStatus.connected))
      ..onDisconnect((_) => _statusController.add(SocketConnectionStatus.disconnected))
      ..onConnectError((_) => _statusController.add(SocketConnectionStatus.error))
      ..onError((_) => _statusController.add(SocketConnectionStatus.error))
      ..on('notification', (data) {
        final parsed = ProcurementSocketEvent.tryParse(data);
        if (parsed != null) _notificationController.add(parsed);
      });
  }

  /// Forces a fresh connection attempt — used when the app returns to the
  /// foreground and the OS may have silently dropped the underlying socket
  /// while backgrounded (reconnection settings alone don't always resume
  /// promptly on resume).
  void ensureConnected(String accessToken) {
    if (isConnected) return;
    connect(accessToken);
  }

  String? _lastToken;

  void disconnect() {
    _lastToken = null;
    _disposeSocket();
    _statusController.add(SocketConnectionStatus.disconnected);
  }

  void _disposeSocket() {
    _socket?.off('notification');
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    _disposeSocket();
    _notificationController.close();
    _statusController.close();
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});
