import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/tool_feedback.dart';

import 'feedback_activity.dart';
import 'feedback_display.dart';

enum _Action { rate, delete, clear }

Future<void> showToolRatingDialog(
  BuildContext context,
  AppController controller, {
  ToolFeedback? expected,
  LearningSession? safetySession,
}) => showDialog<void>(
  context: context,
  builder: (_) => _FeedbackDialog(
    controller: controller,
    action: _Action.rate,
    expected: expected,
    safetySession: safetySession,
  ),
);
Future<void> showDeleteToolFeedbackDialog(
  BuildContext context,
  AppController controller,
  ToolFeedback expected, {
  LearningSession? safetySession,
}) => showDialog<void>(
  context: context,
  builder: (_) => _FeedbackDialog(
    controller: controller,
    action: _Action.delete,
    expected: expected,
    safetySession: safetySession,
  ),
);
Future<void> showClearToolFeedbackDialog(
  BuildContext context,
  AppController controller, {
  LearningSession? safetySession,
}) => showDialog<void>(
  context: context,
  builder: (_) => _FeedbackDialog(
    controller: controller,
    action: _Action.clear,
    safetySession: safetySession,
  ),
);

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({
    required this.controller,
    required this.action,
    this.expected,
    this.safetySession,
  });
  final AppController controller;
  final _Action action;
  final ToolFeedback? expected;
  final LearningSession? safetySession;
  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _activity = FeedbackActivity();
  late final int _revision = widget.controller.replacementRevision;
  late SupportTool _tool = widget.expected?.tool ?? SupportTool.grounding;
  late ToolRating _rating = widget.expected?.rating ?? ToolRating.helpful;
  bool _busy = false;
  bool _invalidated = false;
  String? _error;
  bool get _vehicle => widget.safetySession?.snapshot.possibleVehicle ?? false;
  @override
  void initState() {
    super.initState();
    _activity.addListener(_paused);
    widget.safetySession?.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {
        if (_vehicle) {
          _invalidated = true;
        }
      });
    }
  }

  void _paused() {
    if (mounted) setState(() => _invalidated = true);
  }

  bool _valid(int epoch) =>
      mounted &&
      !_invalidated &&
      _activity.accepts(epoch) &&
      !_vehicle &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  Future<void> _save() async {
    if (_busy || _invalidated || !_activity.active || _vehicle) return;
    final epoch = _activity.epoch;
    bool guard() => _valid(epoch);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final expected = widget.expected;
      switch (widget.action) {
        case _Action.rate:
          if (expected == null) {
            await widget.controller.recordToolFeedback(
              _tool,
              _rating,
              expectedRevision: _revision,
              isActive: guard,
            );
          } else {
            await widget.controller.correctToolFeedback(
              expected.id,
              _rating,
              expected: expected,
              expectedRevision: _revision,
              isActive: guard,
            );
          }
        case _Action.delete:
          await widget.controller.deleteToolFeedback(
            expected!.id,
            expected: expected,
            expectedRevision: _revision,
            isActive: guard,
          );
        case _Action.clear:
          await widget.controller.clearToolFeedback(
            expectedRevision: _revision,
            isActive: guard,
          );
      }
      if (mounted && guard()) Navigator.of(context).pop();
    } catch (_) {
      if (guard()) {
        setState(
          () => _error = 'Could not save this change. Close this view and review your ratings, or try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    widget.safetySession?.removeListener(_changed);
    _activity.dispose();
    super.dispose();
  }

  Widget _choice(String label, bool selected, VoidCallback choose) => Semantics(
    selected: selected,
    child: OutlinedButton.icon(
      onPressed: _busy || _invalidated || !_activity.active || _vehicle
          ? null
          : choose,
      icon: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      label: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.action) {
      _Action.rate =>
        widget.expected == null ? 'Add a rating' : 'Change your rating',
      _Action.delete => 'Delete this rating?',
      _Action.clear => 'Clear your tool ratings?',
    };
    final label = switch (widget.action) {
      _Action.rate => 'Save rating',
      _Action.delete => 'Delete rating',
      _Action.clear => 'Clear all ratings',
    };
    return AlertDialog(
      scrollable: true,
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.action == _Action.rate) ...[
              if (widget.expected == null) ...[
                Text('Tool', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tool in SupportTool.values)
                      _choice(
                        toolName(tool),
                        _tool == tool,
                        () => setState(() => _tool = tool),
                      ),
                  ],
                ),
              ] else
                Text(
                  '${toolName(_tool)} · ${feedbackDate(context, widget.expected!.createdAt)}',
                ),
              const SizedBox(height: 20),
              Text(
                'Your answer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rating in ToolRating.values)
                    _choice(
                      ratingName(rating),
                      _rating == rating,
                      () => setState(() => _rating = rating),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'An optional opinion, stored encrypted on this device. This does not describe your feelings or measure how well a tool works.',
              ),
            ] else
              Text(
                widget.action == _Action.clear
                    ? 'Remove your saved tool ratings from this vault. Your plans, feeling examples, game history and rating settings stay. Copies you exported separately stay outside this app.'
                    : 'Remove this answer from this vault. Your other ratings and plans stay. Copies you exported separately stay outside this app.',
              ),
            if (_vehicle)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Return to your ratings when safely stopped.'),
              ),
            if (_invalidated)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'This view paused. Close it and review your ratings before continuing.',
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _invalidated || !_activity.active || _vehicle
              ? null
              : _save,
          child: Text(_busy ? 'Saving…' : label),
        ),
      ],
    );
  }
}
