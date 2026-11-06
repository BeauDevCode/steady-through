import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/pattern_engine.dart';

final now = DateTime.utc(2026, 11, 5, 12);
final engine = PersonalPatternEngine();
SignalSnapshot signal(double taps, {DateTime? date, bool vehicle = false}) =>
    SignalSnapshot(
      observedAt: date ?? now,
      possibleVehicle: vehicle,
      features: {'tapCount': taps, 'navigationChanges': taps / 10},
    );
LearningExample entry(
  int i,
  FeelingLabel label,
  DateTime date, {
  bool manual = false,
  double? taps,
}) => LearningExample(
  id: 'example-$i',
  createdAt: date,
  label: label,
  snapshot: manual
      ? SignalSnapshot(observedAt: date)
      : signal(taps ?? (label == FeelingLabel.calm ? 10 : 100), date: date),
);
LearningData covered({bool contradictory = false, bool manual = false}) =>
    LearningData(
      enabledSources: {SignalSource.checkIns, if (!manual) SignalSource.inApp},
      examples: [
        for (var i = 0; i < 30; i++)
          entry(
            i,
            i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
            now.subtract(Duration(days: 30 - i)),
            manual: manual,
            taps: contradictory ? 20 : null,
          ),
      ],
    );
LearningData reviewFixture({bool shifted = false}) => LearningData(
  enabledSources: {SignalSource.checkIns, SignalSource.inApp},
  examples: [
    for (var i = 0; i < 80; i++)
      entry(
        i,
        i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
        now.subtract(Duration(days: 79 - i)),
        taps: shifted && i >= 56 ? (i.isEven ? 100 : 10) : null,
      ),
  ],
);

