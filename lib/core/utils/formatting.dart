import 'package:geolocator/geolocator.dart';

String formatTimestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final date =
      '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  final time =
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
  return '$date $time';
}

String formatPosition(Position position) {
  final buffer = StringBuffer()
    ..writeln('纬度: ${position.latitude.toStringAsFixed(6)}')
    ..writeln('经度: ${position.longitude.toStringAsFixed(6)}')
    ..writeln('精度: ±${position.accuracy.toStringAsFixed(1)} 米');
  if (position.altitude != 0) {
    buffer.writeln('海拔: ${position.altitude.toStringAsFixed(1)} 米');
  }
  if (position.speed != 0) {
    buffer.writeln('速度: ${position.speed.toStringAsFixed(2)} m/s');
  }
  return buffer.toString().trim();
}
