import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cancel_reason_model.dart';
import '../repositories/driver_ride_repository.dart';
import '../ride_provider.dart';

/// Auto-disposed FutureProvider to fetch driver ride cancellation reasons dynamically
final driverCancelReasonsProvider =
    FutureProvider.autoDispose<List<CancelReasonModel>>((ref) async {
  final repo = ref.watch(driverRideRepositoryProvider);
  return await repo.getDriverCancelReasons();
});

class CancelRideNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CancelRideNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> cancelRide({
    required String rideId,
    required String code,
    required String reason,
  }) async {
    state = const AsyncValue.loading();

    try {
      final success = await _ref.read(rideProvider.notifier).cancelRide(
            rideId,
            code: code,
            reason: reason,
          );

      if (success) {
        state = const AsyncValue.data(null);
        return true;
      } else {
        state = AsyncValue.error(
          'Failed to cancel ride. Please try again.',
          StackTrace.current,
        );
        return false;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final cancelRideStateProvider =
    StateNotifierProvider.autoDispose<CancelRideNotifier, AsyncValue<void>>((ref) {
  return CancelRideNotifier(ref);
});
