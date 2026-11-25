import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import '../../core/network/token_storage.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/socket_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/driver_ride_invoice_model.dart';
import 'models/ride_request_model.dart';
import 'models/ride_route_model.dart';

enum RideStep { none, accepted, arrived, otpEntered, started, completed, cancelled }

class RideState {
  final bool isOnline;
  final int batteryLevel;
  final bool isDutyLoading;
  final bool isRideLoading;
  final List<RideRequestModel> pendingRequests;
  final RideRequestModel? activeRide;
  final RideRouteModel? activeRoute;
  final RideStep rideStep;
  final String? errorMessage;
  final String? errorCode;
  final RideRequestModel? incomingPopupRide;
  final int incomingCountdownSeconds;
  final int waitingSecondsElapsed;
  final Map<String, dynamic>? completedFareSummary;
  final bool isSocketConnected;

  RideState({
    this.isOnline = false,
    this.batteryLevel = 85,
    this.isDutyLoading = false,
    this.isRideLoading = false,
    this.pendingRequests = const [],
    this.activeRide,
    this.activeRoute,
    this.rideStep = RideStep.none,
    this.errorMessage,
    this.errorCode,
    this.incomingPopupRide,
    this.incomingCountdownSeconds = 15,
    this.waitingSecondsElapsed = 0,
    this.completedFareSummary,
    this.isSocketConnected = false,
  });

  RideState copyWith({
    bool? isOnline,
    int? batteryLevel,
    bool? isDutyLoading,
    bool? isRideLoading,
    List<RideRequestModel>? pendingRequests,
    RideRequestModel? activeRide,
    RideRouteModel? activeRoute,
    bool clearActiveRide = false,
    bool clearActiveRoute = false,
    bool clearIncomingPopup = false,
    bool clearCompletedSummary = false,
    RideStep? rideStep,
    String? errorMessage,
    String? errorCode,
    bool clearErrorCode = false,
    RideRequestModel? incomingPopupRide,
    int? incomingCountdownSeconds,
    int? waitingSecondsElapsed,
    Map<String, dynamic>? completedFareSummary,
    bool? isSocketConnected,
  }) {
    return RideState(
      isOnline: isOnline ?? this.isOnline,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isDutyLoading: isDutyLoading ?? this.isDutyLoading,
      isRideLoading: isRideLoading ?? this.isRideLoading,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeRide: clearActiveRide ? null : (activeRide ?? this.activeRide),
      activeRoute: (clearActiveRide || clearActiveRoute) ? null : (activeRoute ?? this.activeRoute),
      incomingPopupRide: clearIncomingPopup ? null : (incomingPopupRide ?? this.incomingPopupRide),
      rideStep: rideStep ?? this.rideStep,
      errorMessage: errorMessage,
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      incomingCountdownSeconds: incomingCountdownSeconds ?? this.incomingCountdownSeconds,
      waitingSecondsElapsed: waitingSecondsElapsed ?? this.waitingSecondsElapsed,
      completedFareSummary: clearCompletedSummary ? null : (completedFareSummary ?? this.completedFareSummary),
      isSocketConnected: isSocketConnected ?? this.isSocketConnected,
    );
  }
}

class RideNotifier extends StateNotifier<RideState> {
  final ApiService _apiService;
  final SocketService _socketService;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _pollingTimer;
  Timer? _locationTimer;
  Timer? _incomingCountdownTimer;
  Timer? _waitingTimer;

  StreamSubscription? _rideRequestSub;
  StreamSubscription? _rideStatusSub;
  StreamSubscription? _socketConnSub;

  double? currentLat;
  double? currentLng;
  double? currentHeading;
  double? currentSpeed;
  final Set<String> _dismissedRideIds = {};

  RideNotifier({ApiService? apiService, SocketService? socketService})
    : _apiService = apiService ?? ApiService(),
      _socketService = socketService ?? SocketService(),
      super(RideState()) {
    _initSocketListeners();
    restoreDutyStatus();
  }

