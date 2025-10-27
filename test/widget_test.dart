// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('Device info page renders provided details',
      (WidgetTester tester) async {
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceInfoPage(repository: repository),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('设备信息'), findsOneWidget);
    expect(find.textContaining('型号: Pixel'), findsOneWidget);
    expect(find.textContaining('纬度'), findsOneWidget);
    expect(find.textContaining('更新时间'), findsOneWidget);
  });
}

class _FakeRepository extends DeviceInfoRepository {
  @override
  Future<DeviceSnapshot> fetchInfo() async {
    return DeviceSnapshot(
      deviceDetails: {
        '系统': 'Android 14',
        '品牌': 'Google',
        '型号': 'Pixel',
      },
      position: Position(
        longitude: 116.3913,
        latitude: 39.9075,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        accuracy: 5.0,
        altitude: 45.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        headingAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        isMocked: false,
      ),
      locationError: null,
      retrievedAt: DateTime(2024, 1, 1, 12, 0, 5),
    );
  }
}
