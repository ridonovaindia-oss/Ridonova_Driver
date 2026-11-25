import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import '../../core/network/token_storage.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/socket_service.dart';
import 'models/auth_response_model.dart';
import '../kyc/kyc_model.dart';
import '../kyc/kyc_provider.dart';
import '../vehicle/vehicle_model.dart';
import '../vehicle/vehicle_provider.dart';

enum AuthStatus { initial, loading, otpSent, authenticated, unauthenticated, error }

class AuthState {
  final String phoneNumber;
  final String otp;
  final AuthStatus status;
  final String? errorMessage;
  final String? authToken;
  final UserModel? user;
  final bool isSessionLoaded;
  final bool isProfileLoading;
  final String? profileError;
  final int resendCooldown;
  final int attemptsLeft;
  final bool isBlocked;
  final int lockoutSecondsRemaining;

  AuthState({
    this.phoneNumber = '',
    this.otp = '',
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.authToken,
    this.user,
    this.isSessionLoaded = false,
    this.isProfileLoading = false,
    this.profileError,
    this.resendCooldown = 0,
    this.attemptsLeft = 3,
    this.isBlocked = false,
    this.lockoutSecondsRemaining = 0,
  });

  AuthState copyWith({
    String? phoneNumber,
    String? otp,
    AuthStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? authToken,
    UserModel? user,
    bool? isSessionLoaded,
    bool? isProfileLoading,
    String? profileError,
    bool clearProfileError = false,
    int? resendCooldown,
    int? attemptsLeft,
    bool? isBlocked,
    int? lockoutSecondsRemaining,
  }) {
    return AuthState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otp: otp ?? this.otp,
      status: status ?? this.status,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      authToken: authToken ?? this.authToken,
      user: user ?? this.user,
      isSessionLoaded: isSessionLoaded ?? this.isSessionLoaded,
      isProfileLoading: isProfileLoading ?? this.isProfileLoading,
      profileError: clearProfileError ? null : (profileError ?? this.profileError),
      resendCooldown: resendCooldown ?? this.resendCooldown,
      attemptsLeft: attemptsLeft ?? this.attemptsLeft,
      isBlocked: isBlocked ?? this.isBlocked,
      lockoutSecondsRemaining: lockoutSecondsRemaining ?? this.lockoutSecondsRemaining,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final Ref _ref;

  Timer? _cooldownTimer;
  Timer? _lockoutTimer;

  AuthNotifier(this._ref, {ApiService? apiService}) : _apiService = apiService ?? ApiService(), super(AuthState()) {
    loadSavedSession();
  }

  /// Starts 1-second interval cooldown countdown timer for Resend OTP
  void startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    state = state.copyWith(resendCooldown: seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendCooldown > 1) {
        state = state.copyWith(resendCooldown: state.resendCooldown - 1);
      } else {
        timer.cancel();
        state = state.copyWith(resendCooldown: 0);
      }
    });
  }

  /// Starts 1-second interval lockout countdown timer for 10-minute (600s) lock
  void startLockoutTimer(int seconds, {String? phone}) {
    _lockoutTimer?.cancel();
    final targetPhone = phone ?? state.phoneNumber;
    if (targetPhone.isNotEmpty) {
      TokenStorage.setLockout(targetPhone, seconds);
    }
    state = state.copyWith(
      isBlocked: true,
      attemptsLeft: 0,
      lockoutSecondsRemaining: seconds,
    );
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.lockoutSecondsRemaining > 1) {
        state = state.copyWith(lockoutSecondsRemaining: state.lockoutSecondsRemaining - 1);
      } else {
        timer.cancel();
        if (targetPhone.isNotEmpty) {
          TokenStorage.clearLockout(targetPhone);
        }
        state = state.copyWith(
          isBlocked: false,
          attemptsLeft: 3,
          lockoutSecondsRemaining: 0,
          clearErrorMessage: true,
        );
      }
    });
  }

  void cancelTimers() {
    _cooldownTimer?.cancel();
    _lockoutTimer?.cancel();
  }

  @override
  void dispose() {
    cancelTimers();
    super.dispose();
  }

  /// Loads stored user token and session state on app launch
  Future<void> loadSavedSession() async {
    try {
      final token = await TokenStorage.getToken();
      final prefs = await SharedPreferences.getInstance();
      final bool? isNewUser = prefs.getBool('is_new_user');
      final String? userJsonStr = prefs.getString('user_json');
      final String? userPhone = prefs.getString('user_phone');

      if (userPhone != null && userPhone.isNotEmpty) {
        final remainingLockout = await TokenStorage.getRemainingLockoutSeconds(userPhone);
        if (remainingLockout > 0) {
          startLockoutTimer(remainingLockout, phone: userPhone);
        }
      }

      if (token != null && token.isNotEmpty && token != ApiConstants.defaultDevToken) {
        UserModel? user;
        if (userJsonStr != null && userJsonStr.isNotEmpty) {
          try {
            user = UserModel.fromJson(jsonDecode(userJsonStr));
          } catch (_) {}
        }

        user ??= UserModel(
          id: 'stored-user',
          phone: userPhone ?? '',
          fullName: null,
          role: 'driver',
          isNewUser: isNewUser ?? false,
        );

        if (isNewUser != null) {
          user = user.copyWith(isNewUser: isNewUser);
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          authToken: token,
          user: user,
          phoneNumber: user.phone,
          isSessionLoaded: true,
        );

        // Initialize persistent Socket.IO connection for real-time rides & in-ride chat
        try {
          SocketService().initSocket(token);
        } catch (_) {}

        // Fetch fresh profile in background using 'data' key as requested
        fetchProfile();
        return;
      }
    } catch (_) {}

    state = state.copyWith(status: AuthStatus.unauthenticated, isSessionLoaded: true);
  }

  /// Fetches latest driver profile from server using GET /api/driver/profile,
  /// extracting profile, driver (KYC), and vehicle from response['data'].
  Future<bool> fetchProfile() async {
    if (state.authToken == null || state.authToken!.isEmpty) return false;

    state = state.copyWith(isProfileLoading: true, clearProfileError: true);

    try {
      final response = await _apiService.get(ApiConstants.driverProfile, token: state.authToken);

      if (response.isSuccess && response.data != null) {
        final jsonResponse = response.data is String ? jsonDecode(response.data) : response.data;
        if (jsonResponse is Map<String, dynamic>) {
          final dataMap = jsonResponse['data'] ?? jsonResponse['result'] ?? jsonResponse;
          if (dataMap is Map<String, dynamic>) {
            final driverMap = dataMap['driver'];
            final bool hasDriverRecord = driverMap is Map<String, dynamic>;

            // 1. Profile -> UserModel
            final profileMap = dataMap['profile'];
            if (profileMap is Map<String, dynamic>) {
              final user = UserModel.fromJson(profileMap);
              state = state.copyWith(
                user: user.copyWith(isNewUser: !hasDriverRecord),
                phoneNumber: user.phone.isNotEmpty ? user.phone : state.phoneNumber,
              );
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_new_user', !hasDriverRecord);
            }

            // 2. Driver -> KycModel (clear if server returns null)
            if (hasDriverRecord) {
              final kyc = KycModel.fromJson(driverMap);
              _ref.read(kycProvider.notifier).updateKycData(kyc);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_new_user', false);
              if (state.user != null) {
                state = state.copyWith(user: state.user!.copyWith(isNewUser: false));
              }
            } else {
              _ref.read(kycProvider.notifier).reset();
            }

            // 3. Vehicle -> VehicleModel (clear if server returns null)
            final vehicleMap = dataMap['vehicle'];
            if (vehicleMap is Map<String, dynamic>) {
              final vehicle = VehicleModel.fromJson(vehicleMap);
              _ref.read(vehicleProvider.notifier).updateVehicleData(vehicle);
            } else {
              _ref.read(vehicleProvider.notifier).reset();
            }

            // Save user to shared prefs
            if (state.user != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_json', jsonEncode(state.user!.toJson()));
              await prefs.setString('user_phone', state.user!.phone);
            }

            state = state.copyWith(isProfileLoading: false, clearProfileError: true);
            return true;
          }
        }
      }

      // Handle 401 Unauthorized / 403 Forbidden / API error responses
      String? errorMsg = response.errorMessage;
      if (response.data is Map && response.data['message'] != null) {
        errorMsg = response.data['message'].toString();
      }
      state = state.copyWith(
        isProfileLoading: false,
        profileError: errorMsg ?? 'Failed to load driver profile.',
      );
    } catch (e) {
      state = state.copyWith(
        isProfileLoading: false,
        profileError: 'Unable to fetch profile: $e',
      );
    }
    return false;
  }

  Future<void> setPhoneNumber(String phone) async {
    state = state.copyWith(phoneNumber: phone);
    final remainingLockout = await TokenStorage.getRemainingLockoutSeconds(phone);
    if (remainingLockout > 0) {
      startLockoutTimer(remainingLockout, phone: phone);
    } else if (state.isBlocked) {
      cancelTimers();
      state = state.copyWith(
        isBlocked: false,
        attemptsLeft: 3,
        lockoutSecondsRemaining: 0,
        clearErrorMessage: true,
      );
    }
  }

  void setOtp(String otp) {
    state = state.copyWith(otp: otp);
  }

  Future<bool> sendOtp() async {
    if (state.phoneNumber.length < 10) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Please enter a valid 10-digit mobile number');
      return false;
    }

    // Check if phone number is currently locked out
    final remainingLockout = await TokenStorage.getRemainingLockoutSeconds(state.phoneNumber);
    if (remainingLockout > 0) {
      startLockoutTimer(remainingLockout);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Account is temporarily locked for ${(remainingLockout / 60).ceil()} minutes due to 3 incorrect attempts.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final response = await _apiService.post(
      ApiConstants.sendOtp,
      data: {'phone': state.phoneNumber, 'countryCode': '+91', 'role': 'driver'},
    );

    if (response.isSuccess) {
      // 200 OK: OTP sent successfully, start 30s cooldown timer
      startCooldownTimer(30);
      state = state.copyWith(
        status: AuthStatus.otpSent,
        attemptsLeft: 3,
        isBlocked: false,
        lockoutSecondsRemaining: 0,
        clearErrorMessage: true,
      );
      return true;
    } else {
      AuthResponseModel? authResponse;
      if (response.data is Map<String, dynamic>) {
        authResponse = AuthResponseModel.fromJson(response.data);
      }

      final statusCode = response.statusCode;
      final isBlocked = authResponse?.blocked == true;
      final retryAfter = authResponse?.retryAfter;

      if (statusCode == 429 && isBlocked) {
        // Locked due to 3 failed attempts
        final lockoutSec = retryAfter ?? 600;
        startLockoutTimer(lockoutSec);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Account is temporarily locked for ${(lockoutSec / 60).ceil()} minutes due to 3 incorrect attempts.',
        );
        return false;
      } else if (statusCode == 429) {
        // 30s cooldown active
        final waitSec = retryAfter ?? 30;
        startCooldownTimer(waitSec);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Please wait $waitSec seconds before requesting OTP again.',
        );
        return false;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: (authResponse != null && authResponse.message.isNotEmpty)
              ? authResponse.message
              : (response.errorMessage ?? 'Failed to send OTP'),
        );
        return false;
      }
    }
  }

  Future<bool> resendOtp() async {
    if (state.isBlocked) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Account is temporarily locked. Please wait for lockout timer to finish.',
      );
      return false;
    }

    if (state.resendCooldown > 0) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please wait ${state.resendCooldown} seconds before resending OTP.',
      );
      return false;
    }

    if (state.phoneNumber.length < 10) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Invalid phone number for resending OTP');
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final response = await _apiService.post(
      ApiConstants.resendOtp,
      data: {'phone': state.phoneNumber, 'countryCode': '+91', 'role': 'driver'},
    );

    if (response.isSuccess) {
      startCooldownTimer(30);
      state = state.copyWith(status: AuthStatus.otpSent, clearErrorMessage: true);
      return true;
    } else {
      AuthResponseModel? authResponse;
      if (response.data is Map<String, dynamic>) {
        authResponse = AuthResponseModel.fromJson(response.data);
      }

      final statusCode = response.statusCode;
      final isBlocked = authResponse?.blocked == true;
      final retryAfter = authResponse?.retryAfter;

      if (statusCode == 429 && isBlocked) {
        final lockoutSec = retryAfter ?? 600;
        startLockoutTimer(lockoutSec);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Account is temporarily locked for ${(lockoutSec / 60).ceil()} minutes due to 3 incorrect attempts.',
        );
      } else if (statusCode == 429) {
        final waitSec = retryAfter ?? 30;
        startCooldownTimer(waitSec);
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Please wait $waitSec seconds before resending OTP.',
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: (authResponse != null && authResponse.message.isNotEmpty)
              ? authResponse.message
              : (response.errorMessage ?? 'Failed to resend OTP'),
        );
      }
      return false;
    }
  }

  Future<bool> verifyOtp() async {
    if (state.isBlocked) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Account is temporarily locked. Please wait for the lockout period to finish.',
      );
      return false;
    }

    if (state.otp.length < 6) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Please enter complete 6-digit OTP');
      return false;
    }

    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    final fcmToken = await NotificationService().getFcmToken();

    final response = await _apiService.post(
      ApiConstants.verifyOtp,
      data: {
        'phone': state.phoneNumber,
        'otp': state.otp,
        'role': 'driver',
        'deviceId': 'device-uuid-driver-app-123',
        'deviceName': Platform.operatingSystem == 'ios' ? 'iPhone' : 'Android Device',
        'devicePlatform': Platform.operatingSystem,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      },
    );

    if (response.isSuccess) {
      try {
        final authResponse = AuthResponseModel.fromJson(response.data is Map<String, dynamic> ? response.data : {});
        final token = authResponse.data?.token;
        var user = authResponse.data?.user;
        final bool isNewUser = authResponse.isNewUser ?? authResponse.data?.isNewUser ?? user?.isNewUser ?? false;

        if (token != null && token.isNotEmpty) {
          // Clear any lockout record for this phone
          await TokenStorage.clearLockout(state.phoneNumber);
          cancelTimers();

          user = (user ?? UserModel(
            id: 'usr-id',
            phone: state.phoneNumber,
            role: 'driver',
            isNewUser: isNewUser,
          )).copyWith(isNewUser: isNewUser);

          // Save session using TokenStorage (SecureStorage + SharedPreferences)
          await TokenStorage.saveToken(token, user: user);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_new_user', isNewUser);
          await prefs.setString('user_phone', state.phoneNumber);

          state = state.copyWith(
            status: AuthStatus.authenticated,
            authToken: token,
            user: user,
            attemptsLeft: 3,
            isBlocked: false,
            lockoutSecondsRemaining: 0,
            clearErrorMessage: true,
          );

          // Update socket connection with authenticated token
          try {
            SocketService().initSocket(token);
          } catch (_) {}

          // Fetch complete profile (profile, driver, vehicle) after verification
          await fetchProfile();
          return true;
        } else {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: authResponse.message.isNotEmpty ? authResponse.message : 'Invalid response from server',
          );
          return false;
        }
      } catch (e) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: 'Invalid verification response format');
        return false;
      }
    } else {
      // Handle 400 Bad Request (Wrong OTP with attemptsLeft) or 429 Too Many Requests (Lockout)
      AuthResponseModel? authResponse;
      if (response.data is Map<String, dynamic>) {
        authResponse = AuthResponseModel.fromJson(response.data);
      }

      final statusCode = response.statusCode;
      final isBlocked = authResponse?.blocked == true || statusCode == 429;
      final retryAfter = authResponse?.retryAfter;

      if (isBlocked) {
        // 3rd wrong attempt failed -> 10-minute lockout (600 seconds)
        final lockoutSec = retryAfter ?? 600;
        startLockoutTimer(lockoutSec);
        state = state.copyWith(
          status: AuthStatus.error,
          isBlocked: true,
          attemptsLeft: 0,
          lockoutSecondsRemaining: lockoutSec,
          errorMessage: 'Account is temporarily locked for ${(lockoutSec / 60).ceil()} minutes due to 3 incorrect attempts.',
        );
        return false;
      } else if (statusCode == 400) {
        // Incorrect OTP -> display remaining attempts
        final attempts = authResponse?.attemptsLeft ?? (state.attemptsLeft > 1 ? state.attemptsLeft - 1 : 1);
        state = state.copyWith(
          status: AuthStatus.error,
          attemptsLeft: attempts,
          errorMessage: 'Incorrect OTP. $attempts attempt${attempts == 1 ? '' : 's'} left.',
        );
        return false;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: (authResponse != null && authResponse.message.isNotEmpty)
              ? authResponse.message
              : (response.errorMessage ?? 'Invalid OTP code'),
        );
        return false;
      }
    }
  }

  /// Called after KYC and Vehicle registration complete to set isNewUser = false
  Future<void> markOnboardingComplete() async {
    final updatedUser =
        state.user?.copyWith(isNewUser: false) ??
        UserModel(id: 'usr-id', phone: state.phoneNumber, fullName: null, role: 'driver', isNewUser: false);

    state = state.copyWith(user: updatedUser);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_new_user', false);
    await prefs.setString('user_json', jsonEncode(updatedUser.toJson()));
  }

  /// Updates driver duty online/offline status using /api/driver/duty-status,
  /// always extracting data from the 'data' key as requested.
  Future<bool> updateDutyStatus(bool isOnline) async {
    if (state.authToken == null || state.authToken!.isEmpty) return false;

    try {
      final response = await _apiService.post(ApiConstants.dutyStatus, data: {'isOnline': isOnline}, token: state.authToken);

      if (response.isSuccess && response.data != null) {
        final jsonResponse = response.data is String ? jsonDecode(response.data) : response.data;
        if (jsonResponse is Map<String, dynamic>) {
          // Always use 'data' key as requested: jsonResponse['data']
          final dataMap = jsonResponse['data'] ?? jsonResponse['result'] ?? jsonResponse;
          if (dataMap is Map<String, dynamic>) {
            return true;
          }
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _apiService.post(ApiConstants.logout, token: state.authToken);
    } catch (_) {}

    cancelTimers();
    await TokenStorage.clear();
    _ref.read(kycProvider.notifier).reset();
    _ref.read(vehicleProvider.notifier).reset();

    state = AuthState(isSessionLoaded: true);
    return true;
  }

  /// Fetches deletion reasons from server (/api/driver/account/deletion-reasons)
  Future<List<Map<String, dynamic>>> fetchDeletionReasons() async {
    try {
      final response = await _apiService.get(ApiConstants.deletionReasons, token: state.authToken);
      if (response.isSuccess && response.data != null) {
        final jsonResponse = response.data is String ? jsonDecode(response.data) : response.data;
        if (jsonResponse is Map<String, dynamic>) {
          final dataMap = jsonResponse['data'] ?? jsonResponse['result'] ?? jsonResponse;
          if (dataMap is Map && dataMap['reasons'] is List) {
            return (dataMap['reasons'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          } else if (dataMap is List) {
            return dataMap.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        }
      }
    } catch (_) {}
    return [
      {"id": "low_earnings", "label": "Earnings are lower than expected"},
      {"id": "switching_platform", "label": "Switching to another platform / company"},
      {"id": "vehicle_issues", "label": "Vehicle sold or no longer available"},
      {"id": "personal_reasons", "label": "Personal or health reasons"},
      {"id": "other", "label": "Other (Please describe)"},
    ];
  }

  /// Permanently deletes driver account (/api/driver/account)
  Future<ApiResponse> deleteAccount({required String reason, String? reasonText, String? feedback}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final response = await _apiService.delete(
        ApiConstants.deleteAccount,
        data: {
          'reason': reason,
          if (reasonText != null && reasonText.isNotEmpty) 'reasonText': reasonText,
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        },
        token: state.authToken,
      );

      if (response.isSuccess) {
        cancelTimers();
        await TokenStorage.clear();
        _ref.read(kycProvider.notifier).reset();
        _ref.read(vehicleProvider.notifier).reset();

        state = AuthState(isSessionLoaded: true);
        return response;
      } else {
        state = state.copyWith(status: AuthStatus.authenticated, errorMessage: response.errorMessage ?? 'Failed to delete account.');
        return response;
      }
    } catch (e) {
      final err = 'An unexpected error occurred: $e';
      state = state.copyWith(status: AuthStatus.authenticated, errorMessage: err);
      return ApiResponse.failure(err);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
