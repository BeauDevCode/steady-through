import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';
import 'package:steady_through/ui/steady_theme.dart';

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

  for (final dismissal in ['Back to unlock', 'escape', 'back', 'barrier']) {
    testWidgets(
      'passphrase help $dismissal preserves input without resetting',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var resetCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: steadyTheme(Brightness.light),
            home: VaultUnlockScreen(
              creating: false,
              onSubmit: (_) async => throw StateError('Unused in help'),
              onReset: () async {
                resetCalls++;
              },
            ),
          ),
        );
        await tester.enterText(
          find.byType(TextFormField),
          'fictional typed words',
        );
        await tester.ensureVisible(find.text('Forgot your passphrase?'));
        await tester.tap(find.text('Forgot your passphrase?'));
        await tester.pumpAndSettle();
        expect(find.text('Help with your passphrase'), findsOneWidget);
        expect(find.text('Delete vault'), findsNothing);
        expect(resetCalls, 0);
        expect(find.byType(TextFormField, skipOffstage: false), findsOneWidget);
        if (dismissal == 'escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else if (dismissal == 'back') {
          await tester.binding.handlePopRoute();
        } else if (dismissal == 'barrier') {
          await tester.tapAt(const Offset(4, 4));
        } else {
          await tester.tap(find.text('Back to unlock'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(resetCalls, 0);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          'fictional typed words',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'passphrase help defaults keyboard activation to back to unlock',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var resetCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: VaultUnlockScreen(
            creating: false,
            onSubmit: (_) async {},
            onReset: () async {
              resetCalls++;
            },
          ),
        ),
      );
      await tester.ensureVisible(find.text('Forgot your passphrase?'));
      await tester.tap(find.text('Forgot your passphrase?'));
      await tester.pumpAndSettle();
      expect(find.text('Help with your passphrase'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(resetCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending unlock disables passphrase help', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final opening = Completer<void>();
    var resetCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VaultUnlockScreen(
          creating: false,
          onSubmit: (_) => opening.future,
          onReset: () async {
            resetCalls++;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'fictional typed words');
    await tester.tap(find.text('Unlock vault'));
    await tester.pump();
    try {
      final help = find.widgetWithText(TextButton, 'Forgot your passphrase?');
      expect(help, findsOneWidget);
      expect(tester.widget<TextButton>(help).onPressed, isNull);
      await tester.tap(help);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(resetCalls, 0);
    } finally {
      opening.complete();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('help is hidden without a reset callback and during creation', (
    tester,
  ) async {
    for (final creating in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: VaultUnlockScreen(
            creating: creating,
            onSubmit: (_) async {},
            onReset: creating ? () async {} : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Forgot your passphrase?'), findsNothing);
    }
  });

  testWidgets('passphrase help is scrollable at 320px 200% with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    try {
      var resetCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: steadyTheme(Brightness.light),
          home: VaultUnlockScreen(
            creating: false,
            onSubmit: (_) async {},
            onReset: () async {
              resetCalls++;
            },
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byType(TextFormField),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byType(TextFormField),
        'fictional typed words',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Forgot your passphrase?'));
      await tester.pumpAndSettle();
      expect(
        find.text('Forgot your passphrase?').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Forgot your passphrase?'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.bySemanticsLabel('Back to unlock'), findsOneWidget);
      expect(find.bySemanticsLabel('Start over…'), findsOneWidget);
      final ending = find.textContaining('cannot be recovered');
      await tester.ensureVisible(ending);
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(of: dialog, matching: find.byType(Scrollable))
          .first;
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, greaterThan(0));
      expect(position.extentAfter, lessThan(1));
      expect(find.text('Back to unlock').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back to unlock'));
      await tester.pumpAndSettle();
      expect(resetCalls, 0);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'fictional typed words',
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
