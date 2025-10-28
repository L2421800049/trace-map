import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/track_record.dart';
import '../../core/utils/formatting.dart';
import '../app_state_scope.dart';
import '../widgets/app_logo_avatar.dart';

class TrackRecordsPage extends StatelessWidget {
  const TrackRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, state) {
        final records = state.trackRecords;
        return Scaffold(
          appBar: AppBar(
            leading: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: AppLogoAvatar(size: 32),
            ),
            title: const Text('轨迹记录'),
          ),
          body: records.isEmpty
              ? const _EmptyRecords()
              : RefreshIndicator(
                  onRefresh: state.refreshTrackRecords,
                  child: ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return ListTile(
                        leading: const Icon(Icons.route_outlined),
                        title: Text(record.title),
                        subtitle: Text(
                          '${formatTimestamp(record.startTime)} - ${formatTimestamp(record.endTime)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TrackReplayPage(record: record),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('暂无保存的轨迹记录', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class TrackReplayPage extends StatelessWidget {
  const TrackReplayPage({super.key, required this.record});

  final TrackRecord record;

  @override
  Widget build(BuildContext context) {
    final samples = record.samples;
    if (samples.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(record.title)),
        body: const _EmptyReplay(),
      );
    }

    final points = samples
        .map((sample) => LatLng(sample.latitude, sample.longitude))
        .toList();

    final polyline = Polyline(
      points: points,
      color: Colors.orangeAccent,
      strokeWidth: 4,
    );

    return Scaffold(
      appBar: AppBar(title: Text(record.title)),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
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
                      child: const Icon(
                        Icons.place,
                        color: Colors.redAccent,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${record.startName} → ${record.endName}'),
                const SizedBox(height: 6),
                Text(
                  '${formatTimestamp(record.startTime)} - ${formatTimestamp(record.endTime)}',
                ),
                const SizedBox(height: 6),
                Text('点位数量：${samples.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReplay extends StatelessWidget {
  const _EmptyReplay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.info_outline, size: 48),
          SizedBox(height: 12),
          Text('该轨迹记录没有点位数据'),
        ],
      ),
    );
  }
}
