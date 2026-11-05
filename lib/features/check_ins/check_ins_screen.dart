import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';

class CheckInsScreen extends StatelessWidget {
  const CheckInsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final event = controller.activeEvent;
      final simple = controller.data.readingStyle == ReadingStyle.simple;
      final entries =
          controller.data.checkIns
              .where((entry) => entry.eventId == event?.id)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Check-ins', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            simple ? 'Write how you feel. This is just for you.' : 'A check-in is a note for yourself. There is no right answer or score.',
          ),
          const SizedBox(height: 16),
          if (event == null)
            Text(
              simple
                  ? 'Start an event on Home to write a check-in.'
                  : 'Create an event from Home to save a check-in.',
            ),
          if (event != null) ...[
            Text(
              'For ${event.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _addCheckIn(context, event.id),
                icon: const Icon(Icons.add),
                label: const Text('Add check-in'),
              ),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const Text(
                'No check-ins for this event yet. Add one whenever you want.',
              ),
            for (final entry in entries) _entryCard(context, entry),
          ],
        ],
      );
    },
  );

  Widget _entryCard(BuildContext context, CheckIn entry) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.feeling,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Delete check-in ${entry.feeling}',
                onPressed: () => _deleteCheckIn(context, entry),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text(
            MaterialLocalizations.of(context)
                .formatMediumDate(entry.createdAt.toLocal()),
          ),
          if (entry.intensity != null)
            Text('Intensity: ${entry.intensity} of 5'),
          if (entry.note?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(entry.note!),
          ],
        ],
      ),
    ),
  );

  Future<void> _addCheckIn(BuildContext context, String eventId) async {
    final formKey = GlobalKey<FormState>();
    var feeling = '';
    var note = '';
    int? intensity;
    var saving = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add check-in'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'How do you feel?',
                    ),
                    onChanged: (value) => feeling = value,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Write a few words about how you feel.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Intensity (optional)'),
                  const Text('You can skip this number.'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('No number'),
                        selected: intensity == null,
                        onSelected: (_) =>
                            setDialogState(() => intensity = null),
                      ),
                      for (var value = 1; value <= 5; value++)
                        ChoiceChip(
                          label: Text('$value'),
                          selected: intensity == value,
                          onSelected: (_) =>
                              setDialogState(() => intensity = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                    onChanged: (value) => note = value,
                    maxLines: 3,
                  ),
                  if (saveError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      saveError!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        saveError = null;
                      });
                      try {
                        await controller.addCheckIn(
                          eventId,
                          feeling: feeling,
                          intensity: intensity,
                          note: note,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            saveError = 'Could not save this check-in. Please try again.';
                          });
                        }
                      }
                    },
              child: const Text('Save check-in'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCheckIn(BuildContext context, CheckIn entry) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete check-in?'),
        content: const Text('This note will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep check-in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete check-in'),
          ),
        ],
      ),
    );
    if (delete == true) {
      try {
        await controller.deleteCheckIn(entry.id);
      } catch (_) {
        if (context.mounted) {
          _message(
            context,
            'Could not delete this check-in. Please try again.',
          );
        }
      }
    }
  }

  void _message(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
