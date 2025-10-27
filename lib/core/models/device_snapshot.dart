import 'package:geolocator/geolocator.dart';

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.deviceDetails,
    required this.retrievedAt,
    this.position,
    this.locationError,
  });

  final Map<String, String> deviceDetails;
  final DateTime retrievedAt;
  final Position? position;
  final String? locationError;
}
