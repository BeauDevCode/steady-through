import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';
import 'package:steady_through/features/vault/passphrase_dialog.dart';
import 'package:steady_through/ui/steady_theme.dart';

Future<void> _mount(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(320, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: steadyTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
          accessibleNavigation: true,
        ),
        child: child!,
      ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, String label) async {
  // Page children are lazy. Do not index a finder before the label is built.
  final target = find.text(label);
  for (var attempt = 0; target.evaluate().isEmpty && attempt < 30; attempt++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
}

void _expectCompleteLabel(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  expect(paragraph.text.toPlainText(), label);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: 'The full field label must stay readable at 200% text.',
  );
  final natural = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    strutStyle: paragraph.strutStyle,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.size.width);
  try {
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(natural.height - .01),
      reason: 'The label needs enough height for all naturally wrapped lines.',
    );
  } finally {
    natural.dispose();
  }
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

  testWidgets('filled vault confirmation label wraps fully at 320px and 200%', (
    tester,
  ) async {
    await _mount(
      tester,
      VaultUnlockScreen(creating: true, onSubmit: (_) async {}),
    );
    await _reveal(tester, 'Confirm passphrase');
    await tester.enterText(
      find.byType(TextFormField).first,
      'fictional label test phrase',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vault-confirmation-field')),
      'fictional label test phrase',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _reveal(tester, 'Confirm passphrase');
    _expectCompleteLabel(tester, 'Confirm passphrase');
    expect(tester.takeException(), isNull);
  });

  testWidgets('backup confirmation label stays readable at 320px and 200%', (
    tester,
  ) async {
    await _mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showVaultPassphraseDialog(context, creating: true),
            child: const Text('Open fictional backup form'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open fictional backup form'));
    await tester.pumpAndSettle();
    await _reveal(tester, 'Confirm passphrase');
    await tester.enterText(
      find.byKey(const Key('vault-passphrase')),
      'fictional label test phrase',
    );
    await tester.enterText(
      find.byKey(const Key('vault-confirm-passphrase')),
      'fictional label test phrase',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    try {
      await _reveal(tester, 'Confirm passphrase');
      _expectCompleteLabel(tester, 'Confirm passphrase');
      _expectCompleteLabel(tester, '12 characters or more.');
      expect(tester.takeException(), isNull);
    } finally {
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('filled event description label wraps fully at 320px and 200%', (
    tester,
  ) async {
    await _mount(tester, EventForm(simpleWords: true, onSave: (_) async {}));
    await _reveal(tester, 'Optional description');
    await tester.enterText(find.byType(TextFormField).first, 'Fictional event');
    await tester.enterText(
      find.byKey(const ValueKey('event-description-field')),
      'One small step at a time.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _reveal(tester, 'Optional description');
    _expectCompleteLabel(tester, 'Optional description');
    expect(tester.takeException(), isNull);
  });
}
