import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/shimmer_widget.dart';
import '../../../../core/widgets/swipe_to_accept_slider.dart';
import '../../../auth/auth_provider.dart';
import '../../../emergency/emergency_contacts_provider.dart';
import '../../../emergency/models/sos_alert_response_model.dart';
import '../../../rides/models/ride_request_model.dart';
import '../../../rides/ride_provider.dart';
import '../../../rides/widgets/driver_cancel_ride_bottom_sheet.dart';
import '../../../rides/widgets/driver_ride_invoice_sheet.dart';
import '../../../rides/models/driver_chat_model.dart';
import '../../../rides/providers/driver_chat_provider.dart';
import '../../../rides/presentation/screens/driver_chat_screen.dart';
import '../../../wallet/wallet_provider.dart';
import '../../../kyc/kyc_details_screen.dart';
import '../../../kyc/kyc_provider.dart';
import '../../../vehicle/vehicle_details_screen.dart';
import '../../../vehicle/vehicle_provider.dart';
import '../../../lost_items/presentation/driver_lost_items_screen.dart';
import '../../../lost_items/providers/driver_lost_item_provider.dart';

class DriverMapHomeTab extends ConsumerStatefulWidget {
  const DriverMapHomeTab({super.key});

  @override
  ConsumerState<DriverMapHomeTab> createState() => _DriverMapHomeTabState();
}

