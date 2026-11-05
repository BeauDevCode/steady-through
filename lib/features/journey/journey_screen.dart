import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';

const _stageTitles = <JourneyStage, String>{
  JourneyStage.orient: 'Get oriented',
  JourneyStage.settle: 'Settle',
  JourneyStage.support: 'Find support',
  JourneyStage.plan: 'Make a plan',
  JourneyStage.reflect: 'Reflect',
};

const _stagePrompts = <JourneyStage, String>{
  JourneyStage.orient:
      'What needs your attention first? Start with what you know.',
  JourneyStage.settle: 'Pause and notice what is around you.',
  JourneyStage.support: 'Who could help with one part of this?',
  JourneyStage.plan: 'Choose one manageable next step.',
  JourneyStage.reflect: 'What helped, even a little?',
};

const _simpleStagePrompts = <JourneyStage, String>{
  JourneyStage.orient: 'What needs to happen first?',
  JourneyStage.settle: 'Look around and take a short pause.',
  JourneyStage.support: 'Who can help you?',
  JourneyStage.plan: 'What is one small thing you can do?',
  JourneyStage.reflect: 'What helped you?',
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
    if (event == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No event selected',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  _simpleWords
                      ? 'Start an event to see your steps.'
                      : 'Start an event to see your path through it.',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onCreateEvent,
                  child: const Text('Create event'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final doneCount = event.actions.where((action) => action.done).length;
    final actionCount = event.actions.length;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _simpleWords ? 'Your steps' : 'Your path',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (_simpleWords) ...[
                const SizedBox(height: 8),
                const Text('A trusted person can read these steps with you.'),
              ],
              const SizedBox(height: 8),
              Text(event.title, style: Theme.of(context).textTheme.titleLarge),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(event.description),
              ],
              if (event.completedAt != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Completed. You can reopen this event whenever you need to.',
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onEditEvent(event),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit event'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _simpleWords
                    ? '$doneCount of $actionCount steps done'
                    : '$doneCount of $actionCount actions done',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: actionCount == 0 ? 0 : doneCount / actionCount,
                semanticsLabel: 'Action progress',
              ),
              const SizedBox(height: 20),
              for (final stage in JourneyStage.values) ...[
                _stageCard(context, event, stage),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () =>
                      _setCompleted(context, event, event.completedAt == null),
                  icon: Icon(
                    event.completedAt == null
                        ? Icons.check_circle_outline
                        : Icons.refresh,
                  ),
                  label: Text(
                    event.completedAt == null ? 'Finish event' : 'Reopen event',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _deleteEvent(context, event),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete event'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageCard(
    BuildContext context,
    SupportEvent event,
    JourneyStage stage,
  ) {
    final actions = event.actions
        .where((action) => action.stage == stage)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _stageTitles[stage]!,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text((_simpleWords ? _simpleStagePrompts : _stagePrompts)[stage]!),
            const SizedBox(height: 8),
            for (final action in actions) ...[
              CheckboxListTile(
                value: action.done,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(action.title),
                onChanged: (value) =>
                    _toggleAction(context, event, action, value ?? false),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Edit ${action.title}',
                      onPressed: () =>
                          _editAction(context, event, stage, action),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove ${action.title}',
                      onPressed: () => _removeAction(context, event, action),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ],
            TextButton.icon(
              onPressed: () => _editAction(context, event, stage),
              icon: const Icon(Icons.add),
              label: const Text('Add action'),
            ),
          ],
        ),
      ),
    );
  }
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
