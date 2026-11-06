import 'dart:math' as math;

import 'learning_data.dart';

enum PatternStatus {
  insufficientEvidence,
  uncertain,
  tentativeMatch,
  selfReportedTrend,
  possibleVehicle,
}

class PatternInsight {
  const PatternInsight({
    required this.status,
    required this.evidence,
    this.label,
    required this.suggestion,
  });
  final PatternStatus status;
  final String evidence;
  final FeelingLabel? label;
  final String suggestion;
  bool get canReflect => status != PatternStatus.possibleVehicle;
  bool get isTentative => status == PatternStatus.tentativeMatch;
  bool get isVehicleContext => status == PatternStatus.possibleVehicle;
}

enum CalibrationStatus { notDue, insufficientEvidence, noImprovement, adopted }

class CalibrationReport {
  const CalibrationReport({
    required this.status,
    required this.reason,
    required this.reviewedAt,
    required this.revision,
    this.trainingCount = 0,
    this.heldOutCount = 0,
    this.candidateCorrect = 0,
    this.baselineCorrect = 0,
  });
  final CalibrationStatus status;
  final String reason;
  final DateTime reviewedAt;
  final int revision;
  final int trainingCount;
  final int heldOutCount;
  final int candidateCorrect;
  final int baselineCorrect;
  bool get adopted => status == CalibrationStatus.adopted;
}

class CalibrationReview {
  const CalibrationReview({required this.data, required this.report});
  final LearningData data;
  final CalibrationReport report;
}

/// Describes the engine's input coverage, never prediction accuracy/readiness.
class LearningEvidence {
  const LearningEvidence({
    required this.savedCount,
    required this.eligibleCount,
    required this.observationDays,
    required this.coveredFeelingCount,
    required this.hasAggregateHistory,
    required this.hasComparableHistory,
    required this.insight,
  });

  final int savedCount;
  final int eligibleCount;
  final int observationDays;
  final int coveredFeelingCount;
  final bool hasAggregateHistory;
  final bool hasComparableHistory;
  final PatternInsight insight;
}

/// A conservative personal comparison using only the person's explicit labels.
/// Dates, class coverage, absent features, distance and contradictions all gate
/// a reflection. Scores are internal distances, never emotion probabilities.
class PersonalPatternEngine {
  static const minimumExamples = 20;
  static const minimumDistinctDays = 7;
  static const minimumExamplesPerLabel = 5;
  static const minimumComparableFeatures = 2;
  static const calibrationDays = 60;
  static const minimumTrainingExamples = 30;
  static const minimumTrainingDays = 14;
  static const minimumHeldOutExamples = 12;

  LearningEvidence evidence(
    LearningData data,
    SignalSnapshot snapshot, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now().toUtc();
    final bounded = data.bounded(at);
    final visible = _visibleExamples(bounded);
    final eligible = visible
        .where((e) => e.label != FeelingLabel.unsure)
        .toList();
    return LearningEvidence(
      savedCount: bounded.examples.length,
      eligibleCount: eligible.length,
      observationDays: eligible
          .map((e) => _day(e.snapshot.observedAt))
          .toSet()
          .length,
      coveredFeelingCount: _counts(eligible).values
          .where((count) => count >= minimumExamplesPerLabel)
          .length,
      hasAggregateHistory: visible.any((e) => e.snapshot.features.isNotEmpty),
      hasComparableHistory: _train(eligible).model != null,
      insight: assess(bounded, snapshot, now: at),
    );
  }

