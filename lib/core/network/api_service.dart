import 'package:dio/dio.dart';
import 'dio_client.dart';
import 'token_storage.dart';

enum HttpMethod { get, post, put, delete, patch }

class ApiResponse {
  final bool isSuccess;
  final int? statusCode;
  final dynamic data;
  final String? errorMessage;

  ApiResponse({required this.isSuccess, this.statusCode, this.data, this.errorMessage});

  factory ApiResponse.success(dynamic data, {int? statusCode}) {
    return ApiResponse(isSuccess: true, statusCode: statusCode, data: data);
  }

  factory ApiResponse.failure(String errorMessage, {int? statusCode, dynamic data}) {
    return ApiResponse(isSuccess: false, statusCode: statusCode, errorMessage: errorMessage, data: data);
  }
}

class ApiService {
  final DioClient _dioClient;

  ApiService({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  /// Generic request executor that takes [endpoint], [method], [data], [queryParameters], and [headers]
  Future<ApiResponse> request({
    required String endpoint,
    required HttpMethod method,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final dio = _dioClient.dio;

      String? resolvedToken = token;
      if (resolvedToken == null || resolvedToken.isEmpty) {
        resolvedToken = await TokenStorage.getToken();
      }

      final activeToken = resolvedToken ?? '';

      final options = Options(
        method: method.name.toUpperCase(),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (activeToken.isNotEmpty) 'Authorization': 'Bearer $activeToken',
          if (headers != null) ...headers,
        },
      );

      final response = await dio.request(endpoint, data: data, queryParameters: queryParameters, options: options);

      return ApiResponse.success(response.data, statusCode: response.statusCode);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Convenience GET request
  Future<ApiResponse> get(String endpoint, {Map<String, dynamic>? queryParameters, Map<String, String>? headers, String? token}) {
    return request(endpoint: endpoint, method: HttpMethod.get, queryParameters: queryParameters, headers: headers, token: token);
  }

  // Convenience POST request
  Future<ApiResponse> post(String endpoint, {dynamic data, Map<String, dynamic>? queryParameters, Map<String, String>? headers, String? token}) {
    return request(endpoint: endpoint, method: HttpMethod.post, data: data, queryParameters: queryParameters, headers: headers, token: token);
  }

  // Convenience PUT request
  Future<ApiResponse> put(String endpoint, {dynamic data, Map<String, dynamic>? queryParameters, Map<String, String>? headers, String? token}) {
    return request(endpoint: endpoint, method: HttpMethod.put, data: data, queryParameters: queryParameters, headers: headers, token: token);
  }

  // Convenience DELETE request
  Future<ApiResponse> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? token,
  }) {
    return request(endpoint: endpoint, method: HttpMethod.delete, data: data, queryParameters: queryParameters, headers: headers, token: token);
  }

  // Convenience PATCH request
  Future<ApiResponse> patch(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? token,
  }) {
    return request(endpoint: endpoint, method: HttpMethod.patch, data: data, queryParameters: queryParameters, headers: headers, token: token);
  }

  ApiResponse _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiResponse.failure('Connection timed out. Please check your internet connection.', statusCode: error.response?.statusCode, data: error.response?.data);
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        String serverMessage = 'Server error occurred';
        if (responseData is Map) {
          serverMessage = (responseData['message'] ?? responseData['error'] ?? error.response?.statusMessage ?? 'Server error occurred').toString();
        } else if (responseData is String && responseData.isNotEmpty) {
          serverMessage = responseData;
        }
        return ApiResponse.failure(serverMessage, statusCode: statusCode, data: responseData);
      case DioExceptionType.cancel:
        return ApiResponse.failure('Request was cancelled.');
      case DioExceptionType.connectionError:
        return ApiResponse.failure('No internet connection available.');
      default:
        return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }
}
