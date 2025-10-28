import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/core/app_state.dart';
import 'package:myapp/core/models/device_snapshot.dart';
import 'package:myapp/core/models/location_sample.dart';
import 'package:myapp/core/models/map_log_entry.dart';
import 'package:myapp/core/models/map_provider.dart';
import 'package:myapp/core/models/track_record.dart';
import 'package:myapp/core/models/object_store_config.dart';
import 'package:myapp/core/models/storage_mode.dart';
import 'package:myapp/core/repositories/device_info_repository.dart';
import 'package:myapp/core/repositories/track_repository.dart';
import 'package:myapp/core/services/settings_store.dart';
import 'package:myapp/core/services/tencent_map_service.dart';
import 'package:myapp/core/utils/coordinate_transform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sample = LocationSample(
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    latitude: 39.9042,
    longitude: 116.4074,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    isMocked: false,
  );

  AppState createState({String? key, FakeTencentMapService? service}) {
    return AppState.createForTest(
      settingsStore: FakeSettingsStore(),
      trackRepository: FakeTrackRepository(),
      deviceRepository: FakeDeviceInfoRepository(),
      tencentMapService: service ?? FakeTencentMapService(),
      tencentMapKey: key,
    );
  }

  test('falls back to coordinate label when Tencent key is absent', () async {
    final state = createState();
    addTearDown(state.dispose);

    final title = await state.resolvePlaceNameForTest(sample);
    expect(title, '39.90420, 116.40740');
  });

  test('trims SDK response and caches repeated lookups', () async {
    final service = FakeTencentMapService(responses: const ['  Beijing  ']);
    final state = createState(key: 'demo-key', service: service);
    addTearDown(state.dispose);

    final first = await state.resolvePlaceNameForTest(sample);
    final second = await state.resolvePlaceNameForTest(sample);

    expect(first, 'Beijing');
    expect(second, 'Beijing');
    expect(service.callCount, 1);
  });

  test(
    'falls back to coordinate label when SDK returns blank string',
    () async {
      final service = FakeTencentMapService(responses: const ['   ']);
      final state = createState(key: 'demo-key', service: service);
      addTearDown(state.dispose);

      final result = await state.resolvePlaceNameForTest(sample);
      expect(result, '39.90420, 116.40740');
    },
  );

  test('converts WGS84 coordinates to GCJ-02 before querying SDK', () async {
    final service = FakeTencentMapService(responses: const ['Result']);
    final state = createState(key: 'demo-key', service: service);
    addTearDown(state.dispose);

    await state.resolvePlaceNameForTest(sample);

    final projected = wgs84ToGcj02(sample.latitude, sample.longitude);
    expect(service.lastLatitude, closeTo(projected.latitude, 1e-6));
    expect(service.lastLongitude, closeTo(projected.longitude, 1e-6));
  });
}

class FakeSettingsStore implements SettingsStore {
  int? _interval;
  int? _retentionDays;
  String? _mapProvider;
  String? _logoUrl;
  StorageMode _storageMode = StorageMode.local;
  ObjectStoreConfig? _objectStoreConfig;

  @override
  Future<int?> readInterval() async => _interval;

  @override
  Future<void> writeInterval(int seconds) async {
    _interval = seconds;
  }

  @override
  Future<int?> readRetentionDays() async => _retentionDays;

  @override
  Future<void> writeRetentionDays(int days) async {
    _retentionDays = days;
  }

  @override
  Future<String?> readMapProvider() async => _mapProvider;

  @override
  Future<void> writeMapProvider(MapProvider provider) async {
    _mapProvider = mapProviderToStorage(provider);
  }

  @override
  Future<String?> readCustomLogoUrl() async => _logoUrl;

  @override
  Future<void> writeCustomLogoUrl(String? url) async {
    _logoUrl = url;
  }

  @override
  Future<StorageMode> readStorageMode() async => _storageMode;

  @override
  Future<void> writeStorageMode(StorageMode mode) async {
    _storageMode = mode;
  }

  @override
  Future<ObjectStoreConfig?> readObjectStoreConfig() async =>
      _objectStoreConfig;

  @override
  Future<void> writeObjectStoreConfig(ObjectStoreConfig? config) async {
    _objectStoreConfig = config;
  }
}

class FakeTrackRepository implements TrackRepository {
  final List<LocationSample> _samples = [];
  final List<MapLogEntry> _mapLogs = [];
  final Map<String, String> _settings = {};
  final List<TrackRecord> _records = [];
  int _nextId = 1;
  final String _dbPath = '/tmp/device_track.sqlite';

  @override
  Future<void> insertSample(LocationSample sample) async {
    _samples.add(sample);
  }

  @override
  Future<List<LocationSample>> fetchSamples() async =>
      List<LocationSample>.from(_samples);

  @override
  Future<void> deleteOlderThan(DateTime cutoff) async {
    _samples.removeWhere((sample) => sample.timestamp.isBefore(cutoff));
  }

  @override
  Future<void> deleteAll() async {
    _samples.clear();
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> insertMapLog(MapLogEntry entry) async {
    _mapLogs.add(entry);
  }

  @override
  Future<List<MapLogEntry>> fetchMapLogs() async =>
      List<MapLogEntry>.from(_mapLogs);

  @override
  Future<void> clearMapLogs() async {
    _mapLogs.clear();
  }

  @override
  Future<void> upsertSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<String?> readSetting(String key) async => _settings[key];

  @override
  Future<void> deleteSetting(String key) async {
    _settings.remove(key);
  }

  @override
  Future<int> insertTrackRecord(TrackRecord record) async {
    final assigned = TrackRecord(
      id: _nextId++,
      startTime: record.startTime,
      endTime: record.endTime,
      startName: record.startName,
      endName: record.endName,
      startLatitude: record.startLatitude,
      startLongitude: record.startLongitude,
      endLatitude: record.endLatitude,
      endLongitude: record.endLongitude,
      samples: record.samples,
    );
    _records.add(assigned);
    return assigned.id!;
  }

  @override
  Future<List<TrackRecord>> fetchTrackRecords() async =>
      List<TrackRecord>.from(_records);

  @override
  Future<void> deleteTrackRecord(int id) async {
    _records.removeWhere((record) => record.id == id);
  }

  @override
  String get databasePath => _dbPath;

  @override
  Future<void> replaceWith(String sourcePath) async {}
}

class FakeDeviceInfoRepository implements DeviceInfoRepository {
  @override
  Future<DeviceSnapshot> collectSnapshot() async => DeviceSnapshot(
    deviceDetails: const <String, String>{},
    retrievedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  @override
  Future<Map<String, String>> deviceDetails() async => const <String, String>{};
}

class FakeTencentMapService extends TencentMapService {
  FakeTencentMapService({this.responses = const []});

  final List<String?> responses;
  int callCount = 0;
  double? lastLatitude;
  double? lastLongitude;
  String? lastApiKey;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
    required String apiKey,
  }) async {
    callCount += 1;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastApiKey = apiKey;
    if (responses.isEmpty) {
      return null;
    }
    final index = callCount - 1;
    return index < responses.length ? responses[index] : responses.last;
  }
}
