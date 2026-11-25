import 'package:uuid/uuid.dart';

class VehicleModel {
  final String id;
  final String driverId;
  final String vehicleTypeId;
  final String registrationNumber;
  final String make;
  final String model;
  final int year;
  final String color;
  final String fuelType; // "petrol", "diesel", "cng", "electric"
  final String status; // "approved", "pending", "rejected"
  final bool isPrimary;
  final String vehicleTypeName;
  final String vehicleTypeDescription;
  final double? baseFare;
  final double? perKmRate;
  final String rcDocUrl;
  final String insuranceDocUrl;
  final String insuranceExpiry;
  final String vehiclePhotoUrl;

  VehicleModel({
    this.id = '',
    this.driverId = '',
    String? vehicleTypeId,
    this.registrationNumber = '',
    this.make = '',
    this.model = '',
    this.year = 2022,
    this.color = '',
    this.fuelType = 'cng',
    this.status = '',
    this.isPrimary = true,
    this.vehicleTypeName = '',
    this.vehicleTypeDescription = '',
    this.baseFare,
    this.perKmRate,
    this.rcDocUrl = '',
    this.insuranceDocUrl = '',
    this.insuranceExpiry = '',
    this.vehiclePhotoUrl = '',
  }) : vehicleTypeId = vehicleTypeId ?? const Uuid().v4();

  bool get hasVehicle =>
      id.isNotEmpty ||
      registrationNumber.isNotEmpty ||
      (make.isNotEmpty && model.isNotEmpty);

  bool get isApproved {
    final s = status.toLowerCase().trim();
    return s == 'approved' || s == 'active' || s == 'verified';
  }

  bool get isRejected => status.toLowerCase().trim() == 'rejected';

  /// Derives a normalized vehicle type slug for goOnline/socket payloads
  String get normalizedVehicleType {
    final source =
        '${vehicleTypeName.toLowerCase()} ${vehicleTypeId.toLowerCase()}';
    if (source.contains('auto') || source.contains('rickshaw')) return 'auto';
    if (source.contains('bike') ||
        source.contains('moto') ||
        source.contains('scoot'))
      return 'bike';
    if (source.contains('cab') ||
        source.contains('car') ||
        source.contains('sedan') ||
        source.contains('suv') ||
        source.contains('mini')) {
      return 'cab';
    }
    if (vehicleTypeName.isNotEmpty) return vehicleTypeName.toLowerCase();
    return 'bike';
  }

  VehicleModel copyWith({
    String? id,
    String? driverId,
    String? vehicleTypeId,
    String? registrationNumber,
    String? make,
    String? model,
    int? year,
    String? color,
    String? fuelType,
    String? status,
    bool? isPrimary,
    String? vehicleTypeName,
    String? vehicleTypeDescription,
    double? baseFare,
    double? perKmRate,
    String? rcDocUrl,
    String? insuranceDocUrl,
    String? insuranceExpiry,
    String? vehiclePhotoUrl,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      fuelType: fuelType ?? this.fuelType,
      status: status ?? this.status,
      isPrimary: isPrimary ?? this.isPrimary,
      vehicleTypeName: vehicleTypeName ?? this.vehicleTypeName,
      vehicleTypeDescription:
          vehicleTypeDescription ?? this.vehicleTypeDescription,
      baseFare: baseFare ?? this.baseFare,
      perKmRate: perKmRate ?? this.perKmRate,
      rcDocUrl: rcDocUrl ?? this.rcDocUrl,
      insuranceDocUrl: insuranceDocUrl ?? this.insuranceDocUrl,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      vehiclePhotoUrl: vehiclePhotoUrl ?? this.vehiclePhotoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleTypeId': vehicleTypeId,
      'registrationNumber': registrationNumber,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'fuelType': fuelType,
      'rcDocUrl': rcDocUrl,
      'insuranceDocUrl': insuranceDocUrl,
      'insuranceExpiry': insuranceExpiry,
      'vehiclePhotoUrl': vehiclePhotoUrl,
    };
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    final vtMap =
        (json['vehicle_types'] ?? json['vehicleTypes'] ?? json['vehicleType'])
            is Map
        ? Map<String, dynamic>.from(
            (json['vehicle_types'] ??
                    json['vehicleTypes'] ??
                    json['vehicleType'])
                as Map,
          )
        : null;

    double? parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val != null) return double.tryParse(val.toString());
      return null;
    }

    return VehicleModel(
      id: (json['id'] ?? '').toString(),
      driverId: (json['driver_id'] ?? json['driverId'] ?? '').toString(),
      vehicleTypeId:
          (json['vehicleTypeId'] ??
                  json['vehicle_type_id'] ??
                  const Uuid().v4())
              .toString(),
      registrationNumber:
          (json['registrationNumber'] ?? json['registration_number'] ?? '')
              .toString(),
      make: (json['make'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      year: json['year'] is int
          ? json['year']
          : int.tryParse(json['year']?.toString() ?? '') ?? 0,
      color: (json['color'] ?? '').toString(),
      fuelType: (json['fuelType'] ?? json['fuel_type'] ?? 'cng').toString(),
      status: (json['status'] ?? '').toString(),
      isPrimary: json['is_primary'] ?? json['isPrimary'] ?? true,
      vehicleTypeName:
          (vtMap?['name'] ??
                  json['vehicleTypeName'] ??
                  json['vehicle_type_name'] ??
                  '')
              .toString(),
      vehicleTypeDescription: (vtMap?['description'] ?? '').toString(),
      baseFare: parseDouble(vtMap?['base_fare'] ?? vtMap?['baseFare']),
      perKmRate: parseDouble(vtMap?['per_km_rate'] ?? vtMap?['perKmRate']),
      rcDocUrl: (json['rcDocUrl'] ?? json['rc_doc_url'] ?? '').toString(),
      insuranceDocUrl:
          (json['insuranceDocUrl'] ?? json['insurance_doc_url'] ?? '')
              .toString(),
      insuranceExpiry:
          (json['insuranceExpiry'] ?? json['insurance_expiry'] ?? '')
              .toString(),
      vehiclePhotoUrl:
          (json['vehiclePhotoUrl'] ?? json['vehicle_photo_url'] ?? '')
              .toString(),
    );
  }
}
