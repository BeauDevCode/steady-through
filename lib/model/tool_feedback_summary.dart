import 'tool_feedback.dart';

/// Descriptive counts of the person's chosen answers, not efficacy estimates.
class ToolFeedbackCounts {
  const ToolFeedbackCounts({
    required this.helpful,
    required this.notThisTime,
    required this.latest,
  });

  final int helpful;
  final int notThisTime;
  final ToolFeedback? latest;

  int get total => helpful + notThisTime;
}

class ToolFeedbackSummary {
  ToolFeedbackSummary._(this.ratings, this._counts, this.suggestion);

  /// Retained answers, newest first with a deterministic ID tie-break.
  final List<ToolFeedback> ratings;
  final Map<SupportTool, ToolFeedbackCounts> _counts;

  /// Most recent Helpful answer among tools whose latest answer is Helpful.
  /// This is a remembered opinion; every ordinary tool remains available.
  final ToolFeedback? suggestion;

  ToolFeedbackCounts counts(SupportTool tool) => _counts[tool]!;

  factory ToolFeedbackSummary.fromData(ToolFeedbackData data, {DateTime? now}) {
    final retained = data.bounded(now ?? DateTime.now());
    final newest = List<ToolFeedback>.unmodifiable(retained.ratings.reversed);
    final counts = <SupportTool, ToolFeedbackCounts>{};
    for (final tool in SupportTool.values) {
      final opinions = newest.where((rating) => rating.tool == tool).toList();
      counts[tool] = ToolFeedbackCounts(
        helpful: opinions.where((r) => r.rating == ToolRating.helpful).length,
        notThisTime: opinions
            .where((r) => r.rating == ToolRating.notThisTime)
            .length,
        latest: opinions.isEmpty ? null : opinions.first,
      );
    }
    ToolFeedback? suggestion;
    if (data.useSuggestions) {
      for (final rating in newest) {
        if (identical(counts[rating.tool]!.latest, rating) &&
            rating.rating == ToolRating.helpful) {
          suggestion = rating;
          break;
        }
      }
    }
    return ToolFeedbackSummary._(
      newest,
      Map<SupportTool, ToolFeedbackCounts>.unmodifiable(counts),
      suggestion,
    );
  }
}
