import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/event_guidance.dart';

class _Repository implements AppRepository {
  AppData value = AppData.empty();
  bool fail = false;
  int saves = 0;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    if (fail) throw StateError('Unavailable');
    value = next;
    saves++;
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () async => Future<void>.delayed(const Duration(milliseconds: 1)),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final dialog = find.byType(AlertDialog);
  final scrollable = dialog.evaluate().isNotEmpty
      ? find.descendant(of: dialog, matching: find.byType(Scrollable)).first
      : find.byType(Scrollable).first;
  for (var scroll = 0; target.evaluate().isEmpty && scroll < 25; scroll++) {
    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  expect(
    target,
    findsWidgets,
    reason: 'Missing reachable control or content $target',
  );
  await tester.ensureVisible(target.last);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await _reveal(tester, find.text(label));
  expect(
    find.text(label),
    findsWidgets,
    reason: 'Missing visible control $label',
  );
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _createForm(WidgetTester tester, AppController controller) async {
  await tester.pumpWidget(SteadyThroughApp(controller: controller));
  await _tap(tester, 'Create event');
  await tester.enterText(find.byType(TextFormField).at(0), 'A fictional move');
}

Future<void> _chooseGuide(WidgetTester tester, String guide) async {
  await _tap(tester, 'Choose guide');
  await _tap(tester, guide);
  await _tap(tester, 'Use guide');
}

void _expectSelectedCount(WidgetTester tester, int count) {
  final counter = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('$count ${count == 1 ? 'step' : 'steps'} selected'),
  );
  expect(counter, findsOneWidget);
  expect(counter.hitTestable(), findsOneWidget);
  expect(
    find.ancestor(of: counter, matching: find.byType(Scrollable)),
    findsNothing,
    reason: 'The count must stay visible while the starter rows scroll',
  );
  expect(
    tester
        .widget<Semantics>(
          find.ancestor(of: counter, matching: find.byType(Semantics)).first,
        )
        .properties
        .liveRegion,
    isTrue,
  );
}

void main() {
  late _Repository repository;
  late AppController controller;
  setUp(() {
    repository = _Repository();
    controller = AppController(repository, AppData.empty());
  });
  tearDown(() => controller.dispose());

  testWidgets('creation deliberately chooses a guide and a subset of steps', (
    tester,
  ) async {
    await _createForm(tester, controller);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Temporary details',
    );
    await _chooseGuide(tester, 'Adult life changes');
    expect(find.text('5 starter steps selected'), findsOneWidget);
    await _tap(tester, 'Choose starter steps');
    _expectSelectedCount(tester, 5);
    final steps = guideFor(GuidanceContext.adultChanges).starterSteps;
    for (final step in steps.skip(1)) {
      await _tap(tester, step.title);
    }
    _expectSelectedCount(tester, 1);
    await _tap(tester, 'Use selected steps');
    expect(find.text('1 starter step selected'), findsOneWidget);
    expect(controller.activeEvent, isNull);
    await _tap(tester, 'Save event');
    await _settle(tester);
    final event = controller.activeEvent!;
    expect(event.guidanceContext, GuidanceContext.adultChanges);
    expect(event.description, 'Temporary details');
    expect(event.actions.map((action) => action.title), [steps.first.title]);
    expect(repository.saves, 1);
  });

