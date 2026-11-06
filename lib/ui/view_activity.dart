import 'package:flutter/widgets.dart';

/// A view's foreground generation, used before queued ownership writes begin.
class ViewActivity extends ChangeNotifier with WidgetsBindingObserver {
  ViewActivity() {
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }
  bool _active = true;
  bool _alive = true;
  int _epoch = 0;
  bool get active => _alive && _active;
  int get epoch => _epoch;
  bool accepts(int captured) => active && captured == _epoch;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _active) return;
    _active = active;
    _epoch++;
    notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
