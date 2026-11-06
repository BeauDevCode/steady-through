import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';

void main() {
  testWidgets('vault creation requires a long matching passphrase', (
    tester,
  ) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: VaultUnlockScreen(
          creating: true,
          onSubmit: (value) async => submitted.add(value),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.tap(find.text('Create private vault'));
    await tester.pumpAndSettle();
    expect(submitted, isEmpty);
    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'four words for a vault',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'different passphrase',
    );
    await tester.tap(find.text('Create private vault'));
    await tester.pumpAndSettle();
    expect(submitted, isEmpty);
    expect(find.text('The passphrases do not match.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'four words for a vault',
    );
    await tester.tap(find.text('Create private vault'));
    await tester.pumpAndSettle();
    expect(submitted, ['four words for a vault']);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('vault creation counts Unicode code points like the codec', (
    tester,
  ) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: VaultUnlockScreen(
          creating: true,
          onSubmit: (value) async => submitted.add(value),
        ),
      ),
    );
    final six = List.filled(6, '🌿').join();
    await tester.enterText(find.byType(TextFormField).at(0), six);
    await tester.enterText(find.byType(TextFormField).at(1), six);
    await tester.tap(find.text('Create private vault'));
    await tester.pumpAndSettle();
    expect(submitted, isEmpty);
    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    final twelve = List.filled(12, '🌿').join();
    await tester.enterText(find.byType(TextFormField).at(0), twelve);
    await tester.enterText(find.byType(TextFormField).at(1), twelve);
    await tester.tap(find.text('Create private vault'));
    await tester.pumpAndSettle();
    expect(submitted, [twelve]);
  });

  testWidgets('unlock failures keep the vault closed with generic feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultUnlockScreen(
          creating: false,
          onSubmit: (_) async => throw StateError('private diagnostic'),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField),
      'an incorrect passphrase',
    );
    await tester.tap(find.text('Unlock vault'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your passphrase'), findsOneWidget);
    expect(find.textContaining('private diagnostic'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
