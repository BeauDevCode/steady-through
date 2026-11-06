import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/data/data_portability.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/model/app_data.dart';

class _Repository implements AppRepository, ResidualDataRepository {
  _Repository(this.value);
  AppData value;
  AppData? backup;
  bool failSave = false;
  bool failCleanup = true;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    if (failSave) throw StateError('save failed');
    backup = value;
    value = next;
  }

  @override
  Future<void> purgeResidualData() async {
    if (failCleanup) throw StateError('cleanup failed');
    backup = null;
  }
}

class _Archive extends DataPortabilityGateway {
  _Archive(this.data);
  final AppData data;
  @override
  Future<Uint8List?> pickJsonBytes() async =>
      Uint8List.fromList(utf8.encode(jsonEncode(data.toJson())));
  @override
  Future<Uri?> saveJsonFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async => null;
}

AppData _expired() {
  final at = DateTime.now().toUtc().subtract(const Duration(days: 181));
  return AppData(
    learning: LearningData(
      examples: [
        LearningExample(
          id: 'expired',
          createdAt: at,
          label: FeelingLabel.calm,
          snapshot: SignalSnapshot(observedAt: at),
        ),
      ],
    ),
  );
}

String? _warning(AppController controller) => controller.cleanupWarning;

void main() {
  test(
    'a committed event save with failed retention cleanup succeeds once',
    () async {
      final initial = _expired();
      final repository = _Repository(initial);
      final controller = AppController(repository, initial);
      addTearDown(controller.dispose);
      await expectLater(controller.createEvent('New job', ''), completes);
      expect(controller.data.events.single.title, 'New job');
      expect(repository.value.events.single.title, 'New job');
      expect(controller.data.learning.examples, isEmpty);
      expect(repository.backup!.learning.examples, hasLength(1));
      expect(_warning(controller), contains('Older local copies may remain'));
      await controller.flush();
      expect(controller.data.events, hasLength(1));
    },
  );

  test(
    'real import reports success after replacement commits but cleanup fails',
    () async {
      final initial = _expired();
      final repository = _Repository(initial);
      final controller = AppController(repository, initial);
      addTearDown(controller.dispose);
      final imported = AppData(
        events: [
          SupportEvent(
            id: 'imported',
            title: 'Imported event',
            createdAt: DateTime.utc(2026),
          ),
        ],
        activeEventId: 'imported',
      );
      final portability = DataPortability(
        controller,
        gateway: _Archive(imported),
      );
      await expectLater(
        portability.importData(confirm: (_) async => true),
        completion(isTrue),
      );
      expect(controller.activeEvent!.title, 'Imported event');
      expect(repository.value.events.single.id, 'imported');
      expect(controller.replacementRevision, 1);
      expect(_warning(controller), contains('Older local copies may remain'));
    },
  );

  test(
    'an ordinary save cannot clear warning without confirmed cleanup',
    () async {
      final initial = _expired();
      final repository = _Repository(initial);
      final controller = AppController(repository, initial);
      addTearDown(controller.dispose);
      await expectLater(controller.createEvent('New job', ''), completes);
      final warning = _warning(controller);
      await controller.setTheme(ThemeChoice.dark);
      expect(_warning(controller), warning);
      repository.failCleanup = false;
      await controller.clearLearning();
      expect(_warning(controller), isNull);
      expect(repository.backup, isNull);
      expect(controller.data.events.single.title, 'New job');
    },
  );

  test(
    'failed save rejects without replacing records or creating cleanup warning',
    () async {
      final initial = _expired();
      final repository = _Repository(initial)..failSave = true;
      final controller = AppController(repository, initial);
      addTearDown(controller.dispose);
      await expectLater(
        controller.createEvent('Uncommitted', ''),
        throwsStateError,
      );
      expect(controller.data, same(initial));
      expect(repository.value, same(initial));
      expect(controller.replacementRevision, 0);
      expect(repository.backup, isNull);
      expect(_warning(controller), isNull);
      repository.failSave = false;
      repository.failCleanup = false;
      await controller.createEvent('Saved retry', '');
      expect(controller.data.events.single.title, 'Saved retry');
    },
  );

  test(
    'failed import save keeps active records and replacement revision',
    () async {
      final initial = AppData(
        events: [
          SupportEvent(
            id: 'original',
            title: 'Keep this',
            createdAt: DateTime.utc(2026),
          ),
        ],
        activeEventId: 'original',
      );
      final repository = _Repository(initial)..failSave = true;
      final controller = AppController(repository, initial);
      addTearDown(controller.dispose);
      final portability = DataPortability(
        controller,
        gateway: _Archive(AppData.empty()),
      );
      await expectLater(
        portability.importData(confirm: (_) async => true),
        throwsStateError,
      );
      expect(controller.data, same(initial));
      expect(repository.value, same(initial));
      expect(controller.activeEvent!.id, 'original');
      expect(controller.replacementRevision, 0);
      expect(repository.backup, isNull);
    },
  );

  test(
    'clear all commits with warning and can confirm cleanup on retry',
    () async {
      final initial = _expired();
      final repository = _Repository(initial);
      final controller = AppController(repository, initial);
      addTearDown(controller.dispose);
      await expectLater(controller.clearAll(), completes);
      expect(controller.data.learning.examples, isEmpty);
      expect(repository.value.learning.examples, isEmpty);
      expect(_warning(controller), isNotNull);
      repository.failCleanup = false;
      await controller.clearAll();
      expect(_warning(controller), isNull);
      expect(repository.backup, isNull);
    },
  );
}
