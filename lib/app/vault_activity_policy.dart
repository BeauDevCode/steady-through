import 'package:flutter/widgets.dart';

class VaultActivityPolicy {
  DateTime? _leftAt;
  bool covered = false;
  bool active = true;
  int lockEpoch = 0;
  bool canCompleteUnlock(int startedEpoch, DateTime now) =>
      startedEpoch == lockEpoch &&
      (_leftAt == null ||
          now.difference(_leftAt!) < const Duration(minutes: 5));
  bool handle(AppLifecycleState state, DateTime now) {
    if (state == AppLifecycleState.resumed) {
      final lock =
          _leftAt != null &&
          now.difference(_leftAt!) >= const Duration(minutes: 5);
      _leftAt = null;
      covered = false;
      active = true;
      if (lock) lockEpoch++;
      return lock;
    }
    _leftAt ??= now;
    covered = true;
    active = false;
    return false;
  }
}
