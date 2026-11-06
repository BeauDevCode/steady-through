import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/model/app_data.dart';

class _Repository implements AppRepository, ResidualDataRepository {
  _Repository(this.value);
  AppData value;
  AppData? backup;
  bool failCleanup = false;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    backup = value;
    value = next;
  }

  @override
  Future<void> purgeResidualData() async {
    if (failCleanup) throw StateError('cleanup failed');
    backup = null;
  }
}

AppData _data({bool expired = false}) {
  final at = DateTime.now().toUtc().subtract(Duration(days: expired ? 181 : 1));
  return AppData(
    events: [
      SupportEvent(id: 'event', title: 'Keep this event', createdAt: at),
    ],
    activeEventId: 'event',
    learning: LearningData(
      enabledSources: {SignalSource.checkIns},
      examples: [
        LearningExample(
          id: 'example',
          createdAt: at,
          label: FeelingLabel.calm,
          snapshot: SignalSnapshot(observedAt: at),
        ),
      ],
    ),
  );
}

void main() {
  test(
    'import keeps history but requires fresh device-source consent',
    () async {
      final initial = _data();
      final repository = _Repository(initial);
      final controller = AppController(repository, initial);
      addTearDown(controller.dispose);
      final learning = initial.learning.copyWith(
        enabledSources: SignalSource.values.toSet(),
        deviceOwnerConfirmed: true,
        pausedByUser: true,
        calibration: CalibrationState(
          startedAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
        ),
      );
      await controller.replaceData(initial.copyWith(learning: learning));
      final imported = controller.data.learning;
      expect(imported.enabledSources, {
        SignalSource.checkIns,
        SignalSource.inApp,
      });
      expect(imported.deviceOwnerConfirmed, isFalse);
      expect(imported.pausedByUser, isTrue);
      expect(
        imported.examples.single.toJson(),
        learning.examples.single.toJson(),
      );
      expect(imported.calibration.toJson(), learning.calibration.toJson());
      expect(controller.data.events.single.title, 'Keep this event');
    },
  );

  test(
    'the thousand-example cap also purges the evicted recovery record',
    () async {
      final at = DateTime.now().toUtc().subtract(const Duration(days: 3));
      final initial = _data().copyWith(
        learning: LearningData(
          enabledSources: {SignalSource.checkIns},
          examples: [
            for (var index = 0; index < 1000; index++)
              LearningExample(
                id: 'example-$index',
                createdAt: at.add(Duration(minutes: index)),
                label: FeelingLabel.calm,
                snapshot: SignalSnapshot(
                  observedAt: at.add(Duration(minutes: index)),
                ),
              ),
          ],
        ),
      );
      final repository = _Repository(initial);
      final controller = AppController(repository, initial);
      addTearDown(controller.dispose);
      await controller.recordLearning(
        FeelingLabel.calm,
        SignalSnapshot(observedAt: DateTime.now().toUtc()),
      );
      expect(controller.data.learning.examples, hasLength(1000));
      expect(
        controller.data.learning.examples.any(
          (example) => example.id == 'example-0',
        ),
        isFalse,
      );
      expect(repository.backup, isNull);
    },
  );
  test(
    'clear learning also removes its recovery copy while keeping events',
    () async {
      final repository = _Repository(_data());
      final controller = AppController(repository, repository.value);
      addTearDown(controller.dispose);
      await controller.clearLearning();
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.events.single.title, 'Keep this event');
      expect(repository.backup, isNull);
    },
  );
  test(
    'startup pruning removes expired examples and their recovery copy',
    () async {
      final repository = _Repository(_data(expired: true));
      final controller = AppController(repository, repository.value);
      addTearDown(controller.dispose);
      await controller.pruneRetainedData();
      expect(repository.value.learning.examples, isEmpty);
      expect(repository.backup, isNull);
      expect(repository.value.events, hasLength(1));
    },
  );
  test(
    'retention applies to unrelated saves with a committed cleanup warning',
    () async {
      final repository = _Repository(_data(expired: true))..failCleanup = true;
      final controller = AppController(repository, repository.value);
      addTearDown(controller.dispose);
      await expectLater(controller.setTheme(ThemeChoice.dark), completes);
      expect(controller.cleanupWarning, isNotNull);
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.theme, ThemeChoice.dark);
      expect(repository.backup!.learning.examples, hasLength(1));
    },
  );
}
