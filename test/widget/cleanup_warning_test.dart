import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/data/data_portability.dart';
import 'package:steady_through/features/insights/insights_screen.dart';
import 'package:steady_through/features/settings/settings_screen.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';

class _Repository implements AppRepository, ResidualDataRepository {
  _Repository(this.value);
  AppData value;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async => value = next;
  @override
  Future<void> purgeResidualData() async => throw StateError('cleanup failed');
}

class _Archive extends DataPortabilityGateway {
  @override
  Future<Uint8List?> pickJsonBytes() async => Uint8List.fromList(
    utf8.encode(
      jsonEncode(
        AppData(
          people: [TrustedPerson(id: 'p', name: 'Alex')],
        ).toJson(),
      ),
    ),
  );
  @override
  Future<Uri?> saveJsonFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async => null;
}

AppData _initial() {
  final at = DateTime.now().toUtc().subtract(const Duration(days: 181));
  return AppData(
    learning: LearningData(
      examples: [
        LearningExample(
          id: 'old',
          createdAt: at,
          label: FeelingLabel.calm,
          snapshot: SignalSnapshot(observedAt: at),
        ),
      ],
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1)),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, String label) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(label),
    300,
    maxScrolls: 100,
    scrollable: scrollable,
  );
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  late _Repository repository;
  late AppController controller;
  setUp(() {
    repository = _Repository(_initial());
    controller = AppController(repository, repository.value);
  });
  tearDown(() => controller.dispose());

  testWidgets(
    'committed event closes the form and warns without inviting duplicate retry',
    (tester) async {
      await tester.pumpWidget(SteadyThroughApp(controller: controller));
      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'New job');
      await tester.tap(find.text('Save event'));
      await _settle(tester);
      expect(controller.data.events.single.title, 'New job');
      expect(find.text('Save event'), findsNothing);
      expect(find.textContaining('could not be saved'), findsNothing);
      expect(
        find.textContaining('Older local copies may remain'),
        findsOneWidget,
      );
      await tester.tap(find.text('Help now').first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Older local copies may remain'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'import feedback acknowledges committed records and residual copies',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              controller: controller,
              portability: DataPortability(controller, gateway: _Archive()),
            ),
          ),
        ),
      );
      await _reveal(tester, 'Import data');
      await tester.tap(find.text('Import data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace all data'));
      await _settle(tester);
      expect(controller.data.people.single.name, 'Alex');
      expect(repository.value.people.single.name, 'Alex');
      expect(find.textContaining('Data imported.'), findsOneWidget);
      expect(
        find.textContaining('Older local copies may remain'),
        findsOneWidget,
      );
      expect(find.textContaining('current data was kept'), findsNothing);
    },
  );

  testWidgets(
    'delete feedback acknowledges cleared active records and residual copies',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SettingsScreen(controller: controller)),
        ),
      );
      await _reveal(tester, 'Delete all data');
      await tester.tap(find.text('Delete all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await _settle(tester);
      expect(controller.data.learning.examples, isEmpty);
      expect(
        find.textContaining('cleared from the active vault'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Older local copies may remain'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'learning clear feedback reports committed clear with a cleanup warning',
    (tester) async {
      final session = LearningSession(controller);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: InsightsScreen(session: session)),
          ),
        );
        await _reveal(tester, 'Clear learning');
        await tester.tap(find.text('Clear learning'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear learning').last);
        await _settle(tester);
        expect(session.data.examples, isEmpty);
        expect(session.data.enabledSources, isEmpty);
        // The inline result sits near the top of this lazy list. The clear
        // control is near the bottom, so return to the result before reading.
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('Learning cleared.'),
          300,
          maxScrolls: 100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Learning cleared.'), findsOneWidget);
        expect(
          find.textContaining('Older local copies may remain'),
          findsOneWidget,
        );
        expect(
          find.textContaining('could not be fully verified'),
          findsNothing,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(session.close);
        await tester.pump();
      }
    },
  );

  testWidgets(
    'cleanup warning wraps at narrow enlarged text and offers lock retry',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(controller.clearLearning);
      var locks = 0;
      await tester.pumpWidget(
        SteadyThroughApp(
          controller: controller,
          onLock: () async {
            locks++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Older local copies may remain'),
        findsOneWidget,
      );
      expect(find.textContaining('unlock'), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Help now'), findsOneWidget);
      await tester.tap(find.byTooltip('Help now'));
      await tester.pumpAndSettle();
      expect(find.text('Help now'), findsWidgets);
      expect(
        find.textContaining('Older local copies may remain'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Lock vault').first);
      await tester.tap(find.text('Lock vault').first);
      await tester.pumpAndSettle();
      expect(locks, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
