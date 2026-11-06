// Native runtime checks use fictional records and exclusively owned temp files.
// Run on a native target; the normal widget suite does not execute this file.
import 'dart:convert';
import 'dart:io';

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
import 'package:steady_through/features/settings/settings_screen.dart';
import 'package:steady_through/learning/device_signals.dart';

const _vaultPassphrase = 'Fictional native test river garden';
const _exportPassphrase = 'Separate fictional backup meadow';

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

/// Replaces only the unautomatable OS file chooser. Encryption, parsing,
/// confirmation, native file I/O and the encrypted repository are all real.
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

  testWidgets('native bridge remains paused without source consent', (
    tester,
  ) async {
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
  });

  testWidgets(
    'native vault keeps an event through lock and authenticated unlock',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'steady-native-ui-',
      );
      final store = _ObservedVaultStore(directory);
      var completed = false;
      try {
        await tester.pumpWidget(VaultGate(store: store));
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
    'native encrypted backup restores only after its own passphrase',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'steady-native-backup-',
      );
      final store = VaultStore(directory);
      final session = await store.create(_vaultPassphrase);
      final controller = AppController(session.repository, session.initialData);
      try {
        await controller.createEvent(
          'Fictional backup event',
          'Synthetic backup record',
        );
        final originalId = controller.data.events.single.id;
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
            confirm: (replacement) async => replacement.events.length == 1,
          ),
          isTrue,
        );
        expect(controller.data.events.single.id, originalId);
        expect(controller.data.learning.enabledSources, isEmpty);
        await controller.flush();
      } finally {
        controller.dispose();
        session.close();
      }
      final restored = await store.unlock(_vaultPassphrase);
      try {
        expect(
          restored.initialData.events.single.title,
          'Fictional backup event',
        );
      } finally {
        restored.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