  testWidgets('empty starter selection gives a next-step invitation on Home', (
    tester,
  ) async {
    await _createForm(tester, controller);
    await _tap(tester, 'Choose starter steps');
    for (final step in guideFor(GuidanceContext.general).starterSteps) {
      await _tap(tester, step.title);
    }
    _expectSelectedCount(tester, 0);
    await _tap(tester, 'Use selected steps');
    expect(find.text('0 starter steps selected'), findsOneWidget);
    await _tap(tester, 'Save event');
    await _settle(tester);
    expect(controller.activeEvent!.actions, isEmpty);
    await _tap(tester, 'Home');
    expect(
      find.text('Choose a starter step or add your own in Path.'),
      findsOneWidget,
    );
    expect(find.textContaining('All actions are done.'), findsNothing);
    await tester.runAsync(
      () => controller.setReadingStyle(ReadingStyle.simple),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add a step in Path when you are ready.'), findsOneWidget);
  });

  testWidgets(
    'same-guide confirmation and both picker cancellations preserve choices',
    (tester) async {
      await _createForm(tester, controller);
      await _tap(tester, 'Choose starter steps');
      await _tap(tester, 'Take a short pause');
      await _tap(tester, 'Use selected steps');
      await _chooseGuide(tester, 'General');
      expect(find.text('4 starter steps selected'), findsOneWidget);
      await _tap(tester, 'Choose guide');
      await _tap(tester, 'Later life changes');
      await _tap(tester, 'Cancel');
      expect(find.text('General'), findsOneWidget);
      expect(find.text('4 starter steps selected'), findsOneWidget);
      await _tap(tester, 'Choose starter steps');
      await _tap(tester, 'Notice what needs attention first');
      await _tap(tester, 'Cancel');
      expect(find.text('4 starter steps selected'), findsOneWidget);
      await _chooseGuide(tester, 'Later life changes');
      expect(find.text('5 starter steps selected'), findsOneWidget);
    },
  );

  testWidgets('editing changes only the guide and retains saved done actions', (
    tester,
  ) async {
    await tester.runAsync(() => controller.createEvent('Fictional event', ''));
    final before = controller.activeEvent!;
    await tester.runAsync(
      () => controller.setActionDone(before.id, before.actions.first.id, true),
    );
    final savedActions = controller.activeEvent!.actions
        .map((action) => action.toJson())
        .toList();
    await tester.pumpWidget(SteadyThroughApp(controller: controller));
    await _tap(tester, 'Path');
    await _tap(tester, 'Edit event');
    await _reveal(tester, find.text('Your saved steps stay as they are.'));
    expect(find.text('Your saved steps stay as they are.'), findsOneWidget);
    expect(find.text('Choose starter steps'), findsNothing);
    await _chooseGuide(tester, 'Caring for someone');
    await _tap(tester, 'Save event');
    await _settle(tester);
    expect(controller.activeEvent!.guidanceContext, GuidanceContext.caregiving);
    expect(
      controller.activeEvent!.actions.map((action) => action.toJson()).toList(),
      savedActions,
    );
    expect(
      find.text(
        guideFor(GuidanceContext.caregiving)
            .stagePrompt(JourneyStage.orient, simpleWords: false),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Path disables existing standard or simple matches and batches new steps once',
    (tester) async {
      final guide = guideFor(GuidanceContext.adultChanges);
      await tester.runAsync(
        () => controller.createEvent(
          'Fictional event',
          '',
          guidanceContext: guide.context,
          starterStepIds: [],
        ),
      );
      await tester.runAsync(
        () => controller.addAction(
          controller.activeEvent!.id,
          guide.starterSteps.first.stage,
          guide.starterSteps.first.simpleTitle,
        ),
      );
      await tester.pumpWidget(SteadyThroughApp(controller: controller));
      await _tap(tester, 'Path');
      await _tap(tester, 'Choose starter steps');
      final existing = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, guide.starterSteps.first.title),
      );
      expect(existing.onChanged, isNull);
      expect(existing.value, isFalse);
      expect(find.text('Already in your path'), findsOneWidget);
      _expectSelectedCount(tester, 0);
      await _tap(tester, guide.starterSteps[1].title);
      _expectSelectedCount(tester, 1);
      await _tap(tester, guide.starterSteps[1].title);
      _expectSelectedCount(tester, 0);
      await _tap(tester, guide.starterSteps[1].title);
      await _tap(tester, guide.starterSteps[2].title);
      _expectSelectedCount(tester, 2);
      final saves = repository.saves;
      await _tap(tester, 'Use selected steps');
      await _settle(tester);
      expect(repository.saves, saves + 1);
      expect(controller.activeEvent!.actions.length, 3);
      expect(
        controller.activeEvent!.actions.first.title,
        guide.starterSteps.first.simpleTitle,
      );
    },
  );

  testWidgets(
    'each switched event keeps its own guide and contextual prompts',
    (tester) async {
      await tester.runAsync(
        () => controller.createEvent(
          'School fiction',
          '',
          guidanceContext: GuidanceContext.schoolAndGrowing,
        ),
      );
      await tester.runAsync(
        () => controller.createEvent(
          'Later fiction',
          '',
          guidanceContext: GuidanceContext.laterLife,
        ),
      );
      await tester.pumpWidget(SteadyThroughApp(controller: controller));
      expect(find.text('Later life changes'), findsOneWidget);
      await _tap(tester, 'Switch event');
      await _tap(tester, 'School fiction');
      await _settle(tester);
      expect(find.text('School & growing up'), findsOneWidget);
      await _tap(tester, 'Path');
      expect(
        find.text(
          guideFor(GuidanceContext.schoolAndGrowing)
              .stagePrompt(JourneyStage.orient, simpleWords: false),
        ),
        findsOneWidget,
      );
      expect(find.text('School & growing up'), findsOneWidget);
    },
  );

  testWidgets(
    'Simple words uses catalog labels, helper copy, and starter text',
    (tester) async {
      await tester.runAsync(
        () => controller.setReadingStyle(ReadingStyle.simple),
      );
      await _createForm(tester, controller);
      await _chooseGuide(tester, 'School and growing up');
      final guide = guideFor(GuidanceContext.schoolAndGrowing);
      expect(find.text(guide.simpleDescription), findsOneWidget);
      expect(find.text(guide.simpleHelperNote), findsOneWidget);
      await _tap(tester, 'Choose starter steps');
      _expectSelectedCount(tester, 5);
      expect(find.text(guide.starterSteps.first.simpleTitle), findsOneWidget);
      expect(find.text(guide.starterSteps.first.title), findsNothing);
      await _tap(tester, 'Use selected steps');
      await _tap(tester, 'Save event');
      await _settle(tester);
      expect(
        controller.activeEvent!.actions.first.title,
        guide.starterSteps.first.simpleTitle,
      );
    },
  );

  testWidgets(
    'failed creation and batch saves keep visible choices available for retry',
    (tester) async {
      await _createForm(tester, controller);
      await _chooseGuide(tester, 'Adult life changes');
      repository.fail = true;
      await _tap(tester, 'Save event');
      await _settle(tester);
      expect(find.text('Create event'), findsOneWidget);
      expect(
        find.text('The event could not be saved. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Adult life changes'), findsOneWidget);
      expect(controller.activeEvent, isNull);
      repository.fail = false;
      await _tap(tester, 'Save event');
      await _settle(tester);
      await tester.runAsync(
        () => controller.removeAction(
          controller.activeEvent!.id,
          controller.activeEvent!.actions.last.id,
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Choose starter steps');
      await _tap(
        tester,
        guideFor(GuidanceContext.adultChanges).starterSteps.last.title,
      );
      repository.fail = true;
      await _tap(tester, 'Use selected steps');
      await _settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('The steps could not be saved. Please try again.'),
        findsOneWidget,
      );
      expect(controller.activeEvent!.actions.length, 4);
      repository.fail = false;
      await _tap(tester, 'Use selected steps');
      await _settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(controller.activeEvent!.actions.length, 5);
    },
  );

  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'guide controls wrap, scroll, expose checked semantics and support keyboard at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = width == 320
            ? 2
            : 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final semantics = tester.ensureSemantics();
        try {
          await _createForm(tester, controller);
          await _tap(tester, 'Choose guide');
          await _tap(tester, 'Later life changes');
          final radio = find.widgetWithText(
            RadioListTile<GuidanceContext>,
            'Later life changes',
          );
          expect(
            tester
                .getSemantics(radio)
                .getSemanticsData()
                .flagsCollection
                .isChecked,
            CheckedState.isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          await _chooseGuide(tester, 'School & growing up');
          await _tap(tester, 'Choose starter steps');
          _expectSelectedCount(tester, 5);
          final first = find.widgetWithText(
            CheckboxListTile,
            'Choose something on your mind',
          );
          await tester.ensureVisible(first);
          expect(
            tester
                .getSemantics(first)
                .getSemanticsData()
                .flagsCollection
                .isChecked,
            CheckedState.isTrue,
          );
          var keyboardReachedStep = false;
          for (var traversal = 0; traversal < 20; traversal++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
            final focusedTile = FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<CheckboxListTile>();
            if (focusedTile?.title is Text &&
                (focusedTile!.title as Text).data ==
                    'Choose something on your mind') {
              keyboardReachedStep = true;
              await tester.sendKeyEvent(LogicalKeyboardKey.space);
              await tester.pumpAndSettle();
              break;
            }
          }
          expect(
            keyboardReachedStep,
            isTrue,
            reason: 'Starter rows must be reachable with Tab',
          );
          expect(tester.widget<CheckboxListTile>(first).value, isFalse);
          _expectSelectedCount(tester, 4);
          await _tap(tester, 'Notice what you tried');
          _expectSelectedCount(tester, 3);
          await _tap(tester, 'Use selected steps');
          expect(find.text('3 starter steps selected'), findsOneWidget);
          await _tap(tester, 'Save event');
          await _settle(tester);
          expect(controller.activeEvent!.actions.length, 3);
          expect(
            width == 320 ? find.byTooltip('Help now') : find.text('Help now'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
