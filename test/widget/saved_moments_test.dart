import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/insights/saved_moments.dart';
import 'package:steady_through/learning/device_signals.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_theme.dart';
import 'package:steady_through/ui/steady_ui.dart';

class _Repository implements AppRepository {
  _Repository(this.value);
  AppData value;
  bool failSave = false;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData next) async {
    if (failSave) throw StateError('disk unavailable');
    value = next;
  }
}

class _Signals extends DeviceSignals {
  SignalCapabilities available = const SignalCapabilities();
  DeviceSignalReading reading = const DeviceSignalReading();
  @override
  Future<SignalCapabilities> capabilities() async => available;
  @override
  Future<void> start({required bool usage, required bool motion}) async {}
  @override
  Future<DeviceSignalReading> read() async => reading;
  @override
  Future<void> stop() async {}
}

void main() {
  late _Repository repository;
  late AppController controller;
  late LearningSession session;
  late _Signals signals;
  late DateTime at;
  setUp(() {
    at = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
    repository = _Repository(
      AppData(
        learning: LearningData(
          examples: [
            for (var i = 0; i < 4; i++)
              LearningExample(
                id: 'moment-$i',
                createdAt: at.subtract(Duration(days: i)),
                label: FeelingLabel.values[i],
                snapshot: SignalSnapshot(
                  observedAt: at.subtract(Duration(days: i, minutes: 1)),
                  features: i == 0
                      ? const {'tapCount': 8, 'navigationChanges': 2}
                      : const {},
                ),
              ),
          ],
        ),
      ),
    );
    controller = AppController(repository, repository.value);
    signals = _Signals();
    session = LearningSession(controller, signals: signals);
  });
  tearDown(() async {
    await session.close();
    controller.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    double width = 1100,
    double scale = 1,
    bool disabled = false,
    VoidCallback? onOpenHelp,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: steadyTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SteadyPage(
            children: [
              SavedMomentsCard(
                session: session,
                disabled: disabled,
                onChanged: () {},
                onOpenHelp: onOpenHelp,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
  }

  Future<void> settleWrite(WidgetTester tester) async {
    // The controller queue is created in real setUp; UI callbacks run in
    // widget fake-async. Alternate both until the real dialog action finishes.
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      if (find.text('Saving…').evaluate().isEmpty) return;
    }
    fail(
      'Saved-moment action remained busy across 50 real/fake event-loop passes.',
    );
  }

  testWidgets(
    'preview shows latest three and opens all retained moments with sources off',
    (tester) async {
      await show(tester);
      expect(find.byKey(const ValueKey('moment-moment-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('moment-moment-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('moment-moment-3')), findsNothing);
      await tester.tap(find.text('View all 4'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('moment-moment-3')));
      expect(find.text('Energized'), findsOneWidget);
      expect(session.data.enabledSources, isEmpty);
    },
  );

  testWidgets(
    'detail uses saved metrics and local time without inferring old consent',
    (tester) async {
      await show(tester);
      final row = find.byKey(const ValueKey('moment-moment-0'));
      await tester.tap(
        find.descendant(of: row, matching: find.text('View moment')),
      );
      await tester.pumpAndSettle();
      expect(find.text('8 taps'), findsOneWidget);
      expect(find.text('2 navigation changes'), findsOneWidget);
      final material = MaterialLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      );
      expect(
        find.textContaining(material.formatMediumDate(at.toLocal())),
        findsWidgets,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('No aggregate readings saved'), findsNWidgets(2));
    },
  );

  testWidgets('editing preserves record identity and cancel has no effect', (
    tester,
  ) async {
    await tester.runAsync(session.pause);
    await show(tester);
    final row = find.byKey(const ValueKey('moment-moment-0'));
    final edit = find.descendant(of: row, matching: find.text('Edit feeling'));
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Unsure'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      session.data.examples.firstWhere((e) => e.id == 'moment-0').label,
      FeelingLabel.calm,
    );
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Unsure'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await settleWrite(tester);
    await tester.pumpAndSettle();
    expect(
      session.data.examples.firstWhere((e) => e.id == 'moment-0').id,
      'moment-0',
    );
    expect(
      session.data.examples.firstWhere((e) => e.id == 'moment-0').label,
      FeelingLabel.unsure,
    );
    expect(
      session.data.examples.firstWhere((e) => e.id == 'moment-0').createdAt,
      at,
    );
    expect(
      session.data.examples
          .firstWhere((e) => e.id == 'moment-0')
          .snapshot
          .features,
      {'tapCount': 8, 'navigationChanges': 2},
    );
    expect(session.paused, isTrue);
  });

  testWidgets(
    'delete identifies the selected moment and requires confirmation',
    (tester) async {
      await show(tester);
      final row = find.byKey(const ValueKey('moment-moment-0'));
      final delete = find.descendant(of: row, matching: find.text('Delete'));
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.textContaining('Calm'), findsWidgets);
      await tester.tap(find.text('Keep moment'));
      await tester.pumpAndSettle();
      expect(session.data.examples, hasLength(4));
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete moment'));
      await settleWrite(tester);
      await tester.pumpAndSettle();
      expect(session.data.examples.map((e) => e.id), [
        'moment-3',
        'moment-2',
        'moment-1',
      ]);
      expect(find.textContaining('Deleted Calm'), findsOneWidget);
    },
  );

  testWidgets('failed correction stays in the dialog and retry commits once', (
    tester,
  ) async {
    await show(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('moment-moment-0')),
        matching: find.text('Edit feeling'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Low'));
    await tester.pump();
    repository.failSave = true;
    await tester.tap(find.text('Save changes'));
    await settleWrite(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(
      session.data.examples.firstWhere((e) => e.id == 'moment-0').label,
      FeelingLabel.calm,
    );
    repository.failSave = false;
    await tester.tap(find.text('Save changes'));
    await settleWrite(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(session.data.examples, hasLength(4));
    expect(session.data.examples.last.label, FeelingLabel.low);
  });

  testWidgets(
    'busy history keeps records visible while its actions are disabled',
    (tester) async {
      await show(tester, disabled: true);
      expect(find.byKey(const ValueKey('moment-moment-0')), findsOneWidget);
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'View all 4'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'narrow large text supports edit, detail and delete without overflow',
    (tester) async {
      await show(tester, width: 320, scale: 2);
      for (final action in ['View moment', 'Edit feeling', 'Delete']) {
        final control = find.descendant(
          of: find.byKey(const ValueKey('moment-moment-0')),
          matching: find.text(action),
        );
        await reveal(tester, control);
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: action);
        final dismiss = find.text(
          action == 'View moment'
              ? 'Close'
              : action == 'Edit feeling'
              ? 'Cancel'
              : 'Keep moment',
        );
        await tester.ensureVisible(dismiss);
        await tester.tap(dismiss);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$action dismissed');
      }
    },
  );
  testWidgets(
    'failed delete keeps the selected moment and offers a safe retry',
    (tester) async {
      await show(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('moment-moment-0')),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      repository.failSave = true;
      await tester.tap(find.text('Delete moment'));
      await settleWrite(tester);
      expect(find.textContaining('Could not delete'), findsOneWidget);
      expect(session.data.examples, hasLength(4));
      repository.failSave = false;
      await tester.tap(find.text('Delete moment'));
      await settleWrite(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(session.data.examples.any((e) => e.id == 'moment-0'), isFalse);
    },
  );

  testWidgets(
    'open full history responds to vehicle context and preserves help',
    (tester) async {
      var helpOpened = 0;
      await show(tester, onOpenHelp: () => helpOpened++);
      await tester.tap(find.text('View all 4'));
      await tester.pumpAndSettle();
      signals.available = const SignalCapabilities(
        motionSupported: true,
        motionGranted: true,
      );
      signals.reading = const DeviceSignalReading(possibleVehicle: true);
      await tester.runAsync(
        () => session.setSources({
          SignalSource.motion,
        }, deviceOwnerConfirmed: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit feeling'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('Return when safely stopped'), findsOneWidget);
      await tester.tap(find.text('Help now'));
      expect(helpOpened, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(session.close);
      await tester.pump();
    },
  );
  testWidgets(
    'saved detail preserves fractional minutes including a nonzero small reading',
    (tester) async {
      await tester.runAsync(
        () => controller.updateLearning(
          LearningData(
            examples: [
              LearningExample(
                id: 'fractional',
                createdAt: at,
                label: FeelingLabel.calm,
                snapshot: SignalSnapshot(
                  observedAt: at,
                  features: const {
                    'activeMinutes': 0.04,
                    'walkingMinutes': 0.75,
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await show(tester);
      await tester.tap(find.text('View moment'));
      await tester.pumpAndSettle();
      expect(find.text('0.04 active minutes'), findsOneWidget);
      expect(find.text('0.75 walking minutes'), findsOneWidget);
      expect(find.text('0.0 active minutes'), findsNothing);
    },
  );

  testWidgets('feeling-only detail includes its original observation time', (
    tester,
  ) async {
    final moment = session.data.examples.firstWhere((e) => e.id == 'moment-1');
    await show(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('moment-moment-1')),
        matching: find.text('View moment'),
      ),
    );
    await tester.pumpAndSettle();
    final locale = MaterialLocalizations.of(
      tester.element(find.byType(AlertDialog)),
    );
    final observed = locale.formatTimeOfDay(
      TimeOfDay.fromDateTime(moment.snapshot.observedAt.toLocal()),
    );
    expect(find.textContaining(observed), findsOneWidget);
  });
}
