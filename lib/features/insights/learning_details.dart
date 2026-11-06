import 'package:flutter/material.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/learning/pattern_engine.dart';
import 'package:steady_through/ui/steady_ui.dart';

class LearningDetails extends StatefulWidget {
  const LearningDetails({
    super.key,
    required this.session,
    required this.working,
    required this.onReview,
  });
  final LearningSession session;
  final bool working;
  final VoidCallback onReview;
  @override
  State<LearningDetails> createState() => _LearningDetailsState();
}

class _LearningDetailsState extends State<LearningDetails>
    with AutomaticKeepAliveClientMixin {
  bool _expanded = false;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = widget.session;
    // Capture the observation before its assessment clock, as assess does.
    final snapshot = session.snapshot;
    final now = DateTime.now().toUtc();
    final data = session.data.bounded(now);
    final evidence = _expanded
        ? PersonalPatternEngine().evidence(data, snapshot, now: now)
        : null;
    final calibration = data.calibration;
    final since =
        calibration.lastReviewedAt ??
        calibration.startedAt ??
        data.firstExampleAt;
    final days = since == null ? 0 : now.difference(since).inDays.clamp(0, 60);
    return SurfaceCard(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('At your pace'),
          const SizedBox(height: 10),
          Text(
            'How learning works',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your own feelings come first. Optional comparisons need consistent evidence over time, and can still be uncertain.',
          ),
          const SizedBox(height: 12),
          Semantics(
            expanded: _expanded,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(_expanded ? 'Hide details' : 'Show details'),
            ),
          ),
          if (evidence != null) ...[
            const SizedBox(height: 24),
            Text(
              'What is available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _fact(
              '${evidence.savedCount} saved moments',
              'Your chosen feelings, including Unsure.',
            ),
            _fact(
              '${evidence.eligibleCount} moments with a named feeling',
              'A comparison needs at least 20 moments other than Unsure.',
            ),
            _fact(
              '${evidence.observationDays} observation days',
              'A comparison needs at least 7 different UTC observation days.',
            ),
            _fact(
              '${evidence.coveredFeelingCount} feelings represented at least 5 times',
              'A comparison needs at least two such feelings.',
            ),
            _fact(
              evidence.hasComparableHistory
                  ? 'Shared historical readings are available'
                  : 'Shared historical readings are not sufficient',
              'The same complete-feature checks used by the comparison need at least two shared readings and sufficient moments and days after missing readings are excluded.',
            ),
            const Text(
              'These are app safeguards, not research-established guarantees of accuracy. There is no need to save more moments, choose a different feeling or enable another source.',
            ),
            const SizedBox(height: 20),
            Text(
              'Current comparison',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              session.paused
                  ? 'Learning is paused. Your saved history remains available.'
                  : evidence.insight.evidence,
            ),
            if (!evidence.hasAggregateHistory) ...[
              const SizedBox(height: 8),
              const Text(
                'Without comparable aggregate readings, your saved feelings can still show a self-reported history. No device permission is needed for that history.',
              ),
            ],
            const Divider(height: 40),
            Text(
              'The 60-day review',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'A local review checks older examples against separate later examples and a simple baseline. It adopts an update only when coverage and improvement checks pass. Time alone does not prove a pattern.',
            ),
            const SizedBox(height: 12),
            Text(
              since == null
                  ? 'Your first saved feeling starts the review window.'
                  : days >= 60
                  ? 'The review window is due for an evidence check.'
                  : 'Day $days of 60 in this review window.',
            ),
            const SizedBox(height: 8),
            Text('Personal model revision ${calibration.revision}'),
            if (calibration.lastReviewReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(calibration.lastReviewReason),
              const SizedBox(height: 8),
              Text(
                '${calibration.trainingCount} earlier examples · ${calibration.heldOutCount} later examples',
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'A due review starts a new 60-day window even when there is too little evidence to update. Corrections and deletions clear the saved model and review results while preserving that schedule.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.working ? null : widget.onReview,
              icon: const Icon(Icons.auto_graph_rounded),
              label: const Text('Review learning'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Learning keeps at most 180 days or 1,000 moments. Deleting evidence also clears saved model results. Your events, people and game history are managed separately.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _fact(String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(description),
      ],
    ),
  );
}
