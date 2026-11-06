// Run: flutter test --update-goldens tool/capture_learning_ui_test.dart
// Synthetic examples only. No passphrase, KDF, disk vault or OS grant is used.
// These font-dependent captures are outside the normal automated test suite.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/insights/insights_screen.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';
import 'package:steady_through/learning/device_signals.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_theme.dart';

class _CaptureRepository implements AppRepository {
  _CaptureRepository(this.value);
  AppData value;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    value = next;
  }
}

class _NoDeviceSources extends DeviceSignals {
  @override
  Future<SignalCapabilities> capabilities() async => const SignalCapabilities(
    platformNote: 'Sample preview: system usage and motion are unavailable. Manual and in-app sources remain available.',
  );

  @override
  Future<void> start({required bool usage, required bool motion}) async {
    if (usage || motion) {
      throw StateError('Captures must not enable device sources.');
    }
  }

  @override
  Future<DeviceSignalReading> read() async => const DeviceSignalReading(
    usageStatus: 'unsupported',
    motionStatus: 'unsupported',
  );

  @override
  Future<void> stop() async {}

  @override
  Future<void> openUsageSettings() async {
    throw StateError('Captures must not request OS access.');
  }

  @override
  Future<bool> requestMotionPermission() async {
    throw StateError('Captures must not request OS access.');
  }
}

AppData _sampleLearning({required bool dark}) {
  final now = DateTime.now().toUtc();
  final firstDay = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 16));
  final examples = <LearningExample>[];
  for (var day = 0; day < 15; day++) {
    for (var moment = 0; moment < 2; moment++) {
      final calm = moment == 0;
      final observed = firstDay.add(Duration(days: day, hours: calm ? 10 : 18));
      examples.add(
        LearningExample(
          id: 'fictional-$day-$moment',
          createdAt: observed,
          label: calm ? FeelingLabel.calm : FeelingLabel.tense,
          snapshot: SignalSnapshot(
            observedAt: observed,
            features: {
              'tapCount': calm
                  ? (4 + day % 3).toDouble()
                  : (60 + day % 5).toDouble(),
              'navigationChanges': calm
                  ? (1 + day % 2).toDouble()
                  : (10 + day % 3).toDouble(),
            },
          ),
        ),
      );
    }
  }
  return AppData(
    theme: dark ? ThemeChoice.dark : ThemeChoice.light,
    learning: LearningData(
      enabledSources: {SignalSource.checkIns, SignalSource.inApp},
      examples: examples,
      calibration: CalibrationState(startedAt: firstDay),
    ),
  );
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

  testWidgets('private-vault-mobile', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: steadyTheme(Brightness.light),
        debugShowCheckedModeBanner: false,
        home: VaultUnlockScreen(
          creating: true,
          onSubmit: (_) async {
            throw StateError('This preview does not create a vault.');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNWidgets(2));
    for (final field in tester.widgetList<EditableText>(
      find.byType(EditableText),
    )) {
      expect(field.controller.text, isEmpty);
      expect(field.obscureText, isTrue);
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/private-vault-mobile.png'),
    );
  });

  for (final capture in [
    ('private-insights-mobile', const Size(430, 1100), false, false),
    ('private-insights-desktop', const Size(1440, 1100), false, false),
    ('private-insights-dark', const Size(1440, 1100), true, false),
    ('private-sources-mobile', const Size(430, 1100), false, true),
  ]) {
    testWidgets(capture.$1, (tester) async {
      tester.view.physicalSize = capture.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sample = _sampleLearning(dark: capture.$3);
      final controller = AppController(_CaptureRepository(sample), sample);
      late LearningSession session;
      addTearDown(() async {
        await session.close();
        controller.dispose();
      });
      await tester.runAsync(() async {
        session = LearningSession(controller, signals: _NoDeviceSources());
        await session.initialize();
        for (var tap = 0; tap < 5; tap++) {
          session.recordTap();
        }
        session.recordNavigation();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: steadyTheme(capture.$3 ? Brightness.dark : Brightness.light),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            appBar: AppBar(title: const Text('Insights · sample data')),
            body: InsightsScreen(
              session: session,
              onGrounding: () {},
              onOpenPath: () {},
              onOpenHelp: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(session.data.examples, hasLength(30));
      expect(session.capabilities.usageSupported, isFalse);
      expect(session.capabilities.motionSupported, isFalse);
      if (capture.$4) {
        final source = find.byKey(const ValueKey('source-checkIns'));
        await tester.scrollUntilVisible(
          source,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(source), alignment: .25);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/screenshots/${capture.$1}.png'),
      );
    });
  }
}
