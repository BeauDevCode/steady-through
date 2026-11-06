import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/file_app_repository.dart';
import 'package:steady_through/model/app_data.dart';

void main() {
  late Directory temp;
  late FileAppRepository repository;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('steady-through-test-');
    repository = FileAppRepository(temp);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('first load returns an empty document', () async {
    final data = await repository.load();
    expect(data.events, isEmpty);
    expect(data.activeEventId, isNull);
  });

  test('saved data survives a new repository instance', () async {
    final data = AppData.empty().copyWith(theme: ThemeChoice.dark);
    await repository.save(data);

    final reloaded = await FileAppRepository(temp).load();
    expect(reloaded.theme, ThemeChoice.dark);
  });

  test(
    'context and exact stored action titles survive repository round-trip',
    () async {
      final original = AppData(
        events: [
          SupportEvent(
            id: 'fictional-event',
            title: 'Fictional caring event',
            createdAt: DateTime.utc(2026, 11, 6),
            guidanceContext: GuidanceContext.caregiving,
            actions: [
              PlanAction(
                id: 'fictional-action',
                stage: JourneyStage.plan,
                title: 'Fictional personally written action',
                done: true,
              ),
            ],
          ),
        ],
      );
      await repository.save(original);
      final reloaded = await FileAppRepository(temp).load();
      expect(
        reloaded.events.single.guidanceContext,
        GuidanceContext.caregiving,
      );
      expect(reloaded.toJson(), original.toJson());
    },
  );

  test('invalid JSON is reported and left untouched', () async {
    final file = File('${temp.path}/steady-through.json');
    await file.writeAsString('{not json');

    await expectLater(repository.load(), throwsFormatException);
    expect(await file.readAsString(), '{not json');
  });

  test('valid save replaces the file with complete JSON', () async {
    await repository.save(AppData.empty().copyWith(theme: ThemeChoice.light));
    await repository.save(AppData.empty().copyWith(theme: ThemeChoice.dark));

    final file = File('${temp.path}/steady-through.json');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(json['theme'], 'dark');
    expect(json['version'], 4);
    expect(await FileAppRepository(temp).load(), isA<AppData>());
  });

  test('a storage path occupied by a file is not treated as empty', () async {
    final occupied = File('${temp.path}/occupied');
    await occupied.writeAsString('not a directory');
    final unavailable = FileAppRepository(Directory(occupied.path));

    await expectLater(unavailable.load(), throwsA(isA<FileSystemException>()));
    expect(await occupied.readAsString(), 'not a directory');
  });

  test('backup cleanup failure does not desync committed data', () async {
    final cleanupFails = FileAppRepository(
      temp,
      backupCleanup: (file) async {
        throw FileSystemException('Backup cleanup denied', file.path);
      },
    );
    final controller = AppController(cleanupFails, AppData.empty());
    addTearDown(controller.dispose);

    await controller.setTheme(ThemeChoice.light);
    await controller.setTheme(ThemeChoice.dark);

    expect(controller.data.theme, ThemeChoice.dark);
    expect((await FileAppRepository(temp).load()).theme, ThemeChoice.dark);
  });

  test(
    'delete-all commits with a warning when its backup cannot be removed',
    () async {
      final cleanupFails = FileAppRepository(
        temp,
        backupCleanup: (file) async {
          throw FileSystemException('Backup cleanup denied', file.path);
        },
      );
      final controller = AppController(cleanupFails, AppData.empty());
      addTearDown(controller.dispose);
      await controller.createEvent('Private event', '');

      await expectLater(controller.clearAll(), completes);
      expect(
        controller.cleanupWarning,
        contains('Older local copies may remain'),
      );

      // The active document is cleared, while the warning truthfully reflects
      // the actual residual backup below.
      expect(controller.data.events, isEmpty);
      expect((await FileAppRepository(temp).load()).events, isEmpty);
      expect(
        await File('${temp.path}/steady-through.json.bak').readAsString(),
        contains('Private event'),
      );
    },
  );

  test('delete-all removes the active file and its local backup', () async {
    final controller = AppController(repository, AppData.empty());
    addTearDown(controller.dispose);
    await controller.createEvent('Private event', '');

    await controller.clearAll();

    expect(controller.data.events, isEmpty);
    expect((await FileAppRepository(temp).load()).events, isEmpty);
    expect(
      await File('${temp.path}/steady-through.json.bak').exists(),
      isFalse,
    );
    expect(
      await File('${temp.path}/steady-through.json.tmp').exists(),
      isFalse,
    );
  });
}
