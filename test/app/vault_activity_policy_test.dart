import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/vault_activity_policy.dart';

void main() {
  final now = DateTime.utc(2026, 11, 5);
  test(
    'async unlock keeps a real background cover and rejects expired opens',
    () {
      final policy = VaultActivityPolicy();
      final epoch = policy.lockEpoch;
      policy.handle(AppLifecycleState.inactive, now);
      expect(policy.active, isFalse);
      expect(
        policy.canCompleteUnlock(epoch, now.add(const Duration(minutes: 2))),
        isTrue,
      );
      expect(policy.covered, isTrue);
      expect(
        policy.canCompleteUnlock(epoch, now.add(const Duration(minutes: 5))),
        isFalse,
      );
      policy.handle(
        AppLifecycleState.resumed,
        now.add(const Duration(minutes: 6)),
      );
      expect(
        policy.canCompleteUnlock(epoch, now.add(const Duration(minutes: 6))),
        isFalse,
      );
    },
  );
  test('a brief permission dialog covers the app without relocking it', () {
    final policy = VaultActivityPolicy();
    expect(policy.handle(AppLifecycleState.inactive, now), isFalse);
    expect(policy.covered, isTrue);
    expect(
      policy.handle(
        AppLifecycleState.resumed,
        now.add(const Duration(seconds: 20)),
      ),
      isFalse,
    );
    expect(policy.covered, isFalse);
  });
  test('the earliest background event starts the five minute timeout', () {
    final policy = VaultActivityPolicy();
    policy.handle(AppLifecycleState.inactive, now);
    policy.handle(
      AppLifecycleState.hidden,
      now.add(const Duration(minutes: 4)),
    );
    expect(
      policy.handle(
        AppLifecycleState.resumed,
        now.add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
    expect(policy.covered, isFalse);
  });
}
