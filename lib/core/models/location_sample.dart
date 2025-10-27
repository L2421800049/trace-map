import 'package:geolocator/geolocator.dart';

class LocationSample {
  LocationSample({
    this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.altitudeAccuracy,
    required this.speed,
    required this.speedAccuracy,
    required this.heading,
    required this.headingAccuracy,
    required this.isMocked,
    this.floor,
  });

  factory LocationSample.fromPosition(
    Position position, {
    required DateTime timestamp,
  }) {
    return LocationSample(
      timestamp: timestamp,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      isMocked: position.isMocked,
      floor: position.floor,
    );
  }

  factory LocationSample.fromMap(Map<String, Object?> map) {
    return LocationSample(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
      ),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0,
      altitudeAccuracy:
          (map['altitude_accuracy'] as num?)?.toDouble() ?? 0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0,
      speedAccuracy: (map['speed_accuracy'] as num?)?.toDouble() ?? 0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0,
      headingAccuracy:
          (map['heading_accuracy'] as num?)?.toDouble() ?? 0,
      isMocked: (map['is_mocked'] as int? ?? 0) == 1,
      floor: map['floor'] as int?,
    );
  }

  final int? id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double altitudeAccuracy;
  final double speed;
  final double speedAccuracy;
  final double heading;
  final double headingAccuracy;
  final bool isMocked;
  final int? floor;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'altitude_accuracy': altitudeAccuracy,
      'speed': speed,
      'speed_accuracy': speedAccuracy,
      'heading': heading,
      'heading_accuracy': headingAccuracy,
      'is_mocked': isMocked ? 1 : 0,
      'floor': floor,
    };
  }

  Position toPosition() {
    return Position(
      longitude: longitude,
      latitude: latitude,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: altitude,
      altitudeAccuracy: altitudeAccuracy,
      heading: heading,
      headingAccuracy: headingAccuracy,
      speed: speed,
      speedAccuracy: speedAccuracy,
      floor: floor,
      isMocked: isMocked,
    );
  }
}
