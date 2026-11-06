import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/tool_feedback.dart';
import 'package:steady_through/ui/steady_ui.dart';

import 'feedback_activity.dart';
import 'feedback_display.dart';

class ToolFeedbackPrompt extends StatefulWidget {
  const ToolFeedbackPrompt({
    super.key,
    required this.controller,
    required this.tool,
    this.safetySession,
  });
  final AppController controller;
  final SupportTool tool;
  final LearningSession? safetySession;
  @override
  State<ToolFeedbackPrompt> createState() => _ToolFeedbackPromptState();
}

class _ToolFeedbackPromptState extends State<ToolFeedbackPrompt> {
  final _activity = FeedbackActivity();
  bool _expanded = false, _skipped = false, _busy = false;
  int _generation = 0;
  late int _revision;
  ToolFeedback? _receipt;
  String? _error;
  bool get _vehicle => widget.safetySession?.snapshot.possibleVehicle ?? false;
  @override
  void initState() {
    super.initState();
    _revision = widget.controller.replacementRevision;
    widget.controller.addListener(_changed);
    widget.safetySession?.addListener(_changed);
    _activity.addListener(_lifecycle);
  }

  @override
  void didUpdateWidget(covariant ToolFeedbackPrompt old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller || old.tool != widget.tool) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _reset();
    }
    if (old.safetySession != widget.safetySession) {
      old.safetySession?.removeListener(_changed);
      widget.safetySession?.addListener(_changed);
    }
  }

  void _reset() {
    _generation++;
    _busy = false;
    _expanded = false;
    _skipped = false;
    _receipt = null;
    _error = null;
    _revision = widget.controller.replacementRevision;
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (_revision != widget.controller.replacementRevision || _vehicle) {
        // Invalidate the pending attempt as well as hiding its controls.
        _reset();
      } else if (_receipt != null &&
          !widget.controller.data.toolFeedback.ratings.any(
            (r) => identical(r, _receipt),
          )) {
        _receipt = null;
      }
    });
  }

  void _lifecycle() {
    if (mounted) setState(_reset);
  }

  bool _valid(int generation, int epoch, int revision) =>
      mounted &&
      generation == _generation &&
      _activity.accepts(epoch) &&
      revision == widget.controller.replacementRevision &&
      !_vehicle &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  Future<void> _save(ToolRating? rating) async {
    if (_busy || !_activity.active || _vehicle) return;
    final generation = _generation,
        epoch = _activity.epoch,
        revision = _revision;
    final previous = _receipt;
    setState(() {
      _busy = true;
      _error = null;
    });
    bool guard() => _valid(generation, epoch, revision);
    try {
      ToolFeedback? saved;
      if (rating == null) {
        if (previous == null) return;
        await widget.controller.deleteToolFeedback(
          previous.id,
          expected: previous,
          expectedRevision: revision,
          isActive: guard,
        );
      } else if (previous == null) {
        saved = await widget.controller.recordToolFeedback(
          widget.tool,
          rating,
          expectedRevision: revision,
          isActive: guard,
        );
      } else {
        await widget.controller.correctToolFeedback(
          previous.id,
          rating,
          expected: previous,
          expectedRevision: revision,
          isActive: guard,
        );
        for (final r in widget.controller.data.toolFeedback.ratings) {
          if (r.id == previous.id) saved = r;
        }
      }
      if (guard()) {
        setState(() {
          _receipt = saved;
          _expanded = true;
        });
      }
    } catch (_) {
      if (guard()) {
        setState(
          () => _error =
              'Could not save this change. Try again or leave this tool.',
        );
      }
    } finally {
      if (guard()) setState(() => _busy = false);
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
  Widget build(BuildContext context) {
    if (_skipped ||
        !widget.controller.data.toolFeedback.showPrompts ||
        _vehicle ||
        !_activity.active) {
      return const SizedBox.shrink();
    }
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.favorite_border),
          label: const Text('Rate this tool (optional)'),
        ),
      );
    }
    return SurfaceCard(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Your choice'),
          const SizedBox(height: 8),
          Text(
            'Was this useful just now?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Only your answer and this tool are remembered with a time. Stored encrypted on this device. You can change or delete it.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final rating in ToolRating.values)
                OutlinedButton.icon(
                  onPressed: _busy || _receipt?.rating == rating
                      ? null
                      : () => _save(rating),
                  icon: Icon(
                    _receipt?.rating == rating
                        ? Icons.check
                        : rating == ToolRating.helpful
                        ? Icons.favorite_border
                        : Icons.remove_circle_outline,
                  ),
                  label: Text(ratingName(rating)),
                ),
              if (_receipt == null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _skipped = true),
                  child: const Text('Skip'),
                ),
              if (_receipt != null)
                TextButton(
                  onPressed: _busy ? null : () => _save(null),
                  child: const Text('Undo rating'),
                ),
            ],
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(liveRegion: true, child: Text('Saving rating…')),
            ),
          if (_receipt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(liveRegion: true, child: Text('Rating saved')),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (_receipt != null && widget.controller.cleanupWarning != null)
            Text(widget.controller.cleanupWarning!),
        ],
      ),
    );
  }
}
