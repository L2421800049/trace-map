import 'package:shared_preferences/shared_preferences.dart';

import '../models/map_provider.dart';
import '../models/object_store_config.dart';
import '../models/storage_mode.dart';

abstract class SettingsStore {
  Future<int?> readInterval();
  Future<void> writeInterval(int seconds);
  Future<int?> readRetentionDays();
  Future<void> writeRetentionDays(int days);
  Future<String?> readMapProvider();
  Future<void> writeMapProvider(MapProvider provider);
  Future<String?> readCustomLogoUrl();
  Future<void> writeCustomLogoUrl(String? url);
  Future<StorageMode> readStorageMode();
  Future<void> writeStorageMode(StorageMode mode);
  Future<ObjectStoreConfig?> readObjectStoreConfig();
  Future<void> writeObjectStoreConfig(ObjectStoreConfig? config);
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
  static const _storageModeKey = 'storage_mode';
  static const _objectStoreEndpointKey = 'object_store_endpoint';
  static const _objectStoreBucketKey = 'object_store_bucket';
  static const _objectStoreAccessKey = 'object_store_access_key';
  static const _objectStoreSecretKey = 'object_store_secret_key';
  static const _objectStoreUseSslKey = 'object_store_use_ssl';

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

  @override
  Future<StorageMode> readStorageMode() async {
    final raw = _prefs.getString(_storageModeKey);
    return storageModeFromString(raw);
  }

  @override
  Future<void> writeStorageMode(StorageMode mode) async {
    await _prefs.setString(_storageModeKey, storageModeToString(mode));
  }

  @override
  Future<ObjectStoreConfig?> readObjectStoreConfig() async {
    final endpoint = _prefs.getString(_objectStoreEndpointKey);
    final bucket = _prefs.getString(_objectStoreBucketKey);
    final accessKey = _prefs.getString(_objectStoreAccessKey);
    final secretKey = _prefs.getString(_objectStoreSecretKey);
    final useSsl = _prefs.getBool(_objectStoreUseSslKey);
    if (endpoint == null &&
        bucket == null &&
        accessKey == null &&
        secretKey == null) {
      return null;
    }
    return ObjectStoreConfig(
      endpoint: endpoint ?? '',
      bucket: bucket ?? '',
      accessKey: accessKey ?? '',
      secretKey: secretKey ?? '',
      useSsl: useSsl ?? true,
    );
  }

  @override
  Future<void> writeObjectStoreConfig(ObjectStoreConfig? config) async {
    if (config == null) {
      await _prefs.remove(_objectStoreEndpointKey);
      await _prefs.remove(_objectStoreBucketKey);
      await _prefs.remove(_objectStoreAccessKey);
      await _prefs.remove(_objectStoreSecretKey);
      await _prefs.remove(_objectStoreUseSslKey);
      return;
    }
    await _prefs.setString(_objectStoreEndpointKey, config.endpoint);
    await _prefs.setString(_objectStoreBucketKey, config.bucket);
    await _prefs.setString(_objectStoreAccessKey, config.accessKey);
    await _prefs.setString(_objectStoreSecretKey, config.secretKey);
    await _prefs.setBool(_objectStoreUseSslKey, config.useSsl);
  }
}
