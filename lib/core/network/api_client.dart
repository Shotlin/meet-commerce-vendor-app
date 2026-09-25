import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

/// Thrown by [ApiClient] for backend error envelopes (success: false).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isAuthError => statusCode == 401;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

/// Dio wrapper — Bearer token from secure storage, response envelope
/// unwrapping, and 401 → force-logout hook. Mirrors the customer app's
/// DioClient interceptor chain, trimmed to what the vendor app needs.
class ApiClient {
  ApiClient(Ref ref) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;

  Dio get dio => _dio;

  void setForceLogout(void Function() onForceLogout) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onForceLogout();
          }
          handler.next(error);
        },
      ),
    );
  }

  dynamic _unwrap(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == false) {
        throw ApiException(
          data['message']?.toString() ?? 'Request failed',
          statusCode: response.statusCode,
          code: data['code']?.toString(),
        );
      }
      return data['data'] ?? data;
    }
    return data;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      return _unwrap(response);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.post(path, data: body, queryParameters: query);
      return _unwrap(response);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    try {
      final response = await _dio.patch(path, data: body);
      return _unwrap(response);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<dynamic> put(String path, {Object? body}) async {
    try {
      final response = await _dio.put(path, data: body);
      return _unwrap(response);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  ApiException _toApiException(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiException(
        data['message']?.toString() ?? 'Something went wrong',
        statusCode: error.response?.statusCode,
        code: data['code']?.toString(),
      );
    }
    return ApiException(
      'No internet connection. Check your network and try again.',
      statusCode: null,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));
