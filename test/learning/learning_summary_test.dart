import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_summary.dart';
import 'package:steady_through/learning/pattern_engine.dart';

final _now = DateTime.utc(2026, 11, 6, 12);
final _engine = PersonalPatternEngine();

LearningExample _moment(
  String id,
  DateTime at,
  FeelingLabel label, {
  Map<String, double> features = const {},
  DateTime? observedAt,
}) => LearningExample(
  id: id,
  createdAt: at,
  label: label,
  snapshot: SignalSnapshot(observedAt: observedAt ?? at, features: features),
);

LearningData _complete() => LearningData(
  enabledSources: {SignalSource.checkIns, SignalSource.inApp},
  examples: [
    for (var day = 0; day < 10; day++) ...[
      _moment(
        'c-$day',
        _now.subtract(Duration(days: 10 - day)),
        FeelingLabel.calm,
        features: const {'tapCount': 4, 'navigationChanges': 1},
      ),
      _moment(
        't-$day',
        _now.subtract(Duration(days: 10 - day, hours: -1)),
        FeelingLabel.tense,
        features: const {'tapCount': 60, 'navigationChanges': 15},
      ),
    ],
  ],
);

void main() {
  test('seven-day summary includes boundary and Unsure but excludes older/future reports', () {
    final data = LearningData(
      examples: [
        _moment(
          'old',
          _now.subtract(const Duration(days: 7, microseconds: 1)),
          FeelingLabel.low,
        ),
        _moment(
          'boundary',
          _now.subtract(const Duration(days: 7)),
          FeelingLabel.tense,
        ),
        _moment('now', _now, FeelingLabel.unsure),
        _moment(
          'future',
          _now.add(const Duration(seconds: 1)),
          FeelingLabel.energized,
        ),
        _moment(
          'expired',
          _now.subtract(const Duration(days: 181)),
          FeelingLabel.calm,
        ),
      ],
    );
    final summary = LearningSummary.fromData(data, now: _now);
    expect(summary.recentCount, 2);
    expect(summary.recentCounts, {
      FeelingLabel.tense: 1,
      FeelingLabel.unsure: 1,
    });
    expect(summary.moments.map((e) => e.id), ['now', 'boundary', 'old']);
  });

  test('history ordering is newest first with deterministic ID ties', () {
    final summary = LearningSummary.fromData(
      LearningData(
        examples: [
          _moment('a', _now, FeelingLabel.low),
          _moment('z', _now, FeelingLabel.calm),
          _moment(
            'older',
            _now.subtract(const Duration(days: 1)),
            FeelingLabel.tense,
          ),
        ],
      ),
      now: _now,
    );
    expect(summary.moments.map((e) => e.id), ['z', 'a', 'older']);
  });

  test('manual summary is useful when every source is off', () {
    final summary = LearningSummary.fromData(
      _complete().copyWith(enabledSources: {}),
      now: _now,
    );
    expect(summary.recentCount, 14);
    expect(summary.recentCounts, {FeelingLabel.calm: 7, FeelingLabel.tense: 7});
    expect(summary.moments, hasLength(20));
  });

  test('diagnostics report real shared-feature coverage and actual tentative assessment', () {
    final evidence = _engine.evidence(
      _complete(),
      SignalSnapshot(
        observedAt: _now,
        features: const {'tapCount': 4, 'navigationChanges': 1},
      ),
      now: _now,
    );
    expect(evidence.savedCount, 20);
    expect(evidence.eligibleCount, 20);
    expect(evidence.observationDays, 10);
    expect(evidence.coveredFeelingCount, 2);
    expect(evidence.hasComparableHistory, isTrue);
    expect(evidence.hasAggregateHistory, isTrue);
    expect(evidence.insight.status, PatternStatus.tentativeMatch);
  });

  test('Unsure is retained but is not counted as a training feeling', () {
    final data = _complete();
    final evidence = _engine.evidence(
      data.copyWith(
        examples: [
          ...data.examples,
          _moment(
            'unsure',
            _now,
            FeelingLabel.unsure,
            features: const {'tapCount': 4, 'navigationChanges': 1},
          ),
        ],
      ),
      SignalSnapshot(observedAt: _now),
      now: _now,
    );
    expect(evidence.savedCount, 21);
    expect(evidence.eligibleCount, 20);
    expect(evidence.observationDays, 10);
    expect(evidence.coveredFeelingCount, 2);
  });

  test(
    'observation days use UTC rather than saved day or local calendar date',
    () {
      final data = LearningData(
        enabledSources: {SignalSource.inApp},
        examples: [
          _moment(
            'one',
            _now,
            FeelingLabel.calm,
            observedAt: DateTime.parse('2026-11-05T23:30:00-02:00'),
          ),
          _moment(
            'two',
            _now,
            FeelingLabel.tense,
            observedAt: DateTime.parse('2026-11-06T02:30:00+01:00'),
          ),
        ],
      );
      expect(
        _engine
            .evidence(data, SignalSnapshot(observedAt: _now), now: _now)
            .observationDays,
        1,
      );
    },
  );

  test(
    'many same-day reports and one-feeling histories fail coverage honestly',
    () {
      final sameDay = LearningData(
        enabledSources: {SignalSource.inApp},
        examples: [
          for (var i = 0; i < 20; i++)
            _moment(
              '$i',
              _now,
              i.isEven ? FeelingLabel.calm : FeelingLabel.tense,
              features: const {'tapCount': 4, 'navigationChanges': 1},
            ),
        ],
      );
      final oneFeeling = _complete().copyWith(
        examples: [
          for (final e in _complete().examples)
            _moment(
              e.id,
              e.createdAt,
              FeelingLabel.calm,
              features: e.snapshot.features,
            ),
        ],
      );
      for (final data in [sameDay, oneFeeling]) {
        final evidence = _engine.evidence(
          data,
          SignalSnapshot(observedAt: _now),
          now: _now,
        );
        expect(evidence.hasComparableHistory, isFalse);
        expect(evidence.insight.status, PatternStatus.insufficientEvidence);
      }
    },
  );

  test(
    'separately present metrics do not imply complete comparable examples',
    () {
      final source = _complete();
      final data = source.copyWith(
        examples: [
          for (var i = 0; i < source.examples.length; i++)
            _moment(
              source.examples[i].id,
              source.examples[i].createdAt,
              source.examples[i].label,
              features: i ~/ 2 % 2 == 0
                  ? const {'tapCount': 4}
                  : const {'navigationChanges': 1},
            ),
        ],
      );
      final evidence = _engine.evidence(
        data,
        SignalSnapshot(
          observedAt: _now,
          features: const {'tapCount': 4, 'navigationChanges': 1},
        ),
        now: _now,
      );
      expect(evidence.eligibleCount, 20);
      expect(evidence.coveredFeelingCount, 2);
      expect(evidence.hasComparableHistory, isFalse);
      expect(evidence.insight.status, PatternStatus.insufficientEvidence);
    },
  );

  test(
    'revoked source metrics are excluded while chosen-feeling history remains',
    () {
      final data = _complete().copyWith(
        enabledSources: {SignalSource.checkIns},
      );
      final evidence = _engine.evidence(
        data,
        SignalSnapshot(
          observedAt: _now,
          features: const {'tapCount': 4, 'navigationChanges': 1},
        ),
        now: _now,
      );
      expect(evidence.savedCount, 20);
      expect(evidence.hasAggregateHistory, isFalse);
      expect(evidence.hasComparableHistory, isFalse);
      expect(evidence.insight.status, PatternStatus.selfReportedTrend);
    },
  );

  test('historical coverage does not hide missing, stale, future or vehicle readings', () {
    final snapshots = [
      SignalSnapshot(observedAt: _now),
      SignalSnapshot(
        observedAt: _now.subtract(const Duration(minutes: 31)),
        features: const {'tapCount': 4, 'navigationChanges': 1},
      ),
      SignalSnapshot(
        observedAt: _now.add(const Duration(seconds: 1)),
        features: const {'tapCount': 4, 'navigationChanges': 1},
      ),
      SignalSnapshot(observedAt: _now, possibleVehicle: true),
    ];
    for (var i = 0; i < snapshots.length; i++) {
      final evidence = _engine.evidence(_complete(), snapshots[i], now: _now);
      expect(evidence.hasComparableHistory, isTrue);
      expect(
        evidence.insight.status,
        i == 3
            ? PatternStatus.possibleVehicle
            : PatternStatus.insufficientEvidence,
      );
    }
  });
}
