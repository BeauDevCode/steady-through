import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_ui.dart';

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
      final colors = Theme.of(context).colorScheme;
      return SteadyPage(
        maxWidth: 960,
        children: [
          const Eyebrow('A moment for you'),
          const SizedBox(height: 12),
          SectionHeading(
            title: 'Check-ins',
            subtitle: simple ? 'Write how you feel. This is just for you.' : 'A check-in is a note for yourself. There is no right answer or score.',
          ),
          const SizedBox(height: 24),
          if (event == null)
            SurfaceCard(
              color: colors.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    icon: Icons.edit_note_outlined,
                    color: colors.surface,
                    size: 56,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Make space for how you feel',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    simple
                        ? 'Start an event on Home to write a check-in.'
                        : 'Create an event from Home to save a check-in.',
                  ),
                ],
              ),
            ),
          if (event != null) ...[
            SurfaceCard(
              color: colors.primaryContainer,
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Current event'),
                      const SizedBox(height: 8),
                      Text(
                        'For ${event.title}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  );
                  final button = FilledButton.icon(
                    onPressed: () => _addCheckIn(context, event.id),
                    icon: const Icon(Icons.add),
                    label: const Text('Add check-in'),
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [heading, const SizedBox(height: 16), button],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: 24),
                      button,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            Text(
              simple ? 'Your notes' : 'Your check-in history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(icon: Icons.notes_outlined, size: 44),
                    SizedBox(height: 16),
                    Text(
                      'No check-ins for this event yet. Add one whenever you want.',
                    ),
                  ],
                ),
              ),
            for (var index = 0; index < entries.length; index++)
              _entryCard(
                context,
                entries[index],
                first: index == 0,
                last: index == entries.length - 1,
              ),
          ],
        ],
      );
    },
  );

  Widget _entryCard(
    BuildContext context,
    CheckIn entry, {
    required bool first,
    required bool last,
  }) {
    final colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 28,
                  color: first ? Colors.transparent : colors.outlineVariant,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primaryContainer,
                      width: 3,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: colors.outlineVariant),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.feeling,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete check-in ${entry.feeling}',
                          onPressed: () => _deleteCheckIn(context, entry),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(entry.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    if (entry.intensity != null) ...[
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text('Intensity: ${entry.intensity} of 5'),
                        ),
                      ),
                    ],
                    if (entry.note?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 16),
                      Text(
                        entry.note!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                    readOnly: saving,
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
                        onSelected: saving
                            ? null
                            : (_) => setDialogState(() => intensity = null),
                      ),
                      for (var value = 1; value <= 5; value++)
                        ChoiceChip(
                          label: Text('$value'),
                          selected: intensity == value,
                          onSelected: saving
                              ? null
                              : (_) => setDialogState(() => intensity = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    readOnly: saving,
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
