import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/learning/device_signals.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';

class _Barrier {
  final entered = Completer<void>();
  final released = Completer<void>();
  void release() {
    if (!released.isCompleted) released.complete();
  }
}

class _Repository implements AppRepository {
  _Repository(this.value);
  AppData value;
  bool failSave = false;
  _Barrier? nextSave;
  final committed = <AppData>[];

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    final barrier = nextSave;
    nextSave = null;
    if (barrier != null) {
      barrier.entered.complete();
      await barrier.released.future;
    }
    if (failSave) throw StateError('Fictional storage failure');
    value = next;
    committed.add(next);
  }
}

class _Signals extends DeviceSignals {
  _Barrier? nextRead;
  @override
  Future<SignalCapabilities> capabilities() async =>
      const SignalCapabilities(motionSupported: true, motionGranted: true);
  @override
  Future<void> start({required bool usage, required bool motion}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<DeviceSignalReading> read() async {
    final barrier = nextRead;
    nextRead = null;
    if (barrier != null) {
      barrier.entered.complete();
      await barrier.released.future;
    }
    return const DeviceSignalReading(
      walkingMinutes: 2,
      vehicleMinutes: 0,
      motionStatus: 'session-only',
    );
  }
}

AppData _initial() {
  final at = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return AppData(
    learning: LearningData(
      enabledSources: {SignalSource.checkIns},
      examples: [
        LearningExample(
          id: 'older',
          createdAt: at,
          label: FeelingLabel.tense,
          snapshot: SignalSnapshot(observedAt: at),
        ),
      ],
      calibration: CalibrationState(
        startedAt: at.subtract(const Duration(days: 60)),
        lastReviewedAt: at,
        lastReviewReason: 'Fictional earlier review',
      ),
    ),
  );
}

void main() {
  late _Repository repository;
  late AppController controller;
  late _Signals signals;
  late LearningSession session;

  setUp(() {
    repository = _Repository(_initial());
    controller = AppController(repository, repository.value);
    signals = _Signals();
    session = LearningSession(controller, signals: signals);
  });
  tearDown(() async {
    await session.close();
    controller.dispose();
  });

  for (final control in ['pause', 'sources']) {
    test('queued $control preserves a feeling committed ahead of it', () async {
      final barrier = _Barrier();
      repository.nextSave = barrier;
      final saving = session.saveFeeling(FeelingLabel.calm);
      await barrier.entered.future;
      final changing = control == 'pause'
          ? session.pause()
          : session.setSources({SignalSource.checkIns, SignalSource.inApp});
      try {
        // Both intents exist before the storage boundary is released.
      } finally {
        barrier.release();
      }
      await saving;
      await changing;
      expect(controller.data.learning.examples.map((e) => e.label), [
        FeelingLabel.tense,
        FeelingLabel.calm,
      ]);
      expect(repository.value.learning.examples, hasLength(2));
      expect(controller.data.learning.pausedByUser, control == 'pause');
      if (control == 'sources') {
        expect(controller.data.learning.enabledSources, {
          SignalSource.checkIns,
          SignalSource.inApp,
        });
      }
    });
  }

  test(
    'a source choice queued after clear cannot restore evidence or review',
    () async {
      final barrier = _Barrier();
      repository.nextSave = barrier;
      final clearing = session.clear();
      await barrier.entered.future;
      final changing = session.setSources({SignalSource.inApp});
      try {
        // Preserve the caller's new choice, never its pre-clear history.
      } finally {
        barrier.release();
      }
      await clearing;
      await changing;
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.learning.calibration.model, isNull);
      expect(controller.data.learning.calibration.startedAt, isNull);
      expect(controller.data.learning.calibration.lastReviewedAt, isNull);
      expect(controller.data.learning.calibration.lastReviewReason, isEmpty);
      expect(controller.data.learning.enabledSources, {SignalSource.inApp});
      expect(repository.value.learning.examples, isEmpty);
    },
  );

  for (final replacement in ['import', 'clear all']) {
    for (final intent in ['pause', 'sources', 'feeling']) {
      test(
        'queued $intent rejects the document replaced by $replacement',
        () async {
          final barrier = _Barrier();
          repository.nextSave = barrier;
          final replacing = replacement == 'import'
              ? controller.replaceData(
                  AppData(
                    learning: LearningData(
                      enabledSources: {SignalSource.checkIns},
                    ),
                  ),
                )
              : controller.clearAll();
          await barrier.entered.future;
          final Future<void> pending;
          if (intent == 'pause') {
            pending = session.pause();
          } else if (intent == 'sources') {
            pending = session.setSources({SignalSource.inApp});
          } else {
            pending = session.saveFeeling(FeelingLabel.calm);
          }
          final rejected = expectLater(pending, throwsStateError);
          try {
            // Rejection belongs to the queued ownership check.
          } finally {
            barrier.release();
          }
          await replacing;
          await rejected;
          expect(controller.data.learning.examples, isEmpty);
          expect(
            controller.data.learning.enabledSources,
            replacement == 'import' ? {SignalSource.checkIns} : isEmpty,
          );
          expect(controller.data.learning.pausedByUser, isFalse);
          expect(repository.value.learning.examples, isEmpty);
        },
      );
    }
  }