  PatternInsight assess(
    LearningData data,
    SignalSnapshot snapshot, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    if (snapshot.possibleVehicle) {
      return const PatternInsight(
        status: PatternStatus.possibleVehicle,
        evidence: 'Motion may indicate vehicle movement. It does not tell us who is driving.',
        suggestion: 'Return to this reflection when you are safely stopped.',
      );
    }
    final bounded = data.bounded(at);
    if (bounded.enabledSources.isEmpty) {
      return _insufficient(
        'Learning is paused. Choose a source when you want to add personal examples.',
      );
    }
    final all = bounded.examples;
    if (all.isEmpty) {
      return _insufficient('There are no recent self-labelled examples yet.');
    }
    final current = snapshot.forSources(bounded.enabledSources);
    final visible = _visibleExamples(bounded);
    if (current.features.isEmpty &&
        visible.every((e) => e.snapshot.features.isEmpty)) {
      final counts = _counts(all);
      final summary = FeelingLabel.values
          .where(counts.containsKey)
          .map((label) => '${label.name}: ${counts[label]}')
          .join(', ');
      return PatternInsight(
        status: PatternStatus.selfReportedTrend,
        evidence:
            'Your recent self-reported check-ins: $summary. This describes labels you chose; it does not predict your current feeling.',
        suggestion:
            'Choose how you feel now, or try a short pause if that would help.',
      );
    }
    if (snapshot.observedAt.isAfter(at) ||
        at.difference(snapshot.observedAt) > const Duration(minutes: 30)) {
      return _insufficient(
        'This signal snapshot is not current. A fresh observation is needed for a comparison.',
      );
    }
    final eligible = visible
        .where((e) => e.label != FeelingLabel.unsure)
        .toList();
    if (!_coverage(
      eligible,
      minimumExamples,
      minimumExamplesPerLabel,
      minimumDistinctDays,
    )) {
      return _insufficient(
        'A personal comparison needs at least $minimumExamples labelled moments across $minimumDistinctDays different days, with at least $minimumExamplesPerLabel examples of two feelings other than unsure.',
      );
    }
    final fresh = _train(eligible).model;
    if (fresh == null ||
        _comparableFeatures(fresh, current).length <
            minimumComparableFeatures) {
      return _insufficient(
        'There are not enough comparable aggregate readings across your labelled examples. Missing readings stay missing.',
      );
    }
    final adopted = bounded.calibration.model;
    final cutoff = at.subtract(
      const Duration(days: LearningData.retentionDays),
    );
    final model = adopted != null && !adopted.trainedThrough.isBefore(cutoff)
        ? adopted
        : fresh;
    final prediction = _predict(model, current);
    if (prediction == null || !_recentlyConsistent(model, eligible)) {
      return const PatternInsight(
        status: PatternStatus.uncertain,
        evidence: 'These readings overlap different feelings you marked, differ from your recent patterns, or are outside the examples available. There is no clear personal match.',
        suggestion: 'Choose the feeling that fits you now. A short grounding or breathing pause is available if useful.',
      );
    }
    final count = model.sampleCounts[prediction]!;
    return PatternInsight(
      status: PatternStatus.tentativeMatch,
      label: prediction,
      evidence:
          'This resembles aggregate patterns from $count moments you marked ${prediction.name}. It is a tentative comparison; only you can say whether it fits.',
      suggestion: _suggestion(prediction),
    );
  }

