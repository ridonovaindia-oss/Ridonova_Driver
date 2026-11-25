class EmergencyContactModel {
  final String id;
  final String name;
  final String phone;
  final String formattedPhone;
  final String relation;
  final bool shareRideAutomatically;
  final DateTime? createdAt;

  EmergencyContactModel({
    required this.id,
    required this.name,
    required this.phone,
    String? formattedPhone,
    required this.relation,
    this.shareRideAutomatically = false,
    this.createdAt,
  }) : formattedPhone = formattedPhone ?? _formatPhone(phone);

  static String _formatPhone(String rawPhone) {
    final clean = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
    }
    return rawPhone;
  }

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      formattedPhone: json['formattedPhone']?.toString(),
      relation: (json['relation'] ?? 'Other').toString(),
      shareRideAutomatically: json['shareRideAutomatically'] == true ||
          json['shareRideAutomatically']?.toString() == 'true',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relation': relation,
      'shareRideAutomatically': shareRideAutomatically,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  EmergencyContactModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? formattedPhone,
    String? relation,
    bool? shareRideAutomatically,
    DateTime? createdAt,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      formattedPhone: formattedPhone ?? this.formattedPhone,
      relation: relation ?? this.relation,
      shareRideAutomatically: shareRideAutomatically ?? this.shareRideAutomatically,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class EmergencyContactsResponseModel {
  final bool success;
  final List<EmergencyContactModel> contacts;
  final int total;
  final int maxAllowed;
  final String? message;

  EmergencyContactsResponseModel({
    required this.success,
    required this.contacts,
    required this.total,
    this.maxAllowed = 5,
    this.message,
  });

  factory EmergencyContactsResponseModel.fromJson(Map<String, dynamic> json) {
    List<EmergencyContactModel> contactsList = [];

    final rawList = json['contacts'] ?? json['data'];
    if (rawList is List) {
      contactsList = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => EmergencyContactModel.fromJson(item))
          .toList();
    }

    return EmergencyContactsResponseModel(
      success: json['success'] ?? true,
      contacts: contactsList,
      total: json['total'] is int ? json['total'] : contactsList.length,
      maxAllowed: json['maxAllowed'] is int ? json['maxAllowed'] : 5,
      message: json['message']?.toString(),
    );
  }
}