void main() {
  test(
    'sparse, single-label and incomparable examples remain insufficient',
    () {
      expect(
        engine.assess(LearningData(), signal(10), now: now).status,
        PatternStatus.insufficientEvidence,
      );
      final oneClass = LearningData(
        enabledSources: {SignalSource.checkIns, SignalSource.inApp},
        examples: [
          for (var i = 0; i < 30; i++) entry(i, FeelingLabel.calm, now),
        ],
      );
      expect(engine.assess(oneClass, signal(10), now: now).label, isNull);
      final incomparable = engine.assess(
        covered(),
        SignalSnapshot(
          observedAt: now,
          features: {'deviceSwitches': 1, 'activeMinutes': 5},
        ),
        now: now,
      );
      expect(incomparable.status, PatternStatus.insufficientEvidence);
      expect(incomparable.label, isNull);
    },
  );

  test(
    'rapid repeated labels are not mistaken for days of personal history',
    () {
      final burst = LearningData(
        enabledSources: {SignalSource.checkIns, SignalSource.inApp},
        examples: [
          for (var i = 0; i < 30; i++)
            entry(i, i.isEven ? FeelingLabel.calm : FeelingLabel.tense, now),
        ],
      );
      expect(
        engine.assess(burst, signal(10), now: now).status,
        PatternStatus.insufficientEvidence,
      );
      expect(PersonalPatternEngine.minimumExamples, greaterThan(1));
      expect(PersonalPatternEngine.minimumDistinctDays, greaterThan(1));
    },
  );

  test(
    'comparable repeated labels give a tentative explainable reflection',
    () {
      final insight = engine.assess(covered(), signal(10), now: now);
      expect(insight.status, PatternStatus.tentativeMatch);
      expect(insight.label, FeelingLabel.calm);
      expect(insight.evidence.toLowerCase(), contains('you marked'));
      expect(insight.isTentative, isTrue);
      expect(insight.canReflect, isTrue);
      expect(insight.suggestion, isNotEmpty);
    },
  );

  test('contradictory patterns and patterns far outside prior examples stay uncertain', () {
    for (final insight in [
      engine.assess(covered(contradictory: true), signal(20), now: now),
      engine.assess(covered(), signal(10000), now: now),
    ]) {
      expect(insight.status, PatternStatus.uncertain);
      expect(insight.label, isNull);
    }
  });

  test(
    'manual-only labels show a self-reported trend without a prediction',
    () {
      final insight = engine.assess(
        covered(manual: true),
        SignalSnapshot(observedAt: now),
        now: now,
      );
      expect(insight.status, PatternStatus.selfReportedTrend);
      expect(insight.label, isNull);
      expect(insight.evidence.toLowerCase(), contains('self-reported'));
    },
  );

  test('possible vehicle movement suppresses reflections even with sufficient data', () {
    final insight = engine.assess(
      covered(),
      signal(10, vehicle: true),
      now: now,
    );
    expect(insight.status, PatternStatus.possibleVehicle);
    expect(insight.isVehicleContext, isTrue);
    expect(insight.canReflect, isFalse);
    expect(insight.label, isNull);
    expect(insight.suggestion.toLowerCase(), contains('stopped'));
  });

  test('expired and future labels never create evidence', () {
    final data = LearningData(
      enabledSources: {SignalSource.checkIns, SignalSource.inApp},
      examples: [
        for (var i = 0; i < 40; i++)
          entry(
            i,
            i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
            i < 20
                ? now.subtract(const Duration(days: 181))
                : now.add(const Duration(days: 1)),
          ),
      ],
    );
    expect(
      engine.assess(data, signal(10), now: now).status,
      PatternStatus.insufficientEvidence,
    );
  });

  test('calibration cannot run until sixty days of local history exist', () {
    final review = engine.review(covered(), now: now);
    expect(review.report.status, CalibrationStatus.notDue);
    expect(review.data.calibration.revision, 0);
    expect(review.report.adopted, isFalse);
  });

  test('sparse or manual-only sixty-day histories explain why an update is unavailable', () {
    final data = LearningData(
      enabledSources: {SignalSource.checkIns},
      examples: [
        for (var i = 0; i < 15; i++)
          entry(
            i,
            i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
            now.subtract(Duration(days: 70 - i)),
            manual: true,
          ),
      ],
    );
    final review = engine.review(data, now: now);
    expect(review.report.status, CalibrationStatus.insufficientEvidence);
    expect(review.report.reason, isNotEmpty);
    expect(review.data.calibration.revision, 0);
  });

  test(
    'calibration adopts only a temporally held-out improvement over majority',
    () {
      final review = engine.review(reviewFixture(), now: now);
      expect(review.report.status, CalibrationStatus.adopted);
      expect(review.report.trainingCount, 56);
      expect(review.report.heldOutCount, 24);
      expect(review.report.candidateCorrect, 24);
      expect(review.report.baselineCorrect, 12);
      expect(review.data.calibration.revision, 1);
      expect(review.data.calibration.lastAdoptedAt, now);
      final restored = LearningData.fromJson(review.data.toJson());
      expect(
        engine.assess(restored, signal(10), now: now).label,
        FeelingLabel.calm,
      );
      expect(
        engine
            .review(restored, now: now.add(const Duration(days: 1)))
            .report
            .status,
        CalibrationStatus.notDue,
      );
    },
  );

  test('temporal shifts do not get rescued by randomizing the holdout', () {
    final review = engine.review(reviewFixture(shifted: true), now: now);
    expect(review.report.status, CalibrationStatus.noImprovement);
    expect(review.report.candidateCorrect, 0);
    expect(review.data.calibration.revision, 0);
    expect(review.data.calibration.model, isNull);
  });

  test(
    'same-timestamp labels cannot straddle a temporal training boundary',
    () {
      final data = LearningData(
        enabledSources: {SignalSource.checkIns, SignalSource.inApp},
        examples: [
          for (var i = 0; i < 80; i++)
            entry(
              i,
              i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
              now.subtract(const Duration(days: 70)),
            ),
        ],
      );
      final review = engine.review(data, now: now);
      expect(review.report.status, CalibrationStatus.insufficientEvidence);
      expect(review.data.calibration.revision, 0);
    },
  );
}
