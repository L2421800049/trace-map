import 'dart:async' show Timer, unawaited;
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models/device_snapshot.dart';
import 'models/location_sample.dart';
import 'models/map_provider.dart';
import 'models/map_log_entry.dart';
import 'models/object_store_config.dart';
import 'models/storage_mode.dart';
import 'models/track_record.dart';
import 'repositories/device_info_repository.dart';
import 'repositories/track_repository.dart';
import 'services/settings_store.dart';
import 'services/object_store_service.dart';
import 'services/tencent_map_service.dart';
import 'utils/coordinate_transform.dart';

abstract class AppStateBase extends ChangeNotifier {
  DeviceSnapshot? get latestSnapshot;
  UnmodifiableListView<LocationSample> get samples;
  bool get isCollecting;
  int get samplingIntervalSeconds;
  int get retentionDays;
  MapProvider get mapProvider;
  UnmodifiableListView<MapLogEntry> get mapLogs;
  String? get tencentMapKey;
  UnmodifiableListView<TrackRecord> get trackRecords;
  String? get customLogoUrl;
  StorageMode get storageMode;
  ObjectStoreConfig? get objectStoreConfig;

  Future<void> collectNow();
  Future<void> updateSamplingInterval(int seconds);
  Future<void> updateRetentionDays(int days);
  Future<void> clearHistory();
  Future<void> updateMapProvider(MapProvider provider);
  void addMapLog(MapLogEntry entry);
  Future<void> clearMapLogs();
  Future<TrackRecord?> saveCurrentTrackRecord();
  Future<void> refreshTrackRecords();
  Future<void> updateTencentMapKey(String? key);
  Future<void> updateCustomLogoUrl(String? url);
  Future<void> updateStorageMode(StorageMode mode);
  Future<void> updateObjectStoreConfig(ObjectStoreConfig? config);
  Future<void> uploadDatabaseBackup();
  Future<List<String>> listObjectStoreBackups();
  Future<void> restoreDatabaseFromObjectStore(String objectKey);
}

class AppState extends AppStateBase {
  AppState._({
    required SettingsStore settingsStore,
    required TrackRepository trackRepository,
    required DeviceInfoRepository deviceRepository,
    required int samplingIntervalSeconds,
    required int retentionDays,
    required MapProvider mapProvider,
    required String? tencentMapKey,
    required String? customLogoUrl,
    required TencentMapService tencentMapService,
    required StorageMode storageMode,
    required ObjectStoreConfig? objectStoreConfig,
    required ObjectStoreService objectStoreService,
    Map<String, String>? reverseGeocodeCache,
  }) : _settingsStore = settingsStore,
       _trackRepository = trackRepository,
       _deviceRepository = deviceRepository,
       _samplingIntervalSeconds = samplingIntervalSeconds,
       _retentionDays = retentionDays,
       _mapProvider = mapProvider,
       _tencentMapKey = tencentMapKey,
       _customLogoUrl = customLogoUrl,
       _tencentMapService = tencentMapService,
       _storageMode = storageMode,
       _objectStoreConfig = objectStoreConfig,
       _objectStoreService = objectStoreService,
       _reverseGeocodeCache =
           reverseGeocodeCache ?? <String, String>{};

  final SettingsStore _settingsStore;
  final TrackRepository _trackRepository;
  final DeviceInfoRepository _deviceRepository;
  final TencentMapService _tencentMapService;
  final ObjectStoreService _objectStoreService;

  Timer? _timer;
  bool _collecting = false;
  DeviceSnapshot? _latestSnapshot;
  List<LocationSample> _samples = const [];

  int _samplingIntervalSeconds;
  int _retentionDays;
  MapProvider _mapProvider;
  List<MapLogEntry> _mapLogs = const [];
  String? _tencentMapKey;
  String? _customLogoUrl;
  List<TrackRecord> _trackRecords = const [];
  final Map<String, String> _reverseGeocodeCache;
  StorageMode _storageMode;
  ObjectStoreConfig? _objectStoreConfig;

  static const _tencentKeySetting = 'tencent_map_key';

