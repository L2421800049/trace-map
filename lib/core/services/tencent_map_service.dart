import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class TencentMapService {
  const TencentMapService({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const MethodChannel _channel =
      MethodChannel('com.example.myapp/tencent_map_service');

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
    required String apiKey,
  }) async {
    developer.log(
      'reverseGeocode request lat=$latitude lng=$longitude',
      name: 'TencentMapService',
    );
    final nativeResult = _normalizeResult(
      await _reverseGeocodeViaSdk(
        latitude: latitude,
        longitude: longitude,
        apiKey: apiKey,
      ),
    );
    if (nativeResult != null) {
      developer.log(
        'reverseGeocode success via SDK: $nativeResult',
        name: 'TencentMapService',
      );
      return nativeResult;
    }
    developer.log(
      'reverseGeocode falling back to HTTP for lat=$latitude lng=$longitude',
      name: 'TencentMapService',
    );
    return _normalizeResult(
      await _reverseGeocodeViaHttp(
        latitude: latitude,
        longitude: longitude,
        apiKey: apiKey,
      ),
    );
  }

  Future<String?> _reverseGeocodeViaSdk({
    required double latitude,
    required double longitude,
    required String apiKey,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      developer.log(
        'Skipping native reverseGeocode (platform unsupported)',
        name: 'TencentMapService',
      );
      return null;
    }
    try {
      developer.log(
        'Invoking native reverseGeocode lat=$latitude lng=$longitude',
        name: 'TencentMapService',
      );
      return await _channel.invokeMethod<String>('reverseGeocode', {
        'latitude': latitude,
        'longitude': longitude,
        'apiKey': apiKey,
      });
    } on PlatformException catch (error, stackTrace) {
      developer.log(
        'Native reverseGeocode failed: ${error.message}',
        name: 'TencentMapService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      developer.log(
        'Native reverseGeocode plugin missing',
        name: 'TencentMapService',
      );
      return null;
    }
  }

  Future<String?> _reverseGeocodeViaHttp({
    required double latitude,
    required double longitude,
    required String apiKey,
  }) async {
    final client = _client ?? http.Client();
    try {
      final uri = Uri.https('apis.map.qq.com', '/ws/geocoder/v1/', {
        'location': '$latitude,$longitude',
        'key': apiKey,
      });
      developer.log(
        'HTTP reverseGeocode GET $uri',
        name: 'TencentMapService',
      );
      final response = await client.get(uri);
      if (response.statusCode != 200) {
        developer.log(
          'HTTP reverseGeocode non-200: ${response.statusCode}',
          name: 'TencentMapService',
        );
        return null;
      }
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] == 0) {
        final result = data['result'] as Map<String, dynamic>?;
        if (result == null) {
          return null;
        }
        final formatted =
            result['formatted_addresses'] as Map<String, dynamic>?;
        if (formatted != null) {
          final recommend = formatted['recommend'] as String?;
          if (recommend != null && recommend.isNotEmpty) {
            return recommend;
          }
        }
        final address = result['address'] as String?;
        if (address != null && address.isNotEmpty) {
          developer.log(
            'HTTP reverseGeocode success: $address',
            name: 'TencentMapService',
          );
          return address;
        }
      }
      developer.log(
        'HTTP reverseGeocode returned status=${data['status']} without address',
        name: 'TencentMapService',
      );
      return null;
    } catch (error, stackTrace) {
      developer.log(
        'HTTP reverseGeocode threw',
        name: 'TencentMapService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  String? _normalizeResult(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