class _DriverMapHomeTabState extends ConsumerState<DriverMapHomeTab>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final TextEditingController _ratingCommentController =
      TextEditingController();
  StreamSubscription<Position>? _positionStreamSub;

  // Initial viewport fallback while waiting for GPS lock (never pinned as fake driver location)
  static const LatLng _defaultPosition = LatLng(28.6139, 77.2090);
  LatLng _currentPosition = _defaultPosition;
  bool _hasRealLocation = false;
  bool _hasLocationPermission = false;
  bool _hasCenteredInitialCamera = false;
  String _locationStatusText = 'Fetching your current location...';
  String? _locationActionLabel;
  bool _locationServiceDisabled = false;
  bool _locationPermissionDeniedForever = false;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String? _lastRoutedRideId;
  bool _isLoadingLocation = true;
  bool _isLocating = false;
  int _selectedRating = 5;

  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCustomMarkerIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(authProvider.notifier).fetchProfile();
      ref.read(walletProvider.notifier).fetchWalletEarnings();
      await _checkAndRequestLocation();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasRealLocation) {
      _checkAndRequestLocation();
    }
  }

  Future<void> _loadCustomMarkerIcons() async {
    try {
      final pickupIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/mapsPins/p.png',
      );
      final destIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/mapsPins/d.png',
      );
      if (mounted) {
        setState(() {
          _pickupIcon = pickupIcon;
          _destinationIcon = destIcon;
        });
      }
    } catch (e) {
      dev.log(
        'Error loading custom map pin icons: $e',
        name: 'DriverMapHomeTab',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSub?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _ratingCommentController.dispose();
    super.dispose();
  }

  Marker _buildDriverMarker(LatLng position, {double? heading}) {
    return Marker(
      markerId: const MarkerId('driver_location'),
      position: position,
      infoWindow: const InfoWindow(
        title: 'Your Current Location',
        snippet: 'Live GPS Position',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
  }

  void _applyLivePosition(
    Position pos, {
    bool animateCamera = false,
    bool forceCamera = false,
    bool syncServerLocation = false,
  }) {
    if (!mounted) return;
    if (pos.latitude == 0.0 && pos.longitude == 0.0) return;

    final newPos = LatLng(pos.latitude, pos.longitude);
    final updatedMarkers = Set<Marker>.from(_markers)
      ..removeWhere((m) => m.markerId.value == 'driver_location')
      ..add(_buildDriverMarker(newPos, heading: pos.heading));

    setState(() {
      _currentPosition = newPos;
      _hasRealLocation = true;
      _isLoadingLocation = false;
      _locationActionLabel = null;
      _locationServiceDisabled = false;
      _locationPermissionDeniedForever = false;
      _markers = updatedMarkers;
    });

    if (_mapController != null &&
        (forceCamera || (animateCamera && !_hasCenteredInitialCamera))) {
      _hasCenteredInitialCamera = true;
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newPos, zoom: 16.5),
        ),
      );
    }

    final rideNotifier = ref.read(rideProvider.notifier);
    rideNotifier.updateDriverCoordinates(
      newPos.latitude,
      newPos.longitude,
      heading: pos.heading,
      speed: pos.speed,
    );
    if (syncServerLocation || ref.read(rideProvider).isOnline) {
      rideNotifier.updateLocation(newPos.latitude, newPos.longitude);
    }
  }

  Future<bool> _ensureLocationPermission({bool showWarnings = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _locationServiceDisabled = true;
          _locationPermissionDeniedForever = false;
          _locationStatusText = 'GPS is off. Turn on Location to continue.';
          _locationActionLabel = 'ENABLE GPS';
        });
      }
      if (showWarnings && mounted) {
        AppFlushbar.warning(
          context,
          title: 'Location Disabled',
          message: 'Please turn on GPS / Location Services on your device.',
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _locationServiceDisabled = false;
          _locationPermissionDeniedForever = false;
          _locationStatusText = 'Location permission is required.';
          _locationActionLabel = 'ALLOW';
        });
      }
      if (showWarnings && mounted) {
        AppFlushbar.warning(
          context,
          title: 'Permission Denied',
          message: 'Location permission is required to pin your live location.',
        );
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationServiceDisabled = false;
          _locationPermissionDeniedForever = true;
          _locationStatusText = 'Enable Location permission in App Settings.';
          _locationActionLabel = 'SETTINGS';
        });
      }
      if (showWarnings && mounted) {
        AppFlushbar.warning(
          context,
          title: 'Location Permission Blocked',
          message:
              'Please enable Location permission for Ridonova Captain in app settings.',
        );
      }
      return false;
    }

    if (mounted) {
      setState(() {
        _hasLocationPermission = true;
        _locationServiceDisabled = false;
        _locationPermissionDeniedForever = false;
        _locationStatusText = 'Fetching your current location...';
        _locationActionLabel = null;
      });
    }
    return true;
  }

  Future<void> _handleLocationShimmerAction() async {
    if (_locationServiceDisabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    if (_locationPermissionDeniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    await _checkAndRequestLocation();
  }

  Future<Position?> _fetchBestCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        dev.log('Current position fetch fallback error: $e', name: 'DriverMapHomeTab');
        return await Geolocator.getLastKnownPosition();
      }
    }
  }

  void _startLocationStream() {
    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (Position pos) {
        _applyLivePosition(
          pos,
          animateCamera: !_hasCenteredInitialCamera,
          syncServerLocation: !_hasRealLocation,
        );
      },
      onError: (Object error) {
        dev.log('Location stream error: $error', name: 'DriverMapHomeTab');
      },
    );
  }

  Future<void> _checkAndRequestLocation() async {
    if (mounted && !_hasRealLocation) {
      setState(() {
        _isLoadingLocation = true;
        _locationStatusText = 'Fetching your current location...';
        _locationActionLabel = null;
      });
    }

    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        // Keep shimmer visible until real current location is properly fetched
        return;
      }

      // 1. Start continuous live GPS tracking stream (first live fix unlocks shimmer)
      _startLocationStream();

      // 2. Fetch fresh accurate GPS position and pin + center map on it
      final freshPosition = await _fetchBestCurrentPosition();
      if (freshPosition != null) {
        _applyLivePosition(
          freshPosition,
          forceCamera: true,
          syncServerLocation: true,
        );
      } else if (mounted && !_hasRealLocation) {
        setState(() {
          _locationStatusText = 'Weak GPS signal. Waiting for live location...';
          _locationActionLabel = 'RETRY';
        });
      }
    } catch (e) {
      dev.log('Initial location setup error: $e', name: 'DriverMapHomeTab');
      if (mounted && !_hasRealLocation) {
        setState(() {
          _locationStatusText = 'Unable to fetch current location.';
          _locationActionLabel = 'RETRY';
        });
      }
    }
  }

  Future<void> _recenterLocation() async {
    if (_mapController != null && _hasRealLocation) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition, zoom: 16.8, tilt: 25.0),
        ),
      );
    }

    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) return;

      if (_positionStreamSub == null) {
        _startLocationStream();
      }

      final pos = await _fetchBestCurrentPosition();
      if (pos != null) {
        _applyLivePosition(
          pos,
          forceCamera: true,
          syncServerLocation: true,
        );
      } else if (mounted) {
        AppFlushbar.warning(
          context,
          title: 'GPS Signal Weak',
          message: 'Unable to fetch current location. Please check GPS and try again.',
        );
      }
    } catch (e) {
      dev.log('Location recenter error: $e', name: 'DriverMapHomeTab');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _handleDutyToggle(bool isOnline) async {
    final rideNotifier = ref.read(rideProvider.notifier);
    final authNotifier = ref.read(authProvider.notifier);

    authNotifier.updateDutyStatus(isOnline);

    if (isOnline) {
      final vehicle = ref.read(vehicleProvider).vehicleData;
      final success = await rideNotifier.goOnline(
        battery: 85,
        vehicleType: vehicle.hasVehicle ? vehicle.normalizedVehicleType : null,
      );
      if (mounted) {
        if (success) {
          AppFlushbar.success(
            context,
            title: 'Duty Status: ONLINE 🟢',
            message: 'Broadcasting live location & ready for ride requests...',
          );
        } else {
          final errMsg =
              ref.read(rideProvider).errorMessage ??
              'Unable to go online right now. Please try again.';
          AppFlushbar.error(
            context,
            title: 'Cannot Go Online',
            message: errMsg,
          );
        }
      }
    } else {
      await rideNotifier.goOffline();
      if (mounted) {
        AppFlushbar.warning(
          context,
          title: 'Duty Status: OFFLINE 🔴',
          message: 'You are now offline and won\'t receive new ride requests.',
        );
      }
    }
  }

  Future<void> _launchPhoneCall(String phone, String rideId) async {
    final rideNotifier = ref.read(rideProvider.notifier);
    final maskedNum = await rideNotifier.initiateMaskedCall(rideId);
    final targetPhone = (maskedNum != null && maskedNum.isNotEmpty)
        ? maskedNum
        : phone;

    if (targetPhone.isEmpty) {
      if (mounted)
        AppFlushbar.error(
          context,
          title: 'Call Failed',
          message: 'No phone number available.',
        );
      return;
    }

    final url = Uri.parse('tel:$targetPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted)
        AppFlushbar.error(
          context,
          title: 'Call Error',
          message: 'Could not launch phone dialer.',
        );
    }
  }

  void _openDriverChat(BuildContext context, RideRequestModel ride) {
    final displayName = ride.isForSomeoneElse && ride.passengerName.isNotEmpty
        ? ride.passengerName
        : ride.riderName;
    final displayPhone = ride.isForSomeoneElse && ride.passengerPhone.isNotEmpty
        ? ride.passengerPhone
        : ride.riderPhone;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverChatScreen(
          rideId: ride.id,
          riderName: displayName.isNotEmpty ? displayName : 'Passenger',
          riderPhone: displayPhone,
          pickupAddress: ride.pickupAddress,
          destinationAddress: ride.dropAddress,
        ),
      ),
    );
  }

  Widget _buildInRideChatFloatingBanner(
    BuildContext context,
    RideRequestModel ride,
    ChatMessageModel message,
  ) {
    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () {
                  ref
                      .read(driverChatProvider(ride.id).notifier)
                      .dismissLatestBanner();
                  _openDriverChat(context, ride);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.senderName.isNotEmpty
                          ? message.senderName
                          : 'Passenger',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 1-Tap Quick Action "OK, got it!"
            InkWell(
              onTap: () {
                ref
                    .read(driverChatProvider(ride.id).notifier)
                    .sendQuickReply('OK, got it!');
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                ),
                child: const Text(
                  'OK, got it!',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                ref
                    .read(driverChatProvider(ride.id).notifier)
                    .dismissLatestBanner();
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternalNavigation(double lat, double lng) async {
    if (lat == 0.0 || lng == 0.0) return;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted)
        AppFlushbar.error(
          context,
          title: 'Maps Error',
          message: 'Could not open Google Maps navigation.',
        );
    }
  }

  void _showSosConfirmationDialog(String rideId) {
    String selectedReason = 'Driver safety threat / dispute';
    final reasons = [
      'Driver safety threat / dispute',
      'Accident / Medical emergency',
      'Suspicious activity / harassment',
      'Vehicle breakdown in unsafe zone',
      'Other emergency',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Trigger Emergency SOS?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will instantly alert the 24x7 Ridonova Safety Control Room and send an SMS with your live GPS location to your emergency contacts.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select Emergency Reason:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedReason,
                        isExpanded: true,
                        items: reasons
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Police (112) can be called directly from the next screen.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7F1D1D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);

                          final alert = await ref
                              .read(emergencyContactsProvider.notifier)
                              .triggerDriverSos(
                                rideId: rideId,
                                lat: _currentPosition.latitude,
                                lng: _currentPosition.longitude,
                                reason: selectedReason,
                              );

                          if (context.mounted) {
                            Navigator.pop(dialogCtx);
                            if (alert != null) {
                              _showSosActivatedDialog(alert);
                            } else {
                              final err = ref
                                  .read(emergencyContactsProvider)
                                  .errorMessage;
                              AppFlushbar.error(
                                context,
                                title: 'SOS Trigger Failed',
                                message: err ?? 'Could not trigger SOS.',
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'CONFIRM SOS 🚨',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSosActivatedDialog(SosAlertResponseModel alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚨 SOS ACTIVATED',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  Text(
                    'Control Room Alert Dispatched',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alert Reference: ${alert.alertId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF7F1D1D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live GPS: ${_currentPosition.latitude.toStringAsFixed(4)}, ${_currentPosition.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${alert.contactsNotified} emergency contact(s) notified via SMS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Call Police (112) Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => EmergencyContactsNotifier.callPolice(),
                icon: const Icon(Icons.local_police_rounded),
                label: const Text(
                  'CALL POLICE (112)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Call Captain Helpline Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(
                    color: AppColors.secondary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    EmergencyContactsNotifier.callCaptainHelpline(),
                icon: const Icon(Icons.headset_mic_rounded, size: 18),
                label: const Text(
                  'CALL CAPTAIN HELPLINE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'CLOSE ALERT WINDOW',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmationDialog(String rideId) {
    showDriverCancelRideBottomSheet(context, rideId: rideId);
  }

  void _updateRouteOnMap(RideState rideState) {
    final route = rideState.activeRoute;
    final activeRide = rideState.activeRide;

    if (activeRide == null || route == null || route.routeCoordinates.isEmpty) {
      if (_polylines.isNotEmpty || _lastRoutedRideId != null) {
        setState(() {
          _polylines = {};
          _lastRoutedRideId = null;
          _markers = {
            Marker(
              markerId: const MarkerId('driver_location'),
              position: _currentPosition,
              infoWindow: const InfoWindow(
                title: 'Your Current Location',
                snippet: 'Captain Online & Ready',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          };
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition, 16.0),
        );
      }
      return;
    }

    final coords = route.routeCoordinates;
    final isPickup = route.target == 'pickup';

    final LatLng pickupLatLng =
        (activeRide.pickupLat != 0.0 && activeRide.pickupLng != 0.0)
        ? LatLng(activeRide.pickupLat, activeRide.pickupLng)
        : ((isPickup && route.targetLat != 0.0)
              ? LatLng(route.targetLat, route.targetLng)
              : const LatLng(0, 0));

    final LatLng dropLatLng =
        (activeRide.dropLat != 0.0 && activeRide.dropLng != 0.0)
        ? LatLng(activeRide.dropLat, activeRide.dropLng)
        : ((!isPickup && route.targetLat != 0.0)
              ? LatLng(route.targetLat, route.targetLng)
              : const LatLng(0, 0));

    final Set<Marker> updatedMarkers = {
      Marker(
        markerId: const MarkerId('driver_location'),
        position: _currentPosition,
        infoWindow: const InfoWindow(title: 'Driver (You)'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      if (pickupLatLng.latitude != 0.0 && pickupLatLng.longitude != 0.0)
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: pickupLatLng,
          infoWindow: InfoWindow(
            title: 'Pickup Location 🟢',
            snippet: activeRide.pickupAddress.isNotEmpty
                ? activeRide.pickupAddress
                : route.targetAddress,
          ),
          icon:
              _pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      if (dropLatLng.latitude != 0.0 && dropLatLng.longitude != 0.0)
        Marker(
          markerId: const MarkerId('destination_location'),
          position: dropLatLng,
          infoWindow: InfoWindow(
            title: 'Destination 🔴',
            snippet: activeRide.dropAddress.isNotEmpty
                ? activeRide.dropAddress
                : route.targetAddress,
          ),
          icon:
              _destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };

    final Set<Polyline> updatedPolylines = {
      Polyline(
        polylineId: const PolylineId('ride_navigation_route'),
        points: coords,
        color: AppColors.primary,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };

    setState(() {
      _markers = updatedMarkers;
      _polylines = updatedPolylines;
    });

    final routeKey = '${route.rideId}_${route.target}';
    if (_mapController != null &&
        coords.isNotEmpty &&
        _lastRoutedRideId != routeKey) {
      _lastRoutedRideId = routeKey;
      _fitMapBounds(coords);
    }
  }

  void _fitMapBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80.0,
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final rideState = ref.watch(rideProvider);

    ref.listen<RideState>(rideProvider, (previous, next) {
      if (previous?.activeRoute != next.activeRoute ||
          previous?.activeRide != next.activeRide) {
        _updateRouteOnMap(next);
      }

      if (next.rideStep == RideStep.cancelled &&
          previous?.rideStep != RideStep.cancelled) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ride Cancelled'),
            content: Text(
              next.errorMessage ?? 'The ride was cancelled by the customer.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  ref.read(rideProvider.notifier).finishCompletedRide();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    if (!_hasRealLocation || _isLoadingLocation) {
      return Scaffold(
        body: HomeScreenShimmer(
          statusText: _locationStatusText,
          actionLabel: _locationActionLabel,
          onActionPressed: _locationActionLabel != null
              ? _handleLocationShimmerAction
              : null,
        ),
      );
    }

    final isOnline = rideState.isOnline;
    final activeRide = rideState.activeRide;
    final incomingRide =
        rideState.incomingPopupRide ??
        (rideState.pendingRequests.isNotEmpty
            ? rideState.pendingRequests.first
            : null);
    final chatState = activeRide != null
        ? ref.watch(driverChatProvider(activeRide.id))
        : null;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Google Map Background
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: _hasRealLocation ? 16.5 : 12.0,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              if (rideState.activeRoute != null) {
                _updateRouteOnMap(rideState);
              } else if (_hasRealLocation) {
                _hasCenteredInitialCamera = true;
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _currentPosition, zoom: 16.5),
                  ),
                );
              }
            },
          ),

          // 2. Top Bar (Uber / Rapido Style Duty Status & Live Location FAB)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Modern Online/Offline Pill Badge
                GestureDetector(
                  onTap: rideState.isDutyLoading
                      ? null
                      : () => _handleDutyToggle(!isOnline),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A), // Dark slate
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isOnline
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : Colors.white12,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rideState.isDutyLoading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isOnline
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444))
                                          .withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? 'ONLINE' : 'OFFLINE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Colors.white38,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isOnline
                              ? Icons.radar_rounded
                              : Icons.power_settings_new_rounded,
                          size: 14,
                          color: isOnline
                              ? const Color(0xFF34D399)
                              : Colors.white60,
                        ),
                      ],
                    ),
                  ),
                ),

                // Live SOS Floating Action Button during active rides
                if (activeRide != null &&
                    rideState.rideStep != RideStep.completed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => _showSosConfirmationDialog(activeRide.id),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // High-Precision Recenter / My Location FAB
                _buildMyLocationFab(),
              ],
            ),
          ),

          // Live Chat In-Ride Top Floating Banner (When Chat is Minimized)
          if (activeRide != null && chatState?.latestIncomingMessage != null)
            Positioned(
              top: topPadding + 62,
              left: 16,
              right: 16,
              child: _buildInRideChatFloatingBanner(
                context,
                activeRide,
                chatState!.latestIncomingMessage!,
              ),
            ),

          // 3. Ride Execution Flow Sheet or Default Duty Sheet
          if (activeRide != null && rideState.rideStep != RideStep.completed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildActiveRideExecutionSheet(
                activeRide,
                rideState,
                chatState,
              ),
            )
          else if (rideState.rideStep == RideStep.completed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildCompletedSummarySheet(rideState),
            )
          else if (!(isOnline && incomingRide != null))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildDefaultDutySheet(isOnline, rideState.isDutyLoading),
            ),

          // 4. Real-Time Incoming Ride Popup Modal (15-Second Countdown) - Topmost Layer
          if (isOnline && activeRide == null && incomingRide != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildIncomingRidePopupModal(incomingRide, rideState),
            ),
        ],
      ),
    );
  }

  MainAxisSize minWidth(double w) => MainAxisSize.min;

  Widget _buildIncomingRidePopupModal(RideRequestModel req, RideState state) {
    final rideNotifier = ref.read(rideProvider.notifier);
    final countdown = state.incomingCountdownSeconds;
    final progress = countdown / 15.0;

    final pickupText = req.pickupAddress.isNotEmpty
        ? req.pickupAddress
        : 'Pickup Location';
    final dropText = req.dropAddress.isNotEmpty
        ? req.dropAddress
        : 'Drop Location';
    final riderName = req.riderName.isNotEmpty ? req.riderName : 'Customer';
    final vehicleTypeText = req.vehicleType.isNotEmpty
        ? ' • ${req.vehicleType}'
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Countdown Timer Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                countdown > 5 ? AppColors.primary : AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 🟢 1. Badge Row (New Ride + Booked for Someone Else Badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NEW RIDE • ${countdown}s',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (req.isForSomeoneElse) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 12,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'FOR SOMEONE ELSE',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '₹ ${req.fare.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🟢 2. Passenger / Rider Info Row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: req.isForSomeoneElse
                    ? Colors.orange.shade700
                    : AppColors.primary,
                child: Icon(
                  req.isForSomeoneElse
                      ? Icons.person_pin_rounded
                      : Icons.person,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.isForSomeoneElse && req.passengerName.isNotEmpty
                          ? 'Passenger: ${req.passengerName}'
                          : '$riderName$vehicleTypeText',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (req.isForSomeoneElse)
                      Text(
                        'Booked by: ${req.bookedByName.isNotEmpty ? req.bookedByName : riderName}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (req.paymentMethod.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    req.paymentMethod,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.trip_origin, color: Colors.green, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickupText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on, color: Colors.red, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dropText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    rideNotifier.rejectRide(req.id, reason: 'Driver rejected');
                  },
                  child: const Text(
                    'DECLINE',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: state.isRideLoading
                      ? null
                      : () async {
                          final success = await rideNotifier.acceptRide(
                            req.id,
                            driverLat: _currentPosition.latitude,
                            driverLng: _currentPosition.longitude,
                          );
                          if (mounted) {
                            if (success) {
                              AppFlushbar.success(
                                context,
                                title: 'Ride Accepted! 🚖',
                                message: 'Head to the pickup location.',
                              );
                            } else {
                              AppFlushbar.error(
                                context,
                                title: 'Accept Failed',
                                message:
                                    state.errorMessage ??
                                    'Failed to accept ride.',
                              );
                            }
                          }
                        },
                  child: state.isRideLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'ACCEPT RIDE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerifyAndStartRide(String rideId, String otp) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length < 4) {
      AppFlushbar.error(
        context,
        title: 'Incomplete OTP',
        message: 'Please enter all 4 digits of the OTP.',
      );
      return;
    }

    final rideNotifier = ref.read(rideProvider.notifier);
    final success = await rideNotifier.startRide(
      rideId,
      cleanOtp,
      driverLat: _currentPosition.latitude,
      driverLng: _currentPosition.longitude,
    );
    if (mounted) {
      if (success) {
        _otpController.clear();
        AppFlushbar.success(
          context,
          title: 'Ride Started! 🚖',
          message: 'Navigation switched to drop destination.',
        );
      } else {
        final state = ref.read(rideProvider);
        AppFlushbar.error(
          context,
          title: 'Start Ride Failed',
          message:
              state.errorMessage ??
              'The OTP entered is incorrect. Please check with rider and try again.',
        );
      }
    }
  }

  Widget _buildActiveRideExecutionSheet(
    RideRequestModel ride,
    RideState state, [
    DriverChatState? chatState,
  ]) {
    final rideNotifier = ref.read(rideProvider.notifier);
    final route = state.activeRoute;

    final riderName = ride.riderName.isNotEmpty
        ? ride.riderName
        : (route != null && route.riderName.isNotEmpty
              ? route.riderName
              : 'Customer');
    final riderPhone = ride.riderPhone.isNotEmpty
        ? ride.riderPhone
        : (route != null && route.riderPhone.isNotEmpty
              ? route.riderPhone
              : '');

    // Contact details determination
    final displayName = ride.isForSomeoneElse && ride.passengerName.isNotEmpty
        ? ride.passengerName
        : riderName;
    final displayPhone = ride.isForSomeoneElse && ride.passengerPhone.isNotEmpty
        ? ride.passengerPhone
        : riderPhone;

    final pickupText = ride.pickupAddress.isNotEmpty
        ? ride.pickupAddress
        : (route != null &&
                  route.target == 'pickup' &&
                  route.targetAddress.isNotEmpty
              ? route.targetAddress
              : 'Pickup Location');

    final dropText = ride.dropAddress.isNotEmpty
        ? ride.dropAddress
        : (route != null &&
                  route.target == 'dropoff' &&
                  route.targetAddress.isNotEmpty
              ? route.targetAddress
              : 'Drop Destination');

    final isPickupStep =
        state.rideStep == RideStep.accepted ||
        state.rideStep == RideStep.arrived;
    final targetLat = isPickupStep ? ride.pickupLat : ride.dropLat;
    final targetLng = isPickupStep ? ride.pickupLng : ride.dropLng;

    // Status styling without redundant "TRIP STATUS:" prefix
    final String statusLabel;
    final IconData statusIcon;
    final Color statusColor;
    final Color statusBg;
    final Color statusBorder;

    switch (state.rideStep) {
      case RideStep.accepted:
        statusLabel = 'ACCEPTED';
        statusIcon = Icons.directions_car_rounded;
        statusColor = const Color(0xFF1D4ED8);
        statusBg = const Color(0xFFEFF6FF);
        statusBorder = const Color(0xFFBFDBFE);
        break;
      case RideStep.arrived:
        statusLabel = 'ARRIVED';
        statusIcon = Icons.location_on_rounded;
        statusColor = const Color(0xFFB45309);
        statusBg = const Color(0xFFFEF3C7);
        statusBorder = const Color(0xFFFDE68A);
        break;
      case RideStep.started:
        statusLabel = 'ON TRIP';
        statusIcon = Icons.navigation_rounded;
        statusColor = const Color(0xFF047857);
        statusBg = const Color(0xFFECFDF5);
        statusBorder = const Color(0xFFA7F3D0);
        break;
      default:
        statusLabel = state.rideStep.name.toUpperCase();
        statusIcon = Icons.info_outline_rounded;
        statusColor = const Color(0xFF475569);
        statusBg = const Color(0xFFF1F5F9);
        statusBorder = const Color(0xFFCBD5E1);
        break;
    }

    // Compact Pinput themes
    final defaultPinTheme = PinTheme(
      width: 44,
      height: 44,
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: Colors.white,
        border: Border.all(color: AppColors.primary, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: AppColors.success, width: 1.5),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Status Tag & Action Icons (SOS, Maps, Cancel)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Clean Status Badge (without redundant "TRIP STATUS:" prefix)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons Row (Compact SOS, Google Maps Nav, Cancel)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Compact Red SOS Pill Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showSosConfirmationDialog(ride.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // External Google Maps Navigation Button (Compact 28x28)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          _openExternalNavigation(targetLat, targetLng),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: AppColors.primary,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Cancel Ride Button (Compact 28x28)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCancelConfirmationDialog(ride.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.error,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Rider Details & Quick Communication (Chat, Call, Fare)
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ride.isForSomeoneElse
                    ? Colors.orange.shade700
                    : AppColors.secondary,
                child: Icon(
                  ride.isForSomeoneElse
                      ? Icons.person_pin_rounded
                      : Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ride.isForSomeoneElse) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Passenger',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ride.isForSomeoneElse
                          ? 'Booked by ${ride.bookedByName} • ${ride.paymentMethod}'
                          : (displayPhone.isNotEmpty
                                ? 'Phone: $displayPhone'
                                : 'Payment: ${ride.paymentMethod}'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Chat with Rider Button + Unread Badge (Compact 34x34)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openDriverChat(context, ride),
                      borderRadius: BorderRadius.circular(17),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.primary,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                  if ((chatState?.unreadCount ?? 0) > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        child: Text(
                          '${chatState!.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),

              // Call Rider Button (Compact 34x34)
              if (displayPhone.isNotEmpty) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _launchPhoneCall(displayPhone, ride.id),
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_rounded,
                        color: AppColors.success,
                        size: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Trip Fare
              Text(
                '₹${ride.fare.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // 3. Pickup & Drop Addresses with Visual Connector
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
                  Container(
                    width: 2,
                    height: 18,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: const Color(0xFFE2E8F0),
                  ),
                  const Icon(
                    Icons.square_rounded,
                    color: Color(0xFFEF4444),
                    size: 10,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickupText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dropText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // STEP 1: ACCEPTED -> SWIPE TO MARK ARRIVED (Uber / Rapido Style)
          if (state.rideStep == RideStep.accepted) ...[
            SwipeToAcceptSlider(
              text: 'I HAVE ARRIVED AT PICKUP',
              trackColor: AppColors.primary,
              activeTrackColor: AppColors.primaryDark,
              iconColor: AppColors.primary,
              height: 48,
              isLoading: state.isRideLoading,
              onSwipeComplete: () async {
                final success = await rideNotifier.markArrived(
                  ride.id,
                  driverLat: _currentPosition.latitude,
                  driverLng: _currentPosition.longitude,
                );
                if (mounted) {
                  if (success) {
                    AppFlushbar.success(
                      context,
                      title: 'Arrived at Pickup 📍',
                      message:
                          'Waiting timer started. Ask rider for 4-digit OTP.',
                    );
                  } else {
                    AppFlushbar.error(
                      context,
                      title: 'Action Failed',
                      message: state.errorMessage ?? 'Failed to mark arrived.',
                    );
                  }
                }
              },
            ),
          ]
          // STEP 2: ARRIVED -> WAITING TIMER (SECTION 5.24) & ENTER OTP -> START RIDE
          else if (state.rideStep == RideStep.arrived) ...[
            Builder(
              builder: (ctx) {
                final isEligibleCancel = state.canCancelWithWaitingFee;
                final isCharging = state.isWaitingCharging;
                final charge = state.effectiveWaitingCharge;
                final rate = state.waitingChargePerMinute;

                final Color cardBg = isEligibleCancel
                    ? const Color(0xFFFEF2F2)
                    : (isCharging ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5));
                final Color cardBorder = isEligibleCancel
                    ? const Color(0xFFFECACA)
                    : (isCharging ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0));
                final Color iconBg = isEligibleCancel
                    ? const Color(0xFFFEE2E2)
                    : (isCharging ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5));
                final Color accentColor = isEligibleCancel
                    ? const Color(0xFFB91C1C)
                    : (isCharging ? const Color(0xFFB45309) : const Color(0xFF047857));

                final String statusTitle = isEligibleCancel
                    ? 'Waiting Fee Earned: ₹${charge.toStringAsFixed(0)}'
                    : (isCharging
                        ? 'Waiting Charges Active (+₹${charge.toStringAsFixed(0)})'
                        : 'Free Waiting (${_formatSeconds(state.waitingFreeRemainingSeconds)} left)');

                final String statusSubtitle = isEligibleCancel
                    ? '5+ min waited • You may cancel & keep ₹${charge.toStringAsFixed(0)}'
                    : (isCharging
                        ? '₹${rate.toStringAsFixed(0)}/min • Cancel unlocks in ${_formatSeconds(state.driverCancelUnlockInSeconds)}'
                        : '₹${rate.toStringAsFixed(0)}/min applies after 3 min free window');

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isEligibleCancel
                                  ? Icons.payments_rounded
                                  : Icons.hourglass_top_rounded,
                              color: accentColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: accentColor,
                                  ),
                                ),
                                Text(
                                  statusSubtitle,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: accentColor.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: accentColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatSeconds(state.waitingSecondsElapsed),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isEligibleCancel) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.cancel_schedule_send_rounded, size: 16),
                            label: Text(
                              'Cancel Ride & Keep ₹${charge.toStringAsFixed(0)} Waiting Fee',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: state.isRideLoading
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        title: const Text(
                                          'Cancel Ride (Rider No-Show)?',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        content: Text(
                                          'You have waited ${_formatSeconds(state.waitingSecondsElapsed)}. Cancelling now will credit ₹${charge.toStringAsFixed(2)} waiting charges directly to your driver wallet.',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx, false),
                                            child: const Text('Keep Waiting'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFDC2626),
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => Navigator.pop(dCtx, true),
                                            child: Text('Cancel & Keep ₹${charge.toStringAsFixed(0)}'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true || !mounted) return;
                                    final ok = await ref.read(rideProvider.notifier).cancelRide(
                                          ride.id,
                                          reason: 'Rider did not show up after 5+ min wait',
                                          code: 'rider_no_show',
                                        );
                                    if (!mounted) return;
                                    if (ok) {
                                      ref.read(walletProvider.notifier).fetchWalletEarnings();
                                      ref.read(walletProvider.notifier).fetchTransactions();
                                      final msg = ref.read(rideProvider).lastCancelMessage ??
                                          'Ride cancelled. ₹${charge.toStringAsFixed(2)} waiting charge credited to your wallet.';
                                      AppFlushbar.success(
                                        context,
                                        title: 'Waiting Fee Credited',
                                        message: msg,
                                      );
                                    } else {
                                      AppFlushbar.error(
                                        context,
                                        title: 'Cancel Failed',
                                        message: 'Could not cancel ride. Please try again.',
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // Compact OTP Card with Pinput
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.pin_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Enter Rider 4-Digit OTP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ask rider for the 4-digit PIN displayed on their app',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Pinput(
                    length: 4,
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    submittedPinTheme: submittedPinTheme,
                    errorPinTheme: errorPinTheme,
                    forceErrorState:
                        state.errorMessage != null &&
                        state.errorMessage!.isNotEmpty,
                    showCursor: true,
                    keyboardType: TextInputType.number,
                    onCompleted: (pin) {
                      _handleVerifyAndStartRide(ride.id, pin);
                    },
                  ),
                  if (state.errorMessage != null &&
                      state.errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Compact Verify & Start Ride Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: AppColors.success,
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: state.isRideLoading
                  ? null
                  : () => _handleVerifyAndStartRide(
                      ride.id,
                      _otpController.text.trim(),
                    ),
              child: state.isRideLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'VERIFY OTP & START RIDE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ]
          // STEP 3: STARTED -> COMPLETE RIDE
          else if (state.rideStep == RideStep.started) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.navigation_rounded,
                    color: AppColors.success,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'TRIP IN PROGRESS • NAVIGATING TO DROPOFF',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: AppColors.secondary,
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: state.isRideLoading
                  ? null
                  : () async {
                      final success = await rideNotifier.completeRide(ride.id);
                      if (mounted) {
                        if (success) {
                          AppFlushbar.success(
                            context,
                            title: 'Trip Completed! 🎉',
                            message: 'Collect fare payment from rider.',
                          );
                        } else {
                          AppFlushbar.error(
                            context,
                            title: 'Completion Failed',
                            message:
                                state.errorMessage ??
                                'Failed to complete trip.',
                          );
                        }
                      }
                    },
              child: state.isRideLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'COMPLETE RIDE & COLLECT FARE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedSummarySheet(RideState state) {
    final summary = state.completedFareSummary ?? {};
    final fareAmt =
        summary['fare'] ?? summary['totalFare'] ?? summary['amount'] ?? 0.0;
    final paymentMethod = summary['paymentMethod']?.toString() ?? 'CASH';
    final riderName = summary['riderName']?.toString() ?? 'Customer';
    final rideId =
        state.activeRide?.id ??
        summary['rideId']?.toString() ??
        summary['id']?.toString() ??
        '';
    final tipVal =
        (summary['tip'] as num?)?.toDouble() ??
        (summary['tipAmount'] as num?)?.toDouble() ??
        (summary['tips'] as num?)?.toDouble() ??
        0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Trip Completed Successfully! 🎉',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Collect payment from $riderName',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Fare Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Collectible Fare',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹ ${fareAmt is num ? fareAmt.toStringAsFixed(0) : fareAmt}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paymentMethod.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Passenger Tip Received Banner
          if (tipVal > 0) ...[
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'Passenger Tip: ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: '+ ₹${tipVal.toStringAsFixed(0)} ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const TextSpan(
                            text: '(100% Yours • Credited to Wallet)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action: View Official Tax Invoice & Receipt
          if (rideId.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => showDriverRideInvoiceSheet(
                context,
                rideId: rideId,
                preloadedRiderName: riderName,
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.secondary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '📄 View Official Receipt / Tax Invoice',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Rating Bar
          const Text(
            'Rate Rider:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                icon: Icon(
                  starIndex <= _selectedRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
                onPressed: () {
                  setState(() => _selectedRating = starIndex);
                },
              );
            }),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _ratingCommentController,
            decoration: InputDecoration(
              hintText: 'Feedback comment (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppColors.primary,
            ),
            onPressed: state.isRideLoading
                ? null
                : () async {
                    final rideNotifier = ref.read(rideProvider.notifier);
                    final rideId = state.activeRide?.id ?? '';
                    await rideNotifier.rateRider(
                      rideId,
                      rating: _selectedRating,
                      comment: _ratingCommentController.text.trim(),
                    );
                    ref.read(walletProvider.notifier).fetchWalletEarnings();
                    _ratingCommentController.clear();
                    if (mounted) {
                      AppFlushbar.success(
                        context,
                        title: 'Rating Submitted! ⭐️',
                        message: 'Ready for next ride request.',
                      );
                    }
                  },
            child: state.isRideLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('SUBMIT & RETURN TO DUTY'),
          ),
        ],
      ),
    );
  }

  Future<void> _openRegistrationFlow({required bool openVehicleOnly}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => openVehicleOnly
            ? const VehicleDetailsScreen()
            : const KycDetailsScreen(),
      ),
    );
    if (!mounted) return;
    ref.read(rideProvider.notifier).clearErrorCode();
    await ref.read(authProvider.notifier).fetchProfile();
  }

  Widget? _buildKycRegistrationCard() {
    final authState = ref.watch(authProvider);
    final kyc = ref.watch(kycProvider).kycData;
    final vehicle = ref.watch(vehicleProvider).vehicleData;
    final rideState = ref.watch(rideProvider);

    final bool profileMissingFromApi =
        rideState.errorCode == 'DRIVER_PROFILE_MISSING';
    final bool hasDriverProfile = kyc.hasDriverProfile && !profileMissingFromApi;
    final bool isProfileMissing =
        profileMissingFromApi ||
        (!authState.isProfileLoading && !kyc.hasDriverProfile);
    final bool isVehicleMissing =
        !isProfileMissing && hasDriverProfile && !vehicle.hasVehicle;
    final bool isKycRejected = !isProfileMissing && kyc.isKycRejected;
    final bool isKycPending =
        !isProfileMissing &&
        !isVehicleMissing &&
        !isKycRejected &&
        kyc.isKycPending;

    if (!isProfileMissing &&
        !isVehicleMissing &&
        !isKycRejected &&
        !isKycPending) {
      return null;
    }

    final Color bgColor;
    final Color borderColor;
    final Color iconBgColor;
    final Color accentColor;
    final Color titleColor;
    final IconData icon;
    final String title;
    final String subtitle;
    final String buttonText;
    final VoidCallback onPressed;

    if (isProfileMissing) {
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFDBA74);
      iconBgColor = const Color(0xFFFED7AA);
      accentColor = AppColors.primary;
      titleColor = const Color(0xFF9A3412);
      icon = Icons.assignment_late_rounded;
      title = 'Complete Your KYC & Registration';
      subtitle =
          'Your driver profile is incomplete. Submit KYC & vehicle details to go online and accept rides.';
      buttonText = 'COMPLETE REGISTRATION';
      onPressed = () => _openRegistrationFlow(openVehicleOnly: false);
    } else if (isVehicleMissing) {
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFDBA74);
      iconBgColor = const Color(0xFFFED7AA);
      accentColor = AppColors.primary;
      titleColor = const Color(0xFF9A3412);
      icon = Icons.directions_car_filled_rounded;
      title = 'Register Your Vehicle';
      subtitle =
          'KYC submitted! Add your vehicle details to complete registration and start taking rides.';
      buttonText = 'ADD VEHICLE DETAILS';
      onPressed = () => _openRegistrationFlow(openVehicleOnly: true);
    } else if (isKycRejected) {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFCA5A5);
      iconBgColor = const Color(0xFFFECACA);
      accentColor = AppColors.error;
      titleColor = const Color(0xFF991B1B);
      icon = Icons.gpp_bad_rounded;
      title = 'KYC Verification Rejected';
      subtitle =
          'Please re-submit your KYC documents to activate your captain account.';
      buttonText = 'RESUBMIT KYC';
      onPressed = () => _openRegistrationFlow(openVehicleOnly: false);
    } else {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFF93C5FD);
      iconBgColor = const Color(0xFFDBEAFE);
      accentColor = AppColors.secondary;
      titleColor = const Color(0xFF1E3A8A);
      icon = Icons.hourglass_top_rounded;
      title = 'KYC Under Verification';
      subtitle =
          'Your documents are submitted and pending admin approval. Check status again anytime.';
      buttonText = authState.isProfileLoading ? 'CHECKING...' : 'REFRESH STATUS';
      onPressed = () {
        if (!authState.isProfileLoading) {
          ref.read(authProvider.notifier).fetchProfile();
        }
      };
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: titleColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: titleColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isKycPending)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _openRegistrationFlow(openVehicleOnly: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.verified_user_rounded, size: 16),
                      label: const Text(
                        'COMPLETE KYC',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: onPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        authState.isProfileLoading ? 'WAIT...' : 'REFRESH',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  buttonText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultDutySheet(bool isOnline, bool isLoading) {
    final lostItemPendingCount = ref.watch(driverLostItemProvider).pendingCount;
    final kycRegistrationCard = _buildKycRegistrationCard();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // KYC / Registration Incomplete Card
          if (kycRegistrationCard != null) kycRegistrationCard,

          // Pending Lost Item Alert Banner
          if (lostItemPendingCount > 0) ...[
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverLostItemsScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFED7AA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.find_in_page_rounded,
                        color: Color(0xFFC2410C),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$lostItemPendingCount Lost Item Inquiry Pending',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                          const Text(
                            'Passenger reported an item left behind. Tap to check.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: Color(0xFFC2410C),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 2. Primary Status Card (Uber / Rapido Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: isOnline
                  ? const LinearGradient(
                      colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOnline
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF64748B).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isOnline
                          ? Icons.radar_rounded
                          : Icons.power_settings_new_rounded,
                      color: isOnline
                          ? const Color(0xFF059669)
                          : const Color(0xFF475569),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Text Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isOnline ? "You're Online" : "You're Offline",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isOnline
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          if (isOnline) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isOnline
                            ? 'Broadcasting live location & ready for bookings'
                            : 'Go online to start receiving nearby ride requests',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline
                              ? const Color(0xFF047857)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Switch Toggle
                if (isLoading)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                else
                  Transform.scale(
                    scale: 0.95,
                    child: Switch.adaptive(
                      value: isOnline,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      onChanged: (val) => _handleDutyToggle(val),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Primary CTA Button (GO ONLINE / GO OFFLINE)
          if (!isOnline)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF10B981), // Emerald
                elevation: 3,
                shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: isLoading ? null : () => _handleDutyToggle(true),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.power_settings_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'GO ONLINE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: const Color(0xFFF8FAFC),
              ),
              onPressed: isLoading ? null : () => _handleDutyToggle(false),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.power_settings_new_rounded,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'GO OFFLINE',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyLocationFab() {
    return GestureDetector(
      onTap: _recenterLocation,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: _isLocating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.primary,
                  ),
                )
              : const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
        ),
      ),
    );
  }
}
