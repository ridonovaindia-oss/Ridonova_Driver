import 'package:dio/dio.dart';
import 'api_constants.dart';
import 'custom_log_interceptor.dart';
import 'token_refresh_interceptor.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();

  factory DioClient({String? baseUrl}) {
    if (baseUrl != null && baseUrl != _instance._dio.options.baseUrl) {
      return DioClient._internal(baseUrl: baseUrl);
    }
    return _instance;
  }

  late final Dio _dio;

  DioClient._internal({String? baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    // 1. Auto Token Refresh Interceptor on 401 Unauthorized
    _dio.interceptors.add(TokenRefreshInterceptor(dio: _dio));

    // 2. CustomLogInterceptor for request/response logging with truncated base64 support
    _dio.interceptors.add(
      CustomLogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  Dio get dio => _dio;

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }
}
