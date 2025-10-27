import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../models/device_snapshot.dart';

abstract class DeviceInfoRepository {
  Future<DeviceSnapshot> collectSnapshot();
  Future<Map<String, String>> deviceDetails();
}

class PluginDeviceInfoRepository extends DeviceInfoRepository {
  PluginDeviceInfoRepository();

  @override
  Future<DeviceSnapshot> collectSnapshot() async {
    final details = await deviceDetails();
    Position? position;
    String? error;
    try {
      position = await _acquirePosition();
    } on LocationFailure catch (failure) {
      error = failure.message;
    } catch (e) {
      error = '定位失败：$e';
    }

    return DeviceSnapshot(
      deviceDetails: details,
      position: position,
      locationError: error,
      retrievedAt: DateTime.now(),
    );
  }

  @override
  Future<Map<String, String>> deviceDetails() =>
      _collectDeviceDetails();

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
      final result = <String, String>{
        '系统': info.prettyName,
        '设备名称': info.name,
      };
      if (info.version != null && info.version!.isNotEmpty) {
        result['版本'] = info.version!;
      }
      if (info.variant != null && info.variant!.isNotEmpty) {
        result['变体'] = info.variant!;
      }
      if (info.machineId != null && info.machineId!.isNotEmpty) {
        result['机器ID'] = info.machineId!;
      }
      return result;
    }

    final baseInfo = await plugin.deviceInfo;
    return baseInfo.data.map((key, value) => MapEntry(key, value.toString()));
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
