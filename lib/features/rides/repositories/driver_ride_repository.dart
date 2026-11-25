import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../models/cancel_reason_model.dart';

abstract class IDriverRideRepository {
  Future<List<CancelReasonModel>> getDriverCancelReasons({String? token});
  Future<ApiResponse> cancelRide(
    String rideId, {
    required String code,
    required String reason,
    String? token,
  });
}

class DriverRideRepository implements IDriverRideRepository {
  final ApiService _apiService;

  DriverRideRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  @override
  Future<List<CancelReasonModel>> getDriverCancelReasons({String? token}) async {
    try {
      final response = await _apiService.get(ApiConstants.driverCancelReasons, token: token);

      if (response.isSuccess && response.data != null) {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final listData = (raw is Map) ? (raw['data'] ?? raw['reasons'] ?? raw['result']) : raw;

        if (listData is List && listData.isNotEmpty) {
          return listData
              .map((e) => CancelReasonModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}

    // Fallback offline list if network fails or endpoint is unreachable
    return CancelReasonModel.fallbackReasons;
  }

  @override
  Future<ApiResponse> cancelRide(
    String rideId, {
    required String code,
    required String reason,
    String? token,
  }) async {
    return await _apiService.post(
      ApiConstants.cancelDriverRide(rideId),
      data: {
        'code': code,
        'reason': reason,
      },
      token: token,
    );
  }
}

final driverRideRepositoryProvider = Provider<IDriverRideRepository>((ref) {
  return DriverRideRepository();
});
