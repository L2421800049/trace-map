import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _tencentMapKey = '5KABZ-2CCKL-3OUPE-ELJNN-SUT4J-OZBRY';

enum MapProvider {
  defaultMap,
  tencent,
}

String _mapProviderToStorage(MapProvider provider) => provider.name;

MapProvider _mapProviderFromStorage(String? value) {
  if (value == 'tencent') {
    return MapProvider.tencent;
  }
  return MapProvider.defaultMap;
}

String _mapProviderDisplayName(MapProvider provider) {
  switch (provider) {
    case MapProvider.tencent:
      return '腾讯地图';
    case MapProvider.defaultMap:
      return '默认地图';
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = await AppState.initialize();
  runApp(DeviceInsightApp(appState: appState));
}

class DeviceInsightApp extends StatefulWidget {
  const DeviceInsightApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<DeviceInsightApp> createState() => _DeviceInsightAppState();
}

class _DeviceInsightAppState extends State<DeviceInsightApp> {
  @override
  void dispose() {
    widget.appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: widget.appState,
      child: MaterialApp(
        title: '设备轨迹采集',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DeviceInfoPage(),
    MapPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            label: '设备',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: '轨迹',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

class DeviceInfoPage extends StatelessWidget {
  const DeviceInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, appState) {
        final snapshot = appState.latestSnapshot;
        final isLoading = appState.isCollecting && snapshot == null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('设备信息与采集状态'),
            actions: [
              IconButton(
                tooltip: '立即采集',
                onPressed: appState.isCollecting
                    ? null
                    : () {
                        appState.collectNow();
                      },
                icon: appState.isCollecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          body: isLoading
              ? const _CenteredProgress()
              : snapshot == null
                  ? _EmptyState(
                      onRetry: appState.collectNow,
                      interval: appState.samplingIntervalSeconds,
                    )
                  : RefreshIndicator(
                      onRefresh: appState.collectNow,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        children: [
                          _buildStatusCard(appState),
                          const SizedBox(height: 24),
                          _buildDeviceCard(snapshot),
                          const SizedBox(height: 24),
                          _buildLocationCard(snapshot),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildStatusCard(AppStateBase appState) {
    final snapshot = appState.latestSnapshot;
    final locationInfo = snapshot?.position != null
        ? '纬度: ${snapshot!.position!.latitude.toStringAsFixed(6)}\n'
            '经度: ${snapshot.position!.longitude.toStringAsFixed(6)}'
        : snapshot?.locationError ?? '暂无定位数据';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '采集状态',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade200,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: '采集周期',
              value: '${appState.samplingIntervalSeconds} 秒',
            ),
            _InfoRow(
              label: '保存时长',
              value: '${appState.retentionDays} 天',
            ),
            _InfoRow(
              label: '当前记录数',
              value: '${appState.samples.length}',
            ),
            if (snapshot != null)
              _InfoRow(
                label: '最新采集时间',
                value: _formatTimestamp(snapshot.retrievedAt),
              ),
            const SizedBox(height: 12),
            SelectableText(
              locationInfo,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(DeviceSnapshot snapshot) {
    final deviceLines = snapshot.deviceDetails.entries
        .map((entry) => '• ${entry.key}: ${entry.value}')
        .join('\n');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设备信息',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade200,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              deviceLines,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(DeviceSnapshot snapshot) {
    final position = snapshot.position;
    final titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.green.shade200,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('位置信息', style: titleStyle),
            const SizedBox(height: 12),
            if (position != null) ...[
              SelectableText(_formatPosition(position)),
              const SizedBox(height: 8),
              SelectableText('定位时间: ${_formatTimestamp(snapshot.retrievedAt)}'),
            ] else
              SelectableText(snapshot.locationError ?? '暂无位置信息'),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry, required this.interval});

  final Future<void> Function() onRetry;
  final int interval;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_searching, size: 64),
            const SizedBox(height: 16),
            Text(
              '尚未采集到数据，将在 $interval 秒后自动尝试。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('立即尝试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});

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
                          ? _TencentMapView(samples: samples)
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
                            '${_formatTimestamp(samples.first.timestamp)}'
                            ' - ${_formatTimestamp(samples.last.timestamp)}',
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
  const _TencentMapView({required this.samples});

  final List<LocationSample> samples;

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
      ..setBackgroundColor(Colors.transparent);
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant _TencentMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.samples, widget.samples)) {
      _loadContent();
    }
  }

  void _loadContent() {
    final points = widget.samples
        .map((sample) => {
              'lat': sample.latitude,
              'lng': sample.longitude,
            })
        .toList();
    if (points.isEmpty) {
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
    function initMap() {
      if (!points || points.length === 0) {
        return;
      }
      const center = points[points.length - 1];
      const map = new TMap.Map('map', {
        center: new TMap.LatLng(center.lat, center.lng),
        zoom: 16,
      });

      const latLngs = points.map(p => new TMap.LatLng(p.lat, p.lng));

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
    }
  </script>
  <script src="https://map.qq.com/api/gljs?v=1.exp&callback=initMap&key=$_tencentMapKey" async defer></script>
</head>
<body>
  <div id="map"></div>
</body>
</html>
''';

    _controller.loadHtmlString(html);
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
        children: [
          const Icon(Icons.map_outlined, size: 64),
          const SizedBox(height: 16),
          const Text('还没有轨迹数据，等待自动采集或手动采集一次吧。'),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _intervalController;
  late final TextEditingController _retentionController;
  bool _saving = false;
  bool _clearing = false;
  MapProvider? _selectedMapProvider;

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController();
    _retentionController = TextEditingController();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _retentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    _intervalController.text =
        _intervalController.text.isEmpty ? '${appState.samplingIntervalSeconds}' : _intervalController.text;
    _retentionController.text =
        _retentionController.text.isEmpty ? '${appState.retentionDays}' : _retentionController.text;
    _selectedMapProvider ??= appState.mapProvider;

    return Scaffold(
      appBar: AppBar(
        title: const Text('配置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _intervalController,
              decoration: const InputDecoration(
                labelText: '采集间隔（秒）',
                helperText: '允许范围：${SamplingSettings.minInterval} - ${SamplingSettings.maxInterval}',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _retentionController,
              decoration: const InputDecoration(
                labelText: '数据保留天数',
                helperText: '允许范围：${SamplingSettings.minRetentionDays} - ${SamplingSettings.maxRetentionDays}',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MapProvider>(
              initialValue: _selectedMapProvider,
              decoration: const InputDecoration(
                labelText: '地图提供商',
              ),
              items: MapProvider.values
                  .map(
                    (provider) => DropdownMenuItem(
                      value: provider,
                      child: Text(_mapProviderDisplayName(provider)),
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
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings(AppStateBase appState) async {
    final interval = int.tryParse(_intervalController.text.trim());
    final retention = int.tryParse(_retentionController.text.trim());

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
    }

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final intervalValue = interval!;
      final retentionValue = retention!;
      final providerValue = _selectedMapProvider ?? appState.mapProvider;

      await appState.updateSamplingInterval(intervalValue);
      await appState.updateRetentionDays(retentionValue);
      await appState.updateMapProvider(providerValue);
      if (mounted) {
        _intervalController.text = '$intervalValue';
        _retentionController.text = '$retentionValue';
        _selectedMapProvider = providerValue;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmAndClear(AppStateBase appState) async {
    final shouldClear = await showDialog<bool>(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('历史轨迹已清空')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class AppStateBuilder extends StatelessWidget {
  const AppStateBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, AppStateBase state) builder;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => builder(context, state),
    );
  }
}

class AppStateScope extends InheritedNotifier<AppStateBase> {
  const AppStateScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppStateBase of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in context');
    return scope!.notifier!;
  }
}

abstract class AppStateBase extends ChangeNotifier {
  DeviceSnapshot? get latestSnapshot;
  UnmodifiableListView<LocationSample> get samples;
  bool get isCollecting;
  int get samplingIntervalSeconds;
  int get retentionDays;
  MapProvider get mapProvider;

  Future<void> collectNow();
  Future<void> updateSamplingInterval(int seconds);
  Future<void> updateRetentionDays(int days);
  Future<void> clearHistory();
  Future<void> updateMapProvider(MapProvider provider);
}

class AppState extends AppStateBase {
  AppState._({
    required SettingsStore settingsStore,
    required TrackRepository trackRepository,
    required DeviceInfoRepository deviceRepository,
    required int samplingIntervalSeconds,
    required int retentionDays,
    required MapProvider mapProvider,
  })  : _settingsStore = settingsStore,
        _trackRepository = trackRepository,
        _deviceRepository = deviceRepository,
        _samplingIntervalSeconds = samplingIntervalSeconds,
        _retentionDays = retentionDays,
        _mapProvider = mapProvider;

  final SettingsStore _settingsStore;
  final TrackRepository _trackRepository;
  final DeviceInfoRepository _deviceRepository;

  Timer? _timer;
  bool _collecting = false;
  DeviceSnapshot? _latestSnapshot;
  List<LocationSample> _samples = const [];

  int _samplingIntervalSeconds;
  int _retentionDays;
  MapProvider _mapProvider;

  static Future<AppState> initialize() async {
    final settingsStore = await SharedPrefsSettingsStore.create();
    final trackRepository = await TrackRepository.open();
    final deviceRepository = PluginDeviceInfoRepository();

    final samplingInterval =
        await settingsStore.readInterval() ?? SamplingSettings.defaultInterval;
    final retentionDays = await settingsStore.readRetentionDays() ??
        SamplingSettings.defaultRetentionDays;
    final mapProvider =
        _mapProviderFromStorage(await settingsStore.readMapProvider());

    final state = AppState._(
      settingsStore: settingsStore,
      trackRepository: trackRepository,
      deviceRepository: deviceRepository,
      samplingIntervalSeconds: samplingInterval,
      retentionDays: retentionDays,
      mapProvider: mapProvider,
    );
    await state._loadInitialData();
    return state;
  }

  Future<void> _loadInitialData() async {
    await _enforceRetention();
    _samples = await _trackRepository.fetchSamples();
    if (_samples.isNotEmpty) {
      final deviceDetails = await _deviceRepository.deviceDetails();
      final last = _samples.last;
      _latestSnapshot = DeviceSnapshot(
        deviceDetails: deviceDetails,
        position: last.toPosition(),
        locationError: null,
        retrievedAt: last.timestamp,
      );
    }
    await collectNow();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _samplingIntervalSeconds),
      (_) => collectNow(),
    );
  }

  Future<void> _performCollection() async {
    final snapshot = await _deviceRepository.collectSnapshot();
    _latestSnapshot = snapshot;
    if (snapshot.position != null) {
      final sample = LocationSample.fromPosition(
        snapshot.position!,
        timestamp: snapshot.retrievedAt,
      );
      await _trackRepository.insertSample(sample);
    }
    await _enforceRetention();
    _samples = await _trackRepository.fetchSamples();
  }

  Future<void> _enforceRetention() async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: _retentionDays));
    await _trackRepository.deleteOlderThan(cutoff);
  }

  @override
  Future<void> collectNow() async {
    if (_collecting) {
      return;
    }
    _collecting = true;
    notifyListeners();
    try {
      await _performCollection();
    } finally {
      _collecting = false;
      notifyListeners();
    }
  }

  @override
  Future<void> updateSamplingInterval(int seconds) async {
    if (seconds == _samplingIntervalSeconds) {
      return;
    }
    _samplingIntervalSeconds = seconds;
    await _settingsStore.writeInterval(seconds);
    _startTimer();
    notifyListeners();
  }

  @override
  Future<void> updateRetentionDays(int days) async {
    if (days == _retentionDays) {
      return;
    }
    _retentionDays = days;
    await _settingsStore.writeRetentionDays(days);
    await _enforceRetention();
    _samples = await _trackRepository.fetchSamples();
    notifyListeners();
  }

  @override
  Future<void> clearHistory() async {
    await _trackRepository.deleteAll();
    _samples = const [];
    notifyListeners();
  }

  @override
  DeviceSnapshot? get latestSnapshot => _latestSnapshot;

  @override
  UnmodifiableListView<LocationSample> get samples =>
      UnmodifiableListView(_samples);

  @override
  bool get isCollecting => _collecting;

  @override
  int get samplingIntervalSeconds => _samplingIntervalSeconds;

  @override
  int get retentionDays => _retentionDays;

  @override
  MapProvider get mapProvider => _mapProvider;

  @override
  Future<void> updateMapProvider(MapProvider provider) async {
    if (provider == _mapProvider) {
      return;
    }
    _mapProvider = provider;
    await _settingsStore.writeMapProvider(provider);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_trackRepository.close());
    super.dispose();
  }
}

class SamplingSettings {
  static const defaultInterval = 30;
  static const defaultRetentionDays = 7;
  static const minInterval = 10;
  static const maxInterval = 3600;
  static const minRetentionDays = 1;
  static const maxRetentionDays = 30;
}

abstract class SettingsStore {
  Future<int?> readInterval();
  Future<void> writeInterval(int seconds);
  Future<int?> readRetentionDays();
  Future<void> writeRetentionDays(int days);
  Future<String?> readMapProvider();
  Future<void> writeMapProvider(MapProvider provider);
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
      _prefs.setString(_mapProviderKey, _mapProviderToStorage(provider));
}

class TrackRepository {
  TrackRepository._(this._db);

  final Database _db;

  static Future<TrackRepository> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(directory.path, 'device_track.sqlite');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE samples(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            altitude REAL,
            altitude_accuracy REAL,
            speed REAL,
            speed_accuracy REAL,
            heading REAL,
            heading_accuracy REAL,
            is_mocked INTEGER NOT NULL,
            floor INTEGER
          )
        ''');
      },
    );
    return TrackRepository._(db);
  }

  Future<void> insertSample(LocationSample sample) async {
    await _db.insert(
      'samples',
      sample.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<LocationSample>> fetchSamples() async {
    final rows = await _db.query(
      'samples',
      orderBy: 'timestamp ASC',
    );
    return rows.map(LocationSample.fromMap).toList();
  }

  Future<void> deleteOlderThan(DateTime cutoff) async {
    await _db.delete(
      'samples',
      where: 'timestamp < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete('samples');
  }

  Future<void> close() => _db.close();
}

class LocationSample {
  LocationSample({
    this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.altitudeAccuracy,
    required this.speed,
    required this.speedAccuracy,
    required this.heading,
    required this.headingAccuracy,
    required this.isMocked,
    this.floor,
  });

  factory LocationSample.fromPosition(
    Position position, {
    required DateTime timestamp,
  }) {
    return LocationSample(
      timestamp: timestamp,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      isMocked: position.isMocked,
      floor: position.floor,
    );
  }

  factory LocationSample.fromMap(Map<String, Object?> map) {
    return LocationSample(
      id: map['id'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
      ),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0,
      altitudeAccuracy:
          (map['altitude_accuracy'] as num?)?.toDouble() ?? 0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0,
      speedAccuracy: (map['speed_accuracy'] as num?)?.toDouble() ?? 0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0,
      headingAccuracy:
          (map['heading_accuracy'] as num?)?.toDouble() ?? 0,
      isMocked: (map['is_mocked'] as int? ?? 0) == 1,
      floor: map['floor'] as int?,
    );
  }

  final int? id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double altitudeAccuracy;
  final double speed;
  final double speedAccuracy;
  final double heading;
  final double headingAccuracy;
  final bool isMocked;
  final int? floor;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'altitude_accuracy': altitudeAccuracy,
      'speed': speed,
      'speed_accuracy': speedAccuracy,
      'heading': heading,
      'heading_accuracy': headingAccuracy,
      'is_mocked': isMocked ? 1 : 0,
      'floor': floor,
    };
  }

  Position toPosition() {
    return Position(
      longitude: longitude,
      latitude: latitude,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: altitude,
      altitudeAccuracy: altitudeAccuracy,
      heading: heading,
      headingAccuracy: headingAccuracy,
      speed: speed,
      speedAccuracy: speedAccuracy,
      floor: floor,
      isMocked: isMocked,
    );
  }
}

abstract class DeviceInfoRepository {
  Future<DeviceSnapshot> collectSnapshot();
  Future<Map<String, String>> deviceDetails();
}

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.deviceDetails,
    required this.retrievedAt,
    this.position,
    this.locationError,
  });

  final Map<String, String> deviceDetails;
  final DateTime retrievedAt;
  final Position? position;
  final String? locationError;
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
  Future<Map<String, String>> deviceDetails() => _collectDeviceDetails();

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

String _formatTimestamp(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final date =
      '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  final time =
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
  return '$date $time';
}

String _formatPosition(Position position) {
  final buffer = StringBuffer()
    ..writeln('纬度: ${position.latitude.toStringAsFixed(6)}')
    ..writeln('经度: ${position.longitude.toStringAsFixed(6)}')
    ..writeln('精度: ±${position.accuracy.toStringAsFixed(1)} 米');
  if (position.altitude != 0) {
    buffer.writeln('海拔: ${position.altitude.toStringAsFixed(1)} 米');
  }
  if (position.speed != 0) {
    buffer.writeln('速度: ${position.speed.toStringAsFixed(2)} m/s');
  }
  return buffer.toString().trim();
}
