import 'learning_data.dart';

/// A description of chosen feelings, independent of source consent or models.
class LearningSummary {
  LearningSummary._(this.moments, this.recentCounts);

  factory LearningSummary.fromData(LearningData data, {DateTime? now}) {
    final at = now ?? DateTime.now().toUtc();
    final moments = data.bounded(at).examples.reversed.toList();
    final since = at.subtract(const Duration(days: 7));
    final counts = <FeelingLabel, int>{};
    for (final moment in moments) {
      if (!moment.createdAt.isBefore(since)) {
        counts.update(moment.label, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return LearningSummary._(
      List.unmodifiable(moments),
      Map.unmodifiable(counts),
    );
  }

  final List<LearningExample> moments;
  final Map<FeelingLabel, int> recentCounts;
  int get recentCount =>
      recentCounts.values.fold(0, (sum, count) => sum + count);
}
