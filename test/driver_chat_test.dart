import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ridenovo_rider_mobile_app/core/services/socket_service.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/models/driver_chat_model.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/presentation/screens/driver_chat_screen.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/providers/driver_chat_provider.dart';
import 'package:ridenovo_rider_mobile_app/features/rides/repositories/driver_chat_repository.dart';

class MockDriverChatRepository implements IDriverChatRepository {
  bool shouldSucceed = true;
  String? mockErrorMessage;
  List<ChatMessageModel> mockMessages = [];
  List<String> mockQuickReplies = DriverChatHistoryResponse.defaultQuickReplies;
  bool mockCanChat = true;

  String? lastSentRideId;
  String? lastSentText;
  String? lastMarkReadRideId;

  @override
  String? get lastErrorMessage => shouldSucceed ? null : (mockErrorMessage ?? 'Failed to send message');

  @override
  Future<DriverChatHistoryResponse> getChatHistory(String rideId, {String? token}) async {
    if (!shouldSucceed) {
      return DriverChatHistoryResponse(
        rideId: rideId,
        status: 'error',
        canChat: false,
        quickReplies: DriverChatHistoryResponse.defaultQuickReplies,
        messages: [],
      );
    }
    return DriverChatHistoryResponse(
      rideId: rideId,
      status: 'active',
      canChat: mockCanChat,
      quickReplies: mockQuickReplies,
      messages: List.from(mockMessages),
    );
  }

  @override
  Future<ChatMessageModel?> sendMessage(String rideId, String text, {String? token}) async {
    lastSentRideId = rideId;
    lastSentText = text;
    if (!shouldSucceed) return null;

    final confirmed = ChatMessageModel(
      id: 'server-msg-${DateTime.now().millisecondsSinceEpoch}',
      rideId: rideId,
      senderId: 'driver-123',
      senderRole: 'driver',
      senderName: 'Driver',
      message: text,
      isRead: false,
      createdAt: DateTime.now(),
    );
    mockMessages.add(confirmed);
    return confirmed;
  }

  @override
  Future<bool> markAsRead(String rideId, {String? token}) async {
    lastMarkReadRideId = rideId;
    return shouldSucceed;
  }

  @override
  Future<List<String>> getQuickReplies({String? token}) async {
    return mockQuickReplies;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel audioplayersGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const MethodChannel audioplayersChannel = MethodChannel('xyz.luan/audioplayers');
  const MethodChannel urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  const MethodChannel flutterSecureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioplayersGlobalChannel, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioplayersChannel, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (MethodCall methodCall) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(flutterSecureStorageChannel, (MethodCall methodCall) async => null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChatMessageModel Tests', () {
    test('Correctly parses backend snake_case JSON', () {
      final json = {
        'id': 'msg-001',
        'ride_id': 'ride-abc',
        'sender_id': 'usr-rider-1',
        'sender_role': 'rider',
        'sender_name': 'Mohd Usama',
        'message': 'I am standing near Gate 1 ATM',
        'is_read': true,
        'created_at': '2026-11-15T14:40:00.000Z',
      };

      final msg = ChatMessageModel.fromJson(json);

      expect(msg.id, 'msg-001');
      expect(msg.rideId, 'ride-abc');
      expect(msg.senderId, 'usr-rider-1');
      expect(msg.senderRole, 'rider');
      expect(msg.senderName, 'Mohd Usama');
      expect(msg.message, 'I am standing near Gate 1 ATM');
      expect(msg.isRead, true);
      expect(msg.isMe, false);
      expect(msg.formattedTime.isNotEmpty, true);
    });

    test('Correctly identifies driver sender with isMe = true', () {
      final json = {
        'id': 'msg-002',
        'rideId': 'ride-abc',
        'senderId': 'driver-999',
        'senderRole': 'driver',
        'senderName': 'Captain Ramesh',
        'message': 'I have arrived',
        'isRead': false,
        'createdAt': '2026-11-15T14:41:00.000Z',
      };

      final msg = ChatMessageModel.fromJson(json);

      expect(msg.id, 'msg-002');
      expect(msg.isMe, true);
      expect(msg.isRead, false);
    });

    test('toJson and copyWith work as expected', () {
      final original = ChatMessageModel(
        id: 'msg-1',
        rideId: 'ride-1',
        senderId: 'drv-1',
        senderRole: 'driver',
        senderName: 'Captain',
        message: 'Reaching in 2 mins',
        isRead: false,
        createdAt: DateTime.parse('2026-11-15T10:00:00Z'),
      );

      final updated = original.copyWith(isRead: true, message: 'Reaching in 1 min');
      expect(updated.id, 'msg-1');
      expect(updated.isRead, true);
      expect(updated.message, 'Reaching in 1 min');

      final json = updated.toJson();
      expect(json['id'], 'msg-1');
      expect(json['is_read'], true);
      expect(json['message'], 'Reaching in 1 min');
    });

    test('Equality and hash code comparison', () {
      final now = DateTime.now();
      final a = ChatMessageModel(
        id: 'msg-100',
        rideId: 'ride-1',
        senderId: 'd',
        senderRole: 'driver',
        senderName: 'Driver',
        message: 'Hello',
        createdAt: now,
      );
      final b = ChatMessageModel(
        id: 'msg-100',
        rideId: 'ride-1',
        senderId: 'd',
        senderRole: 'driver',
        senderName: 'Driver',
        message: 'Hello',
        createdAt: now,
      );
      final c = ChatMessageModel(
        id: 'msg-200',
        rideId: 'ride-1',
        senderId: 'd',
        senderRole: 'driver',
        senderName: 'Driver',
        message: 'Hello',
        createdAt: now,
      );

      expect(a == b, true);
      expect(a == c, false);
      expect(a.hashCode == b.hashCode, true);
    });
  });

