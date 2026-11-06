import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/vault_gate.dart';
import 'package:steady_through/data/vault_store.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';

class _ControlledStore extends VaultStore {
  _ControlledStore() : super(Directory.systemTemp);

  bool exists = true;
  int resetCalls = 0;
  int unlockCalls = 0;
  final resetCompletion = Completer<void>();
  Completer<VaultSession>? unlockCompletion;

  @override
  Future<bool> hasVault() async => exists;

  @override
  Future<void> reset() async {
    resetCalls++;
    await resetCompletion.future;
  }

  @override
  Future<VaultSession> unlock(String passphrase) async {
    unlockCalls++;
    final completion = unlockCompletion;
    if (completion != null) return completion.future;
    throw const FormatException('Synthetic unavailable vault');
  }
}

Future<void> _confirmReset(WidgetTester tester) async {
  await tester.ensureVisible(
    find.text('Forgot passphrase or need a fresh start?'),
  );
  await tester.tap(find.text('Forgot passphrase or need a fresh start?'));
  await tester.pumpAndSettle();
  final delete = find.widgetWithText(FilledButton, 'Delete vault');
  expect(tester.widget<FilledButton>(delete).onPressed, isNull);
  await tester.enterText(find.byType(TextField).last, 'DELETE');
  await tester.pump();
  await tester.tap(delete);
  // Deletion can be deliberately pending, so never settle an indeterminate
  // progress indicator here.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _mountGate(WidgetTester tester, VaultStore store) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(VaultGate(store: store));
  await tester.pumpAndSettle();
}

Future<void> _dismissConfirmations(WidgetTester tester) async {
  // The unfixed gate can stack two confirmations. Close both even when the
  // assertion failed, so deliberately pending futures do not hang RED runs.
  for (var attempt = 0; attempt < 3; attempt++) {
    if (find.byType(AlertDialog).evaluate().isEmpty) return;
    await tester.tap(find.text('Keep vault').last);
    await tester.pumpAndSettle();
  }
}

class _InterruptedCreation extends VaultStore {
  _InterruptedCreation() : super(Directory.systemTemp);
  bool exists = false;
  @override
  Future<bool> hasVault() async => exists;
  @override
  Future<void> reset() async {
    exists = false;
  }

  @override
  Future<VaultSession> create(String passphrase) async {
    exists = true;
    throw const FileSystemException('Save interrupted after staging');
  }
}

void main() {
  testWidgets('pending deletion blocks unlock and shows progress', (
    tester,
  ) async {
    final store = _ControlledStore();
    await _mountGate(tester, store);
    final screen = tester.widget<VaultUnlockScreen>(
      find.byType(VaultUnlockScreen),
    );
    try {
      await _confirmReset(tester);
      // A retained callback must be safe even after its form is unavailable.
      await expectLater(
        screen.onSubmit('synthetic passphrase'),
        throwsStateError,
      );
      expect(store.unlockCalls, 0);
      expect(store.resetCalls, 1);
      expect(find.byType(VaultUnlockScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Deleting'), findsOneWidget);
    } finally {
      store.exists = false;
      if (!store.resetCompletion.isCompleted) store.resetCompletion.complete();
      await tester.pumpAndSettle();
      await _dismissConfirmations(tester);
    }
    expect(find.text('Create private vault'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening blocks reset even through a retained callback', (
    tester,
  ) async {
    final store = _ControlledStore()
      ..unlockCompletion = Completer<VaultSession>();
    await _mountGate(tester, store);
    final screen = tester.widget<VaultUnlockScreen>(
      find.byType(VaultUnlockScreen),
    );
    final opened = expectLater(
      screen.onSubmit('synthetic passphrase'),
      throwsFormatException,
    );
    try {
      await tester.pump();
      unawaited(screen.onReset!());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.resetCalls, 0);
    } finally {
      store.unlockCompletion!.completeError(
        const FormatException('Synthetic failure'),
      );
      await opened;
      await tester.pumpAndSettle();
      await _dismissConfirmations(tester);
    }
    expect(find.text('Unlock vault'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated reset callbacks open only one confirmation', (
    tester,
  ) async {
    final store = _ControlledStore();
    await _mountGate(tester, store);
    final reset = tester
        .widget<VaultUnlockScreen>(find.byType(VaultUnlockScreen))
        .onReset!;
    try {
      unawaited(reset());
      await tester.pumpAndSettle();
      unawaited(reset());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
    } finally {
      await _dismissConfirmations(tester);
    }
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.resetCalls, 0);
    expect(find.text('Unlock vault'), findsOneWidget);
  });

  for (final remains in [false, true]) {
    testWidgets('failed deletion refreshes storage (vault remains: $remains)', (
      tester,
    ) async {
      final store = _ControlledStore();
      await _mountGate(tester, store);
      await _confirmReset(tester);
      store.exists = remains;
      store.resetCompletion.completeError(
        const FileSystemException('Synthetic reset failure'),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Deletion could not be fully verified'),
        findsOneWidget,
      );
      expect(
        find.text(remains ? 'Unlock vault' : 'Create private vault'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNotNull,
      );
      if (remains) {
        await tester.tap(find.text('Forgot passphrase or need a fresh start?'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Keep vault'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an interrupted first save switches setup to recovery unlock', (
    tester,
  ) async {
    final store = _InterruptedCreation();
    await tester.pumpWidget(VaultGate(store: store));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'a synthetic test passphrase',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'a synthetic test passphrase',
    );
    await tester.tap(find.text('Create private vault'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock vault'), findsOneWidget);
    expect(find.text('Create private vault'), findsNothing);
    expect(
      find.text('Forgot passphrase or need a fresh start?'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
