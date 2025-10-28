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
            actions: [
              if (logs.isNotEmpty)
                IconButton(
                  tooltip: '清空日志',
                  onPressed: () async {
                    final shouldClear =
                        await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('清空地图日志'),
                              content: const Text('确定要删除所有地图日志记录吗？此操作不可恢复。'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('取消'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('清空'),
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;
                    if (shouldClear) {
                      await state.clearMapLogs();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('地图日志已清空')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
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
      child: Text('暂无地图日志记录', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
