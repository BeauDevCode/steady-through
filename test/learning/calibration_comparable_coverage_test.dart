import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/pattern_engine.dart';

void main() {
  for (final comparableCount in [20, 30]) {
    test(
      'calibration training minimums apply after removing featureless labels ($comparableCount comparable)',
      () {
        final now = DateTime.utc(2026, 11, 5, 12);
        LearningExample sample(
          String id,
          int daysAgo,
          int index, {
          bool featureless = false,
        }) {
          final date = now.subtract(Duration(days: daysAgo));
          return LearningExample(
            id: id,
            createdAt: date,
            label: index.isEven ? FeelingLabel.calm : FeelingLabel.tense,
            snapshot: SignalSnapshot(
              observedAt: date,
              features: featureless
                  ? {}
                  : {
                      'tapCount': index.isEven ? 10 : 100,
                      'navigationChanges': index.isEven ? 1 : 10,
                    },
            ),
          );
        }

        final data = LearningData(
          enabledSources: {SignalSource.checkIns, SignalSource.inApp},
          examples: [
            for (var i = 0; i < 56 - comparableCount; i++)
              sample('manual-$i', 79 - i, i, featureless: true),
            for (var i = 0; i < comparableCount; i++)
              sample('comparable-$i', 43 - (i ~/ 3), i),
            for (var i = 0; i < 24; i++) sample('heldout-$i', 23 - i, i),
          ],
        );
        final review = PersonalPatternEngine().review(data, now: now);
        expect(review.report.status, CalibrationStatus.insufficientEvidence);
        expect(review.report.trainingCount, comparableCount);
        expect(review.report.heldOutCount, 24);
        expect(review.data.calibration.trainingCount, comparableCount);
        expect(review.data.calibration.revision, 0);
        expect(review.data.calibration.model, isNull);
      },
    );
  }
}
