import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DriverLostItemModel {
  final String id;
  final String rideId;
  final String riderId;
  final String riderName;
  final String category;
  final String description;
  final String contactPhone;
  final String status;
  final bool? driverFound;
  final String? driverNote;
  final String? driverRespondedAt;
  final String pickupAddress;
  final String dropoffAddress;
  final String reportedAt;
  final String? updatedAt;

  DriverLostItemModel({
    required this.id,
    required this.rideId,
    this.riderId = '',
    this.riderName = '',
    required this.category,
    required this.description,
    this.contactPhone = '',
    this.status = 'reported',
    this.driverFound,
    this.driverNote,
    this.driverRespondedAt,
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.reportedAt = '',
    this.updatedAt,
  });

  bool get isPending => status.toLowerCase() == 'reported';
  bool get isFound => status.toLowerCase() == 'driver_found' || driverFound == true;
  bool get isNotFound => status.toLowerCase() == 'driver_not_found' || driverFound == false;
  bool get isReturned => status.toLowerCase() == 'returned';
  bool get isClosed => status.toLowerCase() == 'closed';
  bool get isResolved => isReturned || isClosed || isNotFound;

  String get categoryEmoji {
    switch (category.toLowerCase().trim()) {
      case 'phone':
        return '📱';
      case 'wallet':
        return '👛';
      case 'keys':
        return '🔑';
      case 'bag':
        return '🎒';
      case 'electronics':
        return '💻';
      case 'clothing':
        return '🧥';
      case 'documents':
        return '📄';
      default:
        return '📦';
    }
  }

  String get categoryDisplayName {
    if (category.isEmpty) return 'Other Item';
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }

  String get statusDisplayName {
    switch (status.toLowerCase().trim()) {
      case 'reported':
        return 'Action Required';
      case 'driver_found':
        return 'Found by You';
      case 'driver_not_found':
        return 'Not Found';
      case 'returned':
        return 'Returned to Passenger';
      case 'closed':
        return 'Closed';
      default:
        return status.toUpperCase();
    }
  }

  Color get statusColor {
    switch (status.toLowerCase().trim()) {
      case 'reported':
        return Colors.orange.shade800;
      case 'driver_found':
        return const Color(0xFF16A34A); // Green
      case 'driver_not_found':
        return AppColors.error;
      case 'returned':
        return const Color(0xFF0284C7); // Sky blue
      case 'closed':
        return Colors.grey.shade700;
      default:
        return AppColors.textPrimary;
    }
  }

  Color get statusBackgroundColor {
    switch (status.toLowerCase().trim()) {
      case 'reported':
        return const Color(0xFFFFF7ED); // Light orange
      case 'driver_found':
        return const Color(0xFFF0FDF4); // Light green
      case 'driver_not_found':
        return const Color(0xFFFEF2F2); // Light red
      case 'returned':
        return const Color(0xFFF0F9FF); // Light blue
      case 'closed':
        return const Color(0xFFF1F5F9); // Light grey
      default:
        return Colors.grey.shade100;
    }
  }

  factory DriverLostItemModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DriverLostItemModel(
        id: '',
        rideId: '',
        category: 'other',
        description: '',
      );
    }

    return DriverLostItemModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      rideId: json['rideId']?.toString() ?? json['ride_id']?.toString() ?? '',
      riderId: json['riderId']?.toString() ?? json['rider_id']?.toString() ?? '',
      riderName: json['riderName']?.toString() ?? json['rider']?['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      description: json['description']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? json['phone']?.toString() ?? '',
      status: json['status']?.toString().toLowerCase() ?? 'reported',
      driverFound: json['driverFound'] as bool?,
      driverNote: json['driverNote']?.toString(),
      driverRespondedAt: json['driverRespondedAt']?.toString(),
      pickupAddress: json['pickupAddress']?.toString() ?? json['pickup']?.toString() ?? '',
      dropoffAddress: json['dropoffAddress']?.toString() ?? json['dropoff']?.toString() ?? '',
      reportedAt: json['reportedAt']?.toString() ?? json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rideId': rideId,
      'riderId': riderId,
      'riderName': riderName,
      'category': category,
      'description': description,
      'contactPhone': contactPhone,
      'status': status,
      'driverFound': driverFound,
      'driverNote': driverNote,
      'driverRespondedAt': driverRespondedAt,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'reportedAt': reportedAt,
      'updatedAt': updatedAt,
    };
  }

  DriverLostItemModel copyWith({
    String? id,
    String? rideId,
    String? riderId,
    String? riderName,
    String? category,
    String? description,
    String? contactPhone,
    String? status,
    bool? driverFound,
    String? driverNote,
    String? driverRespondedAt,
    String? pickupAddress,
    String? dropoffAddress,
    String? reportedAt,
    String? updatedAt,
  }) {
    return DriverLostItemModel(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      category: category ?? this.category,
      description: description ?? this.description,
      contactPhone: contactPhone ?? this.contactPhone,
      status: status ?? this.status,
      driverFound: driverFound ?? this.driverFound,
      driverNote: driverNote ?? this.driverNote,
      driverRespondedAt: driverRespondedAt ?? this.driverRespondedAt,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      reportedAt: reportedAt ?? this.reportedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
