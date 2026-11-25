import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridenovo_rider_mobile_app/core/network/api_service.dart';
import 'package:ridenovo_rider_mobile_app/features/lost_items/models/driver_lost_item_model.dart';
import 'package:ridenovo_rider_mobile_app/features/lost_items/presentation/driver_lost_items_screen.dart';
import 'package:ridenovo_rider_mobile_app/features/lost_items/providers/driver_lost_item_provider.dart';
import 'package:ridenovo_rider_mobile_app/features/lost_items/repositories/driver_lost_item_repository.dart';

class MockDriverLostItemRepository implements IDriverLostItemRepository {
  bool shouldSucceed = true;
  String? mockErrorMessage;
  List<DriverLostItemModel> mockItems = [];

  @override
  Future<ApiResponse> getDriverLostItems({String? status, String? token}) async {
    if (!shouldSucceed) {
      return ApiResponse.failure(mockErrorMessage ?? 'Failed to load lost items');
    }
    return ApiResponse.success({
      'success': true,
      'data': {
        'items': mockItems.map((e) => e.toJson()).toList(),
        'pendingCount': mockItems.where((e) => e.isPending).length,
        'total': mockItems.length,
      },
    });
  }

  @override
  Future<ApiResponse> respondToLostItem(
    String id, {
    required bool found,
    String? note,
    String? token,
  }) async {
    if (!shouldSucceed) {
      return ApiResponse.failure(mockErrorMessage ?? 'Failed to respond');
    }
    return ApiResponse.success({
      'success': true,
      'message': 'Response recorded!',
      'data': {
        'id': id,
        'status': found ? 'driver_found' : 'driver_not_found',
        'driverFound': found,
        'driverNote': note,
        'driverRespondedAt': DateTime.now().toIso8601String(),
      },
    });
  }
}

