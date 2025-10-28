import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../core/models/map_log_entry.dart';
import '../../core/models/map_provider.dart';
import '../../core/models/object_store_config.dart';
import '../../core/models/storage_mode.dart';
import '../../core/utils/formatting.dart';
import '../app_state_scope.dart';
import '../widgets/app_logo_avatar.dart';
import 'log_viewer_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _intervalController;
  late final TextEditingController _retentionController;
  late final TextEditingController _tencentKeyController;
  late final TextEditingController _objectStoreEndpointController;
  late final TextEditingController _objectStoreBucketController;
  late final TextEditingController _objectStoreAccessKeyController;
  late final TextEditingController _objectStoreSecretKeyController;
  bool _saving = false;
  bool _clearing = false;
  bool _clearingLogs = false;
  bool _exporting = false;
  bool _backingUp = false;
  bool _loadingBackups = false;
  bool _restoring = false;
  MapProvider? _selectedMapProvider;
  StorageMode? _selectedStorageMode;
  bool _tencentKeyDirty = false;
  bool _isUpdatingTencentKeyField = false;
  bool _objectStoreDirty = false;
  bool _isUpdatingObjectStoreFields = false;
  bool _objectStoreUseSsl = true;
  bool _showSecret = false;

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController();
    _retentionController = TextEditingController();
    _tencentKeyController = TextEditingController();
    _tencentKeyController.addListener(() {
      if (_isUpdatingTencentKeyField) {
        return;
      }
      _tencentKeyDirty = true;
    });
    _objectStoreEndpointController = TextEditingController();
    _objectStoreBucketController = TextEditingController();
    _objectStoreAccessKeyController = TextEditingController();
    _objectStoreSecretKeyController = TextEditingController();
    void markObjectStoreDirty() {
      if (_isUpdatingObjectStoreFields) {
        return;
      }
      _objectStoreDirty = true;
    }
    _objectStoreEndpointController.addListener(markObjectStoreDirty);
    _objectStoreBucketController.addListener(markObjectStoreDirty);
    _objectStoreAccessKeyController.addListener(markObjectStoreDirty);
    _objectStoreSecretKeyController.addListener(markObjectStoreDirty);
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _retentionController.dispose();
    _tencentKeyController.dispose();
    _objectStoreEndpointController.dispose();
    _objectStoreBucketController.dispose();
    _objectStoreAccessKeyController.dispose();
    _objectStoreSecretKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    _intervalController.text = _intervalController.text.isEmpty
        ? '${appState.samplingIntervalSeconds}'
        : _intervalController.text;
    _retentionController.text = _retentionController.text.isEmpty
        ? '${appState.retentionDays}'
        : _retentionController.text;
    _selectedMapProvider ??= appState.mapProvider;
    final currentTencentKey = appState.tencentMapKey ?? '';
    if (!_tencentKeyDirty && _tencentKeyController.text != currentTencentKey) {
      _isUpdatingTencentKeyField = true;
      _tencentKeyController.text = currentTencentKey;
      _isUpdatingTencentKeyField = false;
    }
    _selectedStorageMode ??= appState.storageMode;
    final objectStoreConfig = appState.objectStoreConfig;
    if (!_objectStoreDirty) {
      _isUpdatingObjectStoreFields = true;
      if (objectStoreConfig != null) {
        _objectStoreEndpointController.text = objectStoreConfig.endpoint;
        _objectStoreBucketController.text = objectStoreConfig.bucket;
        _objectStoreAccessKeyController.text = objectStoreConfig.accessKey;
        _objectStoreSecretKeyController.text = objectStoreConfig.secretKey;
        _objectStoreUseSsl = objectStoreConfig.useSsl;
      } else {
        _objectStoreEndpointController.text = '';
        _objectStoreBucketController.text = '';
        _objectStoreAccessKeyController.text = '';
        _objectStoreSecretKeyController.text = '';
        _objectStoreUseSsl = true;
      }
      _isUpdatingObjectStoreFields = false;
    }
    final mapLogs = appState.mapLogs;
    final bool canExportLogs = appState.mapProvider == MapProvider.tencent;
    final bool hasLogs = mapLogs.isNotEmpty;

    final sections = <Widget>[
      _SectionCard(
        title: '采集设置',
        description: '控制采样频率与历史保留时长，平衡续航与精度。',
        child: Column(
          children: [
            TextField(
              controller: _intervalController,
              decoration: const InputDecoration(
                labelText: '采集间隔（秒）',
                helperText:
                    '允许范围：${SamplingSettings.minInterval} - ${SamplingSettings.maxInterval}',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _retentionController,
              decoration: const InputDecoration(
                labelText: '数据保留天数',
                helperText:
                    '允许范围：${SamplingSettings.minRetentionDays} - ${SamplingSettings.maxRetentionDays}',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _SectionCard(
        title: '地图与腾讯服务',
        description: '切换默认地图，并维护腾讯地图 Key 以便进行轨迹逆地理解析。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<MapProvider>(
              key: ValueKey(_selectedMapProvider),
              initialValue: _selectedMapProvider,
              decoration: const InputDecoration(labelText: '地图提供商'),
              items: MapProvider.values
                  .map(
                    (provider) => DropdownMenuItem(
                      value: provider,
                      child: Text(mapProviderDisplayName(provider)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedMapProvider = value;
                });
              },
            ),
            if (_selectedMapProvider == MapProvider.tencent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _tencentKeyController,
                decoration: const InputDecoration(
                  labelText: '腾讯地图 Key',
                  helperText: '请在腾讯位置服务控制台申请，并填入 WebService Key',
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildLogoCard(appState),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _SectionCard(
        title: '存储设置',
        description: '选择数据库存储方式，可在对象存储中备份 SQLite 文件。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<StorageMode>(
              key: ValueKey(_selectedStorageMode),
              initialValue: _selectedStorageMode ?? StorageMode.local,
              decoration: const InputDecoration(labelText: '存储模式'),
              items: StorageMode.values
                  .map(
                    (mode) => DropdownMenuItem(
                      value: mode,
                      child: Text(
                        mode == StorageMode.local
                            ? '仅本地 SQLite'
                            : '对象存储（MinIO/S3 兼容）',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedStorageMode = value;
                });
              },
            ),
            if ((_selectedStorageMode ?? StorageMode.local) ==
                StorageMode.objectStore) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _objectStoreEndpointController,
                decoration: const InputDecoration(
                  labelText: '对象存储 Endpoint',
                  helperText: '示例：play.min.io:9000 或 10.0.0.2',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _objectStoreBucketController,
                decoration: const InputDecoration(
                  labelText: 'Bucket 名称',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _objectStoreAccessKeyController,
                decoration: const InputDecoration(
                  labelText: 'Access Key',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _objectStoreSecretKeyController,
                decoration: InputDecoration(
                  labelText: 'Secret Key',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showSecret
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSecret = !_showSecret;
                      });
                    },
                  ),
                ),
                obscureText: !_showSecret,
              ),
              SwitchListTile.adaptive(
                value: _objectStoreUseSsl,
                onChanged: (value) {
                  setState(() {
                    _objectStoreUseSsl = value;
                    _objectStoreDirty = true;
                  });
                },
                title: const Text('使用 HTTPS 连接'),
                contentPadding: EdgeInsets.zero,
              ),
              Text(
                '提示：凭证仅存储在本地设备，请妥善保护。',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      _SectionCard(
        title: '同步与历史',
        description: '导出日志、清理历史或保存当前设置。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      await _saveSettings(appState);
                    },
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('保存设置'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _clearing
                  ? null
                  : () async {
                      await _confirmAndClear(appState);
                    },
              icon: _clearing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: const Text('清空历史轨迹'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _exporting || !hasLogs
                  ? null
                  : () async {
                      await _exportMapLogs(appState, mapLogs);
                    },
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('导出地图日志'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _backingUp ||
                      (_selectedStorageMode ?? appState.storageMode) !=
                          StorageMode.objectStore
                  ? null
                  : () async {
                      await _triggerObjectStoreBackup(appState);
                    },
              icon: _backingUp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('备份数据库到对象存储'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadingBackups ||
                      _restoring ||
                      (_selectedStorageMode ?? appState.storageMode) !=
                          StorageMode.objectStore
                  ? null
                  : () async {
                      await _showRestoreDialog(appState);
                    },
              icon: (_loadingBackups || _restoring)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore_outlined),
              label: const Text('从对象存储恢复数据库'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _clearingLogs || !hasLogs
                  ? null
                  : () async {
                      await _confirmAndClearLogs(appState);
                    },
              icon: _clearingLogs
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services_outlined),
              label: const Text('清空地图日志'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: hasLogs
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LogViewerPage(),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('查看地图日志'),
            ),
            if (!hasLogs)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  canExportLogs
                      ? '暂无腾讯地图日志，请先打开“轨迹”页面等待日志生成。'
                      : '当前使用默认地图，切换为腾讯地图后即可记录日志。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogoAvatar(size: 32),
        ),
        title: const Text('配置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: sections,
      ),
    );
  }

  Future<void> _saveSettings(AppStateBase appState) async {
    final interval = int.tryParse(_intervalController.text.trim());
    final retention = int.tryParse(_retentionController.text.trim());
    final providerValue = _selectedMapProvider ?? appState.mapProvider;
    final rawTencentKey = _tencentKeyController.text.trim();
    final keyToSave = rawTencentKey.isEmpty ? null : rawTencentKey;
    final storageModeValue = _selectedStorageMode ?? appState.storageMode;
    final currentObjectStoreConfig = appState.objectStoreConfig;

    ObjectStoreConfig? configToSave = currentObjectStoreConfig;
    final endpoint = _objectStoreEndpointController.text.trim();
    final bucket = _objectStoreBucketController.text.trim();
    final accessKey = _objectStoreAccessKeyController.text.trim();
    final secretKey = _objectStoreSecretKeyController.text.trim();

    
    String? error;
    if (interval == null ||
        interval < SamplingSettings.minInterval ||
        interval > SamplingSettings.maxInterval) {
      error =
          '采集间隔需在 ${SamplingSettings.minInterval}-${SamplingSettings.maxInterval} 秒之间';
    } else if (retention == null ||
        retention < SamplingSettings.minRetentionDays ||
        retention > SamplingSettings.maxRetentionDays) {
      error =
          '保留天数需在 ${SamplingSettings.minRetentionDays}-${SamplingSettings.maxRetentionDays} 天之间';
    } else if (providerValue == MapProvider.tencent && (keyToSave == null)) {
      error = '请选择腾讯地图时必须填写有效的 Key';
    } else if (storageModeValue == StorageMode.objectStore) {
      if (endpoint.isEmpty ||
          bucket.isEmpty ||
          accessKey.isEmpty ||
          secretKey.isEmpty) {
        error = '使用对象存储时必须填写 Endpoint、Bucket、Access Key 和 Secret Key';
      } else {
        configToSave = ObjectStoreConfig(
          endpoint: endpoint,
          bucket: bucket,
          accessKey: accessKey,
          secretKey: secretKey,
          useSsl: _objectStoreUseSsl,
        );
      }
    } else if (_objectStoreDirty) {
      if (endpoint.isEmpty &&
          bucket.isEmpty &&
          accessKey.isEmpty &&
          secretKey.isEmpty) {
        configToSave = null;
      } else {
        configToSave = ObjectStoreConfig(
          endpoint: endpoint,
          bucket: bucket,
          accessKey: accessKey,
          secretKey: secretKey,
          useSsl: _objectStoreUseSsl,
        );
      }
    }

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final intervalValue = interval!;
      final retentionValue = retention!;

      await appState.updateSamplingInterval(intervalValue);
      await appState.updateRetentionDays(retentionValue);
      await appState.updateTencentMapKey(keyToSave);
      await appState.updateMapProvider(providerValue);
      await appState.updateObjectStoreConfig(configToSave);
      await appState.updateStorageMode(storageModeValue);
      if (mounted) {
        _intervalController.text = '$intervalValue';
        _retentionController.text = '$retentionValue';
        _selectedMapProvider = providerValue;
        _isUpdatingTencentKeyField = true;
        _tencentKeyController.text = keyToSave ?? '';
        _isUpdatingTencentKeyField = false;
        _tencentKeyDirty = false;
        _selectedStorageMode = storageModeValue;
        _isUpdatingObjectStoreFields = true;
        if (configToSave != null) {
          _objectStoreEndpointController.text = configToSave.endpoint;
          _objectStoreBucketController.text = configToSave.bucket;
          _objectStoreAccessKeyController.text = configToSave.accessKey;
          _objectStoreSecretKeyController.text = configToSave.secretKey;
          _objectStoreUseSsl = configToSave.useSsl;
        } else {
          _objectStoreEndpointController.text = '';
          _objectStoreBucketController.text = '';
          _objectStoreAccessKeyController.text = '';
          _objectStoreSecretKeyController.text = '';
          _objectStoreUseSsl = true;
        }
        _isUpdatingObjectStoreFields = false;
        _objectStoreDirty = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('设置已保存')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmAndClear(AppStateBase appState) async {
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('确认清空轨迹数据'),
              content: const Text('此操作会删除所有已保存的历史轨迹数据，且不可恢复。是否继续？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('清空'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldClear) {
      return;
    }

    setState(() => _clearing = true);
    try {
      await appState.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('历史轨迹已清空')));
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  Future<void> _confirmAndClearLogs(AppStateBase appState) async {
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('清空地图日志'),
              content: const Text('将删除所有地图日志记录，且不可恢复。是否继续？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('清空'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldClear) {
      return;
    }

    setState(() => _clearingLogs = true);
    try {
      await appState.clearMapLogs();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地图日志已清空')));
      }
    } finally {
      if (mounted) {
        setState(() => _clearingLogs = false);
      }
    }
  }

  Future<void> _triggerObjectStoreBackup(AppStateBase appState) async {
    setState(() => _backingUp = true);
    try {
      await appState.uploadDatabaseBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据库已备份到对象存储')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败：${error.runtimeType}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _backingUp = false);
      }
    }
  }

  Future<void> _showRestoreDialog(AppStateBase appState) async {
    setState(() => _loadingBackups = true);
    List<String> backups = const [];
    try {
      backups = await appState.listObjectStoreBackups();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取备份列表失败：${error.runtimeType}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingBackups = false);
      }
    }
    if (!mounted || backups.isEmpty) {
      if (mounted && backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可用的备份文件')),
        );
      }
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.storage_outlined),
                title: Text('选择要恢复的备份'),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: backups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final key = backups[index];
                    return ListTile(
                      title: Text(key),
                      onTap: () => Navigator.of(context).pop(key),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      await _confirmAndRestore(appState, selected);
    }
  }

  Future<void> _confirmAndRestore(
    AppStateBase appState,
    String objectKey,
  ) async {
    final shouldRestore =
        await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('确认恢复数据库'),
                  content: Text('将覆盖本地数据并从 "$objectKey" 进行恢复，是否继续？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('恢复'),
                    ),
                  ],
                );
              },
            ) ??
        false;

    if (!shouldRestore || !mounted) {
      return;
    }

    setState(() => _restoring = true);
    try {
      await appState.restoreDatabaseFromObjectStore(objectKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已从 $objectKey 恢复数据库')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败：${error.runtimeType}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  Future<void> _exportMapLogs(
    AppStateBase appState,
    List<MapLogEntry> logs,
  ) async {
    setState(() => _exporting = true);
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final filePath = path.join(directory.path, 'map_log_$timestamp.txt');
    final file = File(filePath);

    final buffer = StringBuffer();
    buffer.writeln('# 轨迹采样快照 (${appState.samples.length} 个点)');
    buffer.writeln('--- 样本 ---');

    for (final sample in appState.samples) {
      buffer.writeln(
        '${formatTimestamp(sample.timestamp)} -> (${sample.latitude.toStringAsFixed(6)}, ${sample.longitude.toStringAsFixed(6)})',
      );
    }

    buffer.writeln('--- 日志 ---');
    if (logs.isEmpty) {
      buffer.writeln('暂无日志');
    } else {
      for (final entry in logs) {
        buffer.writeln(
          '${formatTimestamp(entry.timestamp)} -> ${entry.message}',
        );
      }
    }

    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([
      XFile(file.path),
    ], text: '地图日志 (${formatTimestamp(DateTime.now())})');

    if (mounted) {
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日志已导出至 ${file.path}')),
      );
    }
  }

  Widget _buildLogoCard(AppStateBase appState) {
    final customLogo = appState.customLogoUrl;
    final description = customLogo == null || customLogo.isEmpty
        ? '当前使用内置 Logo'
        : '自定义 Logo：$customLogo';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('应用 Logo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: AppLogoAvatar(size: 120),
              ),
            ),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _promptChangeLogo(appState),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('更换 Logo'),
                ),
                if (customLogo != null && customLogo.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      await appState.updateCustomLogoUrl(null);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已恢复默认 Logo')),
                        );
                      }
                    },
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('恢复默认'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptChangeLogo(AppStateBase appState) async {
    final controller = TextEditingController(
      text: appState.customLogoUrl ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置应用 Logo'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '图片地址 (http/https)',
              hintText: '例如：https://example.com/logo.png',
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      await appState.updateCustomLogoUrl(null);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已恢复默认 Logo')));
      }
      return;
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入 http 或 https 开头的图片地址')),
        );
      }
      return;
    }

    await appState.updateCustomLogoUrl(trimmed);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logo 已更新')));
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
