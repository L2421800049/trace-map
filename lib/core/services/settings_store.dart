import 'package:shared_preferences/shared_preferences.dart';

import '../models/map_provider.dart';

abstract class SettingsStore {
  Future<int?> readInterval();
  Future<void> writeInterval(int seconds);
  Future<int?> readRetentionDays();
  Future<void> writeRetentionDays(int days);
  Future<String?> readMapProvider();
  Future<void> writeMapProvider(MapProvider provider);
  Future<String?> readCustomLogoUrl();
  Future<void> writeCustomLogoUrl(String? url);
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
  static const _logoUrlKey = 'app_logo_url';

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
  Future<String?> readCustomLogoUrl() async => _prefs.getString(_logoUrlKey);

  @override
  Future<void> writeCustomLogoUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _prefs.remove(_logoUrlKey);
    } else {
      await _prefs.setString(_logoUrlKey, url);
    }
  }
}
