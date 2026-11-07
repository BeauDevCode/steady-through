// Native runtime checks use fictional records and exclusively owned temp files.
// Run on a native target; the normal widget suite does not execute this file.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/app/vault_gate.dart';
import 'package:steady_through/data/data_portability.dart';
import 'package:steady_through/data/vault_codec.dart';
import 'package:steady_through/data/vault_store.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/journey/focused_action_screen.dart';
import 'package:steady_through/features/journey/journey_screen.dart';
import 'package:steady_through/features/home/home_screen.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/people/people_screen.dart';
import 'package:steady_through/features/settings/settings_screen.dart';
import 'package:steady_through/learning/device_signals.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/tool_feedback.dart';

const _vaultPassphrase = 'Fictional native test river garden';
const _exportPassphrase = 'Separate fictional backup meadow';

// Observe actual framework notifications without manufacturing an active
// lifecycle. The engine's initial value is a startup snapshot, not current UI
// readiness; keeping it separate helps diagnose native alert/scene failures.
class _NativeLifecycleTrace with WidgetsBindingObserver {
  final List<String> _events = [];

  String get summary =>
      'binding=${WidgetsBinding.instance.lifecycleState}; '
      'engineInitial=${ui.PlatformDispatcher.instance.initialLifecycleState}; '
      'transitions=${_events.join(', ')}';

  void mark(String checkpoint) =>
      debugPrint('Native QA lifecycle [$checkpoint]: $summary');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _events.add('${DateTime.now().toUtc().toIso8601String()}:$state');
    if (_events.length > 32) _events.removeAt(0);
    mark('notification');
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  String Function()? diagnostics,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Native flow timed out: $reason. ${diagnostics?.call() ?? ''}');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

// Real storage with boundary diagnostics only. No keys, passphrases or record
// contents are logged, and no storage behavior is replaced.
class _ObservedVaultStore extends VaultStore {
  _ObservedVaultStore(super.root);
  int unlockAttempts = 0;
  String lastOutcome = 'not attempted';