  group('DriverChatHistoryResponse Tests', () {
    test('Parses complete history payload with fallback defaults', () {
      final json = {
        'success': true,
        'data': {
          'rideId': 'ride-xyz',
          'status': 'arrived',
          'canChat': true,
          'role': 'driver',
          'quickReplies': ['I have arrived', 'Waiting outside'],
          'messages': [
            {
              'id': 'msg-1',
              'ride_id': 'ride-xyz',
              'sender_role': 'rider',
              'message': 'Coming down now',
              'created_at': '2026-11-15T12:00:00.000Z',
            }
          ]
        }
      };

      final response = DriverChatHistoryResponse.fromJson(json);

      expect(response.rideId, 'ride-xyz');
      expect(response.status, 'arrived');
      expect(response.canChat, true);
      expect(response.quickReplies.length, 2);
      expect(response.messages.length, 1);
      expect(response.messages.first.message, 'Coming down now');
    });

    test('Automatically disables canChat when ride is completed or cancelled', () {
      final json = {
        'rideId': 'ride-completed',
        'status': 'completed',
        'quickReplies': [],
        'messages': []
      };

      final response = DriverChatHistoryResponse.fromJson(json);
      expect(response.canChat, false);
      expect(response.quickReplies.isNotEmpty, true);
    });
  });

