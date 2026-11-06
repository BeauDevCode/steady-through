import 'package:flutter/widgets.dart';

/// Invalidates pending UI actions across foreground transitions and disposal.
class FeedbackActivity extends ChangeNotifier with WidgetsBindingObserver {
  FeedbackActivity() {
    active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }
  bool active = true;
  bool _alive = true;
  int epoch = 0;
  bool accepts(int captured) => _alive && active && captured == epoch;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = state == AppLifecycleState.resumed;
    if (next == active) return;
    active = next;
    epoch++;
    notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    epoch++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
