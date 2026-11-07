import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/check_ins/check_ins_screen.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/journey/journey_screen.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_theme.dart';

// Only persistence is delayed. Validation, queued mutations and form behavior
// are production code; a failed save must not commit or discard corrected input.
class _DeferredRepository implements AppRepository {
  _DeferredRepository(this.value);
  AppData value;
  Completer<void>? pending;
  int attempts = 0;
  int commits = 0;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    attempts++;
    await pending?.future;
    value = next;
    commits++;
  }
}

AppData _eventData() => AppData(
  activeEventId: 'event',
  events: [
    SupportEvent(
      id: 'event',
      title: 'Fictional original event',
      description: 'Original details',
      createdAt: DateTime.utc(2026, 11, 6),
      actions: [
        PlanAction(
          id: 'action',
          stage: JourneyStage.orient,
          title: 'Original action',
        ),
      ],
    ),
  ],
);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 1)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

String _text(WidgetTester tester, int index) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).at(index),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

// An actual keyboard edit is attempted only when the focused field has an input
// connection. Read-only fields correctly close that connection. Inspecting the
// visible controller value also catches an editable field accepting lost text.
Future<void> _tryTyping(
  WidgetTester tester,
  int index,
  String attempted,
  String expected,
) async {
  await _tap(tester, find.byType(TextFormField).at(index));
  if (tester.testTextInput.hasAnyClients) {
    tester.testTextInput.enterText(attempted);
    await tester.pump();
  }
  expect(
    _text(tester, index),
    expected,
    reason: 'A pending submission must not accept an unsaved correction.',
  );
}

Future<void> _show(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1200));
  await tester.pumpWidget(
    MaterialApp(theme: steadyTheme(Brightness.light), home: screen),
  );
  await tester.pumpAndSettle();
}

Future<void> _showFormRoute(WidgetTester tester, Widget form) async {
  await _show(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .push<void>(MaterialPageRoute<void>(builder: (_) => form)),
          child: const Text('Open fictional form'),
        ),
      ),
    ),
  );
  await _tap(tester, find.text('Open fictional form'));
  await tester.pumpAndSettle();
}

