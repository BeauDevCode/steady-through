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
  AppData? backup;
  bool failSave = false, failCleanup = false;
  Completer<void>? barrier;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    await barrier?.future;
    if (failSave) throw StateError('disk unavailable');
    backup = value;
    value = next;
  }

  @override
  Future<void> purgeResidualData() async {
    if (failCleanup) throw StateError('cleanup unavailable');
    backup = null;
  }
}

class _Signals extends DeviceSignals {
  @override
  Future<SignalCapabilities> capabilities() async => const SignalCapabilities();
  @override
  Future<void> stop() async {}
}

AppData _initial() {
  final at = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return AppData(
    events: [SupportEvent(id: 'event', title: 'Keep my plan', createdAt: at)],
    activeEventId: 'event',
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
    ),
  );
}

void main() {
  late _Repository repository;
  late AppController controller;
  late LearningSession session;
  setUp(() {
    repository = _Repository(_initial());
    controller = AppController(repository, repository.value);
    session = LearningSession(controller, signals: _Signals());
  });
  tearDown(() async {
    await session.close();
    controller.dispose();
  });

  test('correction persists with the old-label recovery copy purged', () async {
    final original = controller.data.learning.examples.single;
    await controller.relabelLearningExample('older', FeelingLabel.low);
    final reloaded = AppData.fromJson((await repository.load()).toJson());
    expect(reloaded.learning.examples.single.label, FeelingLabel.low);
    expect(
      reloaded.learning.examples.single.snapshot.toJson(),
      original.snapshot.toJson(),
    );
    expect(reloaded.events.single.title, 'Keep my plan');
    expect(repository.backup, isNull);
  });

  test(
    'failed primary correction leaves live and persisted state untouched',
    () async {
      repository.failSave = true;
      await expectLater(
        controller.relabelLearningExample('older', FeelingLabel.low),
        throwsStateError,
      );
      expect(
        controller.data.learning.examples.single.label,
        FeelingLabel.tense,
      );
      expect(
        repository.value.learning.examples.single.label,
        FeelingLabel.tense,
      );
    },
  );

  test('cleanup failure is a committed correction with a warning', () async {
    repository.failCleanup = true;
    await controller.relabelLearningExample('older', FeelingLabel.low);
    expect(controller.data.learning.examples.single.label, FeelingLabel.low);
    expect(controller.cleanupWarning, isNotNull);
    expect(
      repository.backup!.learning.examples.single.label,
      FeelingLabel.tense,
    );
  });

  test('save receipt identifies its own record and deletion preserves queued writes', () async {
    final receipt = await controller.recordLearning(
      FeelingLabel.calm,
      SignalSnapshot(observedAt: DateTime.now().toUtc()),
    );
    final eventWrite = controller.setTheme(ThemeChoice.dark);
    final deletion = controller.deleteLearningExample(receipt.id);
    await Future.wait([eventWrite, deletion]);
    expect(controller.data.theme, ThemeChoice.dark);
    expect(controller.data.learning.examples.single.id, 'older');
    expect(repository.backup, isNull);
  });

  test('undo removes only the most recent committed save and survives unrelated writes', () async {
    await session.saveFeeling(FeelingLabel.calm);
    final first = session.undoableMoment!.id;
    await session.saveFeeling(FeelingLabel.low);
    final second = session.undoableMoment!.id;
    expect(first, isNot(second));
    await controller.setTheme(ThemeChoice.dark);
    await session.undoSavedFeeling();
    expect(controller.data.learning.examples.map((e) => e.id), [
      'older',
      first,
    ]);
    expect(controller.data.theme, ThemeChoice.dark);
    expect(session.undoableMoment, isNull);
  });

  test('failed undo keeps its receipt for a retry', () async {
    await session.saveFeeling(FeelingLabel.calm);
    final id = session.undoableMoment!.id;
    repository.failSave = true;
    await expectLater(session.undoSavedFeeling(), throwsStateError);
    expect(session.undoableMoment!.id, id);
    expect(controller.data.learning.examples, hasLength(2));
    repository.failSave = false;
    await session.undoSavedFeeling();
    expect(controller.data.learning.examples.single.id, 'older');
  });

  test('a queued edit prevents undo from deleting the edited record', () async {
    await session.saveFeeling(FeelingLabel.calm);
    final receipt = session.undoableMoment!;
    final edit = controller.relabelLearningExample(
      receipt.id,
      FeelingLabel.low,
    );
    final undo = session.undoSavedFeeling();
    await edit;
    await expectLater(undo, throwsStateError);
    expect(controller.data.learning.examples.last.label, FeelingLabel.low);
    expect(session.undoableMoment, isNull);
  });

  test('history remains manageable with sources off or paused', () async {
    await session.setSources({});
    await session.pause();
    await session.relabelMoment('older', FeelingLabel.energized);
    expect(
      controller.data.learning.examples.single.label,
      FeelingLabel.energized,
    );
    await session.deleteMoment('older');
    expect(controller.data.learning.examples, isEmpty);
    expect(controller.data.learning.enabledSources, isEmpty);
    expect(controller.data.learning.pausedByUser, isTrue);
  });

  test(
    'clear, import and close invalidate undo without restoring old data',
    () async {
      await session.saveFeeling(FeelingLabel.calm);
      await session.clear();
      expect(session.undoableMoment, isNull);
      await expectLater(session.undoSavedFeeling(), throwsStateError);
      await session.setSources({SignalSource.checkIns});
      await session.saveFeeling(FeelingLabel.low);
      await controller.replaceData(_initial());
      expect(session.undoableMoment, isNull);
      await session.saveFeeling(FeelingLabel.calm);
      await session.close();
      expect(session.undoableMoment, isNull);
      await expectLater(session.deleteMoment('older'), throwsStateError);
    },
  );

  test('pruning or editing the undo target invalidates the receipt', () async {
    await session.saveFeeling(FeelingLabel.calm);
    final id = session.undoableMoment!.id;
    await session.relabelMoment(id, FeelingLabel.tense);
    expect(session.undoableMoment, isNull);
    await session.saveFeeling(FeelingLabel.low);
    await controller.updateLearning(
      controller.data.learning.copyWith(
        examples: [controller.data.learning.examples.first],
      ),
    );
    expect(session.undoableMoment, isNull);
  });

  test('background history mutations are rejected', () async {
    await session.suspend();
    await expectLater(
      session.relabelMoment('older', FeelingLabel.low),
      throwsStateError,
    );
    await expectLater(session.deleteMoment('older'), throwsStateError);
    expect(controller.data.learning.examples.single.label, FeelingLabel.tense);
  });

  test(
    'a committed save returns its receipt even when a clear is already queued',
    () async {
      final saving = controller.recordLearning(
        FeelingLabel.calm,
        SignalSnapshot(observedAt: DateTime.now().toUtc()),
      );
      final clearing = controller.clearLearning();
      final receipt = await saving;
      await clearing;
      expect(receipt.label, FeelingLabel.calm);
      expect(controller.data.learning.examples, isEmpty);
    },
  );

  test('conditional undo cannot target a different saved moment', () async {
    final receipt = await controller.recordLearning(
      FeelingLabel.calm,
      SignalSnapshot(observedAt: DateTime.now().toUtc()),
    );
    await expectLater(
      controller.deleteLearningExample('older', expected: receipt),
      throwsStateError,
    );
    expect(controller.data.learning.examples, hasLength(2));
  });
}
