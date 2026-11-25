import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../firebase_options.dart';

/// Top-level background message handler for FCM
/// Required by Firebase Messaging to process notifications when app is in Background or Killed/Terminated state.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  dev.log(
    'Handling background / killed push notification messageId: ${message.messageId}, data: ${message.data}',
    name: 'PushNotificationService',
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _notificationDataController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream to listen to notification tap payloads across app UI
  Stream<Map<String, dynamic>> get notificationDataStream => _notificationDataController.stream;

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'ridonova_driver_channel', // Channel ID
    'Ridonova Driver Notifications', // Channel Name
    description: 'Alerts for new ride requests, trip updates, and driver account notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  bool _isInitialized = false;

  /// Initializes FCM and local notification listeners for Foreground, Background, and Terminated states.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    dev.log('Initializing NotificationService...', name: 'PushNotificationService');

    // 1. Request Push Notification permissions (iOS & Android 13+)
    await _requestPermissions();

    // 2. Initialize Local Notifications Plugin (for foreground banner alerts)
    await _initLocalNotifications();

    // 3. Configure FCM Foreground Notification Options for iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Handle FOREGROUND Notifications (App is active on screen)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      dev.log('Foreground Push Notification Received: ${message.notification?.title}', name: 'PushNotificationService');
      _showLocalNotification(message);
    });

    // 5. Handle BACKGROUND Notification Taps (App is in background and user taps notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      dev.log('Background Notification Tapped: ${message.data}', name: 'PushNotificationService');
      _handleNotificationPayload(message.data);
    });

    // 6. Handle TERMINATED / KILLED State Notification Taps (App was closed completely)
    _checkInitialMessage();

    // 7. Handle FCM Token lifecycle
    _listenToTokenRefresh();

    dev.log('NotificationService initialized successfully!', name: 'PushNotificationService');
  }

  /// Requests notification permissions for iOS and Android 13+ (POST_NOTIFICATIONS)
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    dev.log('FCM Notification permission status: ${settings.authorizationStatus}', name: 'PushNotificationService');

    // Request Android 13+ permission via local notifications plugin
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.createNotificationChannel(_androidChannel);
    }
  }

  /// Configures Flutter Local Notifications plugin
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            _handleNotificationPayload(data);
          } catch (e) {
            dev.log('Error parsing notification payload: $e', name: 'PushNotificationService');
          }
        }
      },
    );
  }

  /// Displays high-priority heads-up local notification banner when notification arrives in FOREGROUND state
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;

    String title = notification?.title ?? data['title'] ?? 'Ridonova Driver Alert';
    String body = notification?.body ?? data['body'] ?? 'You have a new update';

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      platformDetails,
      payload: jsonEncode(data),
    );
  }

  /// Checks if app was launched from a TERMINATED/KILLED state by tapping a notification
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      dev.log('App opened from Terminated state via Notification click: ${initialMessage.data}', name: 'PushNotificationService');
      _handleNotificationPayload(initialMessage.data);
    }
  }

  /// Processes notification tap payloads and emits event on stream
  void _handleNotificationPayload(Map<String, dynamic> data) {
    dev.log('Processing notification payload data: $data', name: 'PushNotificationService');
    _notificationDataController.add(data);
  }

  /// Fetches current FCM token for sending push notifications from backend
  Future<String?> getFcmToken() async {
    try {
      String? token = await _fcm.getToken();
      dev.log('Current FCM Token: $token', name: 'PushNotificationService');
      return token;
    } catch (e) {
      dev.log('Failed to fetch FCM token: $e', name: 'PushNotificationService');
      return null;
    }
  }

  /// Listens to FCM Token refreshes
  void _listenToTokenRefresh() {
    _fcm.onTokenRefresh.listen((String newToken) {
      dev.log('FCM Token Refreshed: $newToken', name: 'PushNotificationService');
      // Here token can be updated on backend if user is authenticated
    });
  }
}
