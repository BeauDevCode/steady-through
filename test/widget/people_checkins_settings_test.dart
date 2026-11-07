import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/data/data_portability.dart';
import 'package:steady_through/features/check_ins/check_ins_screen.dart';
import 'package:steady_through/features/people/people_screen.dart';
import 'package:steady_through/features/settings/settings_screen.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  AppData value = AppData.empty();
  bool failNextSave = false;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Could not write local data');
    }
    value = next;
  }
}

class _NoPhoneHandler implements PhoneActions {
  @override
  Future<bool> openPhone(String number) async => false;

  @override
  Future<bool> openSms(String number) async => false;
}

// Keep these UI tests at the portability boundary. Real encrypted-file and
// passphrase authentication behavior is exercised by test/data.
class _FakePortability extends DataPortability {
  _FakePortability(super.controller);

  AppData replacement = AppData(
    people: [TrustedPerson(id: 'p1', name: 'Alex')],
  );
  final exportedPassphrases = <String>[];
  final importPassphrases = <String>[];
  bool encryptedImport = true;
  bool failExport = false;
  bool failImport = false;

  @override
  Future<Uri?> exportData({required String passphrase}) async {
    if (failExport) throw StateError('private implementation detail');
    exportedPassphrases.add(passphrase);
    return Uri.file('/chosen/steady-through-data.steady');
  }

  @override
  Future<bool> importData({
    required Future<bool> Function(AppData replacement) confirm,
    Future<String?> Function()? requestPassphrase,
  }) async {
    if (encryptedImport) {
      final passphrase = await requestPassphrase?.call();
      if (passphrase == null) return false;
      importPassphrases.add(passphrase);
      if (failImport) {
        throw const FormatException('private authentication detail');
      }
    }
    if (!await confirm(replacement)) return false;
    await controller.replaceData(replacement);
    return true;
  }
}

