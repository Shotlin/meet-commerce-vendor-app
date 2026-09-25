import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshcuts_vendor_app/core/network/api_client.dart';

/// ApiClient's onRequest interceptor reads SecureStorageService.accessToken
/// on every call, which hits flutter_secure_storage's platform channel —
/// unavailable in a plain `test()` with no widget binding. Mock it to
/// answer "no token stored" so the interceptor completes normally.
const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Captures what ApiClient actually hands to Dio, without touching the
/// network — a fake HttpClientAdapter that always answers success and
/// records the request body it was given.
class _CapturingAdapter implements HttpClientAdapter {
  Object? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastData = options.data;
    final body = utf8.encode(jsonEncode({'success': true, 'data': {}}));
    return ResponseBody.fromBytes(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // Regression test for a real, live-confirmed bug: Dio's BaseOptions
  // always sets Content-Type: application/json (api_client.dart), but
  // several calls (accept/decline/withdraw-quote) never passed a body at
  // all. Fastify's own JSON body parser rejects a genuinely empty body
  // when that header is present — "Body cannot be empty when
  // content-type is set to 'application/json'" — before the request ever
  // reaches route validation. Confirmed live against production: Accept
  // Offer failed with exactly that error until ApiClient started
  // defaulting a null body to `{}`.
  late ProviderContainer container;
  late _CapturingAdapter adapter;
  late ApiClient client;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _secureStorageChannel,
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
    container = ProviderContainer();
    client = container.read(apiClientProvider);
    adapter = _CapturingAdapter();
    client.dio.httpClientAdapter = adapter;
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _secureStorageChannel,
      null,
    );
  });

  test('post() with no body sends a real empty JSON object, never null', () async {
    await client.post('/vendor-procurement/vendor/requests/x/accept');
    expect(adapter.lastData, isNotNull);
    expect(adapter.lastData, equals(const {}));
  });

  test('patch() with no body sends a real empty JSON object, never null', () async {
    await client.patch('/vendors/x');
    expect(adapter.lastData, isNotNull);
    expect(adapter.lastData, equals(const {}));
  });

  test('put() with no body sends a real empty JSON object, never null', () async {
    await client.put('/vendor-procurement/vendor/service-profile');
    expect(adapter.lastData, isNotNull);
    expect(adapter.lastData, equals(const {}));
  });

  test('post() with a real body still sends that body unchanged', () async {
    await client.post('/auth/send-otp', body: {'phone': '9800000001'});
    expect(adapter.lastData, equals({'phone': '9800000001'}));
  });
}
