import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_state.dart';
import '../../core/models/map_log_entry.dart';
import '../../core/models/map_provider.dart';
import '../../core/utils/formatting.dart';
import '../app_state_scope.dart';
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
  bool _saving = false;
  bool _clearing = false;
  bool _exporting = false;
  MapProvider? _selectedMapProvider;
  bool _tencentKeyDirty = false;
  bool _isUpdatingTencentKeyField = false;

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
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _retentionController.dispose();
    _tencentKeyController.dispose();
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
    final mapLogs = appState.mapLogs;
    final bool canExportLogs = appState.mapProvider == MapProvider.tencent;
    final bool hasLogs = mapLogs.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('配置')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 28),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
      ),
    );
  }

  Future<void> _saveSettings(AppStateBase appState) async {
    final interval = int.tryParse(_intervalController.text.trim());
    final retention = int.tryParse(_retentionController.text.trim());
    final providerValue = _selectedMapProvider ?? appState.mapProvider;
    final rawTencentKey = _tencentKeyController.text.trim();
    final keyToSave = rawTencentKey.isEmpty ? null : rawTencentKey;

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
      if (mounted) {
        _intervalController.text = '$intervalValue';
        _retentionController.text = '$retentionValue';
        _selectedMapProvider = providerValue;
        _isUpdatingTencentKeyField = true;
        _tencentKeyController.text = keyToSave ?? '';
        _isUpdatingTencentKeyField = false;
        _tencentKeyDirty = false;
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

    final buffer = StringBuffer()
      ..writeln('地图提供商: ${mapProviderDisplayName(appState.mapProvider)}')
      ..writeln('记录数量: ${appState.samples.length}')
      ..writeln('--- 轨迹坐标 ---');

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

    try {
      await file.writeAsString(buffer.toString());

      if (!mounted) {
        return;
      }

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '地图日志 (${formatTimestamp(DateTime.now())})');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}
