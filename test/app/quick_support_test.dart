import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';

class _Repo implements AppRepository, ResidualDataRepository {
  _Repo(this.data);
  AppData data;
  AppData? backup;
  bool fail = false, failCleanup = false;
  Completer<void>? barrier;
  @override
  Future<AppData> load() async => data;
  @override
  Future<void> save(AppData next) async {
    await barrier?.future;
    if (fail) throw StateError('disk');
    backup = data;
    data = next;
  }

  @override
  Future<void> purgeResidualData() async {
    if (failCleanup) throw StateError('cleanup');
    backup = null;
  }
}

AppData _fixture() => AppData(
  people: [
    TrustedPerson(id: 'a', name: 'Fictional helper', phone: '202-555-0126'),
    TrustedPerson(id: 'b', name: 'Other helper'),
  ],
  events: [
    for (final id in ['e', 'other'])
      SupportEvent(
        id: id,
        title: 'Fictional $id',
        createdAt: DateTime.now().toUtc(),
        actions: [
          PlanAction(
            id: '$id-action',
            stage: JourneyStage.plan,
            title: 'My next step',
          ),
          PlanAction(
            id: '$id-later',
            stage: JourneyStage.reflect,
            title: 'A later step',
          ),
        ],
      ),
  ],
  activeEventId: 'e',
  theme: ThemeChoice.dark,
  readingStyle: ReadingStyle.simple,
);
void main() {
  late _Repo repo;
  late AppController c;
  bool disposed = false;
  setUp(() {
    repo = _Repo(_fixture());
    c = AppController(repo, repo.data);
    disposed = false;
  });
  tearDown(() async {
    await c.flush();
    if (!disposed) c.dispose();
  });
  TrustedPerson person() => c.data.people.first;
  PlanAction action() => c.activeEvent!.actions.first;
  Future<void> edit({
    String name = 'Updated helper',
    String phone = '202-555-0156',
  }) => c.updatePerson(
    'a',
    name,
    phone,
    expected: person(),
    expectedRevision: c.replacementRevision,
  );
  Future<void> done(bool value) => c.setFocusedActionDone(
    'e',
    'e-action',
    value,
    expected: action(),
    expectedRevision: c.replacementRevision,
  );

  test(
    'edit trims text and preserves exact person ID/order and unrelated data',
    () async {
      final other = c.data.people.last, events = c.data.events;
      await edit(name: '  New helper  ', phone: '  +1 202 555 0156  ');
      expect(person().id, 'a');
      expect(person().name, 'New helper');
      expect(person().phone, '+1 202 555 0156');
      expect(c.data.people.last, same(other));
      expect(c.data.people.map((p) => p.id), ['a', 'b']);
      expect(c.data.events, events);
      expect(c.data.theme, ThemeChoice.dark);
      expect(c.data.readingStyle, ReadingStyle.simple);
      expect(c.data.learning.enabledSources, isEmpty);
      expect(repo.backup, isNull);
      expect(repo.data.toJson(), c.data.toJson());
    },
  );
  test(
    'blank phone clears it while blank name rejects without a save',
    () async {
      final before = c.data;
      await expectLater(edit(name: ' '), throwsArgumentError);
      expect(c.data, same(before));
      await edit(phone: '  ');
      expect(person().phone, isNull);
      expect(c.data.toJson()['version'], 4);
    },
  );
  test(
    'edit/remove require the matching ID and exact unchanged instance',
    () async {
      final old = person();
      await expectLater(
        c.updatePerson(
          'a',
          'Wrong',
          '',
          expected: c.data.people.last,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      await edit();
      await expectLater(
        c.deletePerson('a', expected: old, expectedRevision: 0),
        throwsStateError,
      );
      expect(c.data.people, hasLength(2));
      await c.deletePerson('a', expected: person(), expectedRevision: 0);
      expect(c.data.people.single.id, 'b');
      expect(repo.backup, isNull);
    },
  );
  test('failed primary edit stays unchanged; failed residual cleanup commits with warning', () async {
    final old = person();
    repo.fail = true;
    await expectLater(edit(), throwsStateError);
    expect(person(), same(old));
    repo.fail = false;
    repo.failCleanup = true;
    await edit();
    expect(person().name, 'Updated helper');
    expect(c.cleanupWarning, isNotNull);
    expect(repo.backup!.people.first.name, 'Fictional helper');
    await c.setTheme(ThemeChoice.light);
    expect(c.cleanupWarning, isNotNull);
  });
  test('queued unrelated write and edit both survive', () async {
    final theme = c.setTheme(ThemeChoice.light), editing = edit();
    await theme;
    await editing;
    expect(c.data.theme, ThemeChoice.light);
    expect(person().name, 'Updated helper');
  });
  test('same-ID import queued first rejects stale edit and delete', () async {
    final old = person();
    final imported = c.replaceData(AppData.fromJson(c.data.toJson()));
    final editing = c.updatePerson(
      'a',
      'Stale',
      '',
      expected: old,
      expectedRevision: 0,
    );
    final removing = c.deletePerson(
      'b',
      expected: c.data.people.last,
      expectedRevision: 0,
    );
    await expectLater(editing, throwsStateError);
    await expectLater(removing, throwsStateError);
    await imported;
    expect(person().name, 'Fictional helper');
    expect(c.data.people, hasLength(2));
  });
  test(
    'foreground guard is checked inside the queue for add and edit',
    () async {
      repo.barrier = Completer<void>();
      var active = true;
      final first = c.setTheme(ThemeChoice.light);
      final editing = c.updatePerson(
        'a',
        'Stale',
        '',
        expected: person(),
        expectedRevision: 0,
        isActive: () => active,
      );
      final adding = c.addPerson(
        'Late helper',
        '',
        expectedRevision: 0,
        isActive: () => active,
      );
      final rejectedEdit = expectLater(editing, throwsStateError),
          rejectedAdd = expectLater(adding, throwsStateError);
      active = false;
      repo.barrier!.complete();
      await first;
      await rejectedEdit;
      await rejectedAdd;
      expect(c.data.people, hasLength(2));
      expect(person().name, 'Fictional helper');
    },
  );
  test('new guarded add checks replacement revision without changing existing add API', () async {
    await c.replaceData(AppData.empty());
    await expectLater(
      c.addPerson('Stale', '', expectedRevision: 0),
      throwsStateError,
    );
    await c.addPerson('New helper', '');
    expect(c.data.people.single.name, 'New helper');
    expect(c.data.people.single.phone, isNull);
  });
  test(
    'closed controllers reject contact and focus ownership writes',
    () async {
      final p = person(), a = action();
      c.dispose();
      disposed = true;
      await expectLater(c.addPerson('Late', ''), throwsStateError);
      await expectLater(
        c.updatePerson('a', 'Late', '', expected: p, expectedRevision: 0),
        throwsStateError,
      );
      await expectLater(
        c.deletePerson('a', expected: p, expectedRevision: 0),
        throwsStateError,
      );
      await expectLater(
        c.setFocusedActionDone(
          'e',
          'e-action',
          true,
          expected: a,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'focused completion and undo change only the exact target action',
    () async {
      final later = c.activeEvent!.actions.last, other = c.data.events.last;
      await done(true);
      expect(action().done, isTrue);
      expect(c.activeEvent!.nextPendingAction!.id, 'e-later');
      expect(c.activeEvent!.actions.last, same(later));
      expect(c.data.events.last, same(other));
      await done(false);
      expect(action().done, isFalse);
      expect(c.data.learning.examples, isEmpty);
    },
  );
  test('focused completion cannot overwrite a corrected action', () async {
    final old = action();
    await c.renameAction('e', 'e-action', 'Renamed');
    await expectLater(
      c.setFocusedActionDone(
        'e',
        'e-action',
        true,
        expected: old,
        expectedRevision: 0,
      ),
      throwsStateError,
    );
    expect(action().title, 'Renamed');
    expect(action().done, isFalse);
  });
  test('focus rejects changed active event, completed event, deleted action and same-ID import', () async {
    var old = action();
    await c.selectEvent('other');
    await expectLater(
      c.setFocusedActionDone(
        'e',
        'e-action',
        true,
        expected: old,
        expectedRevision: 0,
      ),
      throwsStateError,
    );
    await c.selectEvent('e');
    await c.completeEvent('e', true);
    await expectLater(done(true), throwsStateError);
    await c.completeEvent('e', false);
    old = action();
    await c.removeAction('e', 'e-action');
    await expectLater(
      c.setFocusedActionDone(
        'e',
        'e-action',
        true,
        expected: old,
        expectedRevision: 0,
      ),
      throwsStateError,
    );
    await c.replaceData(_fixture());
    old = action();
    final rev = c.replacementRevision;
    await c.replaceData(AppData.fromJson(c.data.toJson()));
    await expectLater(
      c.setFocusedActionDone(
        'e',
        'e-action',
        true,
        expected: old,
        expectedRevision: rev,
      ),
      throwsStateError,
    );
    expect(action().done, isFalse);
  });
  test(
    'focus save failure and queued unrelated changes keep correct state',
    () async {
      repo.fail = true;
      await expectLater(done(true), throwsStateError);
      expect(action().done, isFalse);
      repo.fail = false;
      final saving = done(true), theme = c.setTheme(ThemeChoice.light);
      await saving;
      await theme;
      expect(action().done, isTrue);
      expect(c.data.theme, ThemeChoice.light);
    },
  );
  test('a focus action queued while a view closes is rejected', () async {
    repo.barrier = Completer<void>();
    var active = true;
    final first = c.setTheme(ThemeChoice.light);
    final pending = c.setFocusedActionDone(
      'e',
      'e-action',
      true,
      expected: action(),
      expectedRevision: 0,
      isActive: () => active,
    );
    final rejected = expectLater(pending, throwsStateError);
    active = false;
    repo.barrier!.complete();
    await first;
    await rejected;
    expect(action().done, isFalse);
  });
}
