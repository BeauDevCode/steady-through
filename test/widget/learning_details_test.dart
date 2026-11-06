import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/features/insights/learning_details.dart';
import 'package:steady_through/learning/device_signals.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_theme.dart';
import 'package:steady_through/ui/steady_ui.dart';

class _Repository implements AppRepository {
  _Repository(this.data);
  AppData data;
  @override
  Future<AppData> load() async => data;
  @override
  Future<void> save(AppData value) async {
    data = value;
  }
}

class _Signals extends DeviceSignals {
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets(
    'retention invalidates displayed model results before a pruning write',
    (tester) async {
      final now = DateTime.now().toUtc();
      final initial = AppData(
        learning: LearningData(
          enabledSources: {SignalSource.checkIns},
          examples: [
            for (final days in [181, 1])
              LearningExample(
                id: 'moment-$days',
                createdAt: now.subtract(Duration(days: days)),
                label: FeelingLabel.calm,
                snapshot: SignalSnapshot(
                  observedAt: now.subtract(Duration(days: days)),
                ),
              ),
          ],
          calibration: CalibrationState(
            startedAt: now.subtract(const Duration(days: 100)),
            lastReviewedAt: now.subtract(const Duration(days: 5)),
            lastAdoptedAt: now.subtract(const Duration(days: 5)),
            revision: 2,
            trainingCount: 30,
            heldOutCount: 12,
            candidateCorrect: 10,
            baselineCorrect: 6,
            lastReviewReason: 'Old evaluated model',
            model: CalibratedPattern(
              trainedFrom: now.subtract(const Duration(days: 70)),
              trainedThrough: now.subtract(const Duration(days: 30)),
              distinctDays: 14,
              centroids: const {
                FeelingLabel.calm: {'tapCount': 4, 'navigationChanges': 1},
                FeelingLabel.tense: {'tapCount': 60, 'navigationChanges': 15},
              },
              scales: const {'tapCount': 56, 'navigationChanges': 14},
              sampleCounts: const {
                FeelingLabel.calm: 15,
                FeelingLabel.tense: 15,
              },
            ),
          ),
        ),
      );
      final repository = _Repository(initial);
      final controller = AppController(repository, initial);
      final session = LearningSession(controller, signals: _Signals());
      addTearDown(() async {
        await session.close();
        controller.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: steadyTheme(Brightness.light),
          home: Scaffold(
            body: SteadyPage(
              children: [
                LearningDetails(
                  session: session,
                  working: false,
                  onReview: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show details'));
      await tester.pumpAndSettle();
      expect(find.text('Personal model revision 0'), findsOneWidget);
      expect(find.text('Old evaluated model'), findsNothing);
      expect(
        find.text('30 earlier examples · 12 later examples'),
        findsNothing,
      );
      expect(
        repository.data.learning.examples,
        hasLength(2),
        reason: 'Viewing details must not write/prune the vault.',
      );
      expect(repository.data.learning.calibration.revision, 2);
    },
  );
}
