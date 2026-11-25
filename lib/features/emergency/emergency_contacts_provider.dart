import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_constants.dart';
import '../../core/network/api_service.dart';
import 'models/emergency_contact_model.dart';
import 'models/sos_alert_response_model.dart';

class EmergencyContactsState {
  final List<EmergencyContactModel> contacts;
  final int total;
  final int maxAllowed;
  final bool isLoading;
  final bool isActionLoading;
  final bool isSosTriggering;
  final String? errorMessage;
  final String? successMessage;
  final SosAlertResponseModel? activeSosAlert;

  EmergencyContactsState({
    this.contacts = const [],
    this.total = 0,
    this.maxAllowed = 5,
    this.isLoading = false,
    this.isActionLoading = false,
    this.isSosTriggering = false,
    this.errorMessage,
    this.successMessage,
    this.activeSosAlert,
  });

  bool get isMaxReached => contacts.length >= maxAllowed;

  EmergencyContactsState copyWith({
    List<EmergencyContactModel>? contacts,
    int? total,
    int? maxAllowed,
    bool? isLoading,
    bool? isActionLoading,
    bool? isSosTriggering,
    String? errorMessage,
    String? successMessage,
    bool clearAlert = false,
    SosAlertResponseModel? activeSosAlert,
  }) {
    return EmergencyContactsState(
      contacts: contacts ?? this.contacts,
      total: total ?? this.total,
      maxAllowed: maxAllowed ?? this.maxAllowed,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isSosTriggering: isSosTriggering ?? this.isSosTriggering,
      errorMessage: errorMessage,
      successMessage: successMessage,
      activeSosAlert: clearAlert ? null : (activeSosAlert ?? this.activeSosAlert),
    );
  }
}

class EmergencyContactsNotifier extends StateNotifier<EmergencyContactsState> {
  final ApiService _apiService;

