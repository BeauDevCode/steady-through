import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/pattern_engine.dart';

final reviewedAt = DateTime.utc(2026, 11, 5, 12);
LearningData separableHistory() => LearningData(
  enabledSources: {SignalSource.checkIns, SignalSource.inApp},
  examples: [
    for (var i = 0; i < 80; i++)
      LearningExample(
        id: 'old-$i',
        createdAt: reviewedAt.subtract(Duration(days: 79 - i)),
        label: i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
        snapshot: SignalSnapshot(
          observedAt: reviewedAt.subtract(Duration(days: 79 - i)),
          features: {
            'tapCount': i.isEven ? 10 : 100,
            'navigationChanges': i.isEven ? 1 : 10,
          },
        ),
      ),
  ],
);

void main() {
  test('calibration evidence survives a vault document round trip', () {
    final review = PersonalPatternEngine().review(
      separableHistory(),
      now: reviewedAt,
    );
    final restored = LearningData.fromJson(review.data.toJson());
    expect(restored.calibration.trainingCount, 56);
    expect(restored.calibration.heldOutCount, 24);
    expect(restored.calibration.candidateCorrect, 24);
    expect(restored.calibration.baselineCorrect, 12);
    expect(restored.calibration.lastReviewReason, isNotEmpty);
  });

  test(
    'import rejects evaluation counts that claim more correct than evaluated',
    () {
      final json = LearningData().toJson();
      final calibration = json['calibration'] as Map;
      calibration['heldOutCount'] = 12;
      calibration['candidateCorrect'] = 13;
      expect(() => LearningData.fromJson(json), throwsFormatException);
    },
  );

  test('labels only retain signals from enabled sources', () {
    final example = LearningExample(
      id: 'one',
      createdAt: reviewedAt,
      label: FeelingLabel.calm,
      snapshot: SignalSnapshot(
        observedAt: reviewedAt,
        features: {'tapCount': 12, 'deviceSwitches': 2, 'walkingMinutes': .5},
        possibleVehicle: true,
      ),
    );
    final data = LearningData(enabledSources: {SignalSource.inApp})
        .record(example, now: reviewedAt);
    expect(data.examples.single.snapshot.features, {'tapCount': 12.0});
    expect(data.examples.single.snapshot.possibleVehicle, isFalse);
  });

  test(
    'labelling one old observation across many days does not create diversity',
    () {
      final observed = reviewedAt.subtract(const Duration(days: 40));
      final data = LearningData(
        enabledSources: {SignalSource.inApp},
        examples: [
          for (var i = 0; i < 30; i++)
            LearningExample(
              id: 'repeat-$i',
              createdAt: reviewedAt.subtract(Duration(days: 29 - i)),
              label: i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
              snapshot: SignalSnapshot(
                observedAt: observed,
                features: {
                  'tapCount': i.isEven ? 10 : 100,
                  'navigationChanges': i.isEven ? 1 : 10,
                },
              ),
            ),
        ],
      );
      final insight = PersonalPatternEngine().assess(
        data,
        SignalSnapshot(
          observedAt: reviewedAt,
          features: {'tapCount': 10, 'navigationChanges': 1},
        ),
        now: reviewedAt,
      );
      expect(insight.status, PatternStatus.insufficientEvidence);
      expect(insight.label, isNull);
    },
  );

  test('retention also expires old snapshots that were labelled recently', () {
    final data = LearningData(
      examples: [
        LearningExample(
          id: 'old-snapshot',
          createdAt: reviewedAt,
          label: FeelingLabel.calm,
          snapshot: SignalSnapshot(
            observedAt: reviewedAt.subtract(const Duration(days: 181)),
          ),
        ),
      ],
    );
    expect(data.bounded(reviewedAt).examples, isEmpty);
  });

  test('past vehicle duration is not treated as current vehicle movement', () {
    final data = separableHistory().copyWith(
      enabledSources: {
        SignalSource.inApp,
        SignalSource.checkIns,
        SignalSource.motion,
      },
      deviceOwnerConfirmed: true,
    );
    final insight = PersonalPatternEngine().assess(
      data,
      SignalSnapshot(
        observedAt: reviewedAt,
        possibleVehicle: false,
        features: {'tapCount': 10, 'navigationChanges': 1, 'vehicleMinutes': 4},
      ),
      now: reviewedAt,
    );
    expect(insight.status, PatternStatus.tentativeMatch);
    expect(insight.canReflect, isTrue);
  });

  test('contradictory later labels suppress a previously adopted pattern', () {
    final engine = PersonalPatternEngine();
    var data = engine.review(separableHistory(), now: reviewedAt).data;
    for (var i = 1; i <= 20; i++) {
      final date = reviewedAt.add(Duration(days: i));
      data = data.record(
        LearningExample(
          id: 'later-$i',
          createdAt: date,
          label: i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
          snapshot: SignalSnapshot(
            observedAt: date,
            features: {
              'tapCount': i.isEven ? 100 : 10,
              'navigationChanges': i.isEven ? 10 : 1,
            },
          ),
        ),
        now: date,
      );
    }
    final at = reviewedAt.add(const Duration(days: 20));
    final insight = engine.assess(
      data,
      SignalSnapshot(
        observedAt: at,
        features: {'tapCount': 10, 'navigationChanges': 1},
      ),
      now: at,
    );
    expect(insight.status, PatternStatus.uncertain);
    expect(insight.label, isNull);
  });
}