void main() {
  late _MemoryRepository repository;
  late AppController controller;

  setUp(() {
    repository = _MemoryRepository();
    controller = AppController(repository, AppData.empty());
  });
  tearDown(() => controller.dispose());

  Future<void> showScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
  }

  Future<void> settleAsyncWork(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showSettingsControl(WidgetTester tester, String label) async {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(label),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text(label)),
      alignment: .5,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('person can be saved and removed', (tester) async {
    await showScreen(tester, PeopleScreen(controller: controller));

    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      ' Alex ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('person-phone-field')),
      '555-0100',
    );
    await tester.tap(find.text('Save person'));
    await settleAsyncWork(tester);

    expect(controller.data.people.single.name, 'Alex');
    expect(find.text('555-0100'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Alex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove person'));
    await tester.pumpAndSettle();
    expect(controller.data.people, isEmpty);
    expect(find.text('Alex'), findsNothing);
  });

  testWidgets(
    'phone and SMS launch when an availability probe would be false',
    (tester) async {
      final calls = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'canLaunch') return false;
        if (call.method == 'launch') return true;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      const actions = UrlLauncherPhoneActions();
      final called = await tester.runAsync(() => actions.openPhone('555-0100'));
      final texted = await tester.runAsync(() => actions.openSms('555-0100'));

      expect(called, isTrue);
      expect(texted, isTrue);
      expect(calls, ['launch', 'launch']);
    },
  );

  testWidgets('person write errors keep the form or record with feedback', (
    tester,
  ) async {
    await showScreen(tester, PeopleScreen(controller: controller));
    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Alex');

    repository.failNextSave = true;
    await tester.tap(find.text('Save person'));
    await settleAsyncWork(tester);
    expect(controller.data.people, isEmpty);
    expect(find.textContaining('Could not save this person'), findsOneWidget);
    expect(find.text('Save person'), findsOneWidget);

    await tester.tap(find.text('Save person'));
    await settleAsyncWork(tester);
    expect(controller.data.people.single.name, 'Alex');
    await tester.tap(find.byTooltip('Remove Alex'));
    await tester.pumpAndSettle();
    repository.failNextSave = true;
    await tester.tap(find.text('Remove person'));
    await settleAsyncWork(tester);
    expect(controller.data.people.single.name, 'Alex');
    expect(find.textContaining('Could not remove this person'), findsOneWidget);
  });

  testWidgets(
    'missing phone and SMS handlers keep number visible and copyable',
    (tester) async {
      String? copiedNumber;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedNumber =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.runAsync(() => controller.addPerson('Alex', '555-0100'));
      await showScreen(
        tester,
        PeopleScreen(controller: controller, phoneActions: _NoPhoneHandler()),
      );

      await tester.tap(find.byTooltip('Call Alex'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open a phone app'), findsOneWidget);
      expect(find.text('555-0100'), findsOneWidget);

      await tester.tap(find.byTooltip('Text Alex'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open a text app'), findsOneWidget);
      expect(find.text('555-0100'), findsOneWidget);

      await tester.tap(find.byTooltip('Copy Alex’s number'));
      await settleAsyncWork(tester);
      expect(copiedNumber, '555-0100');
    },
  );

  testWidgets(
    'check-in saves optional details, appears in history, and deletes',
    (tester) async {
      await tester.runAsync(() => controller.createEvent('New job', ''));
      await showScreen(tester, CheckInsScreen(controller: controller));

      await tester.tap(find.text('Add check-in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'How do you feel?'),
        ' Uneasy ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Note (optional)'),
        'First day',
      );
      await tester.tap(find.text('Save check-in'));
      await settleAsyncWork(tester);

      expect(controller.data.checkIns.single.feeling, 'Uneasy');
      expect(controller.data.checkIns.single.intensity, isNull);
      expect(find.text('First day'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete check-in Uneasy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete check-in').last);
      await tester.pumpAndSettle();
      expect(controller.data.checkIns, isEmpty);
      expect(find.text('Uneasy'), findsNothing);
    },
  );

  testWidgets('check-in write errors keep the form or record with feedback', (
    tester,
  ) async {
    await tester.runAsync(() => controller.createEvent('New job', ''));
    await showScreen(tester, CheckInsScreen(controller: controller));
    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'How do you feel?'),
      'Uneasy',
    );

    repository.failNextSave = true;
    await tester.tap(find.text('Save check-in'));
    await settleAsyncWork(tester);
    expect(controller.data.checkIns, isEmpty);
    expect(find.textContaining('Could not save this check-in'), findsOneWidget);
    expect(find.text('Save check-in'), findsOneWidget);

    await tester.tap(find.text('Save check-in'));
    await settleAsyncWork(tester);
    expect(controller.data.checkIns.single.feeling, 'Uneasy');
    await tester.tap(find.byTooltip('Delete check-in Uneasy'));
    await tester.pumpAndSettle();
    repository.failNextSave = true;
    await tester.tap(find.text('Delete check-in').last);
    await settleAsyncWork(tester);
    expect(controller.data.checkIns.single.feeling, 'Uneasy');
    expect(
      find.textContaining('Could not delete this check-in'),
      findsOneWidget,
    );
  });

  testWidgets('check-ins are scoped to the selected event', (tester) async {
    await tester.runAsync(() async {
      await controller.createEvent('First', '');
      await controller.addCheckIn(
        controller.activeEvent!.id,
        feeling: 'Hopeful',
        note: '',
      );
      await controller.createEvent('Second', '');
    });
    await showScreen(tester, CheckInsScreen(controller: controller));

    expect(find.text('Hopeful'), findsNothing);
    await tester.runAsync(
      () => controller.selectEvent(controller.data.events.first.id),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hopeful'), findsOneWidget);
  });

  testWidgets('theme and simple words choices persist', (tester) async {
    await showScreen(tester, SettingsScreen(controller: controller));

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await settleAsyncWork(tester);
    await tester.tap(find.text('Reading style'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simple words'));
    await settleAsyncWork(tester);

    expect(controller.data.theme, ThemeChoice.dark);
    expect(controller.data.readingStyle, ReadingStyle.simple);
    expect(repository.value.readingStyle, ReadingStyle.simple);
    expect(find.textContaining('trusted helper'), findsOneWidget);
  });

  testWidgets('simple words shortens People and Check-ins instructions', (
    tester,
  ) async {
    await tester.runAsync(
      () => controller.setReadingStyle(ReadingStyle.simple),
    );

    await showScreen(tester, PeopleScreen(controller: controller));
    expect(
      find.text('Save people you trust. Their numbers stay on this device.'),
      findsOneWidget,
    );

    await showScreen(tester, CheckInsScreen(controller: controller));
    expect(
      find.text('Write how you feel. This is just for you.'),
      findsOneWidget,
    );
    expect(
      find.text('Start an event on Home to write a check-in.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'failed preference writes keep the old choice and show an error',
    (tester) async {
      await showScreen(tester, SettingsScreen(controller: controller));

      repository.failNextSave = true;
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await settleAsyncWork(tester);
      expect(controller.data.theme, ThemeChoice.system);
      expect(find.textContaining('Could not save your theme'), findsOneWidget);

      repository.failNextSave = true;
      await tester.tap(find.text('Reading style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simple words'));
      await settleAsyncWork(tester);
      expect(controller.data.readingStyle, ReadingStyle.standard);
      expect(
        find.textContaining('Could not save your reading style'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'encrypted import asks for a passphrase before replacement confirmation',
    (tester) async {
      await tester.runAsync(() => controller.createEvent('Keep this', ''));
      final portability = _FakePortability(controller);
      await showScreen(
        tester,
        SettingsScreen(controller: controller, portability: portability),
      );

      await showSettingsControl(tester, 'Import data');
      await tester.tap(find.text('Import data'));
      await tester.pumpAndSettle();
      expect(find.text('Replace all local data?'), findsNothing);
      expect(controller.activeEvent?.title, 'Keep this');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passphrase'),
        'my backup passphrase',
      );
      await tester.tap(find.text('Unlock backup'));
      await tester.pumpAndSettle();
      expect(find.text('Replace all local data?'), findsOneWidget);
      await tester.tap(find.text('Keep current data'));
      await tester.pumpAndSettle();
      expect(controller.activeEvent?.title, 'Keep this');

      await tester.tap(find.text('Import data'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passphrase'),
        'my backup passphrase',
      );
      await tester.tap(find.text('Unlock backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace all data'));
      await settleAsyncWork(tester);
      expect(controller.data.events, isEmpty);
      expect(controller.data.people.single.name, 'Alex');
      expect(find.text('Data imported.'), findsOneWidget);
    },
  );

  testWidgets(
    'export requires a long matching hidden passphrase and cancel saves nothing',
    (tester) async {
      final portability = _FakePortability(controller);
      await showScreen(
        tester,
        SettingsScreen(controller: controller, portability: portability),
      );
      await showSettingsControl(tester, 'Export data');
      await tester.tap(find.text('Export data'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot recover'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.widgetWithText(TextFormField, 'Passphrase'),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('vault-confirm-passphrase')),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isTrue,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passphrase'),
        'short',
      );
      await tester.enterText(
        find.byKey(const Key('vault-confirm-passphrase')),
        'short',
      );
      await tester.tap(find.text('Create encrypted backup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 12'), findsOneWidget);
      expect(portability.exportedPassphrases, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passphrase'),
        'a much longer passphrase',
      );
      await tester.enterText(
        find.byKey(const Key('vault-confirm-passphrase')),
        'does not match',
      );
      await tester.tap(find.text('Create encrypted backup'));
      await tester.pumpAndSettle();
      expect(find.text('The passphrases do not match.'), findsOneWidget);
      expect(portability.exportedPassphrases, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(portability.exportedPassphrases, isEmpty);

      await tester.tap(find.text('Export data'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passphrase'),
        'a much longer passphrase',
      );
      await tester.enterText(
        find.byKey(const Key('vault-confirm-passphrase')),
        'a much longer passphrase',
      );
      await tester.tap(find.text('Create encrypted backup'));
      await tester.pumpAndSettle();
      expect(portability.exportedPassphrases, ['a much longer passphrase']);
      expect(
        find.text('Encrypted backup saved to the chosen file.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cancelled and failed encrypted imports preserve current data with generic errors',
    (tester) async {
      await tester.runAsync(() => controller.createEvent('Keep this', ''));
      final portability = _FakePortability(controller);
      await showScreen(
        tester,
        SettingsScreen(controller: controller, portability: portability),
      );
      await showSettingsControl(tester, 'Import data');
      await tester.tap(find.text('Import data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(portability.importPassphrases, isEmpty);
      expect(controller.activeEvent?.title, 'Keep this');
      expect(find.text('Replace all local data?'), findsNothing);

      portability.failImport = true;
      await tester.tap(find.text('Import data'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passphrase'),
        'wrong passphrase',
      );
      await tester.tap(find.text('Unlock backup'));
      await tester.pumpAndSettle();
      expect(controller.activeEvent?.title, 'Keep this');
      expect(
        find.textContaining('Your current data was kept.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('private authentication detail'),
        findsNothing,
      );
      expect(find.text('Replace all local data?'), findsNothing);
    },
  );

  testWidgets(
    'passphrase dialog supports a narrow screen with large text and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final portability = _FakePortability(controller);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SettingsScreen(
              controller: controller,
              portability: portability,
            ),
          ),
        ),
      );
      await showSettingsControl(tester, 'Export data');
      await tester.tap(find.text('Export data'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(portability.exportedPassphrases, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed exports show a generic error without exposing implementation details',
    (tester) async {
      final portability = _FakePortability(controller)..failExport = true;
      await showScreen(
        tester,
        SettingsScreen(controller: controller, portability: portability),
      );
      await showSettingsControl(tester, 'Export data');
      await tester.tap(find.text('Export data'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Passphrase'),
        'my backup passphrase',
      );
      await tester.enterText(
        find.byKey(const Key('vault-confirm-passphrase')),
        'my backup passphrase',
      );
      await tester.tap(find.text('Create encrypted backup'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not export data. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('private implementation detail'),
        findsNothing,
      );
    },
  );

  testWidgets('delete all and game history clear each require confirmation', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await controller.createEvent('Keep this', '');
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
    });
    await showScreen(tester, SettingsScreen(controller: controller));

    await showSettingsControl(tester, 'Clear game history');
    await tester.tap(find.text('Clear game history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep history'));
    await tester.pumpAndSettle();
    expect(controller.data.gameRounds, hasLength(1));
    await tester.tap(find.text('Clear game history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear history'));
    await settleAsyncWork(tester);
    expect(controller.data.gameRounds, isEmpty);

    await showSettingsControl(tester, 'Delete all data');
    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep data'));
    await tester.pumpAndSettle();
    expect(controller.data.events, hasLength(1));
    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await settleAsyncWork(tester);
    expect(controller.data.events, isEmpty);
    expect(repository.value.events, isEmpty);
  });

  testWidgets('failed clear and delete-all keep data and show errors', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await controller.createEvent('Keep this', '');
      await controller.recordRound(
        GameRound(
          id: 'round-failure',
          createdAt: DateTime.utc(2026, 11, 5),
          boardId: 0,
          moves: 6,
          backtracks: 0,
          restarts: 0,
          feeling: RoundFeeling.neither,
        ),
      );
    });
    await showScreen(tester, SettingsScreen(controller: controller));

    await showSettingsControl(tester, 'Clear game history');
    await tester.tap(find.text('Clear game history'));
    await tester.pumpAndSettle();
    repository.failNextSave = true;
    await tester.tap(find.text('Clear history'));
    await settleAsyncWork(tester);
    expect(controller.data.gameRounds, hasLength(1));
    expect(find.textContaining('Could not clear game history'), findsOneWidget);

    await showSettingsControl(tester, 'Delete all data');
    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    repository.failNextSave = true;
    await tester.tap(find.text('Delete permanently'));
    await settleAsyncWork(tester);
    expect(controller.data.events.single.title, 'Keep this');
    expect(
      find.textContaining('Deletion could not be fully verified'),
      findsOneWidget,
    );
  });
}
