import 'package:flutter/material.dart';

import '../core/app_state.dart';
import 'app_state_scope.dart';
import 'pages/device_info_page.dart';
import 'pages/map_page.dart';
import 'pages/settings_page.dart';

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
