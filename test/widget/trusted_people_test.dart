import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/people/people_screen.dart';
import 'package:steady_through/model/app_data.dart';

// Only the external storage and OS boundaries are faked. The real controller,
// dialog, navigation, and cards participate in every test.
class _Repository implements AppRepository, ResidualDataRepository {
  _Repository(this.value);
  AppData value;
  bool failNext = false;
  bool failCleanup = false;
  int saves = 0;
  Completer<void>? hold;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    saves++;
    final gate = hold;
    hold = null;
    if (gate != null) await gate.future;
    if (failNext) {
      failNext = false;
      throw StateError('private storage detail');
    }
    value = next;
  }

  @override
  Future<void> purgeResidualData() async {
    if (failCleanup) throw StateError('private cleanup detail');
  }
}

class _Phone implements PhoneActions {
  final calls = <String>[];
  final texts = <String>[];
  bool result = false;
  bool throws = false;
  Completer<bool>? pending;
  Future<bool> _open(String number, List<String> values) async {
    values.add(number);
    if (throws) throw StateError('private handler detail');
    if (pending != null) return pending!.future;
    return result;
  }

  @override
  Future<bool> openPhone(String number) => _open(number, calls);
  @override
  Future<bool> openSms(String number) => _open(number, texts);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1)),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: scrollable,
    maxScrolls: 100,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repository;
  late AppController controller;
  late _Phone phone;
  late List<String> copied;
  bool clipboardFails = false;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    repository = _Repository(
      AppData(
        people: [
          TrustedPerson(id: 'first', name: 'Alex', phone: '555-0100'),
          TrustedPerson(id: 'second', name: 'Sam'),
        ],
      ),
    );
    controller = AppController(repository, repository.value);
    phone = _Phone();
    copied = [];
    clipboardFails = false;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (clipboardFails) throw PlatformException(code: 'unavailable');
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });
  tearDown(() {
    controller.dispose();
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> people(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PeopleScreen(controller: controller, phoneActions: phone),
      ),
    ),
  );
  testWidgets(
    'an Add person dialog captures replacement revision when it opens',
    (tester) async {
      await people(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add person'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Unsaved old document helper',
      );
      await tester.runAsync(() => controller.replaceData(AppData.empty()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save person'));
      await _settle(tester);
      expect(controller.data.people, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
  Future<void> help(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HelpScreen(controller: controller, phoneActions: phone),
      ),
    ),
  );
  testWidgets(
    'optional phone label stays fully readable at 320px and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: PeopleScreen(controller: controller, phoneActions: phone),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.byTooltip('Edit Alex'));
      await tester.tap(find.byTooltip('Edit Alex'));
      await tester.pumpAndSettle();
      final label = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Phone number (optional)'),
          )
          .first;
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse);
      final natural = paragraph.getDryLayout(
        BoxConstraints(maxWidth: paragraph.size.width),
      );
      expect(natural.height, lessThanOrEqualTo(paragraph.size.height + 1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
  Future<void> edit(WidgetTester tester) async {
    await _reveal(tester, find.byTooltip('Edit Alex'));
    await tester.tap(find.byTooltip('Edit Alex'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'source-off Help shows saved people without any automatic handoff',
    (tester) async {
      await help(tester);
      await _reveal(tester, find.text('Your trusted people'));
      await _reveal(tester, find.text('Alex'));
      expect(controller.data.learning.enabledSources, isEmpty);
      expect(controller.activeEvent, isNull);
      expect(phone.calls, isEmpty);
      expect(phone.texts, isEmpty);
      expect(copied, isEmpty);
      await _reveal(tester, find.byTooltip('Call Alex'));
      await tester.tap(find.byTooltip('Call Alex'));
      await _settle(tester);
      expect(phone.calls, ['555-0100']);
      expect(find.textContaining('Could not open a phone app'), findsOneWidget);
      expect(find.text('555-0100'), findsOneWidget);
      await tester.tap(find.byTooltip('Text Alex'));
      await _settle(tester);
      expect(phone.texts, ['555-0100']);
      expect(find.textContaining('Could not open a text app'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy Alex’s number'));
      await _settle(tester);
      expect(copied, ['555-0100']);
      expect(controller.data.learning.examples, isEmpty);
    },
  );

  testWidgets(
    'thrown phone failures and clipboard failures keep a usable number',
    (tester) async {
      phone.throws = true;
      await people(tester);
      await _reveal(tester, find.byTooltip('Call Alex'));
      await tester.tap(find.byTooltip('Call Alex'));
      await _settle(tester);
      expect(find.textContaining('Could not open a phone app'), findsOneWidget);
      clipboardFails = true;
      await tester.tap(find.byTooltip('Copy Alex’s number'));
      await _settle(tester);
      expect(find.textContaining('Could not copy'), findsOneWidget);
      expect(find.text('555-0100'), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('numberless people expose no call text or copy action', (
    tester,
  ) async {
    await people(tester);
    await _reveal(tester, find.text('Sam'));
    expect(find.text('No phone number saved'), findsOneWidget);
    expect(find.byTooltip('Call Sam'), findsNothing);
    expect(find.byTooltip('Text Sam'), findsNothing);
    expect(find.byTooltip('Copy Sam’s number'), findsNothing);
  });

  testWidgets(
    'Help previews first three in order and full People returns to Help',
    (tester) async {
      await tester.runAsync(
        () => controller.replaceData(
          AppData(
            people: [
              TrustedPerson(id: 'a', name: 'First'),
              TrustedPerson(id: 'b', name: 'Second'),
              TrustedPerson(id: 'c', name: 'Third'),
              TrustedPerson(id: 'd', name: 'Fourth'),
            ],
          ),
        ),
      );
      await help(tester);
      await _reveal(tester, find.text('Your trusted people'));
      for (final name in ['First', 'Second', 'Third']) {
        await _reveal(tester, find.text(name));
      }
      expect(find.text('Fourth'), findsNothing);
      await _reveal(tester, find.text('View all saved people'));
      await tester.tap(find.text('View all saved people'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Fourth'));
      expect(find.text('Fourth'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Your trusted people'));
      expect(find.text('Your trusted people'), findsOneWidget);
    },
  );

  testWidgets('empty Help Add person saves without an event or source opt-in', (
    tester,
  ) async {
    await tester.runAsync(() => controller.replaceData(AppData.empty()));
    await help(tester);
    await _reveal(tester, find.text('Add person'));
    await tester.tap(find.text('Add person'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      '  Jo  ',
    );
    await tester.tap(find.text('Save person'));
    await _settle(tester);
    expect(controller.data.people.single.name, 'Jo');
    expect(controller.data.people.single.phone, isNull);
    expect(controller.data.learning.enabledSources, isEmpty);
    expect(controller.activeEvent, isNull);
  });

  testWidgets(
    'edit is prefilled trims values clears phone and preserves order',
    (tester) async {
      await people(tester);
      await edit(tester);
      expect(find.text('Edit person'), findsOneWidget);
      final name = find.widgetWithText(TextFormField, 'Name');
      final number = find.byKey(const ValueKey('person-phone-field'));
      expect(tester.widget<TextFormField>(name).controller!.text, 'Alex');
      expect(tester.widget<TextFormField>(number).controller!.text, '555-0100');
      await tester.enterText(name, '  Alexandra  ');
      await tester.enterText(number, '   ');
      await tester.tap(find.text('Save person'));
      await _settle(tester);
      expect(controller.data.people.map((p) => p.id), ['first', 'second']);
      expect(controller.data.people.first.name, 'Alexandra');
      expect(controller.data.people.first.phone, isNull);
      expect(repository.value.people.first.name, 'Alexandra');
      expect(controller.data.people.last.name, 'Sam');
    },
  );

  testWidgets(
    'blank edit rejects save and Cancel preserves the original record',
    (tester) async {
      final original = controller.data.people.first;
      await people(tester);
      await edit(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), '  ');
      await tester.tap(find.text('Save person'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(repository.saves, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(identical(controller.data.people.first, original), isTrue);
    },
  );

  testWidgets('failed edit retains input and retry commits exactly once', (
    tester,
  ) async {
    await people(tester);
    await edit(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Changed',
    );
    repository.failNext = true;
    await tester.tap(find.text('Save person'));
    await _settle(tester);
    expect(find.textContaining('Could not save this person'), findsOneWidget);
    expect(controller.data.people.first.name, 'Alex');
    expect(find.text('Changed'), findsOneWidget);
    await tester.tap(find.text('Save person'));
    await _settle(tester);
    expect(controller.data.people.first.name, 'Changed');
    expect(repository.saves, 2);
    expect(find.text('Save person'), findsNothing);
  });

  for (final adding in [false, true]) {
    testWidgets(
      '${adding ? 'Add' : 'Edit'} fields stop accepting corrections during a pending save',
      (tester) async {
        await people(tester);
        if (adding) {
          await tester.tap(find.text('Add person'));
          await tester.pumpAndSettle();
        } else {
          await edit(tester);
        }
        final name = find.widgetWithText(TextFormField, 'Name');
        final number = find.byKey(const ValueKey('person-phone-field'));
        await tester.enterText(name, 'Submitted helper');
        await tester.enterText(number, '555-0133');
        final gate = Completer<void>();
        repository.hold = gate;
        // Edit covers retry after failure; Add covers successful dismissal.
        repository.failNext = !adding;
        await tester.tap(find.text('Save person'));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        try {
          for (final field in [name, number]) {
            await tester.tap(field);
            await tester.pump();
            expect(
              tester.testTextInput.hasAnyClients,
              isFalse,
              reason: 'Pending submitted fields must not accept new typing.',
            );
          }
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
                .onPressed,
            isNotNull,
          );
        } finally {
          gate.complete();
          await _settle(tester);
        }
        if (adding) {
          expect(find.text('Save person'), findsNothing);
          expect(controller.data.people.last.name, 'Submitted helper');
          expect(controller.data.people.last.phone, '555-0133');
        } else {
          expect(
            find.textContaining('Could not save this person'),
            findsOneWidget,
          );
          expect(controller.data.people.first.name, 'Alex');
          await tester.enterText(name, 'Retry correction');
          await tester.enterText(number, '555-0144');
          await tester.tap(find.text('Save person'));
          await _settle(tester);
          expect(controller.data.people.first.name, 'Retry correction');
          expect(controller.data.people.first.phone, '555-0144');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending edit disables duplicate save but Cancel stays available',
    (tester) async {
      await people(tester);
      await edit(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Changed',
      );
      final gate = Completer<void>();
      repository.hold = gate;
      await tester.tap(find.text('Save person'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save person'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      gate.complete();
      await _settle(tester);
      expect(repository.saves, 1);
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Save person'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceled queued edit cannot write after an unrelated save', (
    tester,
  ) async {
    await people(tester);
    await edit(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Stale');
    final gate = Completer<void>();
    repository.hold = gate;
    final theme = controller.setTheme(ThemeChoice.dark);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.tap(find.text('Save person'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    gate.complete();
    await tester.runAsync(() async {
      await theme;
      await controller.flush();
    });
    await tester.pumpAndSettle();
    expect(controller.data.people.first.name, 'Alex');
    expect(controller.data.theme, ThemeChoice.dark);
    expect(repository.saves, 1);
  });

  testWidgets('backgrounding invalidates an open edit until it is reopened', (
    tester,
  ) async {
    await people(tester);
    await edit(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Stale');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.text('Save person'));
    await _settle(tester);
    expect(repository.saves, 0);
    expect(controller.data.people.first.name, 'Alex');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await edit(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Fresh');
    await tester.tap(find.text('Save person'));
    await _settle(tester);
    expect(controller.data.people.first.name, 'Fresh');
  });

  testWidgets('same-ID import cannot be overwritten by the old edit dialog', (
    tester,
  ) async {
    await people(tester);
    await edit(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Stale');
    await tester.runAsync(
      () => controller.replaceData(
        AppData(
          people: [
            TrustedPerson(id: 'first', name: 'Imported', phone: '555-0199'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save person'));
    await _settle(tester);
    expect(controller.data.people.single.name, 'Imported');
    expect(controller.data.people.single.phone, '555-0199');
    expect(repository.saves, 1);
  });

  testWidgets(
    'same-ID import cannot be deleted by the old remove confirmation',
    (tester) async {
      await people(tester);
      await _reveal(tester, find.byTooltip('Remove Alex'));
      await tester.tap(find.byTooltip('Remove Alex'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => controller.replaceData(
          AppData(
            people: [TrustedPerson(id: 'first', name: 'Imported')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove person'));
      await _settle(tester);
      expect(controller.data.people.single.name, 'Imported');
      expect(
        find.textContaining('Could not remove this person'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Help refreshes after a live import and launches only the new number',
    (tester) async {
      await help(tester);
      await _reveal(tester, find.text('Alex'));
      await tester.runAsync(
        () => controller.replaceData(
          AppData(
            people: [
              TrustedPerson(id: 'first', name: 'New Alex', phone: '555-0199'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.byTooltip('Call New Alex'));
      expect(find.text('Alex'), findsNothing);
      await tester.tap(find.byTooltip('Call New Alex'));
      await _settle(tester);
      expect(phone.calls, ['555-0199']);
    },
  );

  testWidgets(
    'pending phone handoff suppresses duplicate taps and late feedback',
    (tester) async {
      phone.pending = Completer<bool>();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: PeopleScreen(controller: controller, phoneActions: phone),
          ),
        ),
      );
      await _reveal(tester, find.byTooltip('Call Alex'));
      await tester.tap(find.byTooltip('Call Alex'));
      await tester.pump();
      await tester.tap(find.byTooltip('Call Alex'), warnIfMissed: false);
      await tester.pump();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another view')),
        ),
      );
      await tester.pumpAndSettle();
      phone.pending!.complete(false);
      await _settle(tester);
      expect(phone.calls, ['555-0100']);
      expect(find.text('Another view'), findsOneWidget);
      expect(find.textContaining('Could not open'), findsNothing);
    },
  );

  testWidgets(
    'committed edit cleanup warning closes form without inviting retry',
    (tester) async {
      repository.failCleanup = true;
      await people(tester);
      await edit(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Saved',
      );
      await tester.tap(find.text('Save person'));
      await _settle(tester);
      expect(controller.data.people.first.name, 'Saved');
      expect(
        controller.cleanupWarning,
        contains('Older local copies may remain'),
      );
      expect(find.text('Save person'), findsNothing);
      expect(find.textContaining('Could not save'), findsNothing);
      expect(repository.saves, 1);
    },
  );

  testWidgets(
    'Help cards and edit controls fit 320px at 200 percent with Simple words',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => controller.setReadingStyle(ReadingStyle.simple),
      );
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
            body: HelpScreen(
              controller: controller,
              simpleWords: true,
              phoneActions: phone,
            ),
          ),
        ),
      );
      await _reveal(tester, find.text('View all saved people'));
      await tester.tap(find.text('View all saved people'));
      await tester.pumpAndSettle();
      await edit(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(phone.calls, isEmpty);
      expect(copied, isEmpty);
    },
  );
}
