import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';

class MemoryRepository implements AppRepository {
  AppData value = AppData.empty();
  final List<AppData> saved = [];

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    value = next;
    saved.add(next);
  }
}

class BlockingRepository implements AppRepository {
  AppData value = AppData.empty();
  final firstSaveEntered = Completer<void>();
  final releaseFirstSave = Completer<void>();
  int calls = 0;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    calls++;
    if (calls == 1) {
      firstSaveEntered.complete();
      await releaseFirstSave.future;
    }
    value = next;
  }
}

class FailOnceRepository implements AppRepository {
  AppData value = AppData.empty();
  bool shouldFail = true;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    if (shouldFail) {
      shouldFail = false;
      throw const FileSystemExceptionForTest();
    }
    value = next;
  }
}

class FileSystemExceptionForTest implements Exception {
  const FileSystemExceptionForTest();
}

void main() {
  late MemoryRepository repository;
  late AppController controller;

  setUp(() {
    repository = MemoryRepository();
    controller = AppController(repository, AppData.empty());
  });

  tearDown(() => controller.dispose());

  test('creating an event selects it and adds one action per stage', () async {
    await controller.createEvent('  Starting a new job  ', 'First week');

    expect(controller.activeEvent?.title, 'Starting a new job');
    expect(controller.activeEvent?.actions.length, JourneyStage.values.length);
    expect(
      controller.activeEvent?.actions.map((action) => action.stage).toSet(),
      JourneyStage.values.toSet(),
    );
    expect(repository.saved.single.activeEventId, controller.activeEvent?.id);
  });

  test('blank event title is rejected without changing storage', () async {
    await expectLater(controller.createEvent('  ', ''), throwsArgumentError);
    expect(controller.data.events, isEmpty);
    expect(repository.saved, isEmpty);
  });

  test('switching events changes Home selection', () async {
    await controller.createEvent('First', '');
    final first = controller.activeEvent!.id;
    await controller.createEvent('Second', '');
    await controller.selectEvent(first);

    expect(controller.activeEvent?.title, 'First');
    expect(controller.data.events, hasLength(2));
  });

  test(
    'deleting active event removes its check-ins but keeps game history',
    () async {
      await controller.createEvent('First', '');
      final first = controller.activeEvent!.id;
      await controller.addCheckIn(
        first,
        feeling: 'Worried',
        intensity: 3,
        note: '',
      );
      await controller.recordRound(
        GameRound(
          id: 'round-1',
          createdAt: DateTime.utc(2026, 11, 5),
          boardId: 0,
          moves: 6,
          backtracks: 0,
          restarts: 0,
          feeling: RoundFeeling.neither,
        ),
      );
      await controller.createEvent('Second', '');
      await controller.selectEvent(first);
      await controller.deleteEvent(first);

      expect(controller.activeEvent?.title, 'Second');
      expect(controller.data.checkIns, isEmpty);
      expect(controller.data.gameRounds.single.id, 'round-1');
    },
  );

  test('an action can be added, renamed, completed, and removed', () async {
    await controller.createEvent('Move house', '');
    final eventId = controller.activeEvent!.id;
    await controller.addAction(eventId, JourneyStage.plan, '  Pack one box  ');
    final action = controller.activeEvent!.actions.last;

    expect(action.title, 'Pack one box');
    await controller.renameAction(eventId, action.id, 'Call a friend');
    await controller.setActionDone(eventId, action.id, true);
    expect(controller.activeEvent!.actions.last.title, 'Call a friend');
    expect(controller.activeEvent!.actions.last.done, isTrue);
    await controller.removeAction(eventId, action.id);
    expect(
      controller.activeEvent!.actions.any((item) => item.id == action.id),
      isFalse,
    );
  });

  test('delete-all removes every record and preference', () async {
    await controller.createEvent('One', '');
    await controller.setReadingStyle(ReadingStyle.simple);
    await controller.clearAll();

    expect(controller.data.events, isEmpty);
    expect(controller.data.readingStyle, ReadingStyle.standard);
    expect(repository.value.events, isEmpty);
  });

  test('invalid check-in intensity does not change storage', () async {
    await controller.createEvent('First', '');
    final savedBefore = repository.saved.length;
    final eventId = controller.activeEvent!.id;

    await expectLater(
      controller.addCheckIn(eventId, feeling: 'Tense', intensity: 6, note: ''),
      throwsArgumentError,
    );
    expect(controller.data.checkIns, isEmpty);
    expect(repository.saved.length, savedBefore);
  });

  test('overlapping edits save in order without losing an event', () async {
    final blocking = BlockingRepository();
    final subject = AppController(blocking, AppData.empty());
    addTearDown(subject.dispose);

    final first = subject.createEvent('First', '');
    await blocking.firstSaveEntered.future;
    final second = subject.createEvent('Second', '');
    await Future<void>.delayed(Duration.zero);
    final callsBeforeRelease = blocking.calls;
    blocking.releaseFirstSave.complete();
    await Future.wait([first, second]);

    expect(callsBeforeRelease, 1);
    expect(subject.data.events.map((event) => event.title), [
      'First',
      'Second',
    ]);
    expect(blocking.value.events.length, 2);
  });

  test(
    'a failed save leaves state unchanged and later edits can save',
    () async {
      final failing = FailOnceRepository();
      final subject = AppController(failing, AppData.empty());
      addTearDown(subject.dispose);

      await expectLater(
        subject.createEvent('First', ''),
        throwsA(isA<FileSystemExceptionForTest>()),
      );
      expect(subject.data.events, isEmpty);
      await subject.createEvent('Second', '');

      expect(subject.activeEvent?.title, 'Second');
      expect(failing.value.events.single.title, 'Second');
    },
  );
}
