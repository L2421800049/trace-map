import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/models/map_provider.dart';
import '../../core/models/location_sample.dart';
import '../../core/models/map_log_entry.dart';
import '../../core/utils/coordinate_transform.dart';
import '../../core/utils/formatting.dart';
import '../app_state_scope.dart';

const _tencentMapKey = '5KABZ-2CCKL-3OUPE-ELJNN-SUT4J-OZBRY';
const _tencentMapBaseUrl = 'https://tencent-map.flutter-app.local/';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, appState) {
        final samples = appState.samples;

        return Scaffold(
          appBar: AppBar(title: const Text('轨迹地图')),
          body: samples.isEmpty
              ? const _EmptyMapState()
              : Column(
                  children: [
                    Expanded(
                      child: appState.mapProvider == MapProvider.tencent
                          ? _TencentMapView(
                              samples: samples,
                              onLogEntry: appState.addMapLog,
                            )
                          : _DefaultMapView(samples: samples),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('记录点位：${samples.length} 个'),
                          const SizedBox(height: 6),
                          Text(
                            '时间范围：'
                            '${formatTimestamp(samples.first.timestamp)}'
                            ' - ${formatTimestamp(samples.last.timestamp)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _DefaultMapView extends StatelessWidget {
  const _DefaultMapView({required this.samples});

  final List<LocationSample> samples;

  @override
  Widget build(BuildContext context) {
    final points = samples
        .map((sample) => LatLng(sample.latitude, sample.longitude))
        .toList();

    final polyline = Polyline(
      points: points,
      color: Colors.lightBlueAccent,
      strokeWidth: 4,
    );

    return FlutterMap(
      options: MapOptions(initialCenter: points.last, initialZoom: 16),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.myapp',
        ),
        PolylineLayer(polylines: [polyline]),
        MarkerLayer(
          markers: [
            Marker(
              point: points.first,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.flag,
                color: Colors.greenAccent,
                size: 30,
              ),
            ),
            Marker(
              point: points.last,
              width: 40,
              height: 40,
              child: const Icon(Icons.place, color: Colors.redAccent, size: 34),
            ),
          ],
        ),
      ],
    );
  }
}

class _TencentMapView extends StatefulWidget {
  const _TencentMapView({required this.samples, required this.onLogEntry});

  final List<LocationSample> samples;
  final ValueChanged<MapLogEntry> onLogEntry;

  @override
  State<_TencentMapView> createState() => _TencentMapViewState();
}

class _TencentMapViewState extends State<_TencentMapView> {
  late final WebViewController _controller;
  bool _pageReady = false;
  bool _hasLoadedContent = false;
  bool _pendingUpdate = false;
  String? _latestPointsJson;
  bool _loggedProjectionHint = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'LogChannel',
        onMessageReceived: (message) {
          _handleJavaScriptMessage(message.message);
        },
      );
    _loadInitialContent(widget.samples);
  }

  @override
  void didUpdateWidget(covariant _TencentMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.samples, widget.samples)) {
      _pushLog('样本更新：${widget.samples.length} 个点');
      _latestPointsJson = _encodePoints(widget.samples);
      _scheduleMapUpdate();
    }
  }

  void _handleJavaScriptMessage(String rawMessage) {
    if (rawMessage == '__READY__') {
      _pageReady = true;
      _pushLog('腾讯地图页面就绪');
      _flushPendingUpdate();
      return;
    }
    _pushLog('[JS] $rawMessage');
  }

  void _pushLog(String message) {
    final entry = MapLogEntry(timestamp: DateTime.now(), message: message);
    widget.onLogEntry(entry);
  }

  void _loadInitialContent(List<LocationSample> samples) {
    final pointsJson = _encodePoints(samples);
    _latestPointsJson = pointsJson;
    _pageReady = false;
    _pendingUpdate = true;
    final html =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no" />
  <style>
    html, body { margin: 0; padding: 0; height: 100%; background: #121212; }
    #map { width: 100%; height: 100%; }
  </style>
  <script>
    const DEFAULT_CENTER = { lat: 39.909187, lng: 116.397451 };
    const DEFAULT_ZOOM = 16;
    let points = $pointsJson;
    let map = null;
    let trackPolyline = null;
    let markerLayer = null;

    function log(message) {
      try {
        if (window.LogChannel) {
          window.LogChannel.postMessage(message);
        }
      } catch (e) {}
    }
    window.onerror = function(message, source, lineno, colno, error) {
      log('错误: ' + message + ' @ ' + source + ':' + lineno);
    };
    window.addEventListener('unhandledrejection', function(event) {
      log('未处理的 Promise 拒绝: ' + event.reason);
    });
    log('页面 origin: ' + window.location.origin + ', href: ' + window.location.href);

    function createLatLng(point) {
      return new TMap.LatLng(point.lat, point.lng);
    }

    function ensureMapCentered(point) {
      const target = point || DEFAULT_CENTER;
      if (!map) {
        map = new TMap.Map('map', {
          center: createLatLng(target),
          zoom: DEFAULT_ZOOM,
        });
        return;
      }
      try {
        map.setCenter(createLatLng(target));
      } catch (err) {
        log('设置中心点失败: ' + err);
      }
    }

    function clearPolyline() {
      if (!trackPolyline) {
        return;
      }
      if (typeof trackPolyline.setGeometries === 'function') {
        trackPolyline.setGeometries([]);
        return;
      }
      if (typeof trackPolyline.setMap === 'function') {
        try {
          trackPolyline.setMap(null);
        } catch (err) {
          log('清理折线失败: ' + err);
        }
      }
      trackPolyline = null;
    }

    function clearMarkers() {
      if (!markerLayer) {
        return;
      }
      if (typeof markerLayer.setGeometries === 'function') {
        markerLayer.setGeometries([]);
        return;
      }
      if (typeof markerLayer.setMap === 'function') {
        try {
          markerLayer.setMap(null);
        } catch (err) {
          log('清理标记失败: ' + err);
        }
      }
      markerLayer = null;
    }

    function updatePolyline(latLngs) {
      if (latLngs.length < 2) {
        clearPolyline();
        log('只有一个点，跳过折线');
        return;
      }
      const geometries = [{
        paths: latLngs,
        styleId: 'track_style',
      }];
      if (trackPolyline && typeof trackPolyline.setGeometries === 'function') {
        trackPolyline.setGeometries(geometries);
        log('轨迹折线已更新');
        return;
      }
      if (trackPolyline && typeof trackPolyline.setMap === 'function') {
        try {
          trackPolyline.setMap(null);
        } catch (err) {
          log('移除旧折线失败: ' + err);
        }
      }
      trackPolyline = new TMap.MultiPolyline({
        id: 'track',
        map,
        geometries,
        styles: {
          track_style: new TMap.PolylineStyle({
            color: '#64B5F6',
            width: 6,
          }),
        },
      });
      log('轨迹折线已绘制');
    }

    function updateMarkers(latLngs) {
      if (latLngs.length === 0) {
        clearMarkers();
        return;
      }
      const geometries = [];
      geometries.push({ id: 'start', position: latLngs[0], styleId: 'start' });
      const endIndex = latLngs.length > 1 ? latLngs.length - 1 : 0;
      geometries.push({ id: 'end', position: latLngs[endIndex], styleId: 'end' });

      if (markerLayer && typeof markerLayer.setGeometries === 'function') {
        markerLayer.setGeometries(geometries);
        log('起点终点标记已更新');
        return;
      }
      if (markerLayer && typeof markerLayer.setMap === 'function') {
        try {
          markerLayer.setMap(null);
        } catch (err) {
          log('移除旧标记失败: ' + err);
        }
      }
      markerLayer = new TMap.MultiMarker({
        id: 'markers',
        map,
        styles: {
          start: new TMap.MarkerStyle({ width: 30, height: 42, src: 'https://mapapi.qq.com/web/miniprogram/demoCenter/images/marker-start.png' }),
          end: new TMap.MarkerStyle({ width: 30, height: 42, src: 'https://mapapi.qq.com/web/miniprogram/demoCenter/images/marker-end.png' }),
        },
        geometries,
      });
      log('起点终点标记已绘制');
    }

    function renderTrack(pointList) {
      if (!Array.isArray(pointList) || pointList.length === 0) {
        log('没有点位，等待后续更新');
        clearPolyline();
        clearMarkers();
        return;
      }
      const latLngs = pointList.map((p) => createLatLng(p));
      log('生成 LatLng 数组: ' + latLngs.length);
      ensureMapCentered(pointList[pointList.length - 1]);
      updatePolyline(latLngs);
      updateMarkers(latLngs);
      log('轨迹内容已更新');
    }

    window.initMap = function() {
      log('initMap 调用，点位数量: ' + points.length);
      ensureMapCentered(points.length > 0 ? points[points.length - 1] : DEFAULT_CENTER);
      renderTrack(points);
      if (Array.isArray(window.__pendingPoints)) {
        const cached = window.__pendingPoints;
        window.__pendingPoints = null;
        log('应用缓存点位: ' + cached.length);
        renderTrack(cached);
      }
      log('__READY__');
    };

    window.updateTrack = function(updatedPoints) {
      if (!Array.isArray(updatedPoints)) {
        log('updateTrack 收到无效数据');
        return;
      }
      points = updatedPoints;
      if (typeof TMap === 'undefined') {
        log('TMap 尚未可用，暂存点位');
        window.__pendingPoints = updatedPoints;
        return;
      }
      if (!map && (!updatedPoints || updatedPoints.length === 0)) {
        log('updateTrack 空数据，地图尚未初始化');
        return;
      }
      if (!map && updatedPoints.length > 0) {
        ensureMapCentered(updatedPoints[updatedPoints.length - 1]);
      }
      renderTrack(updatedPoints);
    };
  </script>
  <script src="https://map.qq.com/api/gljs?v=1.exp&callback=initMap&referer=flutter_app&key=$_tencentMapKey" async defer></script>
</head>
<body>
  <div id="map"></div>
</body>
</html>
''';

    _controller.loadHtmlString(html, baseUrl: _tencentMapBaseUrl);
    _hasLoadedContent = true;
    _pushLog('加载腾讯地图页面，点位数量：${samples.length}');
  }

  String _encodePoints(List<LocationSample> samples) {
    final converted = samples.map(_toTencentPoint).toList();
    return jsonEncode(converted);
  }

  Map<String, double> _toTencentPoint(LocationSample sample) {
    final projected = wgs84ToGcj02(sample.latitude, sample.longitude);
    if (!_loggedProjectionHint) {
      final latDelta = projected.latitude - sample.latitude;
      final lonDelta = projected.longitude - sample.longitude;
      if (latDelta.abs() > 1e-6 || lonDelta.abs() > 1e-6) {
        _loggedProjectionHint = true;
        _pushLog(
          '应用 GCJ-02 转换：Δlat=${latDelta.toStringAsFixed(6)}, Δlng=${lonDelta.toStringAsFixed(6)}',
        );
      }
    }
    return {'lat': projected.latitude, 'lng': projected.longitude};
  }

  void _scheduleMapUpdate() {
    if (!_hasLoadedContent) {
      return;
    }
    _pendingUpdate = true;
    _flushPendingUpdate();
  }

  void _flushPendingUpdate() {
    if (!_pendingUpdate || !_pageReady) {
      return;
    }
    final pointsJson = _latestPointsJson;
    if (pointsJson == null) {
      return;
    }
    _pendingUpdate = false;
    _controller.runJavaScript('window.updateTrack($pointsJson);').catchError((
      error,
    ) {
      _pushLog('更新轨迹失败: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.map_outlined, size: 64),
          SizedBox(height: 16),
          Text('还没有轨迹数据，等待自动采集或手动采集一次吧。'),
        ],
      ),
    );
  }
}
