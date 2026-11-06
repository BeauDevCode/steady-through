// Run: flutter test --update-goldens tool/capture_feedback_ui_test.dart
// Actual feedback widgets with synthetic opinions and bundled fonts.
// Uses memory only: no vault, passphrase, LearningSession or native permissions.
// Golden files live in docs/screenshots/what-helps/.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/tools/feedback/tool_feedback_history.dart';
import 'package:steady_through/features/tools/feedback/tool_feedback_prompt.dart';
import 'package:steady_through/features/tools/feedback/what_helps_card.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/tool_feedback.dart';
import 'package:steady_through/ui/steady_theme.dart';
import 'package:steady_through/ui/steady_ui.dart';

class _CaptureRepository implements AppRepository {
  _CaptureRepository(this.value);
  AppData value;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async => value = next;
}

class _Profile {
  const _Profile(
    this.name,
    this.size, {
    this.dark = false,
    this.simple = false,
    this.scale = 1,
    this.reducedMotion = false,
  });

  final String name;
  final Size size;
  final bool dark;
  final bool simple;
  final double scale;
  final bool reducedMotion;
}

AppData _fictionalData(_Profile profile) {
  // Relative fictional dates keep the fixture inside the actual UI's retention
  // window. Capture regeneration intentionally reflects the local date format.
  final now = DateTime.now().toUtc();
  final yesterday = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 1));
  ToolFeedback answer(
    String id,
    SupportTool tool,
    ToolRating rating,
    int hoursAgo,
  ) => ToolFeedback(
    id: id,
    createdAt: yesterday.subtract(Duration(hours: hoursAgo)),
    tool: tool,
    rating: rating,
  );

  return AppData(
    theme: profile.dark ? ThemeChoice.dark : ThemeChoice.light,
    readingStyle: profile.simple ? ReadingStyle.simple : ReadingStyle.standard,
    toolFeedback: ToolFeedbackData(
      ratings: [
        answer(
          'fictional-grounding-1',
          SupportTool.grounding,
          ToolRating.helpful,
          48,
        ),
        answer(
          'fictional-game-1',
          SupportTool.pathGame,
          ToolRating.helpful,
          36,
        ),
        answer(
          'fictional-breathing-1',
          SupportTool.breathing,
          ToolRating.helpful,
          24,
        ),
        answer(
          'fictional-game-2',
          SupportTool.pathGame,
          ToolRating.notThisTime,
          12,
        ),
        answer(
          'fictional-breathing-2',
          SupportTool.breathing,
          ToolRating.helpful,
          0,
        ),
      ],
    ),
  );
}

Widget _app(
  _Profile profile,
  String scene,
  AppController controller,
  Widget home,
) => MaterialApp(
  key: ValueKey('${profile.name}-$scene'),
  debugShowCheckedModeBanner: false,
  theme: steadyTheme(Brightness.light),
  darkTheme: steadyTheme(Brightness.dark),
  themeMode: controller.data.theme == ThemeChoice.dark
      ? ThemeMode.dark
      : ThemeMode.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(profile.scale),
      disableAnimations: profile.reducedMotion,
      accessibleNavigation: profile.reducedMotion,
    ),
    child: child!,
  ),
  home: home,
);

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../docs/screenshots/what-helps/$name.png'),
  );
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final dialog = find.byType(AlertDialog);
  final scrollable = dialog.evaluate().isNotEmpty
      ? find.descendant(of: dialog, matching: find.byType(Scrollable)).first
      : find.byType(Scrollable).first;
  for (var scroll = 0; finder.evaluate().isEmpty && scroll < 30; scroll++) {
    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets, reason: 'Missing reachable control $finder');
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
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

  for (final profile in const [
    _Profile('standard-light-mobile', Size(390, 1100)),
    _Profile('standard-dark-desktop', Size(1280, 1100), dark: true),
    _Profile(
      'simple-light-narrow-200-reduced-motion',
      Size(320, 1100),
      simple: true,
      scale: 2,
      reducedMotion: true,
    ),
  ]) {
    testWidgets('feedback captures ${profile.name}', (tester) async {
      tester.view.physicalSize = profile.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = _fictionalData(profile);
      final controller = AppController(_CaptureRepository(data), data);
      addTearDown(controller.dispose);
      String file(String scene) => '$scene-${profile.name}';

      await tester.pumpWidget(
        _app(
          profile,
          'prompt',
          controller,
          Scaffold(
            appBar: AppBar(title: const Text('Grounding')),
            body: SteadyPage(
              maxWidth: 760,
              children: [
                ToolFeedbackPrompt(
                  controller: controller,
                  tool: SupportTool.grounding,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Rate this tool (optional)'));
      await _capture(tester, file('prompt-expanded'));
      if (profile.scale > 1) {
        await _reveal(tester, find.text('Helpful'));
        await _capture(tester, file('prompt-actions'));
      }
      await _tapVisible(tester, find.text('Helpful'));
      expect(controller.data.toolFeedback.ratings, hasLength(6));
      await _reveal(tester, find.text('Rating saved'));
      await _capture(tester, file('prompt-saved'));

      // A fresh route renders the actual summary without retaining prompt UI.
      await tester.pumpWidget(
        _app(
          profile,
          'summary',
          controller,
          Scaffold(
            appBar: AppBar(title: const Text('Tools')),
            body: SteadyPage(
              maxWidth: 960,
              children: [
                WhatHelpsCard(controller: controller, onOpenTool: (_) {}),
              ],
            ),
          ),
        ),
      );
      await _capture(tester, file('summary'));
      await _reveal(tester, find.text('A tool to revisit'));
      await _capture(tester, file('summary-idea'));
      await _reveal(tester, find.text('Show optional ratings after tools'));
      await _capture(tester, file('summary-settings'));
      await _tapVisible(tester, find.text('View and manage ratings'));
      expect(find.byType(ToolFeedbackHistory), findsOneWidget);
      await _capture(tester, file('history'));

      await _tapVisible(tester, find.text('Add a rating'));
      expect(find.byType(AlertDialog), findsOneWidget);
      await _capture(tester, file('dialog-add'));
      await _tapVisible(tester, find.text('Cancel'));

      await _reveal(tester, find.text('Change'));
      await _capture(tester, file('history-records'));
      await _tapVisible(tester, find.text('Change'));
      expect(find.text('Change your rating'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<ToolRating>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not this time').last);
      await tester.pumpAndSettle();
      await _capture(tester, file('dialog-change'));
      await _tapVisible(tester, find.text('Cancel'));

      expect(controller.data.learning.enabledSources, isEmpty);
      expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.gameRounds, isEmpty);
      expect(controller.data.toolFeedback.ratings, hasLength(6));
      // Dispose foreground observers/listeners before the borrowed controller.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
