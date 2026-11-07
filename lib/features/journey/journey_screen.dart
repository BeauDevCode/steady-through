import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/event_guidance.dart';
import 'package:steady_through/features/journey/guidance_picker.dart';
import 'package:steady_through/ui/steady_ui.dart';

const _stageTitles = <JourneyStage, String>{
  JourneyStage.orient: 'Get oriented',
  JourneyStage.settle: 'Settle',
  JourneyStage.support: 'Find support',
  JourneyStage.plan: 'Make a plan',
  JourneyStage.reflect: 'Reflect',
};

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({
    super.key,
    required this.controller,
    required this.onCreateEvent,
    required this.onEditEvent,
    required this.onDeleted,
  });

  final AppController controller;
  final VoidCallback onCreateEvent;
  final ValueChanged<SupportEvent> onEditEvent;
  final VoidCallback onDeleted;

  bool get _simpleWords => controller.data.readingStyle == ReadingStyle.simple;

  Future<void> _chooseSteps(BuildContext context, SupportEvent event) =>
      showDialog<void>(
        context: context,
        builder: (_) => StarterStepsPickerDialog(
          guidanceContext: event.guidanceContext,
          simpleWords: _simpleWords,
          selectedIds: const [],
          existingActions: event.actions,
          onSave: (ids) => controller.addStarterActions(event.id, ids),
        ),
      );

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleAction(
    BuildContext context,
    SupportEvent event,
    PlanAction action,
    bool done,
  ) async {
    try {
      await controller.setActionDone(event.id, action.id, done);
    } catch (_) {
      if (context.mounted) {
        _showError(
          context,
          'The action could not be updated. Please try again.',
        );
      }
    }
  }

  Future<void> _editAction(
    BuildContext context,
    SupportEvent event,
    JourneyStage stage, [
    PlanAction? action,
  ]) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ActionFormDialog(
        action: action,
        onSave: (title) => action == null
            ? controller.addAction(event.id, stage, title)
            : controller.renameAction(event.id, action.id, title),
      ),
    );
  }

  Future<void> _removeAction(
    BuildContext context,
    SupportEvent event,
    PlanAction action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this action?'),
        content: Text('Remove “${action.title}” from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep action'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove action'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.removeAction(event.id, action.id);
    } catch (_) {
      if (context.mounted) {
        _showError(
          context,
          'The action could not be removed. Please try again.',
        );
      }
    }
  }

  Future<void> _setCompleted(
    BuildContext context,
    SupportEvent event,
    bool done,
  ) async {
    try {
      await controller.completeEvent(event.id, done);
    } catch (_) {
      if (context.mounted) {
        _showError(
          context,
          'The event could not be updated. Please try again.',
        );
      }
    }
  }

  Future<void> _deleteEvent(BuildContext context, SupportEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text(
          'This permanently removes the event, its actions, and its check-ins from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep event'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.deleteEvent(event.id);
      if (context.mounted) {
        onDeleted();
      }
    } catch (_) {
      if (context.mounted) {
        _showError(
          context,
          'The event could not be deleted. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = controller.activeEvent;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (event == null) {
      return SteadyPage(
        maxWidth: 900,
        children: [
          SurfaceCard(
            color: colors.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(icon: Icons.route_rounded),
                const SizedBox(height: 24),
                Text('No event selected', style: text.headlineLarge),
                const SizedBox(height: 12),
                Text(
                  _simpleWords
                      ? 'Start an event to see your steps.'
                      : 'Start an event to see your path through it.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onCreateEvent,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create event'),
                ),
                const PathArtwork(height: 180),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _simpleWords
                ? 'You can take a pause, ask for help, and choose one small step.'
                : 'Your path has room to pause, find support, choose a next step, and notice what helps. Move at your own pace.',
            style: text.bodyLarge,
          ),
        ],
      );
    }

    final doneCount = event.actions.where((action) => action.done).length;
    final actionCount = event.actions.length;
    final nextStage = event.nextPendingAction?.stage;
    return SteadyPage(
      maxWidth: 1000,
      children: [
        SurfaceCard(
          color: colors.primaryContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: _simpleWords ? 'Your steps' : 'Your path',
                action: TextButton.icon(
                  onPressed: () => onEditEvent(event),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit event'),
                ),
              ),
              const SizedBox(height: 6),
              Text(event.title, style: text.titleLarge),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(event.description),
              ],
              if (_simpleWords) ...[
                const SizedBox(height: 8),
                const Text('A trusted person can read these steps with you.'),
              ],
              if (event.completedAt != null) ...[
                const SizedBox(height: 10),
                const Text(
                  'Completed. You can reopen this event whenever you need to.',
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _simpleWords
                    ? '$doneCount of $actionCount steps done'
                    : '$doneCount of $actionCount actions done',
                style: text.labelLarge,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: actionCount == 0 ? 0 : doneCount / actionCount,
                minHeight: 7,
                borderRadius: BorderRadius.circular(20),
                backgroundColor: colors.onPrimaryContainer.withValues(
                  alpha: .1,
                ),
                semanticsLabel: 'Action progress',
              ),
              const SizedBox(height: 16),
              GuidanceCard(
                guidanceContext: event.guidanceContext,
                simpleWords: _simpleWords,
                onChooseSteps: () => _chooseSteps(context, event),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        for (final stage in JourneyStage.values)
          _stageSection(context, event, stage, nextStage),
        const SizedBox(height: 8),
        SurfaceCard(
          color: colors.secondaryContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('At your own pace'),
              const SizedBox(height: 8),
              Text(
                event.completedAt == null
                    ? (_simpleWords ? 'Done for now?' : 'A place to pause')
                    : (_simpleWords
                          ? 'You can come back'
                          : 'Every path can be revisited'),
                style: text.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _simpleWords
                    ? 'Finish when you are ready. You can open this event again.'
                    : 'You decide when this event feels finished. Your notes and actions will still be here if you return.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    _setCompleted(context, event, event.completedAt == null),
                icon: Icon(
                  event.completedAt == null
                      ? Icons.check_circle_outline
                      : Icons.refresh_rounded,
                ),
                label: Text(
                  event.completedAt == null ? 'Finish event' : 'Reopen event',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _deleteEvent(context, event),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete event'),
            style: TextButton.styleFrom(foregroundColor: colors.error),
          ),
        ),
      ],
    );
  }

  Widget _stageSection(
    BuildContext context,
    SupportEvent event,
    JourneyStage stage,
    JourneyStage? nextStage,
  ) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final actions = event.actions
        .where((action) => action.stage == stage)
        .toList();
    final current = stage == nextStage && event.completedAt == null;
    final completed =
        actions.isNotEmpty && actions.every((action) => action.done);
    final number = JourneyStage.values.indexOf(stage) + 1;
    return Stack(
      children: [
        Positioned(
          left: 18.25,
          top: 38,
          bottom: 0,
          child: Container(width: 1.5, color: colors.outlineVariant),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Semantics(
                label: 'Stage $number',
                child: ExcludeSemantics(
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: current ? colors.primary : colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current || completed
                            ? colors.primary
                            : colors.outlineVariant,
                      ),
                    ),
                    child: Text(
                      '$number',
                      style: text.labelLarge?.copyWith(
                        color: current ? colors.onPrimary : colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_stageTitles[stage]!, style: text.titleLarge),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guideFor(event.guidanceContext)
                          .stagePrompt(stage, simpleWords: _simpleWords),
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SurfaceCard(
                      padding: const EdgeInsets.all(12),
                      color: current
                          ? colors.surface
                          : colors.surface.withValues(alpha: .6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (actions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              child: Text(
                                _simpleWords
                                    ? 'Add a small step for this part.'
                                    : 'Make this part your own with a small, practical action.',
                                style: text.bodyMedium,
                              ),
                            ),
                          for (
                            var index = 0;
                            index < actions.length;
                            index++
                          ) ...[
                            if (index > 0)
                              Divider(height: 12, color: colors.outlineVariant),
                            _actionRow(context, event, stage, actions[index]),
                          ],
                          TextButton.icon(
                            onPressed: () => _editAction(context, event, stage),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add action'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionRow(
    BuildContext context,
    SupportEvent event,
    JourneyStage stage,
    PlanAction action,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final checkbox = CheckboxListTile(
        value: action.done,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: Text(
          action.title,
          style: action.done
              ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
        ),
        onChanged: (value) =>
            _toggleAction(context, event, action, value ?? false),
      );
      final controls = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit ${action.title}',
            onPressed: () => _editAction(context, event, stage, action),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Remove ${action.title}',
            onPressed: () => _removeAction(context, event, action),
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
        ],
      );
      if (constraints.maxWidth < 420 ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            checkbox,
            Align(alignment: Alignment.centerRight, child: controls),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: checkbox),
          controls,
        ],
      );
    },
  );
}

class _ActionFormDialog extends StatefulWidget {
  const _ActionFormDialog({required this.action, required this.onSave});

  final PlanAction? action;
  final Future<void> Function(String title) onSave;

  @override
  State<_ActionFormDialog> createState() => _ActionFormDialogState();
}

class _ActionFormDialogState extends State<_ActionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.action?.title ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(_title.text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'The action could not be saved. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.action == null ? 'Add an action' : 'Edit action'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _title,
            readOnly: _saving,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Your action'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Write a short action.'
                : null,
            onFieldSubmitted: (_) => _save(),
          ),
          if (_saveError != null) Text(_saveError!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Save action'),
      ),
    ],
  );
}
