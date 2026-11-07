// Run: flutter test --update-goldens tool/capture_reliable_forms_ui_test.dart
// Twenty-one actual-widget captures: seven fictional states in three profiles.
// Memory/deferred persistence only; no vault, grant, external handler or real
// clipboard access. These images are visual evidence, not native validation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/check_ins/check_ins_screen.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/journey/journey_screen.dart';
import 'package:steady_through/features/people/phone_actions.dart';
import 'package:steady_through/features/vault/passphrase_dialog.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_theme.dart';

class _Repository implements AppRepository {
  _Repository(this.value);
  AppData value;
  Completer<void>? pending;
  int attempts = 0;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    attempts++;
    await pending?.future;
    value = next;
  }
}

class _NoHandoff implements PhoneActions {
  @override
  Future<bool> openPhone(String number) async =>
      throw StateError('A capture must not open an external phone app.');
  @override
  Future<bool> openSms(String number) async =>
      throw StateError('A capture must not open an external message app.');
}

class _Profile {
  const _Profile(
    this.name,
    this.size, {
    this.dark = false,
    this.simple = false,
    this.scale = 1,
  });
  final String name;
  final Size size;
  final bool dark;
  final bool simple;
  final double scale;
}

AppData _fictionalData(_Profile profile) => AppData(
  theme: profile.dark ? ThemeChoice.dark : ThemeChoice.light,
  readingStyle: profile.simple ? ReadingStyle.simple : ReadingStyle.standard,
  activeEventId: 'fictional-reliable-event',
  events: [
    SupportEvent(
      id: 'fictional-reliable-event',
      title: 'Settling into a new routine',
      createdAt: DateTime.utc(2026, 11, 6),
      actions: [
        PlanAction(
          id: 'fictional-reliable-action',
          stage: JourneyStage.orient,
          title: 'Choose one small task',
        ),
      ],
    ),
  ],
);

Widget _app(_Profile profile, String scene, Widget home) => MaterialApp(
  key: ValueKey('$scene-${profile.name}'),
  debugShowCheckedModeBanner: false,
  theme: steadyTheme(Brightness.light),
  darkTheme: steadyTheme(Brightness.dark),
  themeMode: profile.dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(profile.scale),
      disableAnimations: profile.simple,
      accessibleNavigation: profile.simple,
    ),
    child: child!,
  ),
  home: home,
);

// Bound every pump: the genuine pending vault has an indeterminate spinner.
Future<void> _frame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final dialogScrollables = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(Scrollable),
  );
  final scrollables = dialogScrollables.evaluate().isNotEmpty
      ? dialogScrollables
      : find.byType(Scrollable);
  for (var attempt = 0; target.evaluate().isEmpty && attempt < 50; attempt++) {
    expect(
      scrollables,
      findsWidgets,
      reason: 'No actual scrollable can reach $target',
    );
    await tester.drag(scrollables.first, const Offset(0, -180));
    await _frame(tester);
  }
  expect(target, findsWidgets, reason: 'Missing capture content $target');
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await _frame(tester);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  expect(
    target.first.hitTestable(),
    findsOneWidget,
    reason: 'Capture control must receive the actual tap: $target',
  );
  await tester.tap(target.first);
  await _frame(tester);
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await _frame(tester);
}

