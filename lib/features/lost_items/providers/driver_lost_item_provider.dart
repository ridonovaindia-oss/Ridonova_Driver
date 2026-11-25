import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver_lost_item_model.dart';
import '../repositories/driver_lost_item_repository.dart';

class DriverLostItemState {
  final List<DriverLostItemModel> items;
  final int pendingCount;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;
  final String filter; // 'pending' | 'all'

  DriverLostItemState({
    this.items = const [],
    this.pendingCount = 0,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.filter = 'pending',
  });

  List<DriverLostItemModel> get pendingItems => items.where((e) => e.isPending).toList();
  List<DriverLostItemModel> get resolvedItems => items.where((e) => !e.isPending).toList();

  DriverLostItemState copyWith({
    List<DriverLostItemModel>? items,
    int? pendingCount,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    String? filter,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return DriverLostItemState(
      items: items ?? this.items,
      pendingCount: pendingCount ?? this.pendingCount,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      filter: filter ?? this.filter,
    );
  }
}

class DriverLostItemNotifier extends StateNotifier<DriverLostItemState> {
  final IDriverLostItemRepository _repository;

  DriverLostItemNotifier({IDriverLostItemRepository? repository})
      : _repository = repository ?? DriverLostItemRepository(),
        super(DriverLostItemState()) {
    loadLostItems();
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  /// 1. Fetch Reported Lost Items from Backend (GET /api/driver/lost-items)
  Future<void> loadLostItems({String? status, String? token}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _repository.getDriverLostItems(status: status, token: token);

      if (response.isSuccess && response.data != null) {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final data = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

        List<DriverLostItemModel> loadedItems = [];
        int reportedCount = 0;

        if (data is Map) {
          if (data['items'] is List) {
            loadedItems = (data['items'] as List)
                .map((e) => DriverLostItemModel.fromJson(e as Map<String, dynamic>?))
                .toList();
          }
          if (data['pendingCount'] is num) {
            reportedCount = (data['pendingCount'] as num).toInt();
          } else {
            reportedCount = loadedItems.where((e) => e.isPending).length;
          }
        } else if (data is List) {
          loadedItems = data
              .map((e) => DriverLostItemModel.fromJson(e as Map<String, dynamic>?))
              .toList();
          reportedCount = loadedItems.where((e) => e.isPending).length;
        }

        // Sort: newest reported first
        loadedItems.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

        state = state.copyWith(
          items: loadedItems,
          pendingCount: reportedCount,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.errorMessage ?? 'Failed to load lost item reports.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred: $e',
      );
    }
  }

  /// 2. Submit Captain Response (POST /api/driver/lost-items/:id/respond)
  Future<bool> submitResponse(
    String id, {
    required bool found,
    String? note,
    String? token,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true, clearSuccess: true);

    try {
      final response = await _repository.respondToLostItem(
        id,
        found: found,
        note: note,
        token: token,
      );

      if (response.isSuccess) {
        final newStatus = found ? 'driver_found' : 'driver_not_found';
        final nowIso = DateTime.now().toIso8601String();

        final updatedList = state.items.map((item) {
          if (item.id == id) {
            return item.copyWith(
              status: newStatus,
              driverFound: found,
              driverNote: note,
              driverRespondedAt: nowIso,
            );
          }
          return item;
        }).toList();

        final newPendingCount = updatedList.where((e) => e.isPending).length;

        state = state.copyWith(
          items: updatedList,
          pendingCount: newPendingCount,
          isSubmitting: false,
          successMessage: found
              ? 'Marked as Found! Passenger has been notified.'
              : 'Response recorded. Passenger notified that item was not found.',
        );
        return true;
      } else {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: response.errorMessage ?? 'Failed to submit response. Please try again.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Network error: $e',
      );
      return false;
    }
  }

  /// 3. Realtime Socket Event: lost_item:reported
  void handleIncomingReport(Map<String, dynamic> data) {
    try {
      final newItem = DriverLostItemModel.fromJson(data);
      if (newItem.id.isEmpty) return;

      final existingIndex = state.items.indexWhere((e) => e.id == newItem.id);
      List<DriverLostItemModel> updatedList;

      if (existingIndex >= 0) {
        updatedList = List.from(state.items);
        updatedList[existingIndex] = newItem;
      } else {
        updatedList = [newItem, ...state.items];
      }

      final newPendingCount = updatedList.where((e) => e.isPending).length;

      state = state.copyWith(
        items: updatedList,
        pendingCount: newPendingCount,
      );
    } catch (_) {}
  }

  /// 4. Realtime Socket Event: lost_item:updated
  void handleStatusUpdate(Map<String, dynamic> data) {
    try {
      final id = data['id']?.toString() ?? data['_id']?.toString() ?? '';
      if (id.isEmpty) return;

      final updatedStatus = data['status']?.toString();
      final driverFound = data['driverFound'] as bool?;
      final driverNote = data['driverNote']?.toString();
      final updatedAt = data['updatedAt']?.toString() ?? DateTime.now().toIso8601String();

      final updatedList = state.items.map((item) {
        if (item.id == id) {
          return item.copyWith(
            status: updatedStatus ?? item.status,
            driverFound: driverFound ?? item.driverFound,
            driverNote: driverNote ?? item.driverNote,
            updatedAt: updatedAt,
          );
        }
        return item;
      }).toList();

      final newPendingCount = updatedList.where((e) => e.isPending).length;

      state = state.copyWith(
        items: updatedList,
        pendingCount: newPendingCount,
      );
    } catch (_) {}
  }
}

final driverLostItemProvider = StateNotifierProvider<DriverLostItemNotifier, DriverLostItemState>((ref) {
  final repo = ref.watch(driverLostItemRepositoryProvider);
  return DriverLostItemNotifier(repository: repo);
});
