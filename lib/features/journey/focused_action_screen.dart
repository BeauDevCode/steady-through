import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/journey/event_form.dart';
import 'package:steady_through/features/journey/journey_screen.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/next_action_target.dart';
import 'package:steady_through/ui/steady_ui.dart';
import 'package:steady_through/ui/view_activity.dart';

/// A focused view of an existing step. Navigation never completes a step.
class FocusedActionScreen extends StatefulWidget {
  const FocusedActionScreen({
    super.key,
    required this.controller,
    required this.target,
    this.onOpenHelp,
    this.onOpenPath,
  });

  final AppController controller;
  final NextActionTarget target;
  final VoidCallback? onOpenHelp;
  final VoidCallback? onOpenPath;

  @override
  State<FocusedActionScreen> createState() => _FocusedActionScreenState();
}

class _FocusedActionScreenState extends State<FocusedActionScreen> {
  final _activity = ViewActivity();
  bool _busy = false;
  int _generation = 0;
  String? _error;

  bool get _simple =>
      widget.controller.data.readingStyle == ReadingStyle.simple;

  SupportEvent? get _event {
    if (widget.target.replacementRevision !=
        widget.controller.replacementRevision) {
      return null;
    }
    final event = widget.controller.activeEvent;
    return event?.id == widget.target.eventId && event?.completedAt == null
        ? event
        : null;
  }

  PlanAction? _action(SupportEvent? event) {
    if (event == null) return null;
    for (final action in event.actions) {
      if (action.id == widget.target.actionId) return action;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _activity.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant FocusedActionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.target.eventId != widget.target.eventId ||
        oldWidget.target.actionId != widget.target.actionId ||
        oldWidget.target.replacementRevision !=
            widget.target.replacementRevision) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _generation++;
      _busy = false;
      _error = null;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _current => ModalRoute.of(context)?.isCurrent ?? true;

  Future<void> _toggle() async {
    final event = _event;
    final action = _action(event);
    if (_busy ||
        !_activity.active ||
        !_current ||
        event == null ||
        action == null) {
      return;
    }
    final controller = widget.controller;
    final target = widget.target;
    final generation = _generation;
    final epoch = _activity.epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    bool sameAttempt() => mounted && generation == _generation;
    bool active() => sameAttempt() && _activity.accepts(epoch) && _current;
    try {
      await controller.setFocusedActionDone(
        event.id,
        action.id,
        !action.done,
        expected: action,
        expectedRevision: target.replacementRevision,
        isActive: active,
      );
      // The controller's persisted data drives the display, including when
      // Help covers this route while an already-started atomic save finishes.
    } catch (_) {
      if (active() && _action(_event) != null) {
        setState(() {
          _error = _simple
              ? 'The step could not be updated. Please try again.'
              : 'This step could not be updated. Please try again.';
        });
      }
    } finally {
      // Always settle this attempt if its view still exists, even after an
      // epoch change or Help. A late completion never pops another route.
      if (sameAttempt()) setState(() => _busy = false);
    }
  }

  void _back() {
    _generation++;
    Navigator.of(context).maybePop();
  }

  void _help() {
    if (widget.onOpenHelp != null) {
      widget.onOpenHelp!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: HelpScreen(controller: widget.controller, simpleWords: _simple),
        ),
      ),
    );
  }

  void _path() {
    if (widget.onOpenPath != null) {
      widget.onOpenPath!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _FullPathScreen(controller: widget.controller),
      ),
    );
  }

  @override
  void dispose() {
    _generation++;
    widget.controller.removeListener(_changed);
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final action = _action(event);
    final text = Theme.of(context).textTheme;
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
    );
    return Scaffold(
      body: SteadyPage(
        maxWidth: 760,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton.icon(
                style: buttonStyle,
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Home'),
              ),
              TextButton.icon(
                style: buttonStyle,
                onPressed: _help,
                icon: const Icon(Icons.support_agent),
                label: const Text('Help now'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeading(title: 'Your next step'),
          const SizedBox(height: 24),
          if (event != null && action != null)
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(icon: Icons.route_outlined),
                  const SizedBox(height: 20),
                  Text(event.title, style: text.titleMedium),
                  const SizedBox(height: 12),
                  Text(action.title, style: text.headlineSmall),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      action.done
                          ? 'This step is done. You can undo it here.'
                          : _simple
                          ? 'Take this one step when you are ready.'
                          : 'Take this step at your own pace. Mark it done when you are ready.',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(_error!)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onPressed: _busy || !_activity.active ? null : _toggle,
                      child: Text(
                        _busy
                            ? 'Saving step…'
                            : action.done
                            ? 'Undo completion'
                            : 'Mark step done',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SurfaceCard(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _simple
                      ? 'This step is no longer available. Go back or open your current path.'
                      : 'This step is no longer available. The event or plan may have changed. You can return Home or view your current path.',
                  style: text.bodyLarge,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: buttonStyle,
              onPressed: _path,
              icon: const Icon(Icons.view_timeline_outlined),
              label: const Text('View full path'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps direct feature use useful when there is no shell navigation callback.
class _FullPathScreen extends StatelessWidget {
  const _FullPathScreen({required this.controller});
  final AppController controller;

  void _edit(BuildContext context, [SupportEvent? event]) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventForm(
          event: event,
          simpleWords: controller.data.readingStyle == ReadingStyle.simple,
          onSave: (submission) => event == null
              ? controller.createEvent(
                  submission.title,
                  submission.description,
                  guidanceContext: submission.guidanceContext,
                  starterStepIds: submission.starterStepIds,
                )
              : controller.updateEvent(
                  event.id,
                  submission.title,
                  submission.description,
                  guidanceContext: submission.guidanceContext,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your path'),
      actions: [
        HelpNowButton(
          controller: controller,
          simpleWords: controller.data.readingStyle == ReadingStyle.simple,
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => JourneyScreen(
        controller: controller,
        onCreateEvent: () => _edit(context),
        onEditEvent: (event) => _edit(context, event),
        onDeleted: () {},
      ),
    ),
  );
}