  static Future<AppState> initialize() async {
    final settingsStore = await SharedPrefsSettingsStore.create();
    final trackRepository = await TrackRepository.open();
    final deviceRepository = PluginDeviceInfoRepository();
    const tencentMapService = TencentMapService();
    const objectStoreService = ObjectStoreService();

    final samplingInterval =
        await settingsStore.readInterval() ?? SamplingSettings.defaultInterval;
    final retentionDays =
        await settingsStore.readRetentionDays() ??
        SamplingSettings.defaultRetentionDays;
    final mapProvider = mapProviderFromStorage(
      await settingsStore.readMapProvider(),
    );
    final tencentKey = await trackRepository.readSetting(_tencentKeySetting);
    final customLogoUrl = await settingsStore.readCustomLogoUrl();
    final storageMode = await settingsStore.readStorageMode();
    final objectStoreConfig = await settingsStore.readObjectStoreConfig();

    final state = AppState._(
      settingsStore: settingsStore,
      trackRepository: trackRepository,
      deviceRepository: deviceRepository,
      samplingIntervalSeconds: samplingInterval,
      retentionDays: retentionDays,
      mapProvider: mapProvider,
      tencentMapKey: tencentKey,
      customLogoUrl: customLogoUrl,
      tencentMapService: tencentMapService,
      storageMode: storageMode,
      objectStoreConfig: objectStoreConfig,
      objectStoreService: objectStoreService,
      reverseGeocodeCache: <String, String>{},
    );

    await state._loadInitialData();
    return state;
  }

  @visibleForTesting
  static AppState createForTest({
    required SettingsStore settingsStore,
    required TrackRepository trackRepository,
    required DeviceInfoRepository deviceRepository,
    required TencentMapService tencentMapService,
    ObjectStoreService objectStoreService = const ObjectStoreService(),
    int samplingIntervalSeconds = SamplingSettings.defaultInterval,
    int retentionDays = SamplingSettings.defaultRetentionDays,
    MapProvider mapProvider = MapProvider.defaultMap,
    String? tencentMapKey,
    String? customLogoUrl,
    Map<String, String>? reverseGeocodeCache,
    StorageMode storageMode = StorageMode.local,
    ObjectStoreConfig? objectStoreConfig,
  }) {
    return AppState._(
      settingsStore: settingsStore,
      trackRepository: trackRepository,
      deviceRepository: deviceRepository,
      samplingIntervalSeconds: samplingIntervalSeconds,
      retentionDays: retentionDays,
      mapProvider: mapProvider,
      tencentMapKey: tencentMapKey,
      customLogoUrl: customLogoUrl,
      tencentMapService: tencentMapService,
      storageMode: storageMode,
      objectStoreConfig: objectStoreConfig,
      objectStoreService: objectStoreService,
      reverseGeocodeCache: reverseGeocodeCache,
    );
  }

