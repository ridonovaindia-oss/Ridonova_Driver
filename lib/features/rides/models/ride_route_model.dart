import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideRouteModel {
  final String rideId;
  final String status;
  final String target; // 'pickup' or 'dropoff'
  final String targetAddress;
  final double targetLat;
  final double targetLng;
  final double driverLat;
  final double driverLng;
  final double distanceKm;
  final int durationMinutes;
  final String polyline;
  final List<LatLng> points;
  final String riderName;
  final String riderPhone;

  RideRouteModel({
    required this.rideId,
    this.status = '',
    this.target = 'pickup',
    this.targetAddress = '',
    this.targetLat = 0.0,
    this.targetLng = 0.0,
    this.driverLat = 0.0,
    this.driverLng = 0.0,
    this.distanceKm = 0.0,
    this.durationMinutes = 0,
    this.polyline = '',
    this.points = const [],
    this.riderName = '',
    this.riderPhone = '',
  });

  /// Returns route coordinates from points list or by decoding polyline string
  List<LatLng> get routeCoordinates {
    if (points.isNotEmpty) {
      return points;
    } else if (polyline.isNotEmpty) {
      return decodePolyline(polyline);
    } else if (driverLat != 0.0 && driverLng != 0.0 && targetLat != 0.0 && targetLng != 0.0) {
      return [
        LatLng(driverLat, driverLng),
        LatLng(targetLat, targetLng),
      ];
    }
    return [];
  }

  RideRouteModel copyWith({
    String? rideId,
    String? status,
    String? target,
    String? targetAddress,
    double? targetLat,
    double? targetLng,
    double? driverLat,
    double? driverLng,
    double? distanceKm,
    int? durationMinutes,
    String? polyline,
    List<LatLng>? points,
    String? riderName,
    String? riderPhone,
  }) {
    return RideRouteModel(
      rideId: rideId ?? this.rideId,
      status: status ?? this.status,
      target: target ?? this.target,
      targetAddress: targetAddress ?? this.targetAddress,
      targetLat: targetLat ?? this.targetLat,
      targetLng: targetLng ?? this.targetLng,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      polyline: polyline ?? this.polyline,
      points: points ?? this.points,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
    );
  }

  factory RideRouteModel.fromJson(Map<String, dynamic> json) {
    final map = (json['data'] is Map<String, dynamic>)
        ? json['data']
        : ((json['result'] is Map<String, dynamic>) ? json['result'] : json);

    String rideId = map['rideId']?.toString() ?? map['id']?.toString() ?? '';
    String status = map['status']?.toString() ?? '';
    String target = map['target']?.toString() ?? 'pickup';
    String targetAddress = map['targetAddress']?.toString() ?? map['target_address']?.toString() ?? '';

    double tLat = 0.0;
    double tLng = 0.0;
    final targetMap = map['targetLocation'] ?? map['target'] ?? (target == 'pickup' ? (map['pickup'] ?? map['pickupLocation']) : (map['drop'] ?? map['dropLocation']));
    if (targetMap is Map) {
      tLat = double.tryParse(targetMap['lat']?.toString() ?? targetMap['latitude']?.toString() ?? '') ?? 0.0;
      tLng = double.tryParse(targetMap['lng']?.toString() ?? targetMap['longitude']?.toString() ?? '') ?? 0.0;
      if (tLat == 0.0 && tLng == 0.0 && targetMap['coordinates'] is List && (targetMap['coordinates'] as List).length >= 2) {
        tLng = double.tryParse(targetMap['coordinates'][0]?.toString() ?? '') ?? 0.0;
        tLat = double.tryParse(targetMap['coordinates'][1]?.toString() ?? '') ?? 0.0;
      }
    }
    if (tLat == 0.0 && tLng == 0.0) {
      tLat = double.tryParse(map['targetLat']?.toString() ?? map['target_lat']?.toString() ?? map['targetLatitude']?.toString() ?? '') ?? 0.0;
      tLng = double.tryParse(map['targetLng']?.toString() ?? map['target_lng']?.toString() ?? map['targetLongitude']?.toString() ?? '') ?? 0.0;
    }

    double dLat = 0.0;
    double dLng = 0.0;
    final driverMap = map['driverLocation'] ?? map['currentLocation'] ?? map['driver'];
    if (driverMap is Map) {
      dLat = double.tryParse(driverMap['lat']?.toString() ?? driverMap['latitude']?.toString() ?? '') ?? 0.0;
      dLng = double.tryParse(driverMap['lng']?.toString() ?? driverMap['longitude']?.toString() ?? '') ?? 0.0;
      if (dLat == 0.0 && dLng == 0.0 && driverMap['coordinates'] is List && (driverMap['coordinates'] as List).length >= 2) {
        dLng = double.tryParse(driverMap['coordinates'][0]?.toString() ?? '') ?? 0.0;
        dLat = double.tryParse(driverMap['coordinates'][1]?.toString() ?? '') ?? 0.0;
      }
    }
    if (dLat == 0.0 && dLng == 0.0) {
      dLat = double.tryParse(map['driverLat']?.toString() ?? map['driver_lat']?.toString() ?? map['driverLatitude']?.toString() ?? '') ?? 0.0;
      dLng = double.tryParse(map['driverLng']?.toString() ?? map['driver_lng']?.toString() ?? map['driverLongitude']?.toString() ?? '') ?? 0.0;
    }

    double dist = double.tryParse(map['distanceKm']?.toString() ?? map['distance_km']?.toString() ?? '0') ?? 0.0;
    int dur = int.tryParse(map['durationMinutes']?.toString() ?? map['duration_mins']?.toString() ?? '0') ?? 0;

    // Check multiple polyline keys
    String poly = map['polyline']?.toString()
        ?? map['geometry']?.toString()
        ?? map['encodedPolyline']?.toString()
        ?? map['routePolyline']?.toString()
        ?? (map['overview_polyline'] is Map ? map['overview_polyline']['points']?.toString() : null)
        ?? '';

    List<LatLng> pointsList = [];
    final pointsData = map['points'] ?? map['coordinates'] ?? map['coords'] ?? map['path'];
    if (pointsData is List) {
      for (var item in pointsData) {
        if (item is Map) {
          final lat = double.tryParse(item['lat']?.toString() ?? item['latitude']?.toString() ?? '');
          final lng = double.tryParse(item['lng']?.toString() ?? item['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            pointsList.add(LatLng(lat, lng));
          }
        } else if (item is List && item.length >= 2) {
          final lat = double.tryParse(item[0]?.toString() ?? '');
          final lng = double.tryParse(item[1]?.toString() ?? '');
          if (lat != null && lng != null) {
            pointsList.add(LatLng(lat, lng));
          }
        }
      }
    }

    String rName = '';
    String rPhone = '';
    if (map['rider'] is Map) {
      rName = map['rider']['fullName']?.toString() ?? map['rider']['name']?.toString() ?? map['rider']['full_name']?.toString() ?? '';
      rPhone = map['rider']['phone']?.toString() ?? map['rider']['mobileNumber']?.toString() ?? map['rider']['mobile_number']?.toString() ?? '';
    }

    return RideRouteModel(
      rideId: rideId,
      status: status,
      target: target,
      targetAddress: targetAddress,
      targetLat: tLat,
      targetLng: tLng,
      driverLat: dLat,
      driverLng: dLng,
      distanceKm: dist,
      durationMinutes: dur,
      polyline: poly,
      points: pointsList,
      riderName: rName,
      riderPhone: rPhone,
    );
  }

  /// Helper algorithm to decode Google Encoded Polyline String
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}
