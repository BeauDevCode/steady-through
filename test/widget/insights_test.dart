import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/insights/insights_screen.dart';
import 'package:steady_through/learning/device_signals.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_theme.dart';

class _Repository implements AppRepository {
  AppData value = AppData.empty();
  bool failNextSave = false;

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('disk unavailable');
    }
    value = next;
  }
}

class _Signals extends DeviceSignals {
  SignalCapabilities available = const SignalCapabilities();
  DeviceSignalReading next = const DeviceSignalReading();
  int permissionRequests = 0;
  int settingsRequests = 0;

  @override
  Future<SignalCapabilities> capabilities() async => available;
  @override
  Future<void> start({required bool usage, required bool motion}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<DeviceSignalReading> read() async => next;
  @override
  Future<bool> requestMotionPermission() async {
    permissionRequests++;
    return false;
  }

  @override
  Future<void> openUsageSettings() async {
    settingsRequests++;
  }
}

void main() {
  late _Repository repository;
  late AppController controller;
  late _Signals signals;
  late LearningSession session;

  setUp(() {
    repository = _Repository();
    controller = AppController(repository, AppData.empty());
    signals = _Signals();
    session = LearningSession(controller, signals: signals);
  });

  tearDown(() async {
    await session.close();
    controller.dispose();
  });

  void insightsTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        // Insights borrows the vault owner's session. The widget cannot close
        // it on route disposal. Close that test-owned session before Flutter
        // checks pending fake timers; package tearDown runs after that check.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(session.close);
        await tester.pump();
      }
    });
  }

  Future<void> show(
    WidgetTester tester, {
    VoidCallback? onOpenHelp,
    bool reducedMotion = false,
    double width = 1100,
  }) async {
    tester.view.physicalSize = Size(width, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(session.initialize);
    await tester.pumpWidget(
      MaterialApp(
        theme: steadyTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
          body: InsightsScreen(session: session, onOpenHelp: onOpenHelp),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      400,
      maxScrolls:
          100, // At 200% the test font produces over 30,000px of content.
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
  }

  Future<void> settleWrite(WidgetTester tester) async {
    // The consent write commits before LearningSession's native-sync future
    // finishes. That future can cross the real setUp and widget fake-async
    // zones more than once. Wait for the actual UI action boundary, not one
    // arbitrary real/fake event-loop flush or merely a visible source value.
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      final sourceReady = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .any((control) => control.onChanged != null);
      final actionReady = tester
          .widgetList<OutlinedButton>(find.byType(OutlinedButton))
          .any((control) => control.onPressed != null);
      if (sourceReady || actionReady) return;
    }
    fail(
      'Insights controls remained busy after 50 real/fake event-loop passes.',
    );
  }

  insightsTest(
    'reduced motion reflection safely pauses, resumes and resizes with sources off',
    (tester) async {
      await show(tester, reducedMotion: true, width: 400);
      expect(session.data.enabledSources, isEmpty);
      await tester.tap(find.text('Pause learning'));
      await settleWrite(tester);
      expect(session.paused, isTrue);
      expect(find.text('Learning is paused'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(600, 2200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Resume learning'));
      await settleWrite(tester);
      expect(session.paused, isFalse);
      expect(find.text('Not enough evidence yet'), findsOneWidget);
      expect(session.data.enabledSources, isEmpty);
      expect(session.snapshot.features, isEmpty);
      expect(signals.permissionRequests, 0);
      expect(signals.settingsRequests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  insightsTest(
    'sources default off with no permission requests or invented aggregate zeroes',
    (tester) async {
      await show(tester);
      await reveal(tester, find.byKey(const ValueKey('source-checkIns')));
      expect(session.data.enabledSources, isEmpty);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('source-checkIns')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('source-inApp')))
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('source-deviceUsage')),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('source-motion')))
            .onChanged,
        isNull,
      );
      await reveal(tester, find.text('App activations'));
      expect(find.text('Unavailable'), findsWidgets);
      expect(signals.permissionRequests, 0);
      expect(signals.settingsRequests, 0);
      expect(repository.value.learning.examples, isEmpty);
    },
  );

  insightsTest(
    'manual-only consent permits an explicit feeling label without device permission',
    (tester) async {
      await show(tester);
      await reveal(tester, find.byKey(const ValueKey('source-checkIns')));
      await tester.tap(find.byKey(const ValueKey('source-checkIns')));
      await settleWrite(tester);
      expect(session.data.enabledSources, {SignalSource.checkIns});
      await reveal(tester, find.text('Calm'));
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Calm'))
            .onPressed,
        isNotNull,
        reason:
            'The consent write and source synchronization must finish before the next feeling action; paused=${session.paused}.',
      );
      await tester.tap(find.text('Calm'));
      await settleWrite(tester);
      expect(controller.data.learning.examples.single.label, FeelingLabel.calm);
      expect(
        controller.data.learning.examples.single.snapshot.features,
        isEmpty,
      );
      expect(signals.permissionRequests, 0);
      expect(signals.settingsRequests, 0);
      expect(find.textContaining('self-reported'), findsWidgets);
    },
  );

  insightsTest(
    'possible vehicle context removes reflection choices while keeping help available',
    (tester) async {
      signals.available = const SignalCapabilities(
        motionSupported: true,
        motionGranted: true,
      );
      signals.next = const DeviceSignalReading(
        possibleVehicle: true,
        motionStatus: 'session-only',
      );
      await tester.runAsync(
        () => session.setSources({
          SignalSource.motion,
        }, deviceOwnerConfirmed: true),
      );
      var helpOpened = 0;
      await show(tester, onOpenHelp: () => helpOpened++);
      expect(find.text('Return when safely stopped'), findsOneWidget);
      expect(find.text('Calm'), findsNothing);
      expect(find.text('Tense'), findsNothing);
      expect(find.text('Low'), findsNothing);
      await tester.tap(find.text('Get help'));
      await tester.pumpAndSettle();
      expect(helpOpened, 1);
      expect(controller.data.learning.examples, isEmpty);
    },
  );

  insightsTest(
    'system consent requires owner confirmation and never silently asks the OS for permission',
    (tester) async {
      signals.available = const SignalCapabilities(motionSupported: true);
      await show(tester);
      final motion = find.byKey(const ValueKey('source-motion'));
      await reveal(tester, motion);
      await tester.tap(motion);
      await tester.pumpAndSettle();
      expect(find.text('This is my device'), findsOneWidget);
      await tester.tap(find.text('Keep off'));
      await tester.pumpAndSettle();
      expect(session.data.enabledSources, isEmpty);
      await tester.tap(motion);
      await tester.pumpAndSettle();
      await tester.tap(find.text('This is my device'));
      await settleWrite(tester);
      expect(session.data.enabledSources, {SignalSource.motion});
      expect(session.data.deviceOwnerConfirmed, isTrue);
      expect(signals.permissionRequests, 0);
      await reveal(tester, find.text('Allow motion access'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Allow motion access'),
            )
            .onPressed,
        isNotNull,
        reason:
            'The consent write and source synchronization must finish before the separate OS permission action; paused=${session.paused}.',
      );
      await tester.tap(find.text('Allow motion access'));
      await settleWrite(tester);
      expect(signals.permissionRequests, 1);
      expect(controller.data.learning.examples, isEmpty);
    },
  );

  insightsTest(
    'failed label write preserves learning and presents retry feedback',
    (tester) async {
      await tester.runAsync(() => session.setSources({SignalSource.checkIns}));
      await show(tester);
      repository.failNextSave = true;
      await tester.tap(find.text('Tense'));
      await settleWrite(tester);
      expect(controller.data.learning.examples, isEmpty);
      expect(
        find.textContaining('Could not save this feeling'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tense'));
      await settleWrite(tester);
      expect(
        controller.data.learning.examples.single.label,
        FeelingLabel.tense,
      );
    },
  );

  insightsTest(
    'clearing learning requires confirmation and preserves the persons events',
    (tester) async {
      await tester.runAsync(() async {
        await controller.createEvent('Starting a new job', '');
        await session.setSources({SignalSource.checkIns});
        await session.saveFeeling(FeelingLabel.calm);
      });
      await show(tester);
      await reveal(tester, find.text('Clear learning'));
      await tester.tap(find.text('Clear learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep learning'));
      await tester.pumpAndSettle();
      expect(session.data.examples, hasLength(1));
      await tester.tap(find.text('Clear learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear learning').last);
      await settleWrite(tester);
      expect(session.data.examples, isEmpty);
      expect(session.data.enabledSources, isEmpty);
      expect(controller.data.events.single.title, 'Starting a new job');
    },
  );

  insightsTest(
    'a source that becomes unsupported can still be revoked individually',
    (tester) async {
      await tester.runAsync(
        () => session.setSources({
          SignalSource.checkIns,
          SignalSource.motion,
        }, deviceOwnerConfirmed: true),
      );
      await show(tester);
      final motion = find.byKey(const ValueKey('source-motion'));
      await reveal(tester, motion);
      await tester.tap(motion);
      await settleWrite(tester);
      expect(session.data.enabledSources, {SignalSource.checkIns});
      expect(tester.widget<SwitchListTile>(motion).value, isFalse);
      expect(tester.widget<SwitchListTile>(motion).onChanged, isNull);
    },
  );

  insightsTest(
    'Insights remains usable at narrow 200 percent text with reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(session.initialize);
      await tester.pumpWidget(
        MaterialApp(
          theme: steadyTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(body: InsightsScreen(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Not enough evidence yet'));
      expect(find.byType(AnimatedSwitcher), findsNothing);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(tester.takeException(), isNull);
      for (final label in <String>[
        'Feeling check-ins',
        'In-app activity',
        'Device usage',
        'Motion context',
        'App activations',
        'A thoughtful 60-day review',
        'Clear learning',
      ]) {
        try {
          await reveal(tester, find.text(label));
        } catch (error) {
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          fail(
            'Could not reveal $label: $error; offset=${position.pixels}, extent=${position.maxScrollExtent}',
          );
        }
        expect(tester.takeException(), isNull, reason: 'Layout at $label');
      }
      expect(session.data.enabledSources, isEmpty);
      expect(signals.permissionRequests, 0);
      expect(signals.settingsRequests, 0);
    },
  );
}
