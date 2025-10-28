import 'dart:async' show Timer, unawaited;
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'models/device_snapshot.dart';
import 'models/location_sample.dart';
import 'models/map_provider.dart';
import 'models/map_log_entry.dart';
import 'models/track_record.dart';
import 'repositories/device_info_repository.dart';
import 'repositories/track_repository.dart';
import 'services/settings_store.dart';
import 'services/tencent_map_service.dart';

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
  }) : _settingsStore = settingsStore,
       _trackRepository = trackRepository,
       _deviceRepository = deviceRepository,
       _samplingIntervalSeconds = samplingIntervalSeconds,
       _retentionDays = retentionDays,
       _mapProvider = mapProvider,
       _tencentMapKey = tencentMapKey;

  final SettingsStore _settingsStore;
  final TrackRepository _trackRepository;
  final DeviceInfoRepository _deviceRepository;

  Timer? _timer;
  bool _collecting = false;
  DeviceSnapshot? _latestSnapshot;
  List<LocationSample> _samples = const [];

  int _samplingIntervalSeconds;
  int _retentionDays;
  MapProvider _mapProvider;
  List<MapLogEntry> _mapLogs = const [];
  String? _tencentMapKey;
  List<TrackRecord> _trackRecords = const [];

  static const _tencentKeySetting = 'tencent_map_key';

  static Future<AppState> initialize() async {
    final settingsStore = await SharedPrefsSettingsStore.create();
    final trackRepository = await TrackRepository.open();
    final deviceRepository = PluginDeviceInfoRepository();

    final samplingInterval =
        await settingsStore.readInterval() ?? SamplingSettings.defaultInterval;
    final retentionDays =
        await settingsStore.readRetentionDays() ??
        SamplingSettings.defaultRetentionDays;
    final mapProvider = mapProviderFromStorage(
      await settingsStore.readMapProvider(),
    );
    final tencentKey = await trackRepository.readSetting(_tencentKeySetting);

    final state = AppState._(
      settingsStore: settingsStore,
      trackRepository: trackRepository,
      deviceRepository: deviceRepository,
      samplingIntervalSeconds: samplingInterval,
      retentionDays: retentionDays,
      mapProvider: mapProvider,
      tencentMapKey: tencentKey,
    );

    state._mapLogs = await trackRepository.fetchMapLogs();

    await state._loadInitialData();
    return state;
  }

  Future<void> _loadInitialData() async {
    await _enforceRetention();
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
    }
    _trackRecords = await _trackRepository.fetchTrackRecords();
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

    final startName = await _resolvePlaceName(first);
    final endName = await _resolvePlaceName(last);

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
      return _trackRecords.firstWhere((element) => element.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> refreshTrackRecords() async {
    _trackRecords = await _trackRepository.fetchTrackRecords();
    notifyListeners();
  }

  String _formatCoordinateLabel(LocationSample sample) {
    return '${sample.latitude.toStringAsFixed(5)}, ${sample.longitude.toStringAsFixed(5)}';
  }

  Future<String> _resolvePlaceName(LocationSample sample) async {
    final key = _tencentMapKey;
    if (key == null || key.isEmpty) {
      return _formatCoordinateLabel(sample);
    }
    final service = TencentMapService();
    final result = await service.reverseGeocode(
      latitude: sample.latitude,
      longitude: sample.longitude,
      apiKey: key,
    );
    if (result == null || result.isEmpty) {
      return _formatCoordinateLabel(sample);
    }
    return result;
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
  static const minInterval = 10;
  static const maxInterval = 3600;
  static const minRetentionDays = 1;
  static const maxRetentionDays = 30;
}
