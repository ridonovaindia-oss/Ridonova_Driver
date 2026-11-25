import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/network/api_service.dart';
import '../models/driver_lost_item_model.dart';

class DriverLostItemsResult {
  final List<DriverLostItemModel> items;
  final int pendingCount;
  final int total;

  DriverLostItemsResult({
    required this.items,
    this.pendingCount = 0,
    this.total = 0,
  });
}

abstract class IDriverLostItemRepository {
  Future<ApiResponse> getDriverLostItems({String? status, String? token});
  Future<ApiResponse> respondToLostItem(String id, {required bool found, String? note, String? token});
}

class DriverLostItemRepository implements IDriverLostItemRepository {
  final ApiService _apiService;

  DriverLostItemRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  @override
  Future<ApiResponse> getDriverLostItems({String? status, String? token}) async {
    final queryParams = status != null && status.isNotEmpty ? {'status': status} : null;
    return await _apiService.get(
      ApiConstants.driverLostItems,
      queryParameters: queryParams,
      token: token,
    );
  }

  @override
  Future<ApiResponse> respondToLostItem(
    String id, {
    required bool found,
    String? note,
    String? token,
  }) async {
    final Map<String, dynamic> body = {'found': found};
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }

    return await _apiService.post(
      ApiConstants.driverRespondLostItem(id),
      data: body,
      token: token,
    );
  }
}

final driverLostItemRepositoryProvider = Provider<IDriverLostItemRepository>((ref) {
  return DriverLostItemRepository();
});
