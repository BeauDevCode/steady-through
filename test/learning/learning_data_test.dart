import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/learning/learning_data.dart';

final reference = DateTime.utc(2026, 11, 5, 12);

LearningExample example(
  String id,
  DateTime date, {
  FeelingLabel label = FeelingLabel.calm,
  Map<String, double> features = const {'tapCount': 12, 'navigationChanges': 2},
}) => LearningExample(
  id: id,
  createdAt: date,
  label: label,
  snapshot: SignalSnapshot(observedAt: date, features: features),
);

void main() {
  test(
    'an explicit learning pause survives serialization and unrelated copies',
    () {
      final paused = LearningData(
        enabledSources: {SignalSource.inApp},
        examples: [example('saved', reference)],
        pausedByUser: true,
      );
      final restored = LearningData.fromJson(paused.toJson())
          .bounded(reference)
          .copyWith(deviceOwnerConfirmed: true);
      expect(restored.pausedByUser, isTrue);
      expect(restored.enabledSources, {SignalSource.inApp});
      expect(restored.examples.single.id, 'saved');
      expect(restored.copyWith(pausedByUser: false).pausedByUser, isFalse);
    },
  );

  test('older learning documents default to no explicit pause', () {
    expect(LearningData().pausedByUser, isFalse);
    final legacy = LearningData().toJson()..remove('pausedByUser');
    expect(LearningData.fromJson(legacy).pausedByUser, isFalse);
  });

  test('an explicit pause field must be a boolean', () {
    for (final invalid in <Object?>[null, 0, 'false', [], {}]) {
      final json = LearningData().toJson()..['pausedByUser'] = invalid;
      expect(() => LearningData.fromJson(json), throwsFormatException);
    }
  });

  test(
    'learning starts off and round trips consent, labels and missing signals',
    () {
      final empty = LearningData();
      expect(empty.enabledSources, isEmpty);
      expect(empty.deviceOwnerConfirmed, isFalse);
      expect(empty.examples, isEmpty);
      final data = LearningData(
        enabledSources: {SignalSource.checkIns, SignalSource.inApp},
        examples: [example('one', reference)],
      );
      final decoded = LearningData.fromJson(data.toJson());
      expect(decoded.enabledSources, {
        SignalSource.checkIns,
        SignalSource.inApp,
      });
      expect(decoded.examples.single.label, FeelingLabel.calm);
      expect(
        decoded.examples.single.snapshot.features['deviceSwitches'],
        isNull,
      );
      expect(decoded.calibration.revision, 0);
      expect(() => decoded.enabledSources.clear(), throwsUnsupportedError);
      expect(() => decoded.examples.clear(), throwsUnsupportedError);
      expect(
        () => decoded.examples.single.snapshot.features.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('system sources require an explicit device owner confirmation', () {
    for (final source in [SignalSource.deviceUsage, SignalSource.motion]) {
      expect(
        () => LearningData(enabledSources: {source}),
        throwsFormatException,
      );
      expect(
        LearningData(
          enabledSources: {source},
          deviceOwnerConfirmed: true,
        ).enabledSources,
        contains(source),
      );
    }
  });

  test(
    'unknown, negative, fractional and nonfinite metrics cannot enter storage',
    () {
      for (final features in <Map<String, double>>[
        {'screenText': 1},
        {'tapCount': -1},
        {'tapCount': .5},
        {'activeMinutes': double.nan},
        {'activeMinutes': double.infinity},
        {'activeMinutes': 1441},
        {'tapCount': 1000001},
      ]) {
        expect(
          () => SignalSnapshot(observedAt: reference, features: features),
          throwsFormatException,
          reason: '$features',
        );
      }
    },
  );

  test('strict JSON validation rejects invalid consents, timestamps and calibration', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (j) => j['enabledSources'] = ['checkIns', 'checkIns'],
      (j) => j['enabledSources'] = ['unknown'],
      (j) => j['enabledSources'] = ['deviceUsage'],
      (j) => j['deviceOwnerConfirmed'] = 'true',
      (j) => j['extra'] = 1,
      (j) => (j['calibration'] as Map)['revision'] = -1,
      (j) => (j['calibration'] as Map)['startedAt'] = '2026-02-30T12:00:00Z',
      (j) => (j['calibration'] as Map)['model'] = {'untrusted': true},
    ];
    for (final mutation in mutations) {
      final json = LearningData().toJson();
      mutation(json);
      expect(() => LearningData.fromJson(json), throwsFormatException);
    }
    final json = LearningData(examples: [example('one', reference)]).toJson();
    ((json['examples'] as List).single as Map)['createdAt'] = 'today';
    expect(() => LearningData.fromJson(json), throwsFormatException);
  });

  test('duplicate labels and snapshots after the self label are rejected', () {
    expect(
      () => LearningData(
        examples: [example('same', reference), example('same', reference)],
      ),
      throwsFormatException,
    );
    expect(
      () => LearningExample(
        id: 'future',
        createdAt: reference,
        label: FeelingLabel.calm,
        snapshot: SignalSnapshot(
          observedAt: reference.add(const Duration(minutes: 1)),
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'recording removes expired entries and retains at most the newest thousand',
    () {
      var data = LearningData(
        enabledSources: {SignalSource.checkIns},
        examples: [
          example('expired', reference.subtract(const Duration(days: 181))),
          example('keep', reference.subtract(const Duration(days: 179))),
        ],
      );
      data = data.record(example('new', reference), now: reference);
      expect(data.examples.map((e) => e.id), ['keep', 'new']);
      for (var i = 0; i < 1001; i++) {
        data = data.record(
          example('entry-$i', reference.add(Duration(seconds: i))),
          now: reference.add(Duration(seconds: i)),
        );
      }
      expect(data.examples, hasLength(1000));
      expect(data.examples.first.id, 'entry-1');
      expect(data.examples.last.id, 'entry-1000');
    },
  );

  test(
    'recording requires a chosen source while revocation preserves history',
    () {
      expect(
        () => LearningData().record(example('off', reference), now: reference),
        throwsStateError,
      );
      final inAppOnly = LearningData(enabledSources: {SignalSource.inApp})
          .record(example('chosen', reference), now: reference);
      expect(inAppOnly.examples.single.label, FeelingLabel.calm);
      final original = LearningData(
        enabledSources: {SignalSource.checkIns},
        examples: [example('saved', reference)],
      );
      final paused = original.copyWith(enabledSources: {});
      expect(paused.examples.single.id, 'saved');
      expect(
        () => paused.record(example('no', reference), now: reference),
        throwsStateError,
      );
    },
  );
}
