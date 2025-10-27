import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myapp/core/app_state.dart';
import 'package:myapp/core/models/device_snapshot.dart';
import 'package:myapp/core/models/location_sample.dart';
import 'package:myapp/core/models/map_provider.dart';
import 'package:myapp/core/models/map_log_entry.dart';
import 'package:myapp/ui/app_state_scope.dart';
import 'package:myapp/ui/pages/device_info_page.dart';

void main() {
  testWidgets('Device info page renders snapshot details', (WidgetTester tester) async {
    final sample = LocationSample(
      timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      latitude: 39.9075,
      longitude: 116.3913,
      accuracy: 5,
      altitude: 45,
      altitudeAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      isMocked: false,
    );

    final snapshot = DeviceSnapshot(
      deviceDetails: const {
        '系统': 'Android 14',
        '品牌': 'Google',
        '型号': 'Pixel',
      },
      position: Position(
        longitude: sample.longitude,
        latitude: sample.latitude,
        timestamp: sample.timestamp,
        accuracy: sample.accuracy,
        altitude: sample.altitude,
        altitudeAccuracy: sample.altitudeAccuracy,
        heading: sample.heading,
        headingAccuracy: sample.headingAccuracy,
        speed: sample.speed,
        speedAccuracy: sample.speedAccuracy,
        isMocked: sample.isMocked,
      ),
      locationError: null,
      retrievedAt: sample.timestamp,
    );

    final fakeState = FakeAppState(
      snapshot: snapshot,
      samples: [sample],
    );

    await tester.pumpWidget(
      AppStateScope(
        notifier: fakeState,
        child: const MaterialApp(
          home: DeviceInfoPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('设备信息'), findsOneWidget);
    expect(find.textContaining('品牌: Google'), findsOneWidget);
    expect(find.textContaining('型号: Pixel'), findsOneWidget);
    expect(find.textContaining('纬度'), findsWidgets);
    expect(find.textContaining('采集周期'), findsOneWidget);
  });
}

class FakeAppState extends AppStateBase {
  FakeAppState({
    required DeviceSnapshot snapshot,
    required List<LocationSample> samples,
  })  : _snapshot = snapshot,
        _samples = List<LocationSample>.of(samples);

  final DeviceSnapshot? _snapshot;
  List<LocationSample> _samples;
  bool _collecting = false;
  int _interval = SamplingSettings.defaultInterval;
  int _retention = SamplingSettings.defaultRetentionDays;
  MapProvider _mapProvider = MapProvider.defaultMap;
  List<MapLogEntry> _mapLogs = const [];
  String? _tencentMapKey;

  @override
  DeviceSnapshot? get latestSnapshot => _snapshot;

  @override
  UnmodifiableListView<LocationSample> get samples =>
      UnmodifiableListView(_samples);

  @override
  bool get isCollecting => _collecting;

  @override
  int get samplingIntervalSeconds => _interval;

  @override
  int get retentionDays => _retention;

  @override
  MapProvider get mapProvider => _mapProvider;

  @override
  UnmodifiableListView<MapLogEntry> get mapLogs =>
      UnmodifiableListView(_mapLogs);

  @override
  String? get tencentMapKey => _tencentMapKey;

  @override
  Future<void> collectNow() async {
    _collecting = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _collecting = false;
    notifyListeners();
  }

  @override
  Future<void> updateSamplingInterval(int seconds) async {
    _interval = seconds;
    notifyListeners();
  }

  @override
  Future<void> updateRetentionDays(int days) async {
    _retention = days;
    notifyListeners();
  }

  @override
  Future<void> clearHistory() async {
    _samples = [];
    notifyListeners();
  }

  @override
  Future<void> updateMapProvider(MapProvider provider) async {
    _mapProvider = provider;
    notifyListeners();
  }

  @override
  void addMapLog(MapLogEntry entry) {
    _mapLogs = [..._mapLogs, entry];
    notifyListeners();
  }

  @override
  Future<void> updateTencentMapKey(String? key) async {
    _tencentMapKey = key;
    notifyListeners();
  }
}
