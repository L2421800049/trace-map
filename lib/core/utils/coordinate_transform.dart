import 'dart:math';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

GeoPoint wgs84ToGcj02(double latitude, double longitude) {
  if (_isOutsideChina(latitude, longitude)) {
    return GeoPoint(latitude, longitude);
  }
  const a = 6378245.0;
  const ee = 0.006693421622965943;
  const pi = 3.14159265358979323846;

  final dLat = _transformLat(longitude - 105.0, latitude - 35.0);
  final dLon = _transformLon(longitude - 105.0, latitude - 35.0);
  final radLat = latitude / 180.0 * pi;
  var magic = sin(radLat);
  magic = 1 - ee * magic * magic;
  final sqrtMagic = sqrt(magic);
  final adjustedLat =
      latitude + (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
  final adjustedLon =
      longitude + (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
  return GeoPoint(adjustedLat, adjustedLon);
}

bool _isOutsideChina(double latitude, double longitude) {
  if (longitude < 72.004 || longitude > 137.8347) {
    return true;
  }
  if (latitude < 0.8293 || latitude > 55.8271) {
    return true;
  }
  return false;
}

double _transformLat(double x, double y) {
  const pi = 3.14159265358979323846;
  var result = -100.0 + 2.0 * x + 3.0 * y;
  result += 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(x.abs());
  result += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  result += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
  result += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
  return result;
}

double _transformLon(double x, double y) {
  const pi = 3.14159265358979323846;
  var result = 300.0 + x + 2.0 * y;
  result += 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
  result += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  result += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
  result +=
      (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
  return result;
}
