import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onCreateEvent,
    required this.onOpenPath,
    required this.onOpenGrounding,
    required this.onOpenCheckIns,
  });

  final AppController controller;
  final VoidCallback onCreateEvent;
  final VoidCallback onOpenPath;
  final VoidCallback onOpenGrounding;
  final VoidCallback onOpenCheckIns;

  bool get _simpleWords => controller.data.readingStyle == ReadingStyle.simple;

  Future<void> _switchEvent(BuildContext context) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Choose an event',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final event in controller.data.events)
              ListTile(
                title: Text(event.title),
                subtitle: event.completedAt == null
                    ? null
                    : const Text('Completed'),
                selected: event.id == controller.activeEvent?.id,
                onTap: () => Navigator.of(sheetContext).pop(event.id),
              ),
          ],
        ),
      ),
    );
    if (selectedId == null || !context.mounted) return;
    try {
      await controller.selectEvent(selectedId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The event could not be selected. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = controller.activeEvent;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: event == null
                ? _emptyContents(context)
                : _eventContents(context, event),
          ),
        ),
      ),
    );
  }

  List<Widget> _emptyContents(BuildContext context) => [
    Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/brand/steady-through-icon.png',
        width: 88,
        height: 88,
        semanticLabel: 'Steady Through mark',
      ),
    ),
    const SizedBox(height: 16),
    Text('Steady Through', style: Theme.of(context).textTheme.headlineLarge),
    const SizedBox(height: 12),
    Text('Start an event', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 12),
    Text(
      _simpleWords
          ? 'Start with one small step. Your notes stay on this device. A trusted person can read with you.'
          : 'When something feels hard, you can start with one small step. Your notes stay on this device, and you do not need an account.',
    ),
    const SizedBox(height: 24),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: onCreateEvent,
        icon: const Icon(Icons.add),
        label: const Text('Create event'),
      ),
    ),
    if (controller.data.events.isNotEmpty) ...[
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _switchEvent(context),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Switch event'),
        ),
      ),
    ],
    const SizedBox(height: 32),
    _toolCard(context),
  ];

  List<Widget> _eventContents(BuildContext context, SupportEvent event) {
    final next = event.actions.where((action) => !action.done).firstOrNull;
    return [
      Text('Steady Through', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 20),
      Text('Your current event', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      Text(event.title, style: Theme.of(context).textTheme.headlineMedium),
      if (event.description.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(event.description),
      ],
      if (event.completedAt != null) ...[
        const SizedBox(height: 10),
        const Chip(label: Text('Completed')),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (controller.data.events.length > 1)
            OutlinedButton.icon(
              onPressed: () => _switchEvent(context),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch event'),
            ),
          TextButton.icon(
            onPressed: onCreateEvent,
            icon: const Icon(Icons.add),
            label: const Text('New event'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _simpleWords ? 'One small step' : 'One next step',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                event.completedAt != null
                    ? (_simpleWords
                          ? 'Done for now. You can open it again in Path.'
                          : 'This event is complete. You can reopen it from Path.')
                    : next?.title ??
                          (_simpleWords
                              ? 'You did every step. You can finish when ready.'
                              : 'All actions are done. You can reflect or finish when ready.'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onOpenPath,
                icon: const Icon(Icons.route),
                label: const Text('View path'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      _toolCard(context),
    ];
  }

  Widget _toolCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Support for right now',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _simpleWords ? 'You can pause or write how you feel.' : 'A short pause or a check-in can help you choose what to do next.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenGrounding,
                icon: const Icon(Icons.spa_outlined),
                label: const Text('Grounding'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCheckIns,
                icon: const Icon(Icons.edit_note),
                label: const Text('Check in'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
