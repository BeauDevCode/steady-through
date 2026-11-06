import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/pattern_engine.dart';

void main() {
  test('reflection evidence counts comparable training observations only', () {
    final now = DateTime.utc(2026, 11, 5, 12);
    final data = LearningData(
      enabledSources: {SignalSource.checkIns, SignalSource.inApp},
      examples: [
        for (var i = 0; i < 30; i++)
          LearningExample(
            id: 'aggregate-$i',
            createdAt: now.subtract(Duration(days: 29 - i)),
            label: i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
            snapshot: SignalSnapshot(
              observedAt: now.subtract(Duration(days: 29 - i)),
              features: {
                'tapCount': i.isEven ? 10 : 100,
                'navigationChanges': i.isEven ? 1 : 10,
              },
            ),
          ),
        for (var i = 0; i < 20; i++)
          LearningExample(
            id: 'manual-$i',
            createdAt: now,
            label: FeelingLabel.calm,
            snapshot: SignalSnapshot(observedAt: now),
          ),
      ],
    );
    final insight = PersonalPatternEngine().assess(
      data,
      SignalSnapshot(
        observedAt: now,
        features: {'tapCount': 10, 'navigationChanges': 1},
      ),
      now: now,
    );
    expect(insight.status, PatternStatus.tentativeMatch);
    expect(insight.evidence, contains('15 moments'));
  });
}