  CalibrationReview review(LearningData data, {DateTime? now}) {
    final at = now ?? DateTime.now();
    var bounded = data.bounded(at);
    final first = bounded.calibration.startedAt ?? bounded.firstExampleAt;
    if (first != null && bounded.calibration.startedAt == null) {
      bounded = bounded.copyWith(
        calibration: bounded.calibration.copyWith(startedAt: first),
      );
    }
    CalibrationReview result(
      CalibrationStatus status,
      String reason, {
      int trainingCount = 0,
      int heldOutCount = 0,
      int candidateCorrect = 0,
      int baselineCorrect = 0,
    }) {
      if (status != CalibrationStatus.notDue) {
        bounded = bounded.copyWith(
          calibration: bounded.calibration.copyWith(
            trainingCount: trainingCount,
            heldOutCount: heldOutCount,
            candidateCorrect: candidateCorrect,
            baselineCorrect: baselineCorrect,
            lastReviewReason: reason,
          ),
        );
      }
      return CalibrationReview(
        data: bounded,
        report: CalibrationReport(
          status: status,
          reason: reason,
          reviewedAt: at,
          revision: bounded.calibration.revision,
          trainingCount: trainingCount,
          heldOutCount: heldOutCount,
          candidateCorrect: candidateCorrect,
          baselineCorrect: baselineCorrect,
        ),
      );
    }

    final anchor = bounded.calibration.lastReviewedAt ?? first;
    if (bounded.enabledSources.isEmpty ||
        anchor == null ||
        at.difference(anchor) < const Duration(days: calibrationDays)) {
      return result(
        CalibrationStatus.notDue,
        bounded.enabledSources.isEmpty
            ? 'Learning is paused. A review can run after you choose a source.'
            : 'Local calibration is reviewed after about 60 days of labelled history, and at least 60 days after the previous review.',
      );
    }
    // A due review is recorded even if it cannot adopt an update. This avoids
    // repeatedly claiming a new calibration opportunity on every screen visit.
    bounded = bounded.copyWith(
      calibration: bounded.calibration.copyWith(lastReviewedAt: at),
    );
    final samples =
        _visibleExamples(bounded)
            .where((e) => e.label != FeelingLabel.unsure)
            .toList()
          ..sort(
            (a, b) => a.snapshot.observedAt.compareTo(b.snapshot.observedAt),
          );
    if (samples.length < minimumTrainingExamples + minimumHeldOutExamples) {
      return result(
        CalibrationStatus.insufficientEvidence,
        'More labelled examples with comparable features are needed for separate older training and later evaluation sets.',
      );
    }
    var split = (samples.length * .7).floor();
    // All examples on the boundary day stay on the evaluation side. Training
    // therefore cannot share an observation day with the temporal holdout.
    final boundaryDay = _day(samples[split].snapshot.observedAt);
    while (split > 0 &&
        _day(samples[split - 1].snapshot.observedAt) == boundaryDay) {
      split--;
    }
    final training = samples.sublist(0, split);
    final heldOut = samples.sublist(split);
    final attempt = _train(training, forCalibration: true);
    final usedTraining = attempt.examples;
    final candidate = attempt.model;
    if ((usedTraining.isNotEmpty &&
            heldOut.isNotEmpty &&
            !usedTraining
                .map((e) => e.createdAt)
                .every(
                  (date) => date.isBefore(heldOut.first.snapshot.observedAt),
                )) ||
        candidate == null ||
        !_coverage(heldOut, minimumHeldOutExamples, 3, minimumDistinctDays)) {
      return result(
        CalibrationStatus.insufficientEvidence,
        'After missing readings are removed, the older set needs at least $minimumTrainingExamples comparable examples over $minimumTrainingDays observation days. Both older and later sets need enough examples of at least two feelings, with observation days kept separate.',
        trainingCount: usedTraining.length,
        heldOutCount: heldOut.length,
      );
    }
    final trainingCounts = _counts(usedTraining);
    final classes = candidate.centroids.keys.toSet();
    final heldOutCounts = _counts(heldOut);
    if (heldOut.any((e) => !classes.contains(e.label)) ||
        classes.any((label) => (heldOutCounts[label] ?? 0) < 3) ||
        heldOut.any(
          (e) =>
              _comparableFeatures(candidate, e.snapshot).length <
              math.max(
                minimumComparableFeatures,
                (candidate.scales.length * .6).ceil(),
              ),
        )) {
      return result(
        CalibrationStatus.insufficientEvidence,
        'The later evaluation set needs comparable readings and coverage of every trained feeling.',
        trainingCount: usedTraining.length,
        heldOutCount: heldOut.length,
      );
    }
    final majority = trainingCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final candidateCorrect = heldOut
        .where((e) => _predict(candidate, e.snapshot) == e.label)
        .length;
    final baselineCorrect = heldOut.where((e) => e.label == majority).length;
    final incumbent = bounded.calibration.model;
    final incumbentCorrect = incumbent == null
        ? 0
        : heldOut
              .where((e) => _predict(incumbent, e.snapshot) == e.label)
              .length;
    final requiredGain = math.max(2, (heldOut.length * .1).ceil());
    if (candidateCorrect < baselineCorrect + requiredGain ||
        candidateCorrect / heldOut.length < .65 ||
        (incumbent != null && candidateCorrect <= incumbentCorrect)) {
      return result(
        CalibrationStatus.noImprovement,
        'The candidate did not clearly improve on the majority-label baseline and any existing personal comparison using later held-out examples. The current revision stays unchanged.',
        trainingCount: usedTraining.length,
        heldOutCount: heldOut.length,
        candidateCorrect: candidateCorrect,
        baselineCorrect: baselineCorrect,
      );
    }
    bounded = bounded.copyWith(
      calibration: bounded.calibration.copyWith(
        revision: bounded.calibration.revision + 1,
        lastAdoptedAt: at,
        model: candidate,
      ),
    );
    return result(
      CalibrationStatus.adopted,
      'A local update improved on the majority-label baseline using later examples that were excluded from training. This is personal calibration, not a clinical accuracy estimate.',
      trainingCount: usedTraining.length,
      heldOutCount: heldOut.length,
      candidateCorrect: candidateCorrect,
      baselineCorrect: baselineCorrect,
    );
  }
}