  @override
  Future<VaultSession> unlock(String passphrase) async {
    unlockAttempts++;
    final watch = Stopwatch()..start();
    lastOutcome = 'pending';
    debugPrint(
      'Native QA unlock attempt $unlockAttempts started; matches fixture: ${passphrase == _vaultPassphrase}',
    );
    try {
      final session = await super.unlock(passphrase);
      lastOutcome = 'authenticated';
      return session;
    } catch (error) {
      lastOutcome = error.runtimeType.toString();
      rethrow;
    } finally {
      debugPrint(
        'Native QA unlock attempt $unlockAttempts: $lastOutcome (${watch.elapsedMilliseconds}ms)',
      );
    }
  }
}

Future<void> _lockThroughMore(WidgetTester tester) async {
  await _until(
    tester,
    () => find.text('More').hitTestable().evaluate().isNotEmpty,
    reason: 'unlocked app becomes interactive',
    diagnostics: () => 'lifecycle=${WidgetsBinding.instance.lifecycleState}',
  );
  await tester.tap(find.text('More').first);
  await tester.pumpAndSettle();
  final lock = find.widgetWithText(TextButton, 'Lock vault');
  await tester.scrollUntilVisible(
    lock,
    250,
    scrollable: find
        .descendant(
          of: find.byType(MoreScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(lock);
  await _until(
    tester,
    () => find.text('Unlock vault').evaluate().isNotEmpty,
    reason: 'lock returns to unlock',
  );
}

Future<void> _unmount(WidgetTester tester) async {
  final matches = find.byType(SteadyThroughApp).evaluate();
  final app = matches.isEmpty
      ? null
      : matches.single.widget as SteadyThroughApp;
  await tester.pumpWidget(const SizedBox.shrink());
  // Gate owns these resources; both methods join its idempotent cleanup.
  await app?.learningSession?.close();
  await app?.controller.flush();
  await tester.pump();
}

// Find and scroll the actual current screen/dialog; never bypass hit testing or
// invoke a widget callback directly. Targets above the current offset can also
// be revealed after a previous interaction scrolled the same page down.
Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  required Finder within,
}) async {
  await tester.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .descendant(of: within, matching: find.byType(Scrollable))
        .first;
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    if (offset > 0) {
      // Lazy pages may have disposed a target above the current viewport. Drag
      // back to the start before searching forward, without a position jump.
      await tester.drag(scrollable, Offset(0, offset + 200));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scrollable,
      maxScrolls: 50,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _tapRevealed(
  WidgetTester tester,
  Finder target, {
  required Finder within,
}) async {
  await _reveal(tester, target, within: within);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Owns file I/O for DataPortability; the case separately supplies scripted
/// passphrase/confirmation callbacks. Encryption, parsing and persistence are
/// real, while the OS chooser and Settings backup dialogs are outside the case.
class _OwnedBackupGateway implements DataPortabilityGateway {
  _OwnedBackupGateway(this.file);
  final File file;

  @override
  Future<Uint8List?> pickJsonBytes() => file.readAsBytes();

  @override
  Future<Uri?> saveJsonFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await file.writeAsBytes(bytes, flush: true);
    return file.uri;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().defaultTestTimeout =
      const Timeout(Duration(minutes: 5));
  WidgetController.hitTestWarningShouldBeFatal = true;
  final lifecycle = _NativeLifecycleTrace();
  WidgetsBinding.instance.addObserver(lifecycle);
  lifecycle.mark('test entry');
  tearDownAll(() => WidgetsBinding.instance.removeObserver(lifecycle));

  testWidgets('native bridge remains paused without source consent', (
    tester,
  ) async {
    lifecycle.mark('bridge start');
    // Querying path_provider establishes native plugin registration without
    // reading or writing the app's normal support directory.
    expect((await getTemporaryDirectory()).isAbsolute, isTrue);
    final signals = DeviceSignals();
    final capabilities = await signals.capabilities();
    await signals.stop();
    final reading = await signals.read();
    expect(reading.usageStatus, 'paused');
    expect(reading.motionStatus, 'paused');
    expect(reading.activeMinutes, isNull);
    expect(reading.vehicleMinutes, isNull);
    expect(reading.possibleVehicle, isFalse);

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // The wrapper intentionally tolerates missing plugins. This direct
      // boundary catches a broken or unregistered native adapter instead.
      const channel = MethodChannel('steady_through/device_signals');
      final native = await channel.invokeMapMethod<String, Object?>(
        'capabilities',
      );
      expect(native, isNotNull);
      expect(native!['usageSupported'], isA<bool>());
      expect(native['motionSupported'], isA<bool>());
      expect(native['platformNote'], isA<String>());
      await channel.invokeMethod<void>('stop');
      final paused = await channel.invokeMapMethod<String, Object?>('read');
      expect(paused, isNotNull);
      expect(paused!['usageStatus'], Platform.isIOS ? 'unsupported' : 'paused');
      expect(
        paused['motionStatus'],
        Platform.isMacOS ? 'unsupported' : 'paused',
      );
      for (final key in [
        'deviceSwitches',
        'activeMinutes',
        'vehicleMinutes',
        'walkingMinutes',
      ]) {
        expect(
          paused[key],
          isNull,
          reason: 'Stopped native $key must be missing',
        );
      }
      expect(paused['possibleVehicle'] == true, isFalse);
    } else {
      expect(capabilities.usageSupported, isFalse);
      expect(capabilities.motionSupported, isFalse);
    }
    lifecycle.mark('bridge end');
  });

  testWidgets(
    'native vault keeps an event through lock and authenticated unlock',
    (tester) async {
      lifecycle.mark('UI case start');
      final directory = await Directory.systemTemp.createTemp(
        'steady-native-ui-',
      );
      final store = _ObservedVaultStore(directory);
      var completed = false;
      try {
        await tester.pumpWidget(VaultGate(store: store));
        lifecycle.mark('gate mounted');
        await _until(
          tester,
          () => find.text('Create private vault').evaluate().isNotEmpty,
          reason: 'first vault setup',
        );
        await tester.enterText(
          find.byType(TextFormField).at(0),
          _vaultPassphrase,
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          _vaultPassphrase,
        );
        await tester.tap(find.text('Create private vault'));
        await _until(
          tester,
          () => find.byType(SteadyThroughApp).evaluate().isNotEmpty,
          reason: 'real KDF and encrypted vault creation',
        );
        lifecycle.mark('vault created');
        await _until(
          tester,
          () => find
              .widgetWithText(FilledButton, 'Create event')
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          reason:
              'new app becomes interactive after native lifecycle transitions',
          diagnostics: () => lifecycle.summary,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Create event'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Fictional native life event',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'A synthetic plan for this native test.',
        );
        await tester.tap(find.text('Save event'));
        await _until(
          tester,
          () => find.byType(EventForm).evaluate().isEmpty,
          reason: 'event save closes form',
        );
        final app = tester.widget<SteadyThroughApp>(
          find.byType(SteadyThroughApp),
        );
        expect(
          app.controller.data.events.single.title,
          'Fictional native life event',
        );
        expect(app.controller.data.learning.enabledSources, isEmpty);
        expect(app.learningSession!.snapshot.features, isEmpty);
        await app.controller.flush();
        final saved = await File('${directory.path}/steady-through.vault')
            .readAsBytes();
        expect(
          utf8.decode(saved),
          isNot(contains('Fictional native life event')),
        );
        expect(
          jsonDecode(utf8.decode(saved))['format'],
          'steady-through-vault',
        );

        await _lockThroughMore(tester);
        await tester.enterText(
          find.byType(TextFormField),
          'Wrong fictional native passphrase',
        );
        await tester.tap(find.text('Unlock vault'));
        await _until(
          tester,
          () => find
              .textContaining('Check your passphrase')
              .evaluate()
              .isNotEmpty,
          reason: 'wrong passphrase stays locked',
        );
        expect(find.byType(SteadyThroughApp), findsNothing);
        // The integration binding does not register the mock IME. After the
        // app unfocuses on submit, showKeyboard's cached EditableText can be
        // unchanged even though the real input connection closed. Refocus by
        // the same visible interaction a person uses before typing a retry.
        await tester.ensureVisible(find.byType(TextFormField));
        await tester.tap(find.byType(TextFormField));
        await tester.enterText(find.byType(TextFormField), _vaultPassphrase);
        await tester.pumpAndSettle();
        final unlockButton = find.widgetWithText(FilledButton, 'Unlock vault');
        expect(tester.widget<FilledButton>(unlockButton).onPressed, isNotNull);
        expect(
          tester
                  .widget<TextFormField>(find.byType(TextFormField))
                  .controller!
                  .text ==
              _vaultPassphrase,
          isTrue,
          reason: 'The synthetic retry must reach the actual form controller',
        );
        await tester.tap(find.text('Unlock vault'));
        await _until(
          tester,
          () => store.unlockAttempts == 2,
          reason: 'correct retry reaches storage',
          timeout: const Duration(seconds: 10),
          diagnostics: () =>
              'attempts=${store.unlockAttempts}, outcome=${store.lastOutcome}',
        );
        await _until(
          tester,
          () => find.byType(SteadyThroughApp).evaluate().isNotEmpty,
          reason: 'authenticated vault recovery',
          diagnostics: () =>
              'attempts=${store.unlockAttempts}, outcome=${store.lastOutcome}, errorVisible=${find.textContaining('Check your passphrase').evaluate().isNotEmpty}',
        );
        final restored = tester.widget<SteadyThroughApp>(
          find.byType(SteadyThroughApp),
        );
        expect(
          restored.controller.data.events.single.title,
          'Fictional native life event',
        );
        expect(restored.controller.data.learning.enabledSources, isEmpty);
        await _lockThroughMore(tester);
        expect(tester.takeException(), isNull);
        completed = true;
      } finally {
        await _unmount(tester);
        // On a timed-out operation leave the owned synthetic fixture for runner
        // diagnostics rather than race an in-flight write. Never touch user paths.
        if (completed) await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'native support flow preserves focused step and people after reopening',
    (tester) async {
      const eventTitle = 'Fictional native support journey';
      const firstStep = 'Make room for your needs too';
      const otherStep = 'Plan one task and possible support';
      const originalName = 'Fictional native journey helper';
      const editedName = 'Edited fictional journey helper';
      const phone = '202-555-0174';
      final directory = await Directory.systemTemp.createTemp(
        'steady-native-journey-',
      );
      var completed = false;
      lifecycle.mark('support flow start');
      try {
        await tester.pumpWidget(VaultGate(store: VaultStore(directory)));
        await _until(
          tester,
          () => find.text('Create private vault').evaluate().isNotEmpty,
          reason: 'support flow vault setup',
          diagnostics: () => lifecycle.summary,
        );
        await tester.enterText(
          find.byType(TextFormField).at(0),
          _vaultPassphrase,
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          _vaultPassphrase,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Create private vault'),
        );
        await _until(
          tester,
          () => find
              .widgetWithText(FilledButton, 'Create event')
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          reason: 'support flow real vault creation and interactive Home',
          diagnostics: () => lifecycle.summary,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Create event'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), eventTitle);
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'A fictional caring plan for native QA.',
        );
        await _tapRevealed(
          tester,
          find.widgetWithText(TextButton, 'Choose guide'),
          within: find.byType(EventForm),
        );
        await _tapRevealed(
          tester,
          find.widgetWithText(
            RadioListTile<GuidanceContext>,
            'Caring for someone',
          ),
          within: find.byType(AlertDialog),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Use guide'));
        await tester.pumpAndSettle();
        await _tapRevealed(
          tester,
          find.widgetWithText(TextButton, 'Choose starter steps'),
          within: find.byType(EventForm),
        );
        for (final title in [
          'Consider a break when care is covered',
          'Identify a task you could ask help with',
          'Review where support would help',
        ]) {
          final option = find.widgetWithText(CheckboxListTile, title);
          await _reveal(tester, option, within: find.byType(AlertDialog));
          expect(tester.widget<CheckboxListTile>(option).value, isTrue);
          await tester.tap(option);
          await tester.pumpAndSettle();
        }
        expect(find.text('2 steps selected'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(FilledButton, 'Use selected steps'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save event'));
        await _until(
          tester,
          () => find.byType(EventForm).evaluate().isEmpty,
          reason: 'support flow event is persisted and Path opens',
        );
        await tester.pumpAndSettle();
        final app = tester.widget<SteadyThroughApp>(
          find.byType(SteadyThroughApp),
        );
        final controller = app.controller;
        final created = controller.activeEvent!;
        final eventId = created.id;
        expect(created.title, eventTitle);
        expect(created.guidanceContext, GuidanceContext.caregiving);
        expect(created.actions.map((action) => action.title).toList(), [
          firstStep,
          otherStep,
        ]);
        expect(created.actions.every((action) => !action.done), isTrue);
        expect(find.byType(JourneyScreen), findsOneWidget);
        expect(find.text(eventTitle), findsOneWidget);
        await _reveal(
          tester,
          find.widgetWithText(CheckboxListTile, firstStep),
          within: find.byType(JourneyScreen),
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, firstStep),
              )
              .value,
          isFalse,
        );

        await tester.tap(find.text('Home').hitTestable().first);
        await _tapRevealed(
          tester,
          find.widgetWithText(FilledButton, 'Go to this step'),
          within: find.byType(HomeScreen),
        );
        expect(find.byType(FocusedActionScreen), findsOneWidget);
        expect(find.text('Your next step'), findsOneWidget);
        expect(find.text(firstStep), findsOneWidget);
        expect(
          controller.activeEvent!.toJson(),
          created.toJson(),
          reason: 'Opening the focused route cannot complete or replace a step',
        );
        for (final label in [
          'Mark step done',
          'Undo completion',
          'Mark step done',
        ]) {
          final shouldBeDone = label == 'Mark step done';
          await _tapRevealed(
            tester,
            find.widgetWithText(FilledButton, label),
            within: find.byType(FocusedActionScreen),
          );
          await _until(
            tester,
            () =>
                controller.activeEvent!.actions.first.done == shouldBeDone &&
                find
                    .widgetWithText(
                      FilledButton,
                      shouldBeDone ? 'Undo completion' : 'Mark step done',
                    )
                    .evaluate()
                    .isNotEmpty,
            reason: 'focused $label persists and settles',
          );
          expect(find.text(firstStep), findsOneWidget);
          expect(
            controller.activeEvent!.actions.last.toJson(),
            created.actions.last.toJson(),
          );
          expect(
            controller.activeEvent!.actions.first.id,
            created.actions.first.id,
          );
        }
        final eventSnapshot = controller.activeEvent!.toJson();
        await _tapRevealed(
          tester,
          find.widgetWithText(TextButton, 'Back to Home'),
          within: find.byType(FocusedActionScreen),
        );
        await tester.tap(find.text('More').hitTestable().first);
        await _tapRevealed(
          tester,
          find.text('People'),
          within: find.byType(MoreScreen),
        );
        await _tapRevealed(
          tester,
          find.widgetWithText(FilledButton, 'Add person'),
          within: find.byType(PeopleScreen),
        );
        final dialogFields = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(dialogFields.at(0), originalName);
        await tester.enterText(dialogFields.at(1), phone);
        await tester.tap(find.widgetWithText(FilledButton, 'Save person'));
        await _until(
          tester,
          () => find.byType(AlertDialog).evaluate().isEmpty,
          reason: 'actual Add person saves',
        );
        final personId = controller.data.people.single.id;
        expect(controller.data.people.single.phone, phone);
        await _tapRevealed(
          tester,
          find.byTooltip('Edit $originalName'),
          within: find.byType(PeopleScreen),
        );
        expect(
          tester.widget<TextFormField>(dialogFields.at(0)).controller!.text,
          originalName,
        );
        expect(
          tester.widget<TextFormField>(dialogFields.at(1)).controller!.text,
          phone,
        );
        await tester.enterText(dialogFields.at(0), editedName);
        await tester.enterText(dialogFields.at(1), '');
        await tester.tap(find.widgetWithText(FilledButton, 'Save person'));
        await _until(
          tester,
          () => find.byType(AlertDialog).evaluate().isEmpty,
          reason: 'actual Edit person saves cleared optional phone',
        );
        expect(controller.data.people.single.id, personId);
        expect(controller.data.people.single.name, editedName);
        expect(controller.data.people.single.phone, isNull);
        final peopleSnapshot = controller.data.people
            .map((person) => person.toJson())
            .toList();
        await _reveal(
          tester,
          find.text(editedName),
          within: find.byType(PeopleScreen),
        );
        expect(find.text('No phone number saved'), findsOneWidget);
        expect(find.text(phone), findsNothing);
        await tester.tap(find.widgetWithText(TextButton, 'Back to More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Help now').hitTestable().first);
        await tester.pumpAndSettle();
        expect(find.byType(HelpScreen), findsOneWidget);
        await _reveal(
          tester,
          find.text(editedName),
          within: find.byType(HelpScreen),
        );
        expect(find.text('Your trusted people'), findsOneWidget);
        expect(find.text('No phone number saved'), findsOneWidget);
        await _tapRevealed(
          tester,
          find.widgetWithText(TextButton, 'View all saved people'),
          within: find.byType(HelpScreen),
        );
        expect(find.text('Your saved people'), findsOneWidget);
        expect(find.byType(PeopleScreen), findsOneWidget);
        await _reveal(
          tester,
          find.text(editedName),
          within: find.byType(PeopleScreen),
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await _tapRevealed(
          tester,
          find.widgetWithText(TextButton, 'Back'),
          within: find.byType(HelpScreen),
        );
        expect(controller.activeEvent!.toJson(), eventSnapshot);
        expect(
          controller.data.people.map((person) => person.toJson()).toList(),
          peopleSnapshot,
        );
        expect(controller.data.learning.enabledSources, isEmpty);
        expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
        expect(app.learningSession!.snapshot.features, isEmpty);
        await controller.flush();
        final saved = await File('${directory.path}/steady-through.vault')
            .readAsString();
        expect(jsonDecode(saved)['format'], 'steady-through-vault');
        for (final marker in [
          eventTitle,
          originalName,
          editedName,
          phone,
          firstStep,
        ]) {
          expect(saved, isNot(contains(marker)));
        }
        await _lockThroughMore(tester);
        await _unmount(tester);
        lifecycle.mark('support flow fresh gate');
        await tester.pumpWidget(VaultGate(store: VaultStore(directory)));
        await _until(
          tester,
          () => find.text('Unlock vault').evaluate().isNotEmpty,
          reason: 'fresh Gate detects the saved encrypted vault',
        );
        expect(find.text('Create private vault'), findsNothing);
        await tester.enterText(find.byType(TextFormField), _vaultPassphrase);
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock vault'));
        await _until(
          tester,
          () => find.text('Home').hitTestable().evaluate().isNotEmpty,
          reason: 'fresh real store authenticates the disk vault',
          diagnostics: () => lifecycle.summary,
        );
        await tester.pumpAndSettle();
        final restored = tester.widget<SteadyThroughApp>(
          find.byType(SteadyThroughApp),
        );
        expect(restored.controller.activeEvent!.id, eventId);
        expect(restored.controller.activeEvent!.toJson(), eventSnapshot);
        expect(
          restored.controller.data.people
              .map((person) => person.toJson())
              .toList(),
          peopleSnapshot,
        );
        expect(restored.controller.data.learning.enabledSources, isEmpty);
        expect(restored.controller.data.learning.deviceOwnerConfirmed, isFalse);
        expect(restored.learningSession!.snapshot.features, isEmpty);
        await _reveal(
          tester,
          find.text(eventTitle),
          within: find.byType(HomeScreen),
        );
        await tester.tap(find.text('Path').hitTestable().first);
        await tester.pumpAndSettle();
        for (final entry in {firstStep: true, otherStep: false}.entries) {
          final checkbox = find.widgetWithText(CheckboxListTile, entry.key);
          await _reveal(tester, checkbox, within: find.byType(JourneyScreen));
          expect(tester.widget<CheckboxListTile>(checkbox).value, entry.value);
        }
        await tester.tap(find.text('More').hitTestable().first);
        await _tapRevealed(
          tester,
          find.text('People'),
          within: find.byType(MoreScreen),
        );
        await _reveal(
          tester,
          find.text(editedName),
          within: find.byType(PeopleScreen),
        );
        expect(find.text('No phone number saved'), findsOneWidget);
        expect(find.text(phone), findsNothing);
        await tester.tap(find.widgetWithText(TextButton, 'Back to More'));
        await tester.pumpAndSettle();
        await _lockThroughMore(tester);
        expect(tester.takeException(), isNull);
        completed = true;
        lifecycle.mark('support flow end');
      } finally {
        await _unmount(tester);
        if (completed) await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'native encrypted backup restores only after its own passphrase',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'steady-native-backup-',
      );
      final store = VaultStore(directory);
      final session = await store.create(_vaultPassphrase);
      final controller = AppController(session.repository, session.initialData);
      late Map<String, dynamic> eventSnapshot;
      late Map<String, dynamic> ratingsSnapshot;
      late List<Map<String, dynamic>> peopleSnapshot;
      late String personId;
      late String originalId;
      try {
        await controller.setTheme(ThemeChoice.dark);
        await controller.setReadingStyle(ReadingStyle.simple);
        await controller.createEvent(
          'Fictional backup event',
          'Synthetic backup record',
          guidanceContext: GuidanceContext.caregiving,
          starterStepIds: ['caregiving.orient', 'caregiving.plan'],
        );
        expect(controller.activeEvent!.actions, hasLength(2));
        originalId = controller.activeEvent!.id;
        final editedActionId = controller.activeEvent!.actions.first.id;
        await controller.renameAction(
          originalId,
          editedActionId,
          'Arrange fictional Tuesday cover',
        );
        await controller.setFocusedActionDone(
          originalId,
          editedActionId,
          true,
          expected: controller.activeEvent!.actions.first,
          expectedRevision: controller.replacementRevision,
        );
        await controller.addAction(
          originalId,
          JourneyStage.reflect,
          'Write one fictional helpful detail',
        );
        eventSnapshot = controller.activeEvent!.toJson();
        for (final tool in SupportTool.values) {
          for (final rating in ToolRating.values) {
            await controller.recordToolFeedback(
              tool,
              rating,
              expectedRevision: controller.replacementRevision,
            );
          }
        }
        await controller.updateToolFeedbackOptions(
          showPrompts: false,
          useSuggestions: false,
          expectedRevision: controller.replacementRevision,
        );
        ratingsSnapshot = controller.data.toolFeedback.toJson();
        expect(controller.data.toolFeedback.ratings, hasLength(6));
        await controller.addPerson('Fictional support helper', '202-555-0126');
        await controller.addPerson('Fictional other helper', '202-555-0146');
        final originalPerson = controller.data.people.first;
        personId = originalPerson.id;
        await controller.updatePerson(
          personId,
          'Edited fictional helper',
          '  ',
          expected: originalPerson,
          expectedRevision: controller.replacementRevision,
        );
        peopleSnapshot = controller.data.people.map((p) => p.toJson()).toList();
        expect(controller.data.people.first.id, personId);
        expect(controller.data.people.first.phone, isNull);

        expect(controller.data.learning.enabledSources, isEmpty);
        expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
        final file = File('${directory.path}/backup.steady');
        final portability = DataPortability(
          controller,
          gateway: _OwnedBackupGateway(file),
        );
        expect(
          await portability.exportData(passphrase: _exportPassphrase),
          file.uri,
        );
        expect(
          await file.readAsString(),
          isNot(contains('Fictional backup event')),
        );
        expect(await file.readAsString(), isNot(contains('toolFeedback')));
        expect(
          await file.readAsString(),
          isNot(contains('Edited fictional helper')),
        );
        await controller.updatePerson(
          personId,
          'Later fictional change',
          '202-555-0191',
          expected: controller.data.people.first,
          expectedRevision: controller.replacementRevision,
        );
        await controller.clearToolFeedback(
          expectedRevision: controller.replacementRevision,
        );
        await controller.updateToolFeedbackOptions(
          showPrompts: true,
          useSuggestions: true,
          expectedRevision: controller.replacementRevision,
        );
        await controller.createEvent(
          'Fictional later event',
          'Should be replaced on confirmed import',
        );
        await expectLater(
          portability.importData(
            requestPassphrase: () async => _vaultPassphrase,
            confirm: (_) async => true,
          ),
          throwsA(isA<VaultUnlockException>()),
        );
        expect(controller.data.events, hasLength(2));
        expect(
          await portability.importData(
            requestPassphrase: () async => _exportPassphrase,
            confirm: (replacement) async {
              expect(replacement.events.single.toJson(), eventSnapshot);
              expect(
                replacement.people.map((p) => p.toJson()).toList(),
                peopleSnapshot,
              );
              expect(replacement.toolFeedback.toJson(), ratingsSnapshot);
              return true;
            },
          ),
          isTrue,
        );
        expect(controller.data.events.single.id, originalId);
        expect(controller.data.activeEventId, originalId);
        expect(controller.data.events.single.toJson(), eventSnapshot);
        expect(controller.data.events.single.actions, hasLength(3));
        expect(
          controller.data.people.map((p) => p.toJson()).toList(),
          peopleSnapshot,
        );
        expect(controller.data.toolFeedback.toJson(), ratingsSnapshot);
        expect(controller.data.theme, ThemeChoice.dark);
        expect(controller.data.readingStyle, ReadingStyle.simple);
        expect(controller.data.learning.enabledSources, isEmpty);
        expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
        await controller.flush();
      } finally {
        controller.dispose();
        session.close();
      }
      final restored = await store.unlock(_vaultPassphrase);
      try {
        expect(restored.initialData.events.single.toJson(), eventSnapshot);
        expect(
          restored.initialData.people.map((p) => p.toJson()).toList(),
          peopleSnapshot,
        );
        expect(restored.initialData.people.first.id, personId);
        expect(restored.initialData.toolFeedback.toJson(), ratingsSnapshot);
        expect(restored.initialData.activeEventId, originalId);
        expect(restored.initialData.theme, ThemeChoice.dark);
        expect(restored.initialData.readingStyle, ReadingStyle.simple);
        expect(restored.initialData.learning.enabledSources, isEmpty);
        expect(restored.initialData.learning.deviceOwnerConfirmed, isFalse);
      } finally {
        restored.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
