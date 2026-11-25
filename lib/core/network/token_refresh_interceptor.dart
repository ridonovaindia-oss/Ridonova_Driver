import 'dart:async';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'api_constants.dart';
import 'token_storage.dart';
import '../services/navigation_service.dart';
import '../services/socket_service.dart';

/// Interceptor that handles automatic JWT token refreshing on 401 Unauthorized responses.
/// Queues concurrent 401 requests to ensure /api/auth/refresh-token is called exactly once.
class TokenRefreshInterceptor extends QueuedInterceptor {
  final Dio dio;
  static Completer<String?>? _refreshCompleter;
  static bool _isRefreshing = false;

  TokenRefreshInterceptor({required this.dio});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Do NOT attempt token refresh for any auth endpoint to prevent infinite retry loops
    final isAuthEndpoint = path.contains('/auth/') || path.endsWith('/auth/refresh-token');

    if (statusCode == 401 && !isAuthEndpoint) {
      dev.log('401 Unauthorized received on $path. Triggering auto-token refresh...', name: 'TokenRefresh');

      if (_isRefreshing) {
        dev.log('Token refresh already in flight. Queuing request for $path', name: 'TokenRefresh');
        try {
          final newToken = await _refreshCompleter?.future;
          if (newToken != null && newToken.isNotEmpty) {
            final response = await _retryRequest(err.requestOptions, newToken);
            return handler.resolve(response);
          } else {
            return handler.next(err);
          }
        } catch (e) {
          return handler.next(err);
        }
      }

      _isRefreshing = true;
      _refreshCompleter = Completer<String?>();

      try {
        final currentToken = await TokenStorage.getToken();
        if (currentToken == null || currentToken.isEmpty || currentToken == ApiConstants.defaultDevToken) {
          dev.log('No existing token found in secure storage. Logging out driver.', name: 'TokenRefresh');
          _isRefreshing = false;
          _refreshCompleter?.complete(null);
          await _handleSessionExpired();
          return handler.next(err);
        }

        // Call backend POST /api/auth/refresh-token with Authorization: Bearer <current_jwt_token>
        final newToken = await _performRefreshToken(currentToken);

        if (newToken != null && newToken.isNotEmpty) {
          dev.log('Token successfully refreshed. Replaying original request: $path', name: 'TokenRefresh');
          await TokenStorage.saveToken(newToken);
          _refreshCompleter?.complete(newToken);
          _isRefreshing = false;

          // Re-initialize socket with fresh token to prevent connection drop
          try {
            SocketService().initSocket(newToken);
          } catch (_) {}

          // Replay the original failed request with the new token
          final response = await _retryRequest(err.requestOptions, newToken);
          return handler.resolve(response);
        } else {
          dev.log('Refresh token returned empty token or grace period expired. Logging out.', name: 'TokenRefresh');
          _isRefreshing = false;
          _refreshCompleter?.complete(null);
          await _handleSessionExpired();
          return handler.next(err);
        }
      } catch (e) {
        dev.log('Token refresh exception: $e', name: 'TokenRefresh');
        _isRefreshing = false;
        _refreshCompleter?.complete(null);
        await _handleSessionExpired();
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  /// Calls POST /api/auth/refresh-token using a separate dedicated Dio instance
  Future<String?> _performRefreshToken(String oldToken) async {
    try {
      final cleanDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $oldToken',
          },
        ),
      );

      final response = await cleanDio.post(ApiConstants.refreshToken);

      if (response.statusCode == 200 && response.data != null) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final dataMap = data['data'] is Map<String, dynamic> ? data['data'] : data;
          final newToken = (dataMap['token'] ?? data['token']) as String?;
          return newToken;
        }
      }
    } on DioException catch (e) {
      dev.log('Refresh token API failed with status ${e.response?.statusCode}: ${e.message}', name: 'TokenRefresh');
    } catch (e) {
      dev.log('Unexpected refresh token error: $e', name: 'TokenRefresh');
    }
    return null;
  }

  /// Retries the failed request with the new refreshed Bearer token
  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions, String newToken) {
    final newHeaders = Map<String, dynamic>.from(requestOptions.headers);
    newHeaders['Authorization'] = 'Bearer $newToken';

    final options = Options(
      method: requestOptions.method,
      headers: newHeaders,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
    );

    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  /// Clears secure session and redirects driver to PhoneLoginScreen
  Future<void> _handleSessionExpired() async {
    await TokenStorage.clear();
    AppNavigator.logoutAndRedirectToLogin();
  }
}

