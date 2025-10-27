import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = await AppState.initialize();
  runApp(DeviceInsightApp(appState: appState));
}
