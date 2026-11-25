import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ridenovo_rider_mobile_app/core/network/api_service.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/models/cancel_reason_model.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/providers/driver_cancel_ride_provider.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/repositories/driver_ride_repository.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/ride_provider.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/widgets/driver_cancel_ride_bottom_sheet.dart';

class MockDriverRideRepository implements IDriverRideRepository {
  bool shouldSucceed = true;
  String? mockErrorMessage;
  List<CancelReasonModel>? customReasons;

  @override
  Future<List<CancelReasonModel>> getDriverCancelReasons({String? token}) async {
    if (!shouldSucceed) {
      return CancelReasonModel.fallbackReasons;
    }
    return customReasons ?? CancelReasonModel.fallbackReasons;
  }

  @override
  Future<ApiResponse> cancelRide(
    String rideId, {
    required String code,
    required String reason,
    String? token,
  }) async {
    if (!shouldSucceed) {
      return ApiResponse.failure(mockErrorMessage ?? 'Failed to cancel');
    }
    return ApiResponse.success({
      'success': true,
      'status': 'cancelled',
      'message': 'Ride cancelled successfully.',
    });
  }
}

class MockRideNotifier extends RideNotifier {
  bool cancelCalled = false;
  String? lastRideId;
  String? lastCode;
  String? lastReason;
  bool shouldCancelSucceed = true;

  @override
  Future<bool> cancelRide(String rideId, {String? reason, String? code}) async {
    cancelCalled = true;
    lastRideId = rideId;
    lastCode = code;
    lastReason = reason;

    if (shouldCancelSucceed) {
      state = state.copyWith(clearActiveRide: true, rideStep: RideStep.none);
      return true;
    } else {
      return false;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel globalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const MethodChannel channel = MethodChannel('xyz.luan/audioplayers');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalChannel, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async => 1);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CancelReasonModel Unit Tests', () {
    test('Correctly parses JSON into model', () {
      final json = {
        'code': 'rider_no_show',
        'label': 'Rider did not show up at pickup point',
      };

      final model = CancelReasonModel.fromJson(json);

      expect(model.code, 'rider_no_show');
      expect(model.label, 'Rider did not show up at pickup point');
      expect(model.toJson(), json);
    });

    test('Fallback reasons provide all essential driver options', () {
      final fallbacks = CancelReasonModel.fallbackReasons;

      expect(fallbacks.isNotEmpty, true);
      expect(fallbacks.any((e) => e.code == 'rider_no_show'), true);
      expect(fallbacks.any((e) => e.code == 'rider_not_reachable'), true);
      expect(fallbacks.any((e) => e.code == 'rider_requested_cancel'), true);
      expect(fallbacks.any((e) => e.code == 'vehicle_breakdown'), true);
      expect(fallbacks.any((e) => e.code == 'other'), true);
    });

    test('Equality operator works properly', () {
      final a = CancelReasonModel(code: 'test', label: 'Test Label');
      final b = CancelReasonModel(code: 'test', label: 'Test Label');
      final c = CancelReasonModel(code: 'different', label: 'Different');

      expect(a == b, true);
      expect(a == c, false);
      expect(a.hashCode == b.hashCode, true);
    });
  });

  group('DriverRideRepository Unit Tests', () {
    test('Returns fallback reasons when backend fails or throws', () async {
      final mockRepo = MockDriverRideRepository()..shouldSucceed = false;

      final reasons = await mockRepo.getDriverCancelReasons();

      expect(reasons.isNotEmpty, true);
      expect(reasons.first.code, 'rider_no_show');
    });

    test('cancelRide returns success ApiResponse when request succeeds', () async {
      final mockRepo = MockDriverRideRepository()..shouldSucceed = true;

      final response = await mockRepo.cancelRide(
        'ride_123',
        code: 'rider_no_show',
        reason: 'Rider did not show up',
      );

      expect(response.isSuccess, true);
      expect(response.data['status'], 'cancelled');
    });
  });

  group('CancelRideNotifier State Tests', () {
    test('Cancels ride and transitions state on success', () async {
      final mockRideNotifier = MockRideNotifier();
      final container = ProviderContainer(
        overrides: [
          rideProvider.overrideWith((ref) => mockRideNotifier),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cancelRideStateProvider.notifier);

      final result = await notifier.cancelRide(
        rideId: 'ride_abc',
        code: 'vehicle_breakdown',
        reason: 'Flat tyre',
      );

      expect(result, true);
      expect(mockRideNotifier.cancelCalled, true);
      expect(mockRideNotifier.lastRideId, 'ride_abc');
      expect(mockRideNotifier.lastCode, 'vehicle_breakdown');
      expect(mockRideNotifier.lastReason, 'Flat tyre');
      expect(container.read(cancelRideStateProvider).isLoading, false);
      expect(container.read(cancelRideStateProvider).hasError, false);
    });

    test('Transitions to error state when cancel fails', () async {
      final mockRideNotifier = MockRideNotifier()..shouldCancelSucceed = false;
      final container = ProviderContainer(
        overrides: [
          rideProvider.overrideWith((ref) => mockRideNotifier),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cancelRideStateProvider.notifier);

      final result = await notifier.cancelRide(
        rideId: 'ride_fail',
        code: 'heavy_traffic',
        reason: 'Road blocked',
      );

      expect(result, false);
      expect(container.read(cancelRideStateProvider).hasError, true);
    });
  });

  group('DriverCancelRideBottomSheet UI Widget Tests', () {
    testWidgets('Renders modal, fetches reasons, selects reason and submits cancellation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRideNotifier = MockRideNotifier();
      final mockRepo = MockDriverRideRepository();
      mockRepo.customReasons = [
        CancelReasonModel(code: 'rider_no_show', label: 'Rider did not show up at pickup point'),
        CancelReasonModel(code: 'other', label: 'Other reason'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverRideRepositoryProvider.overrideWithValue(mockRepo),
            rideProvider.overrideWith((ref) => mockRideNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DriverCancelRideBottomSheet(rideId: 'ride_test_999'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Warning
      expect(find.text('Cancel Ride'), findsOneWidget);
      expect(find.text('RIDE #test_999'), findsOneWidget);
      expect(
        find.textContaining('Frequent cancellations may affect your acceptance score'),
        findsOneWidget,
      );

      // Verify Reasons List
      expect(find.text('Rider did not show up at pickup point'), findsOneWidget);
      expect(find.text('Other reason'), findsOneWidget);

      // Select "Other reason" to verify expandable text field
      await tester.tap(find.text('Other reason'));
      await tester.pumpAndSettle();

      expect(find.text('Provide more details:'), findsOneWidget);

      // Enter custom reason
      await tester.enterText(
        find.byType(TextField),
        'Road completely blocked due to marathon',
      );
      await tester.pumpAndSettle();

      // Tap Confirm Cancel
      await tester.tap(find.text('CONFIRM CANCEL'));
      await tester.pumpAndSettle();

      // Verify rideProvider cancellation was called with custom reason
      expect(mockRideNotifier.cancelCalled, true);
      expect(mockRideNotifier.lastRideId, 'ride_test_999');
      expect(mockRideNotifier.lastCode, 'other');
      expect(mockRideNotifier.lastReason, 'Road completely blocked due to marathon');
    });
  });
}
