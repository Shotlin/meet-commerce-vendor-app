import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token storage — access/refresh tokens live in the iOS Keychain /
/// Android Keystore (mirrors the customer app's SecureStorageService).
class SecureStorageService {
  SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccessToken = 'vendor_access_token';
  static const _keyRefreshToken = 'vendor_refresh_token';
  static const _keyUserId = 'vendor_user_id';

  static Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    String? userId,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) await _storage.write(key: _keyRefreshToken, value: refreshToken);
    if (userId != null) await _storage.write(key: _keyUserId, value: userId);
  }

  static Future<String?> get accessToken => _storage.read(key: _keyAccessToken);
  static Future<String?> get refreshToken => _storage.read(key: _keyRefreshToken);
  static Future<String?> get userId => _storage.read(key: _keyUserId);

  static Future<void> clear() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
  }
}