Future<void> _cleanup(
  WidgetTester tester,
  Completer<void> barrier, [
  AppController? controller,
]) async {
  // RED assertions may exit before the intended release. Never leave a save or
  // vault callback blocked, even when that assertion correctly exposes the bug.
  if (!barrier.isCompleted) barrier.complete();
  await _settle(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await controller?.flush();
  controller?.dispose();
  await tester.binding.setSurfaceSize(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final creating in [true, false]) {
    testWidgets(
      '${creating ? 'create' : 'unlock'} vault freezes submitted phrase and restores corrected retry after failure',
      (tester) async {
        final barrier = Completer<void>();
        final attempts = <String>[];
        var successes = 0;
        await _show(
          tester,
          VaultUnlockScreen(
            creating: creating,
            onSubmit: (phrase) async {
              attempts.add(phrase);
              if (attempts.length == 1) await barrier.future;
              successes++;
            },
          ),
        );
        try {
          await tester.enterText(
            find.byType(TextFormField).first,
            'fictional original phrase',
          );
          if (creating) {
            await tester.enterText(
              find.byKey(const ValueKey('vault-confirmation-field')),
              'fictional original phrase',
            );
          }
          final save = find.text(
            creating ? 'Create private vault' : 'Unlock vault',
          );
          await _tap(tester, save);
          await _tryTyping(
            tester,
            0,
            'fictional lost correction',
            'fictional original phrase',
          );
          if (creating) {
            await _tryTyping(
              tester,
              1,
              'fictional lost correction',
              'fictional original phrase',
            );
          }
          await _tap(tester, save);
          expect(attempts, ['fictional original phrase']);
          barrier.completeError(StateError('Fictional vault failure'));
          await _settle(tester);
          expect(successes, 0);
          expect(
            find.textContaining(
              creating
                  ? 'The vault could not be created.'
                  : 'The vault could not be opened.',
            ),
            findsOneWidget,
          );
          await tester.enterText(
            find.byType(TextFormField).first,
            'fictional corrected phrase',
          );
          if (creating) {
            await tester.enterText(
              find.byKey(const ValueKey('vault-confirmation-field')),
              'fictional corrected phrase',
            );
          }
          await _tap(tester, save);
          await _settle(tester);
          expect(attempts, [
            'fictional original phrase',
            'fictional corrected phrase',
          ]);
          expect(successes, 1);
          expect(_text(tester, 0), isEmpty);
          if (creating) expect(_text(tester, 1), isEmpty);
        } finally {
          await _cleanup(tester, barrier);
        }
      },
    );
  }

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'edit' : 'create'} event freezes submitted fields and choices and restores corrected retry',
      (tester) async {
        final initial = editing ? _eventData() : AppData.empty();
        final repository = _DeferredRepository(initial);
        final controller = AppController(repository, initial);
        final barrier = Completer<void>();
        repository.pending = barrier;
        final submissions = <EventFormSubmission>[];
        await _showFormRoute(
          tester,
          EventForm(
            event: editing ? controller.activeEvent : null,
            onSave: (submission) {
              submissions.add(submission);
              return editing
                  ? controller.updateEvent(
                      'event',
                      submission.title,
                      submission.description,
                      guidanceContext: submission.guidanceContext,
                    )
                  : controller.createEvent(
                      submission.title,
                      submission.description,
                      guidanceContext: submission.guidanceContext,
                      starterStepIds: submission.starterStepIds,
                    );
            },
          ),
        );
        try {
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'Fictional submitted event',
          );
          await tester.enterText(
            find.byKey(const ValueKey('event-description-field')),
            'Submitted details',
          );
          await _tap(tester, find.text('Save event'));
          await _tryTyping(
            tester,
            0,
            'Lost event correction',
            'Fictional submitted event',
          );
          await _tryTyping(
            tester,
            1,
            'Lost detail correction',
            'Submitted details',
          );
          // Guide/starter controls are deliberately unavailable throughout save.
          expect(find.text('Choose guide'), findsNothing);
          expect(find.text('Choose starter steps'), findsNothing);
          expect(submissions, hasLength(1));
          barrier.completeError(StateError('Fictional event failure'));
          await _settle(tester);
          expect(repository.commits, 0);
          expect(controller.data.events.length, editing ? 1 : 0);
          expect(
            find.textContaining('The event could not be saved.'),
            findsOneWidget,
          );
          await _tap(tester, find.text('Choose guide'));
          await tester.pumpAndSettle();
          await _tap(tester, find.text('Adult life changes'));
          await _tap(tester, find.text('Use guide'));
          await tester.pumpAndSettle();
          if (!editing) {
            await _tap(tester, find.text('Choose starter steps'));
            await tester.pumpAndSettle();
            final firstChoice = find.byType(CheckboxListTile).first;
            await _tap(tester, firstChoice);
            await _tap(tester, find.text('Use selected steps'));
            await tester.pumpAndSettle();
          }
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'Fictional corrected event',
          );
          await tester.enterText(
            find.byKey(const ValueKey('event-description-field')),
            'Corrected details',
          );
          repository.pending = null;
          await _tap(tester, find.text('Save event'));
          await _settle(tester);
          expect(find.text('Open fictional form'), findsOneWidget);
          expect(repository.attempts, 2);
          expect(repository.commits, 1);
          expect(submissions, hasLength(2));
          final saved = controller.activeEvent!;
          expect(saved.title, 'Fictional corrected event');
          expect(saved.description, 'Corrected details');
          expect(saved.guidanceContext, GuidanceContext.adultChanges);
          expect(saved.actions.length, editing ? 1 : 4);
          if (editing) {
            expect(saved.actions.single.id, 'action');
            expect(saved.actions.single.title, 'Original action');
          }
        } finally {
          await _cleanup(tester, barrier, controller);
        }
      },
    );
  }

  for (final editing in [false, true]) {
    testWidgets(
      '${editing ? 'edit' : 'add'} action freezes submitted text and restores corrected retry',
      (tester) async {
        final initial = _eventData();
        final repository = _DeferredRepository(initial);
        final controller = AppController(repository, initial);
        final barrier = Completer<void>();
        repository.pending = barrier;
        await _show(
          tester,
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) => Scaffold(
              body: JourneyScreen(
                controller: controller,
                onCreateEvent: () {},
                onEditEvent: (_) {},
                onDeleted: () {},
              ),
            ),
          ),
        );
        try {
          await _tap(
            tester,
            editing
                ? find.byTooltip('Edit Original action')
                : find.text('Add action').first,
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextFormField),
            'Fictional submitted action',
          );
          await _tap(tester, find.text('Save action'));
          await _tryTyping(
            tester,
            0,
            'Lost action correction',
            'Fictional submitted action',
          );
          await _tap(tester, find.text('Save action'));
          expect(repository.attempts, 1);
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
                .onPressed,
            isNull,
          );
          barrier.completeError(StateError('Fictional action failure'));
          await _settle(tester);
          expect(repository.commits, 0);
          expect(
            controller.activeEvent!.actions.single.title,
            'Original action',
          );
          expect(
            find.textContaining('The action could not be saved.'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
                .onPressed,
            isNotNull,
          );
          await tester.enterText(
            find.byType(TextFormField),
            'Fictional corrected action',
          );
          repository.pending = null;
          await _tap(tester, find.text('Save action'));
          await _settle(tester);
          expect(find.byType(AlertDialog), findsNothing);
          expect(repository.attempts, 2);
          expect(repository.commits, 1);
          final actions = controller.activeEvent!.actions;
          expect(actions, hasLength(editing ? 1 : 2));
          expect(actions.last.title, 'Fictional corrected action');
          if (editing) expect(actions.single.id, 'action');
        } finally {
          await _cleanup(tester, barrier, controller);
        }
      },
    );
  }

  testWidgets(
    'check-in freezes text and intensity and restores corrected retry',
    (tester) async {
      final initial = _eventData();
      final repository = _DeferredRepository(initial);
      final controller = AppController(repository, initial);
      final barrier = Completer<void>();
      repository.pending = barrier;
      await _show(
        tester,
        Scaffold(body: CheckInsScreen(controller: controller)),
      );
      try {
        await _tap(tester, find.text('Add check-in'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Fictional submitted feeling',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Submitted note',
        );
        await _tap(tester, find.widgetWithText(ChoiceChip, '2'));
        await _tap(tester, find.text('Save check-in'));
        await _tryTyping(
          tester,
          0,
          'Lost feeling correction',
          'Fictional submitted feeling',
        );
        await _tryTyping(tester, 1, 'Lost note correction', 'Submitted note');
        await _tap(tester, find.widgetWithText(ChoiceChip, '5'));
        await _tap(tester, find.widgetWithText(ChoiceChip, 'No number'));
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '2'))
              .selected,
          isTrue,
        );
        await _tap(tester, find.text('Save check-in'));
        expect(repository.attempts, 1);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
              .onPressed,
          isNull,
        );
        barrier.completeError(StateError('Fictional check-in failure'));
        await _settle(tester);
        expect(repository.commits, 0);
        expect(controller.data.checkIns, isEmpty);
        expect(
          find.textContaining('Could not save this check-in.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
              .onPressed,
          isNotNull,
        );
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Fictional corrected feeling',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Corrected note',
        );
        await _tap(tester, find.widgetWithText(ChoiceChip, '4'));
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '4'))
              .selected,
          isTrue,
        );
        repository.pending = null;
        await _tap(tester, find.text('Save check-in'));
        await _settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(repository.attempts, 2);
        expect(repository.commits, 1);
        final saved = controller.data.checkIns.single;
        expect(saved.eventId, 'event');
        expect(saved.feeling, 'Fictional corrected feeling');
        expect(saved.note, 'Corrected note');
        expect(saved.intensity, 4);
      } finally {
        await _cleanup(tester, barrier, controller);
      }
    },
  );
}
