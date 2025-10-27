import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models/device_snapshot.dart';
import '../../core/utils/formatting.dart';
import '../app_state_scope.dart';

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
                value: formatTimestamp(snapshot.retrievedAt),
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
              SelectableText(formatPosition(position)),
              const SizedBox(height: 8),
              SelectableText('定位时间: ${formatTimestamp(snapshot.retrievedAt)}'),
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

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