  @override
  void dispose() {
    _stopAllTimers();
    _rideRequestSub?.cancel();
    _rideStatusSub?.cancel();
    _socketConnSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Helper to safely retrieve current driver JWT token from local preferences
  Future<String> _getAuthToken() async {
    final token = await TokenStorage.getToken();
    return token ?? '';
  }

  void updateDriverCoordinates(double lat, double lng, {double? heading, double? speed}) {
    currentLat = lat;
    currentLng = lng;
    if (heading != null) currentHeading = heading;
    if (speed != null) currentSpeed = speed;
  }

  /// Sets up real-time socket event handlers
  void _initSocketListeners() {
    _socketConnSub = _socketService.connectionStream.listen((connected) {
      state = state.copyWith(isSocketConnected: connected);
    });

    _rideRequestSub = _socketService.rideRequestStream.listen((data) {
      if (!state.isOnline || state.activeRide != null) return;
      dev.log('Socket incoming ride request: $data', name: 'RideNotifier');
      final parsed = RideRequestModel.tryParse(data);
      if (parsed != null && !_dismissedRideIds.contains(parsed.id)) {
        showIncomingRidePopup(parsed);
      }
    });

    _rideStatusSub = _socketService.rideStatusStream.listen((data) {
      dev.log('Socket ride status changed: $data', name: 'RideNotifier');
      final rideId = data['rideId']?.toString() ?? data['id']?.toString();
      final status = data['status']?.toString();

      if (state.incomingPopupRide != null && (rideId == null || rideId == state.incomingPopupRide!.id)) {
        if (status == 'cancelled') {
          _dismissedRideIds.add(state.incomingPopupRide!.id);
          dismissIncomingRidePopup();
        }
      }

      if (state.activeRide != null && (rideId == null || rideId == state.activeRide!.id)) {
        if (status == 'cancelled') {
          dev.log('Active ride was cancelled by customer', name: 'RideNotifier');
          _stopWaitingTimer();
          state = state.copyWith(
            clearActiveRide: true,
            clearActiveRoute: true,
            rideStep: RideStep.cancelled,
            errorMessage: 'Ride was cancelled by the customer.',
          );
        }
      }
    });
  }

  /// Restores online duty status from SharedPreferences on app launch
  Future<void> restoreDutyStatus() async {
    try {
      final token = await _getAuthToken();
      final prefs = await SharedPreferences.getInstance();
      final bool isOnlineSaved = prefs.getBool('is_duty_online') ?? false;

      if (isOnlineSaved && token.isNotEmpty) {
        // Re-verify with the server (KYC / block / wallet may have changed while the app was closed)
        await goOnline(battery: state.batteryLevel > 0 ? state.batteryLevel : 85);
      }
    } catch (_) {}
  }

  void _stopAllTimers() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    _incomingCountdownTimer?.cancel();
    _incomingCountdownTimer = null;
    _stopWaitingTimer();
  }

  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
  }

  void _startWaitingTimer() {
    _stopWaitingTimer();
    state = state.copyWith(waitingSecondsElapsed: 0);
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(waitingSecondsElapsed: state.waitingSecondsElapsed + 1);
    });
  }

  void _startTimers() {
    _pollingTimer?.cancel();
    _locationTimer?.cancel();

    // Poll for pending ride requests every 3 seconds as backup to Socket
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (state.isOnline && state.activeRide == null) {
        fetchPendingRequests();
      }
    });

    // Send live GPS coordinates every 2-3 seconds via socket + REST fallback
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (state.isOnline && currentLat != null && currentLng != null) {
        updateLocation(currentLat!, currentLng!);
      }
    });
  }

  /// Plays alert chime sound when new ride request popup triggers
  Future<void> _playAlertSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
    } catch (_) {}
  }

  /// Stops alert chime sound
  Future<void> _stopAlertSound() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  /// Displays 15-second incoming ride popup modal with countdown timer
  void showIncomingRidePopup(RideRequestModel req) {
    if (state.activeRide != null) return;
    if (state.incomingPopupRide?.id == req.id) {
      state = state.copyWith(incomingPopupRide: state.incomingPopupRide!.mergeWith(req));
      return;
    }

    _incomingCountdownTimer?.cancel();
    _playAlertSound();

    state = state.copyWith(incomingPopupRide: req, incomingCountdownSeconds: 15);

    _incomingCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.incomingCountdownSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        _stopAlertSound();
        rejectRide(req.id, reason: 'Timeout (15s elapsed)');
        dismissIncomingRidePopup();
      } else {
        state = state.copyWith(incomingCountdownSeconds: remaining);
      }
    });
  }

  /// Dismisses incoming ride popup modal
  void dismissIncomingRidePopup() {
    _incomingCountdownTimer?.cancel();
    _incomingCountdownTimer = null;
    _stopAlertSound();
    state = state.copyWith(clearIncomingPopup: true, incomingCountdownSeconds: 15);
  }

  void clearErrorCode() {
    if (state.errorCode != null) {
      state = state.copyWith(clearErrorCode: true);
    }
  }

  /// 1. Go Online (POST /driver/online)
  Future<bool> goOnline({int battery = 85, String? vehicleType}) async {
    state = state.copyWith(isDutyLoading: true, errorMessage: null, clearErrorCode: true);

    final token = await _getAuthToken();
    final fcmToken = await NotificationService().getFcmToken();

    final response = await _apiService.post(
      ApiConstants.goOnline,
      data: {
        'battery': battery,
        'lat': currentLat ?? 28.6139,
        'lng': currentLng ?? 77.2090,
        'vehicleType': vehicleType ?? 'bike',
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      },
      token: token,
    );

    // Backend refuses when driver profile is missing, KYC is pending, account is blocked or wallet is below -₹1,000
    if (!response.isSuccess) {
      String? parsedErrorCode;
      if (response.data is Map) {
        final rawCode = response.data['error'] ?? response.data['code'] ?? response.data['errorCode'];
        if (rawCode != null && rawCode.toString().isNotEmpty) {
          parsedErrorCode = rawCode.toString();
        }
      }
      state = state.copyWith(
        isOnline: false,
        isDutyLoading: false,
        errorMessage: response.errorMessage ?? 'Unable to go online right now. Please try again.',
        errorCode: parsedErrorCode,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_duty_online', false);
      } catch (_) {}
      return false;
    }

    // Connect persistent socket with active JWT token
    _socketService.initSocket(token);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_duty_online', true);
    } catch (_) {}

    state = state.copyWith(
      isOnline: true,
      batteryLevel: battery,
      isDutyLoading: false,
      clearErrorCode: true,
    );
    _startTimers();
    fetchPendingRequests();

    if (currentLat != null && currentLng != null) {
      updateLocation(currentLat!, currentLng!);
    }

    return true;
  }

  /// 2. Go Offline (POST /driver/offline)
  Future<bool> goOffline() async {
    state = state.copyWith(isDutyLoading: true, errorMessage: null);

    final token = await _getAuthToken();
    await _apiService.post(ApiConstants.goOffline, token: token);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_duty_online', false);
    } catch (_) {}

    _stopAllTimers();
    _socketService.disconnect();

    state = state.copyWith(
      isOnline: false,
      isDutyLoading: false,
      pendingRequests: [],
      clearActiveRide: true,
      clearActiveRoute: true,
      clearIncomingPopup: true,
      rideStep: RideStep.none,
    );
    return true;
  }

  /// 3. Update Live Location (Socket + REST Fallback)
  Future<bool> updateLocation(double lat, double lng) async {
    if (!state.isOnline) return false;

    currentLat = lat;
    currentLng = lng;

    final String? activeRideId = state.activeRide?.id;
    final token = await _getAuthToken();

    // Ensure socket is initialized with driver JWT token
    _socketService.initSocket(token);

    // 1. Emit live location via Socket.IO
    _socketService.emitLocationUpdate(
      lat: lat,
      lng: lng,
      heading: currentHeading ?? 0.0,
      speed: currentSpeed ?? 0.0,
      status: 'online',
      rideId: activeRideId,
    );

    // 2. REST Fallback
    final response = await _apiService.post(
      ApiConstants.updateLocation,
      data: {'lat': lat, 'lng': lng, 'heading': currentHeading ?? 0.0, 'speed': currentSpeed ?? 0.0, 'rideId': activeRideId},
      token: token,
    );

    // Auto refresh route polyline when driver moves during active ride
    if (activeRideId != null && state.activeRide != null) {
      final isPickup = state.rideStep == RideStep.accepted || state.rideStep == RideStep.arrived;
      final tLat = isPickup ? state.activeRide!.pickupLat : state.activeRide!.dropLat;
      final tLng = isPickup ? state.activeRide!.pickupLng : state.activeRide!.dropLng;
      final target = isPickup ? 'pickup' : 'dropoff';
      fetchRideRoute(activeRideId, lat: lat, lng: lng, targetLat: tLat, targetLng: tLng, target: target);
    }

    return response.isSuccess;
  }

  /// 4. Update Battery Level (POST /driver/battery)
  Future<bool> updateBattery(int battery) async {
    state = state.copyWith(batteryLevel: battery);
    final token = await _getAuthToken();
    final response = await _apiService.post(ApiConstants.updateBattery, data: {'battery': battery}, token: token);
    return response.isSuccess;
  }

  /// 5. Get Pending Ride Requests (GET /driver/ride-requests)
  Future<void> fetchPendingRequests() async {
    if (!state.isOnline || state.activeRide != null) return;

    final token = await _getAuthToken();
    final response = await _apiService.get(ApiConstants.getRideRequests, token: token);

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        var dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

        if (dataPayload is Map) {
          if (dataPayload['requests'] is List) {
            dataPayload = dataPayload['requests'];
          } else if (dataPayload['rideRequests'] is List) {
            dataPayload = dataPayload['rideRequests'];
          } else if (dataPayload['rides'] is List) {
            dataPayload = dataPayload['rides'];
          } else if (dataPayload['pending'] is List) {
            dataPayload = dataPayload['pending'];
          }
        }

        List<RideRequestModel> requests = [];
        if (dataPayload is List) {
          for (var item in dataPayload) {
            final parsed = RideRequestModel.tryParse(item);
            if (parsed != null && !_dismissedRideIds.contains(parsed.id)) {
              requests.add(parsed);
            }
          }
        } else if (dataPayload is Map<String, dynamic> && dataPayload.isNotEmpty) {
          final parsed = RideRequestModel.tryParse(dataPayload);
          if (parsed != null && !_dismissedRideIds.contains(parsed.id)) {
            requests.add(parsed);
          }
        }

        state = state.copyWith(pendingRequests: requests);

        // Auto trigger incoming popup if new request found
        if (requests.isNotEmpty && state.incomingPopupRide == null) {
          showIncomingRidePopup(requests.first);
        }
      } catch (_) {}
    }
  }

  /// 6. Accept Ride Request
  Future<bool> acceptRide(String rideId, {double? driverLat, double? driverLng}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final double balance = prefs.getDouble('wallet_balance') ?? 0.0;
      if (balance <= -1000.0) {
        state = state.copyWith(
          isRideLoading: false,
          errorMessage:
              'Your wallet balance is -₹${balance.abs().toStringAsFixed(2)}. Ride acceptance is blocked as per platform policy (-₹1,000 limit). Please clear your dues.',
        );
        return false;
      }
    } catch (_) {}

    dismissIncomingRidePopup();
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final existingReq = state.pendingRequests.firstWhere(
      (r) => r.id == rideId,
      orElse: () => state.incomingPopupRide ?? RideRequestModel(id: rideId, status: 'accepted'),
    );

    final token = await _getAuthToken();
    final acceptPayload = {
      'driverLat': driverLat ?? currentLat,
      'driverLng': driverLng ?? currentLng,
      'lat': driverLat ?? currentLat,
      'lng': driverLng ?? currentLng,
    };
    var response = await _apiService.post(ApiConstants.acceptRideRequest(rideId), data: acceptPayload, token: token);
    if (!response.isSuccess && response.statusCode == 404) {
      response = await _apiService.post('/driver/rides/$rideId/accept', data: acceptPayload, token: token);
    }

    if (response.isSuccess) {
      RideRequestModel? acceptedRide;
      RideRouteModel? acceptedRoute;

      if (response.data != null) {
        try {
          final raw = response.data is String ? jsonDecode(response.data) : response.data;
          final dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

          if (dataPayload is Map<String, dynamic>) {
            acceptedRide = RideRequestModel.tryParse(dataPayload);
            if (dataPayload['route'] is Map) {
              acceptedRoute = RideRouteModel.fromJson({'data': dataPayload['route'], 'rideId': rideId});
            }
          }
        } catch (_) {}
      }

      final finalActive = acceptedRide != null
          ? existingReq.mergeWith(acceptedRide).copyWith(status: 'accepted')
          : existingReq.copyWith(status: 'accepted');

      // Join ride socket tracking room
      _socketService.joinRide(rideId);

      state = state.copyWith(
        isRideLoading: false,
        activeRide: finalActive,
        activeRoute: acceptedRoute ?? state.activeRoute,
        rideStep: RideStep.accepted,
        pendingRequests: [],
        clearIncomingPopup: true,
      );

      // Fetch road-following polyline from driver's location to pickup location
      await fetchRideRoute(
        rideId,
        lat: driverLat ?? currentLat ?? 0.0,
        lng: driverLng ?? currentLng ?? 0.0,
        targetLat: finalActive.pickupLat,
        targetLng: finalActive.pickupLng,
        target: 'pickup',
        targetAddress: finalActive.pickupAddress,
      );

      return true;
    } else {
      final taken = response.statusCode == 409;
      state = state.copyWith(
        isRideLoading: false,
        errorMessage: taken
            ? 'This ride was already accepted by another captain.'
            : (response.errorMessage ?? 'Failed to accept ride. Please try again.'),
        pendingRequests: taken ? state.pendingRequests.where((r) => r.id != rideId).toList() : state.pendingRequests,
        clearIncomingPopup: taken,
      );
      return false;
    }
  }

  /// 7. Get Ride Details (GET /driver/rides/{rideId})
  Future<void> fetchRideDetails(String rideId) async {
    final token = await _getAuthToken();
    final response = await _apiService.get(ApiConstants.getRideDetails(rideId), token: token);

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        var dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

        if (dataPayload is Map) {
          if (dataPayload['ride'] is Map) {
            dataPayload = dataPayload['ride'];
          } else if (dataPayload['rideDetails'] is Map) {
            dataPayload = dataPayload['rideDetails'];
          } else if (dataPayload['request'] is Map) {
            dataPayload = dataPayload['request'];
          }
        }

        if (dataPayload is Map<String, dynamic>) {
          final fetchedRide = RideRequestModel.fromJson(dataPayload);
          final mergedRide = state.activeRide != null ? state.activeRide!.mergeWith(fetchedRide) : fetchedRide;
          state = state.copyWith(activeRide: mergedRide);
        }
      } catch (_) {}
    }
  }

  /// Helper to fetch road-following route coordinates from public OSRM router if backend provides straight line
  Future<List<LatLng>> _fetchRoadRouteFromOsrm(double startLat, double startLng, double endLat, double endLng) async {
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=polyline';
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(sendTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)),
      );
      if (response.statusCode == 200 && response.data != null) {
        final routes = response.data['routes'];
        if (routes is List && routes.isNotEmpty) {
          final geometry = routes[0]['geometry']?.toString();
          if (geometry != null && geometry.isNotEmpty) {
            final decoded = RideRouteModel.decodePolyline(geometry);
            if (decoded.isNotEmpty) {
              return decoded;
            }
          }
        }
      }
    } catch (e) {
      dev.log('OSRM route fetch error: $e', name: 'RideNotifier');
    }
    return [LatLng(startLat, startLng), LatLng(endLat, endLng)];
  }

  /// 7b. Get Ride Route (GET /driver/rides/{rideId}/route?lat={lat}&lng={lng})
  Future<RideRouteModel?> fetchRideRoute(
    String rideId, {
    required double lat,
    required double lng,
    double? targetLat,
    double? targetLng,
    String target = 'pickup',
    String targetAddress = '',
  }) async {
    final token = await _getAuthToken();
    final response = await _apiService.get(ApiConstants.getRideRoute(rideId, lat, lng), token: token);

    RideRouteModel? routeModel;

    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        final dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;

        if (dataPayload is Map<String, dynamic>) {
          routeModel = RideRouteModel.fromJson(dataPayload);
        }
      } catch (_) {}
    }

    // Driver Start Coordinate
    double sLat = (routeModel != null && routeModel.driverLat != 0.0) ? routeModel.driverLat : (currentLat ?? (lat != 0.0 ? lat : 0.0));
    double sLng = (routeModel != null && routeModel.driverLng != 0.0) ? routeModel.driverLng : (currentLng ?? (lng != 0.0 ? lng : 0.0));

    // Target Destination Coordinate
    // Priority: routeModel.targetLat -> explicitly passed targetLat -> activeRide.pickupLat / dropLat
    double eLat = (routeModel != null && routeModel.targetLat != 0.0)
        ? routeModel.targetLat
        : ((targetLat != null && targetLat != 0.0)
              ? targetLat
              : (target == 'pickup' ? (state.activeRide?.pickupLat ?? 0.0) : (state.activeRide?.dropLat ?? 0.0)));

    double eLng = (routeModel != null && routeModel.targetLng != 0.0)
        ? routeModel.targetLng
        : ((targetLng != null && targetLng != 0.0)
              ? targetLng
              : (target == 'pickup' ? (state.activeRide?.pickupLng ?? 0.0) : (state.activeRide?.dropLng ?? 0.0)));

    List<LatLng> roadPoints = routeModel?.routeCoordinates ?? [];

    // If points/polyline are missing or only a straight line (<=2 points), fetch actual road route via HTTPS OSRM
    if (roadPoints.length <= 2 && sLat != 0.0 && sLng != 0.0 && eLat != 0.0 && eLng != 0.0) {
      roadPoints = await _fetchRoadRouteFromOsrm(sLat, sLng, eLat, eLng);
    }

    final effectiveTarget = (routeModel != null && routeModel.target.isNotEmpty) ? routeModel.target : target;
    final effectiveTargetAddress = (routeModel != null && routeModel.targetAddress.isNotEmpty)
        ? routeModel.targetAddress
        : (targetAddress.isNotEmpty
              ? targetAddress
              : (target == 'pickup' ? (state.activeRide?.pickupAddress ?? '') : (state.activeRide?.dropAddress ?? '')));

    if (routeModel == null) {
      routeModel = RideRouteModel(
        rideId: rideId,
        status: state.activeRide?.status ?? 'accepted',
        target: effectiveTarget,
        targetAddress: effectiveTargetAddress,
        targetLat: eLat,
        targetLng: eLng,
        driverLat: sLat,
        driverLng: sLng,
        points: roadPoints,
        riderName: state.activeRide?.riderName ?? '',
        riderPhone: state.activeRide?.riderPhone ?? '',
      );
    } else {
      routeModel = routeModel.copyWith(
        target: effectiveTarget,
        targetAddress: effectiveTargetAddress,
        targetLat: eLat != 0.0 ? eLat : routeModel.targetLat,
        targetLng: eLng != 0.0 ? eLng : routeModel.targetLng,
        driverLat: sLat != 0.0 ? sLat : routeModel.driverLat,
        driverLng: sLng != 0.0 ? sLng : routeModel.driverLng,
        points: roadPoints.isNotEmpty ? roadPoints : routeModel.points,
      );
    }

    state = state.copyWith(activeRoute: routeModel);

    if (state.activeRide != null) {
      var active = state.activeRide!;
      bool updated = false;

      if (active.riderName.isEmpty && routeModel.riderName.isNotEmpty) {
        active = active.copyWith(riderName: routeModel.riderName, riderPhone: routeModel.riderPhone);
        updated = true;
      }
      if (active.pickupAddress.isEmpty && routeModel.target == 'pickup' && routeModel.targetAddress.isNotEmpty) {
        active = active.copyWith(
          pickupAddress: routeModel.targetAddress,
          pickupLat: routeModel.targetLat != 0.0 ? routeModel.targetLat : active.pickupLat,
          pickupLng: routeModel.targetLng != 0.0 ? routeModel.targetLng : active.pickupLng,
        );
        updated = true;
      }
      if (active.dropAddress.isEmpty && routeModel.target == 'dropoff' && routeModel.targetAddress.isNotEmpty) {
        active = active.copyWith(
          dropAddress: routeModel.targetAddress,
          dropLat: routeModel.targetLat != 0.0 ? routeModel.targetLat : active.dropLat,
          dropLng: routeModel.targetLng != 0.0 ? routeModel.targetLng : active.dropLng,
        );
        updated = true;
      }

      if (updated) {
        state = state.copyWith(activeRide: active);
      }
    }

    return routeModel;
  }

  /// 8. Mark Arrived at Pickup (POST /driver/rides/{rideId}/arrived)
  Future<bool> markArrived(String rideId, {double? driverLat, double? driverLng}) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final token = await _getAuthToken();
    final response = await _apiService.post(ApiConstants.arrivedAtPickup(rideId), token: token);

    if (response.isSuccess) {
      _startWaitingTimer();
      getWaitingCharges(rideId);

      state = state.copyWith(
        isRideLoading: false,
        rideStep: RideStep.arrived,
        activeRide: state.activeRide?.copyWith(status: 'arrived'),
      );

      await fetchRideRoute(
        rideId,
        lat: driverLat ?? currentLat ?? (state.activeRide?.pickupLat ?? 0.0),
        lng: driverLng ?? currentLng ?? (state.activeRide?.pickupLng ?? 0.0),
        targetLat: state.activeRide?.pickupLat ?? 0.0,
        targetLng: state.activeRide?.pickupLng ?? 0.0,
        target: 'pickup',
        targetAddress: state.activeRide?.pickupAddress ?? '',
      );

      return true;
    } else {
      state = state.copyWith(isRideLoading: false, errorMessage: response.errorMessage ?? 'Failed to mark arrived at pickup location.');
      return false;
    }
  }

  /// 9. Start Ride with 4-Digit OTP (POST /driver/rides/{rideId}/start)
  Future<bool> startRide(String rideId, String otp, {double? driverLat, double? driverLng}) async {
    if (otp.length < 4) {
      state = state.copyWith(errorMessage: 'Please enter a valid 4-digit OTP.');
      return false;
    }

    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final token = await _getAuthToken();
    final response = await _apiService.post(ApiConstants.startRide(rideId), data: {'otp': otp}, token: token);

    if (response.isSuccess) {
      _stopWaitingTimer();

      state = state.copyWith(
        isRideLoading: false,
        rideStep: RideStep.started,
        activeRide: state.activeRide?.copyWith(status: 'started'),
      );

      // Fetch route polyline to dropoff destination
      await fetchRideRoute(
        rideId,
        lat: driverLat ?? currentLat ?? 0.0,
        lng: driverLng ?? currentLng ?? 0.0,
        targetLat: state.activeRide?.dropLat ?? 0.0,
        targetLng: state.activeRide?.dropLng ?? 0.0,
        target: 'dropoff',
        targetAddress: state.activeRide?.dropAddress ?? '',
      );

      return true;
    } else {
      state = state.copyWith(
        isRideLoading: false,
        errorMessage: response.errorMessage ?? 'The OTP entered is incorrect. Please check with rider and try again.',
      );
      return false;
    }
  }

  /// Reject Ride Request (POST /driver/riderequests/{rideId}/reject)
  Future<bool> rejectRide(String rideId, {String? reason}) async {
    _dismissedRideIds.add(rideId);
    dismissIncomingRidePopup();

    state = state.copyWith(isRideLoading: false, pendingRequests: state.pendingRequests.where((r) => r.id != rideId).toList());

    final token = await _getAuthToken();
    final response = await _apiService.post(ApiConstants.rejectRideRequest(rideId), data: {'reason': reason ?? 'Driver rejected'}, token: token);
    return response.isSuccess;
  }

  /// 10. Cancel Ride (POST /driver/rides/{rideId}/cancel)
  Future<bool> cancelRide(String rideId, {String? reason, String? code}) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final token = await _getAuthToken();
    final Map<String, dynamic> body = {
      'reason': reason ?? 'Driver cancelled',
    };
    if (code != null && code.isNotEmpty) {
      body['code'] = code;
    }

    final response = await _apiService.post(ApiConstants.cancelDriverRide(rideId), data: body, token: token);

    _socketService.leaveRide(rideId);
    _stopWaitingTimer();

    state = state.copyWith(isRideLoading: false, clearActiveRide: true, clearActiveRoute: true, rideStep: RideStep.none);
    return response.isSuccess;
  }

  /// Complete Ride (POST /driver/rides/{rideId}/complete)
  Future<bool> completeRide(String rideId) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final token = await _getAuthToken();
    final response = await _apiService.post(ApiConstants.completeRide(rideId), token: token);

    if (response.isSuccess) {
      Map<String, dynamic> summary = {
        'fare': state.activeRide?.fare ?? 0.0,
        'paymentMethod': state.activeRide?.paymentMethod ?? 'CASH',
        'pickupAddress': state.activeRide?.pickupAddress ?? '',
        'dropAddress': state.activeRide?.dropAddress ?? '',
        'riderName': state.activeRide?.riderName ?? 'Customer',
      };

      if (response.data != null) {
        try {
          final raw = response.data is String ? jsonDecode(response.data) : response.data;
          final dataPayload = (raw is Map) ? (raw['data'] ?? raw['result'] ?? raw) : raw;
          if (dataPayload is Map<String, dynamic>) {
            summary = {...summary, ...dataPayload};
          }
        } catch (_) {}
      }

      _socketService.leaveRide(rideId);
      _stopWaitingTimer();

      state = state.copyWith(isRideLoading: false, rideStep: RideStep.completed, completedFareSummary: summary);
      return true;
    } else {
      state = state.copyWith(isRideLoading: false, errorMessage: response.errorMessage ?? 'Failed to complete ride.');
      return false;
    }
  }

  /// Reset ride state after rating rider
  void finishCompletedRide() {
    state = state.copyWith(
      isRideLoading: false,
      clearActiveRide: true,
      clearActiveRoute: true,
      clearCompletedSummary: true,
      rideStep: RideStep.none,
    );
  }

  /// Get Waiting Charges / Policy (GET /driver/rides/{rideId}/waiting)
  Future<dynamic> getWaitingCharges(String rideId) async {
    final token = await _getAuthToken();
    final response = await _apiService.get(ApiConstants.getWaitingCharges(rideId), token: token);
    return response.isSuccess ? response.data : null;
  }

  /// Masked Call API (POST /call/mask-call)
  Future<String?> initiateMaskedCall(String rideId) async {
    final token = await _getAuthToken();
    final response = await _apiService.post(ApiConstants.maskCall, data: {'rideId': rideId}, token: token);
    if (response.isSuccess && response.data != null) {
      try {
        final raw = response.data is String ? jsonDecode(response.data) : response.data;
        return raw['data']?['virtualNumber']?.toString() ?? raw['phone']?.toString();
      } catch (_) {}
    }
    return null;
  }

  /// Rate Rider (POST /driver/rides/{rideId}/rate)
  Future<bool> rateRider(String rideId, {required int rating, String? comment}) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);

    final token = await _getAuthToken();
    final response = await _apiService.post(
      ApiConstants.rateRider(rideId),
      data: {'rating': rating, if (comment != null && comment.isNotEmpty) 'comment': comment},
      token: token,
    );

    finishCompletedRide();
    return response.isSuccess;
  }

  // Request Payout (POST /driver/payout-request)
  Future<bool> requestPayout({required double amount}) async {
    final token = await _getAuthToken();
    final response = await _apiService.post(ApiConstants.payoutRequest, data: {'amount': amount}, token: token);
    return response.isSuccess;
  }

  /// Confirm Cash Collection & Commission Auto-Deduct (POST /driver/rides/{rideId}/collect-cash)
  Future<bool> collectCash(String rideId, double amount) async {
    state = state.copyWith(isRideLoading: true, errorMessage: null);
    final token = await _getAuthToken();
    final response = await _apiService.post(ApiConstants.collectCash(rideId), data: {'amount': amount}, token: token);
    state = state.copyWith(isRideLoading: false);
    return response.isSuccess;
  }

  /// Triggers Live SOS Emergency Alert during active trip: POST /api/driver/rides/{rideId}/sos
  Future<dynamic> triggerSos(String rideId, {required double lat, required double lng, String? reason}) async {
    final token = await _getAuthToken();
    final response = await _apiService.post(
      ApiConstants.triggerRideSos(rideId),
      data: {
        'lat': lat,
        'lng': lng,
        'reason': reason ?? 'Driver emergency / dispute / accident',
      },
      token: token,
    );
    return response.isSuccess ? response.data : null;
  }

  /// Fetches Trip Invoice & Receipt: GET /api/driver/rides/:rideId/invoice
  Future<DriverRideInvoiceModel?> getDriverRideInvoice(String rideId) async {
    final token = await _getAuthToken();
    try {
      final response = await _apiService.get(ApiConstants.rideInvoice(rideId), token: token);
      if (response.isSuccess && response.data != null) {
        final dynamic raw = response.data is String ? jsonDecode(response.data) : response.data;
        if (raw is Map<String, dynamic>) {
          return DriverRideInvoiceModel.fromJson(rideId, raw);
        }
      }
    } catch (e) {
      dev.log('Error fetching ride invoice: $e', name: 'RideInvoice');
    }
    return null;
  }

  /// Opens printable HTML invoice in external browser for viewing or saving as PDF
  /// Short-lived signed invoice URL (works in a browser without the app's login header)
  static Future<String?> getInvoiceShareLink(String rideId) async {
    final token = await TokenStorage.getToken();
    final res = await ApiService().get(ApiConstants.rideInvoiceLink(rideId), token: token);
    if (!res.isSuccess || res.data == null) return null;
    try {
      final raw = res.data is String ? jsonDecode(res.data) : res.data;
      final payload = (raw is Map) ? (raw['data'] ?? raw) : raw;
      final url = (payload is Map) ? payload['url']?.toString() : null;
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openPrintableInvoice(String rideId) async {
    final urlStr = await getInvoiceShareLink(rideId);
    if (urlStr == null) return false;
    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      dev.log('Error launching printable invoice URL: $e', name: 'RideInvoice');
      return false;
    }
  }
}

final rideProvider = StateNotifierProvider<RideNotifier, RideState>((ref) {
  return RideNotifier();
});