void main() {
  group('DriverLostItemModel Tests', () {
    test('Correctly parses JSON response from backend', () {
      final json = {
        'id': 'lost-12345',
        'rideId': 'RIDE-8899',
        'riderId': 'usr-rider-1',
        'category': 'phone',
        'description': 'Black iPhone 13 with silicone case',
        'contactPhone': '9876543210',
        'status': 'reported',
        'driverFound': null,
        'driverNote': null,
        'driverRespondedAt': null,
        'pickupAddress': 'Connaught Place, New Delhi',
        'dropoffAddress': 'Saket Mall, New Delhi',
        'reportedAt': '2026-11-15T13:30:00.000Z',
      };

      final model = DriverLostItemModel.fromJson(json);

      expect(model.id, 'lost-12345');
      expect(model.rideId, 'RIDE-8899');
      expect(model.category, 'phone');
      expect(model.categoryEmoji, '📱');
      expect(model.categoryDisplayName, 'Phone');
      expect(model.isPending, true);
      expect(model.isFound, false);
      expect(model.isNotFound, false);
      expect(model.isResolved, false);
      expect(model.statusDisplayName, 'Action Required');
    });

    test('Helper getters correctly identify status transitions', () {
      final foundItem = DriverLostItemModel(
        id: 'lost-1',
        rideId: 'R-1',
        category: 'wallet',
        description: 'Brown leather wallet',
        status: 'driver_found',
        driverFound: true,
        driverNote: 'Safe with captain',
      );

      expect(foundItem.isPending, false);
      expect(foundItem.isFound, true);
      expect(foundItem.isNotFound, false);
      expect(foundItem.categoryEmoji, '👛');
      expect(foundItem.statusDisplayName, 'Found by You');

      final notFoundItem = DriverLostItemModel(
        id: 'lost-2',
        rideId: 'R-2',
        category: 'keys',
        description: 'Bike keys with keychain',
        status: 'driver_not_found',
        driverFound: false,
      );

      expect(notFoundItem.isPending, false);
      expect(notFoundItem.isFound, false);
      expect(notFoundItem.isNotFound, true);
      expect(notFoundItem.isResolved, true);
      expect(notFoundItem.categoryEmoji, '🔑');
      expect(notFoundItem.statusDisplayName, 'Not Found');

      final returnedItem = DriverLostItemModel(
        id: 'lost-3',
        rideId: 'R-3',
        category: 'bag',
        description: 'Black backpack',
        status: 'returned',
      );

      expect(returnedItem.isReturned, true);
      expect(returnedItem.isResolved, true);
      expect(returnedItem.categoryEmoji, '🎒');
      expect(returnedItem.statusDisplayName, 'Returned to Passenger');
    });

    test('copyWith updates specified fields only', () {
      final original = DriverLostItemModel(
        id: 'lost-original',
        rideId: 'R-100',
        category: 'electronics',
        description: 'Earbuds case',
        status: 'reported',
      );

      final updated = original.copyWith(
        status: 'driver_found',
        driverFound: true,
        driverNote: 'Found on seat',
      );

      expect(updated.id, 'lost-original');
      expect(updated.category, 'electronics');
      expect(updated.status, 'driver_found');
      expect(updated.driverFound, true);
      expect(updated.driverNote, 'Found on seat');
      expect(original.status, 'reported'); // Immutability preserved
    });
  });

  group('DriverLostItemNotifier & State Tests', () {
    late MockDriverLostItemRepository mockRepo;
    late DriverLostItemNotifier notifier;

    setUp(() {
      mockRepo = MockDriverLostItemRepository();
      mockRepo.mockItems = [
        DriverLostItemModel(
          id: 'lost-1',
          rideId: 'R-1',
          category: 'phone',
          description: 'Phone left in car',
          status: 'reported',
          reportedAt: '2026-11-15T12:00:00Z',
        ),
        DriverLostItemModel(
          id: 'lost-2',
          rideId: 'R-2',
          category: 'wallet',
          description: 'Wallet on floor',
          status: 'driver_found',
          driverFound: true,
          reportedAt: '2026-11-14T12:00:00Z',
        ),
      ];
      notifier = DriverLostItemNotifier(repository: mockRepo);
    });

    test('Initial loadLostItems populates items and pendingCount', () async {
      await notifier.loadLostItems();

      expect(notifier.state.items.length, 2);
      expect(notifier.state.pendingCount, 1);
      expect(notifier.state.pendingItems.length, 1);
      expect(notifier.state.resolvedItems.length, 1);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNull);
    });

    test('submitResponse updates item status to driver_found and decrements pendingCount', () async {
      await notifier.loadLostItems();
      expect(notifier.state.pendingCount, 1);

      final success = await notifier.submitResponse(
        'lost-1',
        found: true,
        note: 'Found in boot',
      );

      expect(success, true);
      expect(notifier.state.pendingCount, 0);
      final updatedItem = notifier.state.items.firstWhere((e) => e.id == 'lost-1');
      expect(updatedItem.status, 'driver_found');
      expect(updatedItem.driverFound, true);
      expect(updatedItem.driverNote, 'Found in boot');
      expect(notifier.state.successMessage, contains('Marked as Found'));
    });

    test('submitResponse updates item status to driver_not_found when not found', () async {
      await notifier.loadLostItems();

      final success = await notifier.submitResponse(
        'lost-1',
        found: false,
        note: 'Checked thoroughly, not found',
      );

      expect(success, true);
      expect(notifier.state.pendingCount, 0);
      final updatedItem = notifier.state.items.firstWhere((e) => e.id == 'lost-1');
      expect(updatedItem.status, 'driver_not_found');
      expect(updatedItem.driverFound, false);
    });

    test('handleIncomingReport socket event adds new item and increments pendingCount', () {
      final initialCount = notifier.state.pendingCount;

      final incomingPayload = {
        'id': 'lost-new-socket',
        'rideId': 'R-300',
        'category': 'documents',
        'description': 'Important office file folder',
        'status': 'reported',
        'reportedAt': '2026-11-15T14:00:00Z',
      };

      notifier.handleIncomingReport(incomingPayload);

      expect(notifier.state.items.any((e) => e.id == 'lost-new-socket'), true);
      expect(notifier.state.pendingCount, initialCount + 1);
    });

    test('handleStatusUpdate socket event updates existing item status', () {
      final updatePayload = {
        'id': 'lost-1',
        'status': 'returned',
        'updatedAt': '2026-11-15T15:00:00Z',
      };

      notifier.handleStatusUpdate(updatePayload);

      final updatedItem = notifier.state.items.firstWhere((e) => e.id == 'lost-1');
      expect(updatedItem.status, 'returned');
      expect(updatedItem.isReturned, true);
    });
  });

  group('DriverLostItemsScreen UI Widget Tests', () {
    testWidgets('Renders DriverLostItemsScreen with pending inquiry card and responds',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockDriverLostItemRepository();
      mockRepo.mockItems = [
        DriverLostItemModel(
          id: 'lost-w1',
          rideId: 'R-777',
          category: 'phone',
          description: 'Left red iPhone on rear seat',
          contactPhone: '9876543210',
          status: 'reported',
          pickupAddress: 'Sector 62, Noida',
          dropoffAddress: 'Indirapuram, Ghaziabad',
          reportedAt: '2026-11-15T12:00:00Z',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverLostItemRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: DriverLostItemsScreen(),
          ),
        ),
      );

      // Settle initial load
      await tester.pumpAndSettle();

      // Verify screen header and tabs
      expect(find.text('Lost & Found Items'), findsOneWidget);
      expect(find.text('Action Needed'), findsOneWidget);
      expect(find.text('History / All'), findsOneWidget);

      // Verify item card details
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Ride #R-777'), findsOneWidget);
      expect(find.text('ACTION REQUIRED'), findsOneWidget);
      expect(find.text('Left red iPhone on rear seat'), findsOneWidget);
      expect(find.text('Respond / Check Car'), findsOneWidget);

      // Tap on Respond / Check Car
      await tester.tap(find.text('Respond / Check Car'));
      await tester.pumpAndSettle();

      // Verify Respond Bottom Sheet is displayed
      expect(find.text('Lost Item Inquiry'), findsOneWidget);
      expect(find.text('Did you find this item in your vehicle?'), findsOneWidget);
      expect(find.text('Yes, I Found It'), findsOneWidget);
      expect(find.text('No, Not in Car'), findsOneWidget);

      // Select "Yes, I Found It"
      await tester.tap(find.text('Yes, I Found It'));
      await tester.pumpAndSettle();

      // Verify Handover Note input appears
      expect(find.text('Handover Note for Passenger (Optional)'), findsOneWidget);
      expect(find.text('CONFIRM & NOTIFY PASSENGER'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('CONFIRM & NOTIFY PASSENGER'));
      await tester.pumpAndSettle();

      // Bottom sheet closes
      expect(find.text('Lost Item Inquiry'), findsNothing);
    });
  });
}