Future<void> _capture(
  WidgetTester tester,
  _Profile profile,
  String scene,
) async {
  await _frame(tester);
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../docs/screenshots/reliable-journeys/$scene-${profile.name}.png',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final profile in const [
    _Profile('standard-light-mobile', Size(390, 1100)),
    _Profile('standard-dark-desktop', Size(1280, 1100), dark: true),
    _Profile(
      'simple-light-narrow-200-reduced-motion',
      Size(320, 1100),
      simple: true,
      scale: 2,
    ),
  ]) {
    for (final scene in const [
      'vault-creating-pending',
      'vault-failure',
      'event-saving',
      'action-saving',
      'check-in-saving',
      'backup-confirmation',
      'help-copy-failure',
    ]) {
      testWidgets('$scene ${profile.name}', (tester) async {
        tester.view.physicalSize = profile.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final initial = _fictionalData(profile);
        final repository = _Repository(initial);
        final controller = AppController(repository, initial);
        final gate = Completer<void>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var clipboardCalls = 0;
        String? backupResult;
        var backupClosed = false;
        try {
          if (scene.startsWith('vault-')) {
            await tester.pumpWidget(
              _app(
                profile,
                scene,
                VaultUnlockScreen(creating: true, onSubmit: (_) => gate.future),
              ),
            );
            await _frame(tester);
            await _reveal(
              tester,
              find.widgetWithText(TextFormField, 'Passphrase'),
            );
            await tester.enterText(
              find.byType(TextFormField).first,
              'fictional capture phrase',
            );
            await _reveal(
              tester,
              find.byKey(const ValueKey('vault-confirmation-field')),
            );
            await tester.enterText(
              find.byKey(const ValueKey('vault-confirmation-field')),
              'fictional capture phrase',
            );
            await _hideKeyboard(tester);
            await _tap(tester, find.text('Create private vault'));
            if (scene == 'vault-failure') {
              gate.completeError(StateError('Fictional capture failure'));
              await _frame(tester);
              await _reveal(
                tester,
                find.textContaining('The vault could not be created.'),
              );
            } else {
              expect(find.byType(CircularProgressIndicator), findsOneWidget);
              await _reveal(
                tester,
                find.byKey(const ValueKey('vault-confirmation-field')),
              );
            }
          } else if (scene == 'event-saving') {
            repository.pending = gate;
            await tester.pumpWidget(
              _app(
                profile,
                scene,
                EventForm(
                  simpleWords: profile.simple,
                  onSave: (submission) => controller.createEvent(
                    submission.title,
                    submission.description,
                    guidanceContext: submission.guidanceContext,
                    starterStepIds: submission.starterStepIds,
                  ),
                ),
              ),
            );
            await _frame(tester);
            await _reveal(
              tester,
              find.widgetWithText(TextFormField, 'Event title'),
            );
            await tester.enterText(
              find.byType(TextFormField).first,
              'A new routine',
            );
            await _reveal(
              tester,
              find.byKey(const ValueKey('event-description-field')),
            );
            await tester.enterText(
              find.byKey(const ValueKey('event-description-field')),
              'One small step at a time.',
            );
            await _hideKeyboard(tester);
            await _tap(tester, find.text('Save event'));
            await _reveal(
              tester,
              find.byKey(const ValueKey('event-description-field')),
            );
            expect(find.text('Saving…'), findsOneWidget);
          } else if (scene == 'action-saving') {
            repository.pending = gate;
            await tester.pumpWidget(
              _app(
                profile,
                scene,
                Scaffold(
                  body: JourneyScreen(
                    controller: controller,
                    onCreateEvent: () {},
                    onEditEvent: (_) {},
                    onDeleted: () {},
                  ),
                ),
              ),
            );
            await _frame(tester);
            await _tap(tester, find.byTooltip('Edit Choose one small task'));
            await _reveal(tester, find.byType(TextFormField));
            await tester.enterText(
              find.byType(TextFormField),
              'Ask a trusted person for help',
            );
            await _hideKeyboard(tester);
            await _tap(tester, find.text('Save action'));
            expect(
              tester
                  .widget<EditableText>(
                    find.descendant(
                      of: find.byType(TextFormField),
                      matching: find.byType(EditableText),
                    ),
                  )
                  .readOnly,
              isTrue,
            );
          } else if (scene == 'check-in-saving') {
            repository.pending = gate;
            await tester.pumpWidget(
              _app(
                profile,
                scene,
                Scaffold(body: CheckInsScreen(controller: controller)),
              ),
            );
            await _frame(tester);
            await _tap(tester, find.text('Add check-in'));
            await _reveal(
              tester,
              find.widgetWithText(TextFormField, 'How do you feel?'),
            );
            await tester.enterText(
              find.byType(TextFormField).first,
              'A little more settled',
            );
            await _hideKeyboard(tester);
            await _tap(tester, find.widgetWithText(ChoiceChip, '2'));
            expect(
              tester
                  .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '2'))
                  .selected,
              isTrue,
            );
            await _reveal(
              tester,
              find.widgetWithText(TextFormField, 'Note (optional)'),
            );
            await tester.enterText(
              find.byType(TextFormField).at(1),
              'A short pause helped me choose a step.',
            );
            await _hideKeyboard(tester);
            await _tap(tester, find.text('Save check-in'));
            await _reveal(
              tester,
              find.widgetWithText(TextFormField, 'Note (optional)'),
            );
            expect(
              tester
                  .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '2'))
                  .onSelected,
              isNull,
            );
          } else if (scene == 'backup-confirmation') {
            await tester.pumpWidget(
              _app(
                profile,
                scene,
                Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: () async {
                          backupResult = await showVaultPassphraseDialog(
                            context,
                            creating: true,
                            title: 'Protect your backup',
                          );
                          backupClosed = true;
                        },
                        child: const Text('Open fictional backup dialog'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await _frame(tester);
            await _tap(tester, find.text('Open fictional backup dialog'));
            await _reveal(tester, find.byKey(const Key('vault-passphrase')));
            await tester.enterText(
              find.byKey(const Key('vault-passphrase')),
              'fictional backup capture phrase',
            );
            await _reveal(
              tester,
              find.byKey(const Key('vault-confirm-passphrase')),
            );
            await tester.enterText(
              find.byKey(const Key('vault-confirm-passphrase')),
              'fictional backup capture phrase',
            );
            await _hideKeyboard(tester);
            await _reveal(tester, find.text('Confirm passphrase'));
            expect(find.text('Protect your backup'), findsOneWidget);
          } else {
            // This override exists only for this scene and never reaches the
            // system clipboard. The actual Help copy button handles the error.
            messenger.setMockMethodCallHandler(SystemChannels.platform, (
              call,
            ) async {
              if (call.method == 'Clipboard.setData') {
                clipboardCalls++;
                throw PlatformException(code: 'fictional-unavailable');
              }
              return null;
            });
            await tester.pumpWidget(
              _app(
                profile,
                scene,
                Scaffold(
                  body: HelpScreen(
                    controller: controller,
                    simpleWords: profile.simple,
                    phoneActions: _NoHandoff(),
                  ),
                ),
              ),
            );
            await _frame(tester);
            await _tap(tester, find.text('Copy 988'));
            expect(clipboardCalls, 1);
            expect(find.textContaining('Could not copy'), findsOneWidget);
            expect(find.text('988 copied.'), findsNothing);
          }
          if (scene == 'event-saving' ||
              scene == 'action-saving' ||
              scene == 'check-in-saving') {
            expect(repository.attempts, 1);
          }
          await _capture(tester, profile, scene);
          if (scene == 'backup-confirmation') {
            await _tap(tester, find.text('Cancel'));
            expect(backupClosed, isTrue);
            expect(backupResult, isNull);
            expect(repository.attempts, 0);
            expect(find.byType(AlertDialog), findsNothing);
          }
          expect(controller.data.learning.enabledSources, isEmpty);
          expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
        } finally {
          // Dispose form routes before releasing successful saves so their
          // ordinary pop behavior cannot remove the capture's root route.
          await tester.pumpWidget(const SizedBox.shrink());
          if (!gate.isCompleted) gate.complete();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
          await controller.flush();
          controller.dispose();
          if (scene == 'help-copy-failure') {
            messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          }
          await tester.pump();
        }
      });
    }
  }
}
