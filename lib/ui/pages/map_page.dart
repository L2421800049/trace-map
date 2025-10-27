import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/models/map_provider.dart';
import '../../core/models/location_sample.dart';
import '../../core/models/map_log_entry.dart';
import '../../core/utils/formatting.dart';
import '../app_state_scope.dart';

const _tencentMapKey = '5KABZ-2CCKL-3OUPE-ELJNN-SUT4J-OZBRY';

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
          appBar: AppBar(
            title: const Text('轨迹地图'),
          ),
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
        .map(
          (sample) => LatLng(sample.latitude, sample.longitude),
        )
        .toList();

    final polyline = Polyline(
      points: points,
      color: Colors.lightBlueAccent,
      strokeWidth: 4,
    );

    return FlutterMap(
      options: MapOptions(
        initialCenter: points.last,
        initialZoom: 16,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.myapp',
        ),
        PolylineLayer(
          polylines: [polyline],
        ),
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
              child: const Icon(
                Icons.place,
                color: Colors.redAccent,
                size: 34,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TencentMapView extends StatefulWidget {
  const _TencentMapView({
    required this.samples,
    required this.onLogEntry,
  });

  final List<LocationSample> samples;
  final ValueChanged<MapLogEntry> onLogEntry;

  @override
  State<_TencentMapView> createState() => _TencentMapViewState();
}

class _TencentMapViewState extends State<_TencentMapView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'LogChannel',
        onMessageReceived: (message) {
          _pushLog('[JS] ${message.message}');
        },
      );
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant _TencentMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.samples, widget.samples)) {
      _pushLog('样本更新：${widget.samples.length} 个点');
      _loadContent();
    }
  }

  void _pushLog(String message) {
    final entry = MapLogEntry(
      timestamp: DateTime.now(),
      message: message,
    );
    widget.onLogEntry(entry);
  }

  void _loadContent() {
    final points = widget.samples
        .map((sample) => {
              'lat': sample.latitude,
              'lng': sample.longitude,
            })
        .toList();
    if (points.isEmpty) {
      _pushLog('没有采集点，跳过地图绘制');
      return;
    }
    final pointsJson = jsonEncode(points);
    final html = '''
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
    const points = $pointsJson;
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
    window.initMap = function() {
      log('initMap 调用，点位数量: ' + points.length);
      if (!points || points.length === 0) {
        log('没有点位，结束绘制');
        return;
      }
      const center = points[points.length - 1];
      const map = new TMap.Map('map', {
        center: new TMap.LatLng(center.lat, center.lng),
        zoom: 16,
      });

      const latLngs = points.map(p => new TMap.LatLng(p.lat, p.lng));
      log('生成 LatLng 数组: ' + latLngs.length);

      if (latLngs.length > 1) {
        new TMap.MultiPolyline({
          id: 'track',
          map,
          geometries: [{
            paths: latLngs,
            styleId: 'track_style',
          }],
          styles: {
            track_style: new TMap.PolylineStyle({
              color: '#64B5F6',
              width: 6,
            }),
          },
        });
        log('轨迹折线已绘制');
      } else {
        log('只有一个点，跳过折线');
      }

      new TMap.MultiMarker({
        id: 'markers',
        map,
        styles: {
          start: new TMap.MarkerStyle({ width: 30, height: 42, src: 'https://mapapi.qq.com/web/miniprogram/demoCenter/images/marker-start.png' }),
          end: new TMap.MarkerStyle({ width: 30, height: 42, src: 'https://mapapi.qq.com/web/miniprogram/demoCenter/images/marker-end.png' }),
        },
        geometries: [
          { id: 'start', position: latLngs[0], styleId: 'start' },
          { id: 'end', position: latLngs[latLngs.length - 1], styleId: 'end' },
        ],
      });
      log('起点终点标记已绘制');
    };
  </script>
  <script src="https://map.qq.com/api/gljs?v=1.exp&callback=initMap&key=$_tencentMapKey" async defer></script>
</head>
<body>
  <div id="map"></div>
</body>
</html>
''';

    _controller.loadHtmlString(html);
    _pushLog('加载腾讯地图页面，点位数量：${points.length}');
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
