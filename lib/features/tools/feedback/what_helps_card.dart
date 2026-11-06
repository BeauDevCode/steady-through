import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/tool_feedback.dart';
import 'package:steady_through/model/tool_feedback_summary.dart';
import 'package:steady_through/ui/steady_ui.dart';

import 'feedback_activity.dart';
import 'feedback_display.dart';
import 'tool_feedback_history.dart';

class WhatHelpsCard extends StatelessWidget {
  const WhatHelpsCard({
    super.key,
    required this.controller,
    this.safetySession,
    this.onOpenTool,
  });
  final AppController controller;
  final LearningSession? safetySession;
  final ValueChanged<SupportTool>? onOpenTool;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?safetySession]),
    builder: (context, _) {
      final summary = ToolFeedbackSummary.fromData(
        controller.data.toolFeedback,
      );
      final suggestion = summary.suggestion;
      final vehicle = safetySession?.snapshot.possibleVehicle ?? false;
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                  icon: Icons.favorite_border,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('In your own words'),
                      const SizedBox(height: 6),
                      Text(
                        'What helps you',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Your optional answers help you find tools you marked helpful. They are personal opinions, not a measure of treatment or your feelings.',
            ),
            if (summary.ratings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Your optional ratings will appear here. You can add one even if you stopped a tool early.',
                ),
              ),
            for (final tool in SupportTool.values)
              if (summary.counts(tool).total > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(toolIcon(tool), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              toolName(tool),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Helpful ${summary.counts(tool).helpful} · Not this time ${summary.counts(tool).notThisTime}',
                            ),
                            Text(
                              'Latest: ${ratingName(summary.counts(tool).latest!.rating)} · ${feedbackDate(context, summary.counts(tool).latest!.createdAt)}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            if (suggestion != null && !vehicle) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A tool to revisit',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You marked ${toolName(suggestion.tool)} helpful on ${feedbackDate(context, suggestion.createdAt)}. This is your latest helpful answer among tools whose latest answer is Helpful.',
                    ),
                    if (onOpenTool != null) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => onOpenTool!(suggestion.tool),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text('Revisit ${toolName(suggestion.tool)}'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FeedbackOptions(
              controller: controller,
              safetySession: safetySession,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: vehicle
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ToolFeedbackHistory(
                          controller: controller,
                          safetySession: safetySession,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.history),
              label: const Text('View and manage ratings'),
            ),
            if (vehicle)
              const Text('Return to your ratings when safely stopped.'),
            if (controller.cleanupWarning != null)
              Semantics(
                liveRegion: true,
                child: Text(controller.cleanupWarning!),
              ),
          ],
        ),
      );
    },
  );
}

class FeedbackOptions extends StatefulWidget {
  const FeedbackOptions({
    super.key,
    required this.controller,
    this.safetySession,
  });
  final AppController controller;
  final LearningSession? safetySession;
  @override
  State<FeedbackOptions> createState() => _FeedbackOptionsState();
}

class _FeedbackOptionsState extends State<FeedbackOptions> {
  final _activity = FeedbackActivity();
  bool _busy = false;
  String? _error;
  bool get _vehicle => widget.safetySession?.snapshot.possibleVehicle ?? false;
  @override
  void initState() {
    super.initState();
    _activity.addListener(_changed);
    widget.controller.addListener(_changed);
    widget.safetySession?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _update({bool? prompts, bool? suggestions}) async {
    if (_busy || _vehicle || !_activity.active) return;
    final epoch = _activity.epoch,
        revision = widget.controller.replacementRevision;
    bool guard() =>
        mounted &&
        _activity.accepts(epoch) &&
        !_vehicle &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.updateToolFeedbackOptions(
        showPrompts: prompts,
        useSuggestions: suggestions,
        expectedRevision: revision,
        isActive: guard,
      );
    } catch (_) {
      if (guard()) {
        setState(
          () => _error = 'Could not save your rating settings. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.safetySession?.removeListener(_changed);
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show optional ratings after tools'),
        subtitle: const Text('You can always add a rating in your history.'),
        value: widget.controller.data.toolFeedback.showPrompts,
        onChanged: _busy || _vehicle || !_activity.active
            ? null
            : (value) => _update(prompts: value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Use my ratings for ideas'),
        subtitle: const Text('Find a tool from your recent Helpful answers.'),
        value: widget.controller.data.toolFeedback.useSuggestions,
        onChanged: _busy || _vehicle || !_activity.active
            ? null
            : (value) => _update(suggestions: value),
      ),
      if (_error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}
