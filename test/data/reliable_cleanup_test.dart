import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/data/vault_store.dart';
import 'package:steady_through/model/app_data.dart';

class _Repository implements AppRepository, ResidualDataRepository {
  _Repository(this.value);
  AppData value;
  AppData? backup;
  bool failSave = false;
  bool failCleanup = false;
  int cleanupAttempts = 0;

  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    if (failSave) throw StateError('Fictional primary failure');
    backup = value;
    value = next;
  }

  @override
  Future<void> purgeResidualData() async {
    cleanupAttempts++;
    if (failCleanup) throw StateError('Fictional cleanup failure');
    backup = null;
  }
}

AppData _fixture() {
  final at = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return AppData(
    events: [
      SupportEvent(
        id: 'remove-event',
        title: 'Fictional old event',
        createdAt: at,
      ),
      SupportEvent(
        id: 'keep-event',
        title: 'Fictional retained event',
        createdAt: at,
      ),
    ],
    activeEventId: 'remove-event',
    people: [TrustedPerson(id: 'keep-person', name: 'Fictional Alex')],
    checkIns: [
      CheckIn(
        id: 'remove-check-in',
        eventId: 'remove-event',
        createdAt: at,
        feeling: 'Fictional old feeling',
        note: 'Fictional private note',
      ),
      CheckIn(
        id: 'keep-check-in',
        eventId: 'keep-event',
        createdAt: at,
        feeling: 'Fictional retained feeling',
      ),
    ],
    gameRounds: [
      GameRound(
        id: 'remove-round',
        createdAt: at,
        boardId: 0,
        moves: 8,
        backtracks: 1,
        restarts: 0,
        feeling: RoundFeeling.neither,
      ),
    ],
  );
}

AppData _replacement() => AppData(
  events: [
    SupportEvent(
      id: 'imported-event',
      title: 'Fictional imported event',
      createdAt: DateTime.now().toUtc(),
    ),
  ],
  activeEventId: 'imported-event',
);

Future<void> _remove(AppController controller, String operation) {
  switch (operation) {
    case 'event and its check-ins':
      return controller.deleteEvent('remove-event');
    case 'single check-in':
      return controller.deleteCheckIn('remove-check-in');
    case 'game history':
      return controller.clearGameRounds();
    case 'event-only import':
      return controller.replaceData(_replacement());
    default:
      throw ArgumentError(operation);
  }
}

void _expectActiveChange(AppData actual, String operation) {
  expect(actual.learning.examples, isEmpty);
  expect(actual.toolFeedback.ratings, isEmpty);
  if (operation == 'event-only import') {
    expect(actual.events.map((e) => e.id), ['imported-event']);
    expect(actual.activeEventId, 'imported-event');
    expect(actual.people, isEmpty);
    expect(actual.checkIns, isEmpty);
    expect(actual.gameRounds, isEmpty);
    return;
  }
  expect(actual.people.single.id, 'keep-person');
  expect(
    actual.events.map((e) => e.id),
    operation == 'event and its check-ins'
        ? ['keep-event']
        : ['remove-event', 'keep-event'],
  );
  expect(
    actual.checkIns.map((c) => c.id),
    operation == 'game history'
        ? ['remove-check-in', 'keep-check-in']
        : ['keep-check-in'],
  );
  expect(
    actual.gameRounds.map((r) => r.id),
    operation == 'game history' ? isEmpty : ['remove-round'],
  );
}

void main() {
  const operations = [
    'event and its check-ins',
    'single check-in',
    'game history',
    'event-only import',
  ];
  for (final operation in operations) {
    test(
      '$operation removes the previous recovery copy without learning records',
      () async {
        final repository = _Repository(_fixture());
        final controller = AppController(repository, repository.value);
        addTearDown(controller.dispose);
        await _remove(controller, operation);
        _expectActiveChange(controller.data, operation);
        _expectActiveChange(repository.value, operation);
        expect(repository.cleanupAttempts, 1);
        expect(repository.backup, isNull);
        expect(controller.cleanupWarning, isNull);
      },
    );

    test(
      '$operation commits once and warns when residual cleanup fails',
      () async {
        final repository = _Repository(_fixture())..failCleanup = true;
        final controller = AppController(repository, repository.value);
        addTearDown(controller.dispose);
        await _remove(controller, operation);
        _expectActiveChange(controller.data, operation);
        _expectActiveChange(repository.value, operation);
        expect(repository.cleanupAttempts, 1);
        expect(repository.backup!.events.first.id, 'remove-event');
        expect(repository.backup!.checkIns.first.id, 'remove-check-in');
        expect(repository.backup!.gameRounds.single.id, 'remove-round');
        expect(controller.cleanupWarning, isNotNull);
        await controller.setTheme(ThemeChoice.dark);
        expect(controller.cleanupWarning, isNotNull);
        expect(repository.cleanupAttempts, 1);
      },
    );

    test(
      '$operation rejects primary failure without attempting residual cleanup',
      () async {
        final initial = _fixture();
        final repository = _Repository(initial)..failSave = true;
        final controller = AppController(repository, initial);
        addTearDown(controller.dispose);
        await expectLater(_remove(controller, operation), throwsStateError);
        expect(controller.data, same(initial));
        expect(repository.value, same(initial));
        expect(repository.cleanupAttempts, 0);
        expect(repository.backup, isNull);
        expect(controller.cleanupWarning, isNull);
        expect(controller.replacementRevision, 0);
      },
    );

    test(
      '$operation purges the real encrypted backup and reopens active records',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'steady-reliable-cleanup-',
        );
        VaultSession? session;
        VaultSession? reopened;
        AppController? controller;
        try {
          session = await VaultStore(directory)
              .create('fictional cleanup passphrase');
          final initial = _fixture();
          await session.repository.save(initial);
          controller = AppController(session.repository, initial);
          await _remove(controller, operation);
          _expectActiveChange(controller.data, operation);
          expect(
            await File('${directory.path}/steady-through.vault.bak').exists(),
            isFalse,
          );
          expect(
            await File('${directory.path}/steady-through.vault.tmp').exists(),
            isFalse,
          );
          final primary = File('${directory.path}/steady-through.vault');
          expect(await primary.exists(), isTrue);
          expect(await primary.readAsString(), isNot(contains('Fictional')));
          controller.dispose();
          controller = null;
          session.close();
          session = null;
          reopened = await VaultStore(directory)
              .unlock('fictional cleanup passphrase');
          _expectActiveChange(reopened.initialData, operation);
        } finally {
          controller?.dispose();
          session?.close();
          reopened?.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