PatternInsight _insufficient(String evidence) => PatternInsight(
  status: PatternStatus.insufficientEvidence,
  evidence: evidence,
  suggestion: 'You can choose a feeling yourself and use any support tool while evidence grows.',
);

List<LearningExample> _visibleExamples(LearningData data) => [
  for (final example in data.examples)
    LearningExample(
      id: example.id,
      createdAt: example.createdAt,
      label: example.label,
      snapshot: example.snapshot.forSources(data.enabledSources),
    ),
];

Map<FeelingLabel, int> _counts(List<LearningExample> examples) {
  final counts = <FeelingLabel, int>{};
  for (final example in examples) {
    counts.update(example.label, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

String _day(DateTime date) => date.toUtc().toIso8601String().substring(0, 10);

bool _coverage(
  List<LearningExample> examples,
  int count,
  int perLabel,
  int days,
) =>
    examples.length >= count &&
    examples.map((e) => _day(e.snapshot.observedAt)).toSet().length >= days &&
    _counts(examples).values.where((value) => value >= perLabel).length >= 2;

class _TrainingAttempt {
  const _TrainingAttempt({this.model, this.examples = const []});
  final CalibratedPattern? model;
  final List<LearningExample> examples;
}

_TrainingAttempt _train(
  List<LearningExample> examples, {
  bool forCalibration = false,
}) {
  final counts = _counts(examples);
  final labels = counts.keys
      .where(
        (label) =>
            label != FeelingLabel.unsure &&
            counts[label]! >= PersonalPatternEngine.minimumExamplesPerLabel,
      )
      .toList();
  if (labels.length < 2) return const _TrainingAttempt();
  final common = signalMetrics.keys
      .where(
        (metric) => labels.every(
          (label) =>
              examples
                  .where(
                    (e) =>
                        e.label == label &&
                        e.snapshot.features.containsKey(metric),
                  )
                  .length >=
              PersonalPatternEngine.minimumExamplesPerLabel,
        ),
      )
      .toList();
  if (common.length < PersonalPatternEngine.minimumComparableFeatures) {
    return const _TrainingAttempt();
  }
  final used = examples
      .where(
        (e) =>
            labels.contains(e.label) &&
            common.every(e.snapshot.features.containsKey),
      )
      .toList();
  if (!_coverage(
        used,
        forCalibration
            ? PersonalPatternEngine.minimumTrainingExamples
            : PersonalPatternEngine.minimumExamples,
        PersonalPatternEngine.minimumExamplesPerLabel,
        forCalibration
            ? PersonalPatternEngine.minimumTrainingDays
            : PersonalPatternEngine.minimumDistinctDays,
      ) ||
      labels.any(
        (label) =>
            used.where((e) => e.label == label).length <
            PersonalPatternEngine.minimumExamplesPerLabel,
      )) {
    return _TrainingAttempt(examples: used);
  }
  final scales = <String, double>{};
  final centroids = <FeelingLabel, Map<String, double>>{};
  for (final metric in common) {
    final values = used.map((e) => e.snapshot.features[metric]!);
    scales[metric] = math.max(
      1.0,
      values.reduce(math.max) - values.reduce(math.min),
    );
  }
  for (final label in labels) {
    final group = used.where((e) => e.label == label).toList();
    centroids[label] = {
      for (final metric in common)
        metric:
            group
                .map((e) => e.snapshot.features[metric]!)
                .reduce((a, b) => a + b) /
            group.length,
    };
  }
  used.sort((a, b) => a.snapshot.observedAt.compareTo(b.snapshot.observedAt));
  return _TrainingAttempt(
    examples: used,
    model: CalibratedPattern(
      trainedFrom: used.first.snapshot.observedAt,
      trainedThrough: used
          .map((e) => e.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b),
      distinctDays: used.map((e) => _day(e.snapshot.observedAt)).toSet().length,
      centroids: centroids,
      scales: scales,
      sampleCounts: {
        for (final label in labels)
          label: used.where((e) => e.label == label).length,
      },
    ),
  );
}

List<String> _comparableFeatures(
  CalibratedPattern model,
  SignalSnapshot snapshot,
) => model.scales.keys.where(snapshot.features.containsKey).toList();

FeelingLabel? _predict(CalibratedPattern model, SignalSnapshot snapshot) {
  final metrics = _comparableFeatures(model, snapshot);
  if (metrics.length <
      math.max(
        PersonalPatternEngine.minimumComparableFeatures,
        (model.scales.length * .6).ceil(),
      )) {
    return null;
  }
  final distances = <MapEntry<FeelingLabel, double>>[
    for (final centroid in model.centroids.entries)
      MapEntry(
        centroid.key,
        math.sqrt(
          metrics
                  .map((metric) {
                    final delta =
                        (snapshot.features[metric]! - centroid.value[metric]!) /
                        model.scales[metric]!;
                    return delta * delta;
                  })
                  .reduce((a, b) => a + b) /
              metrics.length,
        ),
      ),
  ]..sort((a, b) => a.value.compareTo(b.value));
  final first = distances[0];
  final second = distances[1];
  if (first.value > .75 ||
      second.value - first.value < .2 ||
      first.value > second.value * .75) {
    return null;
  }
  return first.key;
}

bool _recentlyConsistent(
  CalibratedPattern model,
  List<LearningExample> examples,
) {
  final ordered = [...examples]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final recent = ordered.length > 20
      ? ordered.sublist(ordered.length - 20)
      : ordered;
  final comparable = recent
      .where(
        (e) =>
            _comparableFeatures(model, e.snapshot).length >=
            PersonalPatternEngine.minimumComparableFeatures,
      )
      .toList();
  return comparable.length < 10 ||
      comparable.where((e) => _predict(model, e.snapshot) == e.label).length /
              comparable.length >=
          .6;
}

String _suggestion(FeelingLabel label) => switch (label) {
  FeelingLabel.calm => 'Does calm fit? You might keep what is helping, or choose a different feeling.',
  FeelingLabel.tense => 'Does tense fit? A short breathing pause or grounding exercise is available.',
  FeelingLabel.low => 'Does low fit? You could choose one small next step or connect with someone you trust.',
  FeelingLabel.energized =>
    'Does energized fit? You could choose one useful action for that energy.',
  FeelingLabel.unsure => 'You can choose a feeling or take a short pause.',
};
