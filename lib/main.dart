import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const DeviceInsightApp());
}

class DeviceInsightApp extends StatelessWidget {
  const DeviceInsightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '设备信息',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DeviceInfoPage(),
    );
  }
}

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key, DeviceInfoRepository? repository})
      : repository = repository ?? const PluginDeviceInfoRepository();

  final DeviceInfoRepository repository;

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  late Future<DeviceSnapshot> _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = widget.repository.fetchInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备信息与当前位置'),
      ),
      body: FutureBuilder<DeviceSnapshot>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _CenteredProgress();
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData) {
            return _ErrorState(
              message: '未能获取数据',
              onRetry: _refresh,
            );
          }
          return _InfoContent(snapshot.data!, onRefresh: _refresh);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  void _refresh() {
    setState(() {
      _infoFuture = widget.repository.fetchInfo();
    });
  }
}

class _InfoContent extends StatelessWidget {
  const _InfoContent(this.snapshot, {required this.onRefresh});

  final DeviceSnapshot snapshot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final deviceLines = snapshot.deviceDetails.entries
        .map((entry) => '• ${entry.key}: ${entry.value}')
        .join('\n');

    final locationLines = _buildLocationLines(snapshot.position);
    final locationText = locationLines ?? snapshot.locationError ?? '未知';

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('设备信息', style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            SelectableText(
              deviceLines,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            Text('位置信息', style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            SelectableText(
              locationText,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            SelectableText(
              '更新时间：${_formatTimestamp(snapshot.retrievedAt)}',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String? _buildLocationLines(Position? position) {
    if (position == null) {
      return null;
    }
    final buffer = StringBuffer()
      ..writeln('• 纬度: ${position.latitude.toStringAsFixed(6)}')
      ..writeln('• 经度: ${position.longitude.toStringAsFixed(6)}');
    if (position.altitude != 0) {
      buffer.writeln('• 海拔: ${position.altitude.toStringAsFixed(1)} 米');
    }
    if (position.accuracy != 0) {
      buffer.writeln('• 精度: ±${position.accuracy.toStringAsFixed(1)} 米');
    }
    buffer.writeln(
      '• 定位时间: ${_formatTimestamp(position.timestamp)}',
    );
    return buffer.toString().trim();
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

abstract class DeviceInfoRepository {
  const DeviceInfoRepository();

  Future<DeviceSnapshot> fetchInfo();
}

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.deviceDetails,
    required this.retrievedAt,
    this.position,
    this.locationError,
  });

  final Map<String, String> deviceDetails;
  final Position? position;
  final String? locationError;
  final DateTime retrievedAt;
}

class PluginDeviceInfoRepository extends DeviceInfoRepository {
  const PluginDeviceInfoRepository();

  @override
  Future<DeviceSnapshot> fetchInfo() async {
    final details = await _collectDeviceDetails();
    Position? position;
    String? locationError;

    try {
      position = await _acquirePosition();
    } on LocationFailure catch (failure) {
      locationError = failure.message;
    } catch (error) {
      locationError = '定位失败：$error';
    }

    return DeviceSnapshot(
      deviceDetails: details,
      position: position,
      locationError: locationError,
      retrievedAt: DateTime.now(),
    );
  }

  Future<Map<String, String>> _collectDeviceDetails() async {
    final plugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return {
        '系统': 'Android ${info.version.release} (API ${info.version.sdkInt})',
        '品牌': info.brand,
        '制造商': info.manufacturer,
        '型号': info.model,
        '设备ID': info.id,
      };
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return {
        '系统': '${info.systemName} ${info.systemVersion}',
        '设备名称': info.name,
        '型号': info.model,
        '标识符': info.identifierForVendor ?? '未知',
      };
    }
    if (Platform.isMacOS) {
      final info = await plugin.macOsInfo;
      return {
        '系统': 'macOS ${info.osRelease}',
        '设备名称': info.computerName,
        '型号': info.model,
        '主机名': info.hostName,
      };
    }
    if (Platform.isWindows) {
      final info = await plugin.windowsInfo;
      return {
        '系统': 'Windows ${info.releaseId}',
        '设备名称': info.computerName,
        '用户': info.userName,
        'CPU 核心数': info.numberOfCores.toString(),
      };
    }
    if (Platform.isLinux) {
      final info = await plugin.linuxInfo;
      final details = <String, String>{
        '系统': info.prettyName,
        '设备名称': info.name,
      };
      if (info.version != null && info.version!.isNotEmpty) {
        details['版本'] = info.version!;
      }
      if (info.variant != null && info.variant!.isNotEmpty) {
        details['变体'] = info.variant!;
      }
      if (info.machineId != null && info.machineId!.isNotEmpty) {
        details['机器ID'] = info.machineId!;
      }
      return details;
    }

    // Unsupported platform fallback (e.g., web)
    final baseInfo = await plugin.deviceInfo;
    return baseInfo.data.map(
      (key, value) => MapEntry(key, value.toString()),
    );
  }

  Future<Position> _acquirePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure('定位服务未开启，请在系统设置中启用定位功能。');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationFailure('定位权限被拒绝，无法获取当前位置。');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure('定位权限被永久拒绝，请在系统设置中手动开启。');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    );
  }
}

class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

String _formatTimestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  final date = '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  final time =
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
  return '$date $time';
}
