import 'package:flutter/widgets.dart';

import '../core/app_state.dart';

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
