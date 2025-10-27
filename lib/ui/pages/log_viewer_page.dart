import 'package:flutter/material.dart';

import '../../core/models/map_log_entry.dart';
import '../../core/utils/formatting.dart';
import '../app_state_scope.dart';

class LogViewerPage extends StatelessWidget {
  const LogViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, state) {
        final logs = state.mapLogs;
        return Scaffold(
          appBar: AppBar(
            title: const Text('地图日志'),
          ),
          body: logs.isEmpty
              ? const _EmptyLogs()
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final MapLogEntry entry = logs[index];
                    return ListTile(
                      leading: const Icon(Icons.bubble_chart_outlined),
                      title: Text(formatTimestamp(entry.timestamp)),
                      subtitle: Text(entry.message),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '暂无地图日志记录',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
