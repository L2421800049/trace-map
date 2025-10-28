import 'dart:convert';
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
    final nativeResult = _normalizeResult(
      await _reverseGeocodeViaSdk(
        latitude: latitude,
        longitude: longitude,
        apiKey: apiKey,
      ),
    );
    if (nativeResult != null) {
      return nativeResult;
    }
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
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('reverseGeocode', {
        'latitude': latitude,
        'longitude': longitude,
        'apiKey': apiKey,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
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
      final response = await client.get(uri);
      if (response.statusCode != 200) {
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
          return address;
        }
      }
      return null;
    } catch (_) {
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
