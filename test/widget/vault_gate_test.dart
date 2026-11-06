import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/vault_gate.dart';
import 'package:steady_through/data/vault_store.dart';

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
