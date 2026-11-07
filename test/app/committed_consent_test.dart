import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/learning/device_signals.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';

class _Repository implements AppRepository, ResidualDataRepository {
  _Repository(this.value);
  AppData value;
  bool failPrimary = false;
  bool failCleanup = false;
  int purges = 0;
  final purgeEntered = Completer<void>();
  final releasePurge = Completer<void>();

  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    if (failPrimary) throw StateError('Fictional primary failure');
    value = next;
  }

  @override
  Future<void> purgeResidualData() async {
    purges++;
    purgeEntered.complete();
    await releasePurge.future;
    if (failCleanup) throw StateError('Fictional cleanup failure');
  }
}

class _Signals extends DeviceSignals {
  bool active = false;
  int stops = 0;
  @override
  Future<SignalCapabilities> capabilities() async => const SignalCapabilities(
    usageSupported: true,
    usageGranted: true,
    motionSupported: true,
    motionGranted: true,
  );
  @override
  Future<void> start({required bool usage, required bool motion}) async =>
      active = usage || motion;
  @override
  Future<void> stop() async {
    stops++;
    active = false;
  }

  @override
  Future<DeviceSignalReading> read() async => active
      ? const DeviceSignalReading(deviceSwitches: 7, walkingMinutes: 2)
      : const DeviceSignalReading();
}

void main() {
  late _Repository repository;
  late AppController controller;
  late _Signals signals;
  late LearningSession session;

  setUp(() async {
    repository = _Repository(
      AppData(
        learning: LearningData(
          enabledSources: {
            SignalSource.inApp,
            SignalSource.deviceUsage,
            SignalSource.motion,
          },
          deviceOwnerConfirmed: true,
        ),
      ),
    );
    controller = AppController(repository, repository.value);
    signals = _Signals();
    session = LearningSession(controller, signals: signals);
    await session.initialize();
    session.recordTap();
    expect(signals.active, isTrue);
    expect(session.reading.deviceSwitches, 7);
    expect(session.snapshot.features['tapCount'], 1);
  });
  tearDown(() async {
    if (!repository.releasePurge.isCompleted) {
      repository.releasePurge.complete();
    }
    await controller.flush();
    await session.close();
    controller.dispose();
  });

  for (final cleanupFails in [false, true]) {
    test(
      'import stops old sources before ${cleanupFails ? 'failed' : 'slow'} cleanup finishes',
      () async {
        repository.failCleanup = cleanupFails;
        final warnings = <String?>[];
        controller.addListener(() => warnings.add(controller.cleanupWarning));
        final before = signals.stops;
        final importing = controller.replaceData(AppData.empty());
        await repository.purgeEntered.future;
        try {
          // Immediate fake source futures drain before this event-loop turn.
          // Cleanup stays blocked, so it cannot be the reason collection stops.
          await Future<void>.delayed(Duration.zero);
          expect(repository.value.learning.enabledSources, isEmpty);
          expect(controller.replacementRevision, 1);
          expect(
            signals.active,
            isFalse,
            reason: 'Committed consent loss must not wait for residual I/O.',
          );
          expect(signals.stops, greaterThan(before));
          expect(session.reading.deviceSwitches, isNull);
          expect(session.snapshot.features, isEmpty);
          expect(warnings, [null]);
        } finally {
          repository.releasePurge.complete();
          await importing;
        }
        expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
        expect(repository.purges, 1);
        if (cleanupFails) {
          expect(controller.cleanupWarning, contains('Older local copies'));
          expect(warnings, [null, controller.cleanupWarning]);
        } else {
          expect(controller.cleanupWarning, isNull);
          expect(warnings, [null]);
        }
      },
    );
  }

  test(
    'failed primary import publishes no consent change or cleanup',
    () async {
      final original = controller.data;
      final stops = signals.stops;
      var notifications = 0;
      controller.addListener(() => notifications++);
      repository.failPrimary = true;
      await expectLater(
        controller.replaceData(AppData.empty()),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(identical(controller.data, original), isTrue);
      expect(identical(repository.value, original), isTrue);
      expect(repository.purges, 0);
      expect(notifications, 0);
      expect(signals.active, isTrue);
      expect(signals.stops, stops);
      expect(session.reading.deviceSwitches, 7);
      expect(controller.cleanupWarning, isNull);
    },
  );
}
