import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/learning/learning_data.dart';

final _now = DateTime.utc(2026, 11, 6, 12);

LearningExample _moment(String id, {DateTime? at}) => LearningExample(
  id: id,
  createdAt: at ?? _now,
  label: FeelingLabel.calm,
  snapshot: SignalSnapshot(
    observedAt: (at ?? _now).subtract(const Duration(minutes: 1)),
    features: const {'tapCount': 8, 'navigationChanges': 2},
    possibleVehicle: true,
  ),
);

LearningData _history() => LearningData(
  enabledSources: {SignalSource.inApp, SignalSource.motion},
  deviceOwnerConfirmed: true,
  pausedByUser: true,
  examples: [_moment('a'), _moment('b')],
  calibration: CalibrationState(
    startedAt: _now.subtract(const Duration(days: 90)),
    lastReviewedAt: _now.subtract(const Duration(days: 1)),
    lastAdoptedAt: _now.subtract(const Duration(days: 1)),
    revision: 2,
    trainingCount: 30,
    heldOutCount: 12,
    candidateCorrect: 10,
    baselineCorrect: 6,
    lastReviewReason: 'Old evaluation',
    model: CalibratedPattern(
      trainedFrom: _now.subtract(const Duration(days: 70)),
      trainedThrough: _now.subtract(const Duration(days: 30)),
      distinctDays: 14,
      centroids: const {
        FeelingLabel.calm: {'tapCount': 8, 'navigationChanges': 2},
        FeelingLabel.tense: {'tapCount': 80, 'navigationChanges': 20},
      },
      scales: const {'tapCount': 72, 'navigationChanges': 18},
      sampleCounts: const {FeelingLabel.calm: 15, FeelingLabel.tense: 15},
    ),
  ),
);

void main() {
  test(
    'correction changes one label without changing the saved observation',
    () {
      final original = _history();
      final changed = original.relabel('a', FeelingLabel.unsure);
      final saved = changed.examples.first;
      expect(saved.label, FeelingLabel.unsure);
      expect(saved.id, 'a');
      expect(saved.createdAt, _now);
      expect(saved.snapshot, same(original.examples.first.snapshot));
      expect(changed.examples.last, same(original.examples.last));
      expect(changed.enabledSources, original.enabledSources);
      expect(changed.deviceOwnerConfirmed, isTrue);
      expect(changed.pausedByUser, isTrue);
      expect(original.examples.first.label, FeelingLabel.calm);
      expect(
        LearningData.fromJson(changed.toJson()).examples.first.label,
        FeelingLabel.unsure,
      );
    },
  );

  test('same-label correction keeps the existing calibration', () {
    final original = _history();
    expect(original.relabel('a', FeelingLabel.calm), same(original));
  });

  test(
    'changed evidence clears model and review artifacts but keeps cadence',
    () {
      final original = _history();
      for (final changed in [
        original.relabel('a', FeelingLabel.low),
        original.remove('a'),
      ]) {
        final state = changed.calibration;
        expect(state.model, isNull);
        expect(state.revision, 0);
        expect(state.lastAdoptedAt, isNull);
        expect(state.trainingCount, 0);
        expect(state.heldOutCount, 0);
        expect(state.candidateCorrect, 0);
        expect(state.baselineCorrect, 0);
        expect(state.lastReviewReason, isEmpty);
        expect(state.startedAt, original.calibration.startedAt);
        expect(state.nextReviewAt, original.calibration.nextReviewAt);
      }
    },
  );

  test(
    'deleting the last moment resets calibration and preserves preferences',
    () {
      final changed = _history().remove('a').remove('b');
      expect(changed.examples, isEmpty);
      expect(changed.calibration.toJson(), CalibrationState().toJson());
      expect(changed.enabledSources, {SignalSource.inApp, SignalSource.motion});
      expect(changed.pausedByUser, isTrue);
    },
  );

  test('missing targets cannot silently alter or reintroduce a moment', () {
    final data = _history();
    expect(() => data.remove('gone'), throwsStateError);
    expect(() => data.relabel('gone', FeelingLabel.low), throwsStateError);
  });

  test('retention removes expired evidence and its derived model', () {
    final data = _history().copyWith(
      examples: [
        _moment('expired', at: _now.subtract(const Duration(days: 181))),
        _moment('keep'),
      ],
    );
    final retained = data.bounded(_now);
    expect(retained.examples.map((e) => e.id), ['keep']);
    expect(retained.calibration.model, isNull);
    expect(retained.calibration.lastReviewReason, isEmpty);
    expect(retained.calibration.nextReviewAt, data.calibration.nextReviewAt);
  });
}
