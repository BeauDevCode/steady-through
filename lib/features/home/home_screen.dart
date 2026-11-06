import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onCreateEvent,
    required this.onOpenPath,
    required this.onOpenGrounding,
    required this.onOpenCheckIns,
    this.onOpenInsights,
  });

  final AppController controller;
  final VoidCallback onCreateEvent;
  final VoidCallback onOpenPath;
  final VoidCallback onOpenGrounding;
  final VoidCallback onOpenCheckIns;
  final VoidCallback? onOpenInsights;

  bool get _simpleWords => controller.data.readingStyle == ReadingStyle.simple;

  Widget _insightsCard(BuildContext context) => SurfaceCard(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconBadge(icon: Icons.insights_rounded),
        const SizedBox(height: 14),
        Text(
          'Understand your own patterns',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          _simpleWords
              ? 'Choose what the app can learn. You can tell it how you feel.'
              : 'Choose your sources, reflect on a possible pattern, and teach your private model what fits. Every permission is optional.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onOpenInsights,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Open Insights'),
        ),
      ],
    ),
  );

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
    return SteadyPage(
      children: event == null
          ? _emptyContents(context)
          : _eventContents(context, event),
    );
  }

  List<Widget> _emptyContents(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return [
      SurfaceCard(
        color: colors.primaryContainer,
        child: _heroLayout(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('A place to begin'),
              const SizedBox(height: 10),
              Text('Start an event', style: text.headlineLarge),
              const SizedBox(height: 12),
              Text(
                _simpleWords
                    ? 'Start with one small step. Your notes stay on this device. A trusted person can read with you.'
                    : 'Make a little room for what is happening. Your notes stay on this device, and you do not need an account.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onCreateEvent,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create event'),
                  ),
                  if (controller.data.events.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _switchEvent(context),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Switch event'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _supportHeading(context),
      const SizedBox(height: 14),
      _quickActions(context),
      const SizedBox(height: 32),
      if (onOpenInsights != null) ...[
        _insightsCard(context),
        const SizedBox(height: 28),
      ],
      SectionHeading(
        title: _simpleWords
            ? 'What is an event?'
            : 'For the things life brings',
        subtitle: _simpleWords
            ? 'An event is something you want help with. It can be big or small.'
            : 'An event is simply something you want to work through. Big changes and everyday moments both belong here.',
      ),
      const SizedBox(height: 18),
      ResponsiveColumns(
        minWidth: 240,
        children: [
          _example(
            context,
            Icons.school_outlined,
            'Learning & growing',
            _simpleWords
                ? 'A school day, a test, or meeting new people.'
                : 'A new school, an exam, or finding your people.',
          ),
          _example(
            context,
            Icons.home_work_outlined,
            'Everyday changes',
            _simpleWords
                ? 'A new job, moving, or caring for someone.'
                : 'A job change, moving home, or caring for someone.',
          ),
          _example(
            context,
            Icons.wb_sunny_outlined,
            'New chapters',
            _simpleWords
                ? 'Retiring, a loss, or a change in your health.'
                : 'Retirement, a loss, or a change in health or routine.',
          ),
        ],
      ),
    ];
  }

  List<Widget> _eventContents(BuildContext context, SupportEvent event) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final next = event.actions.where((action) => !action.done).firstOrNull;
    final doneCount = event.actions.where((action) => action.done).length;
    final actionCount = event.actions.length;
    return [
      SurfaceCard(
        color: colors.primaryContainer,
        child: _heroLayout(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Your current event'),
              const SizedBox(height: 10),
              Text(event.title, style: text.headlineLarge),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(event.description, style: text.bodyMedium),
              ],
              const SizedBox(height: 20),
              if (event.completedAt != null) ...[
                const Chip(
                  avatar: Icon(Icons.check_rounded, size: 18),
                  label: Text('Completed'),
                ),
                const SizedBox(height: 8),
              ],
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (controller.data.events.length > 1)
                    TextButton.icon(
                      onPressed: () => _switchEvent(context),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Switch event'),
                    ),
                  TextButton.icon(
                    onPressed: onCreateEvent,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New event'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      SurfaceCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contents = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _simpleWords ? 'One small step' : 'One next step',
                  style: text.titleLarge,
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
                  style: text.bodyLarge,
                ),
              ],
            );
            final button = FilledButton.icon(
              onPressed: onOpenPath,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('View path'),
            );
            if (constraints.maxWidth < 600 || _largeText(context)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [contents, const SizedBox(height: 16), button],
              );
            }
            return Row(
              children: [
                const IconBadge(icon: Icons.route_rounded),
                const SizedBox(width: 20),
                Expanded(child: contents),
                const SizedBox(width: 24),
                button,
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 28),
      _supportHeading(context),
      const SizedBox(height: 14),
      _quickActions(context),
      if (onOpenInsights != null) ...[
        const SizedBox(height: 24),
        _insightsCard(context),
      ],
    ];
  }

  bool _largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) > 20;

  Widget _heroLayout(BuildContext context, Widget contents) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 550 || _largeText(context)) return contents;
      return Row(
        children: [
          Expanded(flex: 3, child: contents),
          const SizedBox(width: 20),
          const Expanded(flex: 2, child: PathArtwork(height: 210)),
        ],
      );
    },
  );

  Widget _supportHeading(BuildContext context) => Text(
    'Support for right now',
    style: Theme.of(context).textTheme.titleLarge,
  );

  Widget _quickActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ResponsiveColumns(
      minWidth: 260,
      children: [
        _supportAction(
          context,
          icon: Icons.spa_outlined,
          title: 'Grounding',
          description: _simpleWords
              ? 'Pause and notice what is around you.'
              : 'Come back to the here and now with a short, guided pause.',
          color: colors.surfaceContainerLow,
          badgeColor: colors.primaryContainer,
          onTap: onOpenGrounding,
        ),
        _supportAction(
          context,
          icon: Icons.edit_note_rounded,
          title: 'Check in',
          description: _simpleWords
              ? 'Write how you feel. A few words are enough.'
              : 'Name how things feel. A few words can be enough for today.',
          color: colors.secondaryContainer,
          badgeColor: colors.surface.withValues(alpha: .65),
          onTap: onOpenCheckIns,
        ),
      ],
    );
  }

  Widget _supportAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(icon: icon, color: badgeColor, size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: text.titleMedium)),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(description, style: text.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _example(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 25),
          const SizedBox(height: 14),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            description,
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