  test(
    'two queued source choices both apply in their original order',
    () async {
      final barrier = _Barrier();
      repository.nextSave = barrier;
      final first = session.setSources({SignalSource.inApp});
      await barrier.entered.future;
      final second = session.setSources({SignalSource.checkIns});
      try {
        // An ordinary source transition must not invalidate a later control.
      } finally {
        barrier.release();
      }
      await first;
      await second;
      expect(repository.committed.map((d) => d.learning.enabledSources), [
        {SignalSource.inApp},
        {SignalSource.checkIns},
      ]);
      expect(controller.data.learning.examples.single.id, 'older');
    },
  );

  test('mutating a caller source set cannot rewrite a queued choice', () async {
    final barrier = _Barrier();
    repository.nextSave = barrier;
    final blocking = controller.setTheme(ThemeChoice.dark);
    await barrier.entered.future;
    final sources = {SignalSource.inApp};
    final changing = session.setSources(sources);
    sources
      ..clear()
      ..add(SignalSource.checkIns);
    try {
      // Expected source is a literal, independent of the mutated input set.
    } finally {
      barrier.release();
    }
    await blocking;
    await changing;
    expect(controller.data.learning.enabledSources, {SignalSource.inApp});
  });

  test('closing a session rejects its queued source change', () async {
    final barrier = _Barrier();
    repository.nextSave = barrier;
    final blocking = controller.setTheme(ThemeChoice.dark);
    await barrier.entered.future;
    final changing = session.setSources({SignalSource.inApp});
    final rejected = expectLater(changing, throwsStateError);
    try {
      await session.close();
    } finally {
      barrier.release();
    }
    await blocking;
    await rejected;
    expect(controller.data.learning.enabledSources, {SignalSource.checkIns});
  });

  for (final boundary in ['clear and re-enable', 'suspend and activate']) {
    test('motion save cannot cross $boundary while a reading is pending', () async {
      await session.setSources({
        SignalSource.checkIns,
        SignalSource.motion,
      }, deviceOwnerConfirmed: true);
      final barrier = _Barrier();
      signals.nextRead = barrier;
      final saving = session.saveFeeling(FeelingLabel.calm);
      final rejected = expectLater(saving, throwsStateError);
      await barrier.entered.future;
      Future<void>? restarting;
      try {
        if (boundary == 'clear and re-enable') {
          await session.clear();
          restarting = session.setSources({
            SignalSource.checkIns,
            SignalSource.motion,
          }, deviceOwnerConfirmed: true);
          // Wait for the source commit, not the native sync joining this read.
          await controller.flush();
        } else {
          await session.suspend();
          restarting = session.activate();
        }
      } finally {
        barrier.release();
      }
      await restarting;
      await rejected;
      expect(
        controller.data.learning.examples.map((e) => e.id),
        boundary == 'clear and re-enable' ? isEmpty : ['older'],
      );
      expect(session.undoableMoment, isNull);
    });
  }

  test('a queued feeling rejects a later foreground suspension', () async {
    final barrier = _Barrier();
    repository.nextSave = barrier;
    final blocking = controller.setTheme(ThemeChoice.dark);
    await barrier.entered.future;
    final saving = session.saveFeeling(FeelingLabel.calm);
    final rejected = expectLater(saving, throwsStateError);
    try {
      await session.suspend();
    } finally {
      barrier.release();
    }
    await blocking;
    await rejected;
    expect(controller.data.learning.examples.single.id, 'older');
  });

  test(
    'a queued feeling cannot write after Pause commits ahead of it',
    () async {
      final barrier = _Barrier();
      repository.nextSave = barrier;
      final pausing = session.pause();
      await barrier.entered.future;
      final saving = session.saveFeeling(FeelingLabel.calm);
      final rejected = expectLater(saving, throwsStateError);
      try {
        // The feeling began while the old document still looked unpaused.
      } finally {
        barrier.release();
      }
      await pausing;
      await rejected;
      expect(controller.data.learning.pausedByUser, isTrue);
      expect(controller.data.learning.examples.single.id, 'older');
    },
  );

  test('canonical feeling receipt supports exact-instance undo', () async {
    await session.saveFeeling(FeelingLabel.calm);
    final receipt = session.undoableMoment;
    expect(receipt, isNotNull);
    expect(receipt, same(controller.data.learning.examples.last));
    await session.undoSavedFeeling();
    expect(controller.data.learning.examples.single.id, 'older');
  });

  test('a direct committed receipt survives an already queued clear', () async {
    final saving = controller.recordLearning(
      FeelingLabel.calm,
      SignalSnapshot(observedAt: DateTime.now().toUtc()),
    );
    final clearing = controller.clearLearning();
    final receipt = await saving;
    await clearing;
    expect(receipt.label, FeelingLabel.calm);
    expect(receipt, same(repository.committed.first.learning.examples.last));
    expect(controller.data.learning.examples, isEmpty);
  });

  test(
    'failed feeling persistence preserves prior data and retryable undo',
    () async {
      repository.failSave = true;
      await expectLater(
        session.saveFeeling(FeelingLabel.calm),
        throwsStateError,
      );
      expect(controller.data.learning.examples.single.id, 'older');
      expect(repository.value.learning.examples.single.id, 'older');
      expect(session.undoableMoment, isNull);
      repository.failSave = false;
      await session.saveFeeling(FeelingLabel.calm);
      expect(
        session.undoableMoment,
        same(controller.data.learning.examples.last),
      );
    },
  );
}
