import 'package:flutter/material.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';

import 'moment_display.dart';

Future<bool?> changeSavedMoment(
  BuildContext context,
  LearningSession session,
  LearningExample moment, {
  bool deleting = false,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _MomentChangeDialog(session: session, moment: moment, deleting: deleting),
);

class _MomentChangeDialog extends StatefulWidget {
  const _MomentChangeDialog({
    required this.session,
    required this.moment,
    required this.deleting,
  });
  final LearningSession session;
  final LearningExample moment;
  final bool deleting;
  @override
  State<_MomentChangeDialog> createState() => _MomentChangeDialogState();
}

class _MomentChangeDialogState extends State<_MomentChangeDialog> {
  late FeelingLabel _selected = widget.moment.label;
  bool _working = false;
  String? _error;

  Future<void> _commit() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (widget.deleting) {
        await widget.session.deleteMoment(widget.moment.id);
      } else {
        await widget.session.relabelMoment(widget.moment.id, _selected);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = widget.deleting
              ? 'Could not delete this moment. Your saved moments are unchanged. Try again when safely stopped.'
              : 'Could not save this change. Your saved moments are unchanged. Try again when safely stopped.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final vehicle = widget.session.insight.isVehicleContext;
      return PopScope(
        canPop: !_working,
        child: AlertDialog(
          scrollable: true,
          title: Text(
            widget.deleting ? 'Delete this moment?' : 'Edit this feeling',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${feelingName(widget.moment.label)} · ${momentTime(context, widget.moment.createdAt)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (vehicle)
                const Text(
                  'Return when safely stopped to manage saved moments.',
                )
              else if (!widget.deleting) ...[
                const Text(
                  'Choose the feeling you meant for this moment. Its time and saved readings stay the same.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in FeelingLabel.values)
                      ChoiceChip(
                        label: Text(feelingName(label)),
                        selected: _selected == label,
                        onSelected: _working
                            ? null
                            : (_) => setState(() => _selected = label),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                  ],
                ),
              ] else
                const Text(
                  'This removes only this saved moment. It cannot be undone. Your other moments and plans stay available.',
                ),
              const SizedBox(height: 16),
              const Text(
                'Changing saved evidence clears the saved personal model and its review results. Remaining moments can still support a fresh, tentative comparison.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: _working ? null : () => Navigator.pop(context, false),
              child: Text(widget.deleting ? 'Keep moment' : 'Cancel'),
            ),
            FilledButton(
              onPressed:
                  _working ||
                      vehicle ||
                      (!widget.deleting && _selected == widget.moment.label)
                  ? null
                  : _commit,
              child: Text(
                _working
                    ? 'Saving…'
                    : widget.deleting
                    ? 'Delete moment'
                    : 'Save changes',
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> viewSavedMoment(
  BuildContext context,
  LearningExample moment,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    scrollable: true,
    title: const Text('Saved moment'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          feelingName(moment.label),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('Saved ${momentTime(context, moment.createdAt)}'),
        const SizedBox(height: 20),
        Text(
          momentContext(moment.snapshot),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (moment.snapshot.features.isNotEmpty) ...[
          Text('Observed ${momentTime(context, moment.snapshot.observedAt)}'),
          const SizedBox(height: 12),
          for (final metric in signalMetrics.keys)
            if (moment.snapshot.features.containsKey(metric))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  metricDescription(metric, moment.snapshot.features[metric]!),
                ),
              ),
        ],
        if (moment.snapshot.possibleVehicle)
          const Text(
            'Possible vehicle movement was recorded. This does not identify who was driving.',
          ),
        const SizedBox(height: 12),
        const Text(
          'These are the readings saved with your chosen feeling. They do not establish how you felt. No app names, typed content or routes are included.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);
