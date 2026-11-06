import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/journey/guidance_picker.dart';
import 'package:steady_through/model/app_data.dart';

Widget _cardHost({
  bool reducedMotion = true,
  bool canChoose = true,
  double width = 640,
  GuidanceContext guide = GuidanceContext.general,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: GuidanceCard(
            guidanceContext: guide,
            simpleWords: false,
            onChooseGuide: canChoose ? () {} : null,
            onChooseSteps: canChoose ? () {} : null,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('reduced motion guide resizes safely when saving hides controls', (
    tester,
  ) async {
    await tester.pumpWidget(_cardHost());
    final initialHeight = tester.getSize(find.byType(GuidanceCard)).height;
    expect(find.text('Choose guide'), findsOneWidget);

    // EventForm removes these callbacks while its asynchronous save is pending.
    await tester.pumpWidget(_cardHost(canChoose: false));
    expect(tester.takeException(), isNull);
    expect(find.text('Choose guide'), findsNothing);
    expect(find.text('Choose starter steps'), findsNothing);
    final savedHeight = tester.getSize(find.byType(GuidanceCard)).height;
    expect(savedHeight, lessThan(initialHeight));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getSize(find.byType(GuidanceCard)).height, savedHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion event saves across keyboard resize and route pop',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final save = Completer<void>();
      EventFormSubmission? submitted;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => EventForm(
                      onSave: (submission) {
                        submitted = submission;
                        return save.future;
                      },
                    ),
                  ),
                ),
                child: const Text('Create event'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Create event'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Fictional reduced motion event',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(GuidanceCard));
      await tester.pumpAndSettle();
      expect(find.text('Your guide'), findsOneWidget);
      await tester.tap(find.text('Save event'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(submitted?.title, 'Fictional reduced motion event');
      expect(find.text('Saving…'), findsOneWidget);

      tester.view.resetViewInsets();
      save.complete();
      await tester.pumpAndSettle();
      expect(find.byType(EventForm), findsNothing);
      expect(find.text('Create event'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guide stays safe when reduced motion begins during a resize', (
    tester,
  ) async {
    await tester.pumpWidget(_cardHost(reducedMotion: false));
    await tester.pumpWidget(
      _cardHost(
        reducedMotion: false,
        width: 320,
        guide: GuidanceContext.caregiving,
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(
      _cardHost(width: 320, guide: GuidanceContext.caregiving),
    );
    await tester.pumpWidget(
      _cardHost(
        width: 640,
        guide: GuidanceContext.caregiving,
        canChoose: false,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Your guide'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