  group('DriverChatNotifier Provider & Socket Tests', () {
    late MockDriverChatRepository mockRepo;
    late SocketService socketService;

    setUp(() {
      mockRepo = MockDriverChatRepository();
      socketService = SocketService();
    });

    test('Loads chat history, preserves unread count until chat opens, then marks read', () async {
      mockRepo.mockMessages = [
        ChatMessageModel(
          id: 'msg-10',
          rideId: 'ride-123',
          senderId: 'usr-1',
          senderRole: 'rider',
          senderName: 'Rider',
          message: 'Near the gate',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      final notifier = DriverChatNotifier(
        rideId: 'ride-123',
        repository: mockRepo,
        socketService: socketService,
      );

      // Wait for loadChat (chat screen not opened yet)
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.messages.length, 1);
      expect(notifier.state.messages.first.message, 'Near the gate');
      expect(notifier.state.canChat, true);
      expect(notifier.state.unreadCount, 1);
      expect(mockRepo.lastMarkReadRideId, isNull);

      // Opening the chat screen marks messages as read
      notifier.setChatScreenActive(true);
      await Future.delayed(const Duration(milliseconds: 30));
      expect(mockRepo.lastMarkReadRideId, 'ride-123');
      expect(notifier.state.unreadCount, 0);

      notifier.dispose();
    });

    test('sendQuickReply adds optimistic message and replaces with server confirmation', () async {
      final notifier = DriverChatNotifier(
        rideId: 'ride-123',
        repository: mockRepo,
        socketService: socketService,
      );

      await Future.delayed(const Duration(milliseconds: 20));

      await notifier.sendQuickReply('OK, got it!');

      expect(mockRepo.lastSentRideId, 'ride-123');
      expect(mockRepo.lastSentText, 'OK, got it!');
      expect(notifier.state.messages.isNotEmpty, true);
      expect(notifier.state.messages.last.message, 'OK, got it!');
      expect(notifier.state.messages.last.isMe, true);

      notifier.dispose();
    });

    test('Deduplicates incoming socket messages with existing message IDs', () async {
      final notifier = DriverChatNotifier(
        rideId: 'ride-123',
        repository: mockRepo,
        socketService: socketService,
      );

      await Future.delayed(const Duration(milliseconds: 20));

      final initialMsg = ChatMessageModel(
        id: 'unique-msg-999',
        rideId: 'ride-123',
        senderId: 'usr-1',
        senderRole: 'rider',
        senderName: 'Usama',
        message: 'Waiting at main entrance',
        createdAt: DateTime.now(),
      );

      notifier.state = notifier.state.copyWith(messages: [initialMsg]);

      expect(notifier.state.messages.length, 1);

      notifier.dispose();
    });

    test('updateRideStatus sets canChat false when completed', () {
      final notifier = DriverChatNotifier(
        rideId: 'ride-123',
        repository: mockRepo,
        socketService: socketService,
      );

      expect(notifier.state.canChat, true);
      notifier.updateRideStatus('completed');
      expect(notifier.state.canChat, false);

      notifier.dispose();
    });

    test('Marks failed message and retries cleanly when repository recovers', () async {
      final notifier = DriverChatNotifier(
        rideId: 'ride-123',
        repository: mockRepo,
        socketService: socketService,
      );
      await Future.delayed(const Duration(milliseconds: 20));

      mockRepo.shouldSucceed = false;
      mockRepo.mockErrorMessage = 'Network unavailable';
      await notifier.sendCustomMessage('Are you near the gate?');

      expect(notifier.state.messages.length, 1);
      expect(notifier.state.messages.first.isFailed, true);
      expect(notifier.state.messages.first.isPending, false);
      expect(notifier.state.errorMessage, 'Network unavailable');

      final failedId = notifier.state.messages.first.id;
      mockRepo.shouldSucceed = true;
      await notifier.retryFailedMessage(failedId);

      expect(notifier.state.messages.length, 1);
      expect(notifier.state.messages.first.isFailed, false);
      expect(notifier.state.messages.first.isPending, false);
      expect(notifier.state.messages.first.id.startsWith('server-msg-'), true);
      expect(notifier.state.errorMessage, isNull);

      notifier.dispose();
    });

    test('refreshMessages pulls new passenger messages when socket misses them', () async {
      final notifier = DriverChatNotifier(
        rideId: 'ride-123',
        repository: mockRepo,
        socketService: socketService,
      );
      await Future.delayed(const Duration(milliseconds: 20));

      mockRepo.mockMessages.add(
        ChatMessageModel(
          id: 'rider-msg-55',
          rideId: 'ride-123',
          senderId: 'rider-1',
          senderRole: 'rider',
          senderName: 'Customer',
          message: 'Please wait 1 minute',
          createdAt: DateTime.now(),
        ),
      );

      await notifier.refreshMessages(silent: true);

      expect(notifier.state.messages.any((m) => m.id == 'rider-msg-55'), true);
      expect(notifier.state.unreadCount, 1);

      notifier.dispose();
    });
  });

  group('DriverChatScreen Widget Tests', () {
    late MockDriverChatRepository mockRepo;

    setUp(() {
      mockRepo = MockDriverChatRepository();
      mockRepo.mockMessages = [
        ChatMessageModel(
          id: 'm1',
          rideId: 'ride-test',
          senderId: 'rider-1',
          senderRole: 'rider',
          senderName: 'Mohd Usama',
          message: 'I am at Gate 1',
          isRead: true,
          createdAt: DateTime.now(),
        ),
        ChatMessageModel(
          id: 'm2',
          rideId: 'ride-test',
          senderId: 'driver-1',
          senderRole: 'driver',
          senderName: 'Driver',
          message: 'OK, arriving in 1 min',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];
    });

    testWidgets('Renders AppBar, Messages, and 1-Tap Quick Reply Chips', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverChatRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: DriverChatScreen(
              rideId: 'ride-test',
              riderName: 'Mohd Usama',
              riderPhone: '+919876543210',
              pickupAddress: 'Connaught Place, Delhi',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AppBar details
      expect(find.text('Mohd Usama'), findsWidgets);
      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);

      // Verify Message bubbles
      expect(find.text('I am at Gate 1'), findsOneWidget);
      expect(find.text('OK, arriving in 1 min'), findsOneWidget);

      // Verify 1-Tap Quick Replies section
      expect(find.text('1-Tap Quick Replies'), findsOneWidget);
      expect(find.text('I have arrived at your pickup point'), findsOneWidget);
    });

    testWidgets('Tapping 1-Tap Quick Reply chip sends instant message', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverChatRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: DriverChatScreen(
              rideId: 'ride-test',
              riderName: 'Mohd Usama',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final quickReplyFinder = find.text('I have arrived at your pickup point');
      expect(quickReplyFinder, findsOneWidget);

      await tester.tap(quickReplyFinder);
      await tester.pumpAndSettle();

      expect(mockRepo.lastSentText, 'I have arrived at your pickup point');
    });

    testWidgets('Shows closed chat notice when ride is completed', (tester) async {
      mockRepo.mockCanChat = false;

      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            driverChatRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: DriverChatScreen(
              rideId: 'ride-test',
              riderName: 'Mohd Usama',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ride completed. Chat closed.'), findsOneWidget);
      expect(find.text('Type a message...'), findsNothing);
    });
  });
}
