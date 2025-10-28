import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

void _setPixel(
  img.Image image,
  int x,
  int y,
  int r,
  int g,
  int b, [
  int a = 255,
]) {
  if (x < 0 || x >= image.width || y < 0 || y >= image.height) {
    return;
  }
  image.setPixelRgba(x, y, r, g, b, a);
}

void _drawCircle(
  img.Image image,
  int cx,
  int cy,
  int radius,
  int r,
  int g,
  int b,
) {
  final radius2 = radius * radius;
  for (var y = -radius; y <= radius; y++) {
    for (var x = -radius; x <= radius; x++) {
      if (x * x + y * y <= radius2) {
        _setPixel(image, cx + x, cy + y, r, g, b);
      }
    }
  }
}

void _drawThickPoint(
  img.Image image,
  int x,
  int y,
  int radius,
  int r,
  int g,
  int b,
) {
  _drawCircle(image, x, y, radius, r, g, b);
}

Point<double> _cubic(
  Point<double> p0,
  Point<double> p1,
  Point<double> p2,
  Point<double> p3,
  double t,
) {
  final mt = 1 - t;
  final mt2 = mt * mt;
  final t2 = t * t;
  final a = mt2 * mt;
  final b = 3 * mt2 * t;
  final c = 3 * mt * t2;
  final d = t * t2;
  final x = p0.x * a + p1.x * b + p2.x * c + p3.x * d;
  final y = p0.y * a + p1.y * b + p2.y * c + p3.y * d;
  return Point<double>(x, y);
}

void main() {
  const size = 1024;
  final canvas = img.Image(width: size, height: size);

  const bgStart = [14, 165, 233];
  const bgEnd = [16, 185, 129];
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (size * 2);
      final r = _lerp(bgStart[0], bgEnd[0], t);
      final g = _lerp(bgStart[1], bgEnd[1], t);
      final b = _lerp(bgStart[2], bgEnd[2], t);
      _setPixel(canvas, x, y, r, g, b);
    }
  }

  void drawGridLine(int x0, int y0, int x1, int y1) {
    final dx = x1 - x0;
    final dy = y1 - y0;
    final steps = max(dx.abs(), dy.abs());
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = (x0 + dx * t).round();
      final y = (y0 + dy * t).round();
      for (var offset = -2; offset <= 2; offset++) {
        _setPixel(
          canvas,
          x + (dy == 0 ? 0 : offset),
          y + (dx == 0 ? 0 : offset),
          255,
          255,
          255,
          60,
        );
      }
    }
  }

  for (final x in [288, 512, 736]) {
    drawGridLine(x, 160, x, 864);
  }
  for (final y in [224, 448, 672]) {
    drawGridLine(336, y, 864, y);
  }

  final p0 = Point<double>(220, 720);
  final p1 = Point<double>(360, 580);
  final p2 = Point<double>(420, 460);
  final p3 = Point<double>(520, 300);
  final p4 = Point<double>(600, 340);
  final p5 = Point<double>(740, 520);
  final p6 = Point<double>(800, 520);

  Point<double> pointOnTrack(double t) {
    if (t <= 0.5) {
      final nt = t * 2;
      return _cubic(p0, p1, p2, p3, nt);
    }
    final nt = (t - 0.5) * 2;
    return _cubic(p3, p4, p5, p6, nt);
  }

  for (var t = 0.0; t <= 1.0; t += 0.01) {
    final point = pointOnTrack(t);
    _drawThickPoint(
      canvas,
      point.x.round(),
      point.y.round(),
      18,
      255,
      255,
      255,
    );
  }

  void drawNode(Point<double> center, int radius) {
    _drawCircle(
      canvas,
      center.x.round(),
      center.y.round(),
      radius + 6,
      255,
      255,
      255,
    );
    for (var r = radius; r >= 0; r--) {
      final t = 1 - r / radius;
      final rr = _lerp(245, 249, t);
      final gg = _lerp(158, 115, t);
      final bb = _lerp(11, 22, t);
      _drawCircle(canvas, center.x.round(), center.y.round(), r, rr, gg, bb);
    }
  }

  drawNode(const Point(220, 720), 26);
  drawNode(const Point(420, 460), 22);
  drawNode(const Point(800, 520), 24);

  _drawCircle(canvas, 312, 926, 16, 255, 200, 130);
  _drawCircle(canvas, 312, 926, 10, 255, 255, 255);
  _drawCircle(canvas, 712, 922, 16, 255, 200, 130);
  _drawCircle(canvas, 712, 922, 10, 255, 255, 255);

  for (var x = 260; x <= 764; x++) {
    for (var y = -7; y <= 7; y++) {
      _setPixel(canvas, x, 936 + y, 255, 200, 130);
    }
  }

  final file = File('assets/logo/tracemap_logo.png');
  file.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(canvas));
}
