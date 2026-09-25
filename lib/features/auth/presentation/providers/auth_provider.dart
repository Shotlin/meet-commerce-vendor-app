import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/secure_storage_service.dart';

/// Auth/session state machine for the vendor app.
enum AuthStatus { booting, unauthenticated, authenticated, unreachable }

class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.phone,
    this.vendorId,
    this.vendorName,
    this.vendorStatus,
    this.error,
  });

  final AuthStatus status;
  final String? userId;
  final String? phone;
  final String? vendorId;
  final String? vendorName;
  final String? vendorStatus;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? phone,
    String? vendorId,
    String? vendorName,
    String? vendorStatus,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorStatus: vendorStatus ?? this.vendorStatus,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api) : super(const AuthState(status: AuthStatus.booting));

  final ApiClient _api;

  /// Session bootstrap: if a token exists, resolve the vendor context via the
  /// service-profile endpoint (vendor scope resolves from the active
  /// vendor_users membership on the backend).
  Future<void> bootstrap() async {
    final token = await SecureStorageService.accessToken;
    final userId = await SecureStorageService.userId;
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final profile = await _api.get(ApiConstants.vendorServiceProfile);
      final vendorBlock = profile is Map ? profile['vendor'] : null;
      final vendor = vendorBlock is Map ? vendorBlock : <dynamic, dynamic>{};
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: userId,
        vendorId: vendor['id']?.toString(),
        vendorName: vendor['name']?.toString(),
        vendorStatus: vendor['status']?.toString(),
      );
    } on ApiException catch (error) {
      if (error.isNetworkError) {
        state = const AuthState(status: AuthStatus.unreachable);
      } else {
        await SecureStorageService.clear();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = const AuthState(status: AuthStatus.unreachable);
    }
  }

  /// Demo/local login: OTP 123456 for seeded phones. Requests the code, then
  /// verifies it and stores the session.
  Future<void> sendOtp(String phone) async {
    await _api.post(ApiConstants.sendOtp, body: {'phone': phone});
  }

  Future<void> verifyOtp(String phone, String code) async {
    final result = await _api.post(
      ApiConstants.verifyOtp,
      body: {'phone': phone, 'otp': code, 'device_name': 'vendor-app'},
    );
    final accessToken = result is Map ? (result['accessToken'] ?? result['access_token'])?.toString() : null;
    final refreshToken = result is Map ? (result['refreshToken'] ?? result['refresh_token'])?.toString() : null;
    final user = result is Map ? result['user'] : null;
    if (accessToken == null) {
      throw ApiException('Login failed — no token returned', statusCode: 500);
    }
    await SecureStorageService.saveSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: user is Map ? user['id']?.toString() : null,
    );
    await bootstrap();
  }

  Future<void> logout() async {
    await SecureStorageService.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(apiClientProvider)),
);