  Future<void> _loadInitialData() async {
    await _enforceRetention();
    await _reloadFromDatabase(notify: false);
    await collectNow();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _samplingIntervalSeconds),
      (_) => collectNow(),
    );
  }

  Future<void> _reloadFromDatabase({bool notify = true}) async {
    _samples = await _trackRepository.fetchSamples();
    if (_samples.isNotEmpty) {
      final deviceDetails = await _deviceRepository.deviceDetails();
      final last = _samples.last;
      _latestSnapshot = DeviceSnapshot(
        deviceDetails: deviceDetails,
        position: last.toPosition(),
        locationError: null,
        retrievedAt: last.timestamp,
      );
    } else {
      _latestSnapshot = null;
    }
    _trackRecords = await _trackRepository.fetchTrackRecords();
    _mapLogs = await _trackRepository.fetchMapLogs();
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _performCollection() async {
    final snapshot = await _deviceRepository.collectSnapshot();
    _latestSnapshot = snapshot;
    if (snapshot.position != null) {
      final sample = LocationSample.fromPosition(
        snapshot.position!,
        timestamp: snapshot.retrievedAt,
      );
      await _trackRepository.insertSample(sample);
    }
    await _enforceRetention();
    _samples = await _trackRepository.fetchSamples();
  }

  Future<void> _enforceRetention() async {
    final cutoff = DateTime.now().subtract(Duration(days: _retentionDays));
    await _trackRepository.deleteOlderThan(cutoff);
  }

  @override
  Future<void> collectNow() async {
    if (_collecting) {
      return;
    }
    _collecting = true;
    notifyListeners();
    try {
      await _performCollection();
    } finally {
      _collecting = false;
      notifyListeners();
    }
  }

  @override
  Future<void> updateSamplingInterval(int seconds) async {
    if (seconds == _samplingIntervalSeconds) {
      return;
    }
    _samplingIntervalSeconds = seconds;
    await _settingsStore.writeInterval(seconds);
    _startTimer();
    notifyListeners();
  }

  @override
  Future<void> updateRetentionDays(int days) async {
    if (days == _retentionDays) {
      return;
    }
    _retentionDays = days;
    await _settingsStore.writeRetentionDays(days);
    await _enforceRetention();
    _samples = await _trackRepository.fetchSamples();
    notifyListeners();
  }

  @override
  Future<void> clearHistory() async {
    await _trackRepository.deleteAll();
    _samples = const [];
    notifyListeners();
    unawaited(_uploadDatabaseBackup(reason: 'clear-history'));
  }

  @override
  DeviceSnapshot? get latestSnapshot => _latestSnapshot;

  @override
  UnmodifiableListView<LocationSample> get samples =>
      UnmodifiableListView(_samples);

  @override
  bool get isCollecting => _collecting;

  @override
  int get samplingIntervalSeconds => _samplingIntervalSeconds;

  @override
  int get retentionDays => _retentionDays;

  @override
  MapProvider get mapProvider => _mapProvider;

  @override
  String? get tencentMapKey => _tencentMapKey;

  @override
  UnmodifiableListView<TrackRecord> get trackRecords =>
      UnmodifiableListView(_trackRecords);

  @override
  StorageMode get storageMode => _storageMode;

  @override
  ObjectStoreConfig? get objectStoreConfig => _objectStoreConfig;

  @override
  String? get customLogoUrl => _customLogoUrl;

  @override
  UnmodifiableListView<MapLogEntry> get mapLogs =>
      UnmodifiableListView(_mapLogs);

  @override
  Future<void> updateMapProvider(MapProvider provider) async {
    if (provider == _mapProvider) {
      return;
    }
    _mapProvider = provider;
    await _settingsStore.writeMapProvider(provider);
    notifyListeners();
  }

  @override
  void addMapLog(MapLogEntry entry) {
    _mapLogs = [entry, ..._mapLogs];
    unawaited(_trackRepository.insertMapLog(entry));
    notifyListeners();
  }

  @override
  Future<void> clearMapLogs() async {
    await _trackRepository.clearMapLogs();
    _mapLogs = const [];
    notifyListeners();
  }

  @override
  Future<TrackRecord?> saveCurrentTrackRecord() async {
    if (_samples.isEmpty) {
      return null;
    }

    final samples = List<LocationSample>.from(_samples);
    final first = samples.first;
    final last = samples.last;

    final names = await Future.wait<String>([
      _resolvePlaceName(first),
      _resolvePlaceName(last),
    ]);
    final startName = names[0];
    final endName = names[1];

    final record = TrackRecord(
      startTime: first.timestamp,
      endTime: last.timestamp,
      startName: startName,
      endName: endName,
      startLatitude: first.latitude,
      startLongitude: first.longitude,
      endLatitude: last.latitude,
      endLongitude: last.longitude,
      samples: samples,
    );

    final id = await _trackRepository.insertTrackRecord(record);
    await refreshTrackRecords();

    try {
      final saved =
          _trackRecords.firstWhere((element) => element.id == id, orElse: () => TrackRecord(
                id: id,
                startTime: record.startTime,
                endTime: record.endTime,
                startName: record.startName,
                endName: record.endName,
                startLatitude: record.startLatitude,
                startLongitude: record.startLongitude,
                endLatitude: record.endLatitude,
                endLongitude: record.endLongitude,
                samples: record.samples,
              ));
      await _trackRepository.deleteAll();
      _samples = const [];
      unawaited(_uploadDatabaseBackup(reason: 'track-save'));
      notifyListeners();
      return saved;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> refreshTrackRecords() async {
    _trackRecords = await _trackRepository.fetchTrackRecords();
    notifyListeners();
  }

  @override
  Future<void> updateCustomLogoUrl(String? url) async {
    final trimmed = url?.trim();
    _customLogoUrl = trimmed?.isEmpty ?? true ? null : trimmed;
    await _settingsStore.writeCustomLogoUrl(_customLogoUrl);
    notifyListeners();
  }

  @override
  Future<void> updateStorageMode(StorageMode mode) async {
    if (mode == _storageMode) {
      return;
    }
    _storageMode = mode;
    await _settingsStore.writeStorageMode(mode);
    notifyListeners();
    if (mode == StorageMode.objectStore) {
      unawaited(_uploadDatabaseBackup(reason: 'mode-change'));
    }
  }

  @override
  Future<void> updateObjectStoreConfig(ObjectStoreConfig? config) async {
    _objectStoreConfig = config;
    await _settingsStore.writeObjectStoreConfig(config);
    notifyListeners();
  }

  @override
  Future<void> uploadDatabaseBackup() async {
    await _uploadDatabaseBackup(
      reason: 'manual',
      throwOnError: true,
    );
  }

  @override
  Future<List<String>> listObjectStoreBackups() async {
    if (_storageMode != StorageMode.objectStore) {
      throw StateError('存储模式未设置为对象存储');
    }
    final config = _objectStoreConfig;
    if (config == null || !config.isComplete) {
      throw StateError('对象存储配置不完整');
    }
    return _objectStoreService.listBackups(config: config);
  }

  @override
  Future<void> restoreDatabaseFromObjectStore(String objectKey) async {
    if (_storageMode != StorageMode.objectStore) {
      throw StateError('存储模式未设置为对象存储');
    }
    final config = _objectStoreConfig;
    if (config == null || !config.isComplete) {
      throw StateError('对象存储配置不完整');
    }
    final tempDir = await Directory.systemTemp.createTemp('trace-map-restore');
    final tempFile = File('${tempDir.path}/device_track_restore.sqlite');
    try {
      await _objectStoreService.downloadObject(
        config: config,
        objectName: objectKey,
        destinationPath: tempFile.path,
      );
      await _trackRepository.replaceWith(tempFile.path);
      _reverseGeocodeCache.clear();
      await _reloadFromDatabase();
      developer.log(
        'Database restored from $objectKey',
        name: 'AppState',
      );
    } finally {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  String _formatCoordinateLabel(LocationSample sample) {
    return '${sample.latitude.toStringAsFixed(5)}, ${sample.longitude.toStringAsFixed(5)}';
  }

  String _cacheKeyForSample(LocationSample sample) {
    return '${sample.latitude.toStringAsFixed(6)},${sample.longitude.toStringAsFixed(6)}';
  }

  Future<String> _resolvePlaceName(LocationSample sample) async {
    final cacheKey = _cacheKeyForSample(sample);
    final cached = _reverseGeocodeCache[cacheKey];
    if (cached != null) {
      developer.log(
        'Using cached place name for $cacheKey -> $cached',
        name: 'AppState',
      );
      return cached;
    }

    final key = _tencentMapKey;
    if (key == null || key.isEmpty) {
      final fallback = _formatCoordinateLabel(sample);
      _reverseGeocodeCache[cacheKey] = fallback;
      developer.log(
        'Tencent key missing; fallback to coordinates for $cacheKey',
        name: 'AppState',
      );
      return fallback;
    }
    final projected = wgs84ToGcj02(sample.latitude, sample.longitude);
    final result = await _tencentMapService.reverseGeocode(
      latitude: projected.latitude,
      longitude: projected.longitude,
      apiKey: key,
    );
    final normalized = result?.trim();
    final resolved =
        (normalized == null || normalized.isEmpty)
            ? _formatCoordinateLabel(sample)
            : normalized;
    _reverseGeocodeCache[cacheKey] = resolved;
    developer.log(
      normalized == null || normalized.isEmpty
          ? 'Reverse geocode fallback to coordinates for $cacheKey'
          : 'Reverse geocode success for $cacheKey -> $resolved',
      name: 'AppState',
    );
    return resolved;
  }

  Future<void> _uploadDatabaseBackup({
    required String reason,
    bool throwOnError = false,
  }) async {
    if (_storageMode != StorageMode.objectStore) {
      if (throwOnError) {
        throw StateError('Storage mode is not set to objectStore');
      }
      return;
    }
    final config = _objectStoreConfig;
    if (config == null || !config.isComplete) {
      if (throwOnError) {
        throw StateError('Object storage configuration is incomplete');
      }
      developer.log(
        'Skipping database backup ($reason); configuration incomplete',
        name: 'AppState',
      );
      return;
    }
    try {
      await _objectStoreService.ensureBucket(config: config);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final versionedObject = 'backups/device_track_$timestamp.sqlite';
      await _objectStoreService.uploadDatabaseFile(
        config: config,
        filePath: _trackRepository.databasePath,
        objectName: versionedObject,
      );
      await _objectStoreService.uploadDatabaseFile(
        config: config,
        filePath: _trackRepository.databasePath,
        objectName: 'backups/device_track_latest.sqlite',
      );
      await _objectStoreService.enforceBackupRetention(
        config: config,
        maxBackups: 7,
      );
      developer.log(
        'Database backup uploaded ($reason) as $versionedObject',
        name: 'AppState',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to upload database backup ($reason)',
        name: 'AppState',
        error: error,
        stackTrace: stackTrace,
      );
      if (throwOnError) {
        rethrow;
      }
    }
  }

  @visibleForTesting
  Future<String> resolvePlaceNameForTest(LocationSample sample) {
    return _resolvePlaceName(sample);
  }

  @override
  Future<void> updateTencentMapKey(String? key) async {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _tencentMapKey = null;
      await _trackRepository.deleteSetting(_tencentKeySetting);
    } else {
      _tencentMapKey = trimmed;
      await _trackRepository.upsertSetting(_tencentKeySetting, trimmed);
    }
    _reverseGeocodeCache.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_trackRepository.close());
    super.dispose();
  }
}

class SamplingSettings {
  static const defaultInterval = 30;
  static const defaultRetentionDays = 7;
  static const minInterval = 3;
  static const maxInterval = 3600;
  static const minRetentionDays = 1;
  static const maxRetentionDays = 30;
}
