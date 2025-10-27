import 'package:shared_preferences/shared_preferences.dart';

import '../models/map_provider.dart';

abstract class SettingsStore {
  Future<int?> readInterval();
  Future<void> writeInterval(int seconds);
  Future<int?> readRetentionDays();
  Future<void> writeRetentionDays(int days);
  Future<String?> readMapProvider();
  Future<void> writeMapProvider(MapProvider provider);
  Future<List<String>?> readMapLogs();
  Future<void> writeMapLogs(List<String> logs);
  Future<void> clearMapLogs();
}

class SharedPrefsSettingsStore implements SettingsStore {
  SharedPrefsSettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPrefsSettingsStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsSettingsStore._(prefs);
  }

  static const _intervalKey = 'sampling_interval_seconds';
  static const _retentionKey = 'retention_days';
  static const _mapProviderKey = 'map_provider';
  static const _mapLogsKey = 'map_logs';

  @override
  Future<int?> readInterval() async => _prefs.getInt(_intervalKey);

  @override
  Future<void> writeInterval(int seconds) async =>
      _prefs.setInt(_intervalKey, seconds);

  @override
  Future<int?> readRetentionDays() async => _prefs.getInt(_retentionKey);

  @override
  Future<void> writeRetentionDays(int days) async =>
      _prefs.setInt(_retentionKey, days);

  @override
  Future<String?> readMapProvider() async => _prefs.getString(_mapProviderKey);

  @override
  Future<void> writeMapProvider(MapProvider provider) async =>
      _prefs.setString(_mapProviderKey, mapProviderToStorage(provider));

  @override
  Future<List<String>?> readMapLogs() async =>
      _prefs.getStringList(_mapLogsKey);

  @override
  Future<void> writeMapLogs(List<String> logs) async =>
      _prefs.setStringList(_mapLogsKey, logs);

  @override
  Future<void> clearMapLogs() async => _prefs.remove(_mapLogsKey);
}
