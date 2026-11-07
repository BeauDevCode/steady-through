import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/ui/steady_ui.dart';

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => value++),
    child: Text('Count $value'),
  );
}

Widget _host({bool reduced = false, Widget? child, double scale = 1}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: child ?? const GentleReveal(child: _Counter())),
      ),
    );
void main() {
  testWidgets('changing motion preference preserves the active child state', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Count 0'));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);
    await tester.pumpWidget(_host(reduced: true));
    expect(find.text('Count 1'), findsOneWidget);
    await tester.pumpWidget(_host());
    expect(find.text('Count 1'), findsOneWidget);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  testWidgets('large text gives each responsive card room to read', (
    tester,
  ) async {
    Widget content() => const SizedBox(
      width: 700,
      child: ResponsiveColumns(
        minWidth: 280,
        children: [Text('First reading card'), Text('Second reading card')],
      ),
    );
    await tester.pumpWidget(_host(child: content()));
    expect(
      tester.getTopLeft(find.text('First reading card')).dy,
      tester.getTopLeft(find.text('Second reading card')).dy,
    );
    await tester.pumpWidget(_host(scale: 2, child: content()));
    expect(
      tester.getTopLeft(find.text('Second reading card')).dy,
      greaterThan(tester.getTopLeft(find.text('First reading card')).dy),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reduced motion during entry keeps focused text and settles immediately',
    (tester) async {
      Widget content() =>
          const GentleReveal(child: TextField(key: ValueKey('step-field')));
      await tester.pumpWidget(_host(child: content()));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(find.byType(TextField), 'My small step');
      final entering = tester.getTopLeft(find.byType(TextField));
      await tester.pumpWidget(_host(reduced: true, child: content()));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, 'My small step');
      expect(editable.focusNode.hasFocus, isTrue);
      final settled = tester.getTopLeft(find.byType(TextField));
      expect(settled.dy, lessThan(entering.dy));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getTopLeft(find.byType(TextField)), settled);
      editable.focusNode.unfocus();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