  EmergencyContactsNotifier({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(EmergencyContactsState()) {
    fetchContacts();
  }

  /// Fetches saved driver emergency contacts: GET /api/driver/emergency-contacts
  Future<void> fetchContacts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiService.get(ApiConstants.emergencyContacts);

      if (response.isSuccess && response.data != null) {
        final dynamic data = response.data;
        if (data is Map<String, dynamic>) {
          final resModel = EmergencyContactsResponseModel.fromJson(data);
          state = state.copyWith(
            contacts: resModel.contacts,
            total: resModel.total,
            maxAllowed: resModel.maxAllowed,
            isLoading: false,
          );
          return;
        }
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: response.errorMessage ?? 'Failed to load emergency contacts.',
      );
    } catch (e) {
      dev.log('Error fetching emergency contacts: $e', name: 'EmergencyContacts');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error loading emergency contacts.',
      );
    }
  }

  /// Adds a new contact: POST /api/driver/emergency-contacts
  Future<bool> addContact({
    required String name,
    required String phone,
    required String relation,
    bool shareRideAutomatically = false,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    if (state.isMaxReached) {
      state = state.copyWith(errorMessage: 'Maximum ${state.maxAllowed} emergency contacts allowed.');
      return false;
    }

    if (cleanName.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter contact name.');
      return false;
    }

    if (cleanPhone.length != 10 || !RegExp(r'^[6-9]').hasMatch(cleanPhone)) {
      state = state.copyWith(errorMessage: 'Please enter a valid 10-digit mobile number.');
      return false;
    }

    final isDuplicate = state.contacts.any((c) => c.phone == cleanPhone);
    if (isDuplicate) {
      state = state.copyWith(errorMessage: 'A contact with this phone number already exists.');
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);

    try {
      final response = await _apiService.post(
        ApiConstants.emergencyContacts,
        data: {
          'name': cleanName,
          'phone': cleanPhone,
          'relation': relation,
          'shareRideAutomatically': shareRideAutomatically,
        },
      );

      if (response.isSuccess) {
        await fetchContacts();
        state = state.copyWith(
          isActionLoading: false,
          successMessage: 'Emergency contact added successfully.',
        );
        return true;
      } else {
        state = state.copyWith(
          isActionLoading: false,
          errorMessage: response.errorMessage ?? 'Failed to add emergency contact.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: 'Failed to add contact: $e',
      );
      return false;
    }
  }

  /// Updates existing contact: PUT /api/driver/emergency-contacts/:id
  Future<bool> updateContact(
    String id, {
    required String name,
    required String phone,
    required String relation,
    bool shareRideAutomatically = false,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    if (cleanName.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter contact name.');
      return false;
    }

    if (cleanPhone.length != 10 || !RegExp(r'^[6-9]').hasMatch(cleanPhone)) {
      state = state.copyWith(errorMessage: 'Please enter a valid 10-digit mobile number.');
      return false;
    }

    final isDuplicate = state.contacts.any((c) => c.id != id && c.phone == cleanPhone);
    if (isDuplicate) {
      state = state.copyWith(errorMessage: 'Another contact with this phone number already exists.');
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);

    try {
      final response = await _apiService.put(
        ApiConstants.emergencyContactDetails(id),
        data: {
          'name': cleanName,
          'phone': cleanPhone,
          'relation': relation,
          'shareRideAutomatically': shareRideAutomatically,
        },
      );

      if (response.isSuccess) {
        await fetchContacts();
        state = state.copyWith(
          isActionLoading: false,
          successMessage: 'Emergency contact updated successfully.',
        );
        return true;
      } else {
        state = state.copyWith(
          isActionLoading: false,
          errorMessage: response.errorMessage ?? 'Failed to update emergency contact.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: 'Failed to update contact: $e',
      );
      return false;
    }
  }

  /// Deletes emergency contact: DELETE /api/driver/emergency-contacts/:id
  Future<bool> deleteContact(String id) async {
    state = state.copyWith(isActionLoading: true, errorMessage: null);

    try {
      final response = await _apiService.delete(ApiConstants.emergencyContactDetails(id));

      if (response.isSuccess) {
        final updatedList = state.contacts.where((c) => c.id != id).toList();
        state = state.copyWith(
          contacts: updatedList,
          total: updatedList.length,
          isActionLoading: false,
          successMessage: 'Emergency contact removed.',
        );
        return true;
      } else {
        state = state.copyWith(
          isActionLoading: false,
          errorMessage: response.errorMessage ?? 'Failed to delete emergency contact.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: 'Failed to delete contact: $e',
      );
      return false;
    }
  }

  /// Triggers live emergency SOS alert during active ride: POST /api/driver/rides/:rideId/sos
  Future<SosAlertResponseModel?> triggerDriverSos({
    required String rideId,
    required double lat,
    required double lng,
    String? reason,
  }) async {
    state = state.copyWith(isSosTriggering: true, errorMessage: null);

    try {
      final response = await _apiService.post(
        ApiConstants.triggerRideSos(rideId),
        data: {
          'lat': lat,
          'lng': lng,
          'reason': reason ?? 'Driver emergency / dispute / accident',
        },
      );

      if (response.isSuccess && response.data != null) {
        final dynamic data = response.data;
        SosAlertResponseModel alertModel;
        if (data is Map<String, dynamic>) {
          alertModel = SosAlertResponseModel.fromJson(
            data,
            defaultMessage: '🚨 SOS Emergency Alert triggered successfully! Control Room & Police alerted.',
          );
        } else {
          alertModel = SosAlertResponseModel(
            alertId: 'SOS-${DateTime.now().millisecondsSinceEpoch}',
            contactsNotified: state.contacts.length,
            emergencyNumber: '112',
            status: 'active',
            message: '🚨 SOS Emergency Alert triggered successfully!',
          );
        }

        state = state.copyWith(
          isSosTriggering: false,
          activeSosAlert: alertModel,
          successMessage: alertModel.message,
        );
        return alertModel;
      } else {
        state = state.copyWith(
          isSosTriggering: false,
          errorMessage: response.errorMessage ?? 'Failed to trigger SOS alert.',
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isSosTriggering: false,
        errorMessage: 'Network error triggering SOS alert: $e',
      );
      return null;
    }
  }

  void clearActiveAlert() {
    state = state.copyWith(clearAlert: true);
  }

  /// Helper to trigger direct phone call using url_launcher
  static Future<bool> makePhoneCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      dev.log('Error launching dialer for $phoneNumber: $e', name: 'EmergencyDialer');
      return false;
    }
  }

  static Future<bool> callPolice() => makePhoneCall('112');
  static Future<bool> callAmbulance() => makePhoneCall('108');
  static Future<bool> callCaptainHelpline() => makePhoneCall('18002008888');
}

final emergencyContactsProvider =
    StateNotifierProvider<EmergencyContactsNotifier, EmergencyContactsState>((ref) {
  return EmergencyContactsNotifier();
});

