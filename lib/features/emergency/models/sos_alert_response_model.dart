class SosAlertResponseModel {
  final String alertId;
  final int contactsNotified;
  final String emergencyNumber;
  final String status;
  final String trackingUrl;
  final String? message;
  final DateTime triggeredAt;

  SosAlertResponseModel({
    required this.alertId,
    required this.contactsNotified,
    this.emergencyNumber = '112',
    this.status = 'active',
    this.trackingUrl = '',
    this.message,
    DateTime? triggeredAt,
  }) : triggeredAt = triggeredAt ?? DateTime.now();

  factory SosAlertResponseModel.fromJson(Map<String, dynamic> json, {String? defaultMessage}) {
    final dataMap = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    return SosAlertResponseModel(
      alertId: (dataMap['alertId'] ?? dataMap['id'] ?? 'SOS-${DateTime.now().millisecondsSinceEpoch}').toString(),
      contactsNotified: dataMap['contactsNotified'] is int
          ? dataMap['contactsNotified']
          : int.tryParse(dataMap['contactsNotified']?.toString() ?? '0') ?? 0,
      emergencyNumber: (dataMap['emergencyNumber'] ?? '112').toString(),
      status: (dataMap['status'] ?? 'active').toString(),
      trackingUrl: (dataMap['trackingUrl'] ?? '').toString(),
      message: json['message']?.toString() ?? defaultMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alertId': alertId,
      'contactsNotified': contactsNotified,
      'emergencyNumber': emergencyNumber,
      'status': status,
      'trackingUrl': trackingUrl,
      'message': message,
      'triggeredAt': triggeredAt.toIso8601String(),
    };
  }
}

