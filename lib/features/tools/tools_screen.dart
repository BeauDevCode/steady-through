import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/tools/breathing_screen.dart';
import 'package:steady_through/features/tools/grounding_screen.dart';
import 'package:steady_through/features/tools/path_game_screen.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_ui.dart';

/// Body for the Tools destination. Each tool opens in its own route.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({
    super.key,
    required this.controller,
    this.showHelpNow = true,
    this.onOpenHelp,
    this.onOpenPath,
  });

  final AppController controller;

  /// Set false when a containing app bar already provides Help now.
  final bool showHelpNow;
  final VoidCallback? onOpenHelp;
  final VoidCallback? onOpenPath;

  void _open(BuildContext context, Widget body) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: body)));
  }

  @override
  Widget build(BuildContext context) {
    final simple = controller.data.readingStyle == ReadingStyle.simple;
    final colors = Theme.of(context).colorScheme;
    return SteadyPage(
      children: [
        if (showHelpNow) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: HelpNowButton(simpleWords: simple, openHelp: onOpenHelp),
          ),
          const SizedBox(height: 20),
        ],
        SectionHeading(
          title: 'Tools',
          subtitle: simple
              ? 'Pick a tool. You can stop at any time.'
              : 'Choose what feels useful right now. Every tool is optional.',
        ),
        const SizedBox(height: 28),
        ResponsiveColumns(
          minWidth: 280,
          children: [
            _toolCard(
              context,
              icon: Icons.visibility_outlined,
              color: colors.secondaryContainer,
              title: 'Notice this moment',
              description: simple
                  ? 'Look around and pick one next thing to do.'
                  : 'A short, self-paced way to notice your surroundings and choose one next action.',
              buttonLabel: 'Grounding',
              onPressed: () => _open(
                context,
                GroundingScreen(controller: controller, onOpenHelp: onOpenHelp),
              ),
            ),
            _toolCard(
              context,
              icon: Icons.air,
              color: colors.primaryContainer,
              title: 'Follow a gentle rhythm',
              description: simple
                  ? 'Watch a circle grow and shrink as you breathe.'
                  : 'An optional visual pace for breathing comfortably. Stop whenever you want.',
              buttonLabel: 'Breathing pace',
              onPressed: () => _open(
                context,
                BreathingScreen(controller: controller, onOpenHelp: onOpenHelp),
              ),
            ),
            _toolCard(
              context,
              icon: Icons.route_outlined,
              color: colors.surface,
              title: 'Find a route',
              description: simple
                  ? 'Find a path. Take as long as you like.'
                  : 'An untimed path puzzle with no score or failure state.',
              buttonLabel: 'Path game',
              onPressed: () => _open(
                context,
                PathGameScreen(
                  controller: controller,
                  onOpenHelp: onOpenHelp,
                  onOpenPath: onOpenPath,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.favorite_border, size: 20, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                simple ? 'Use what helps. You can come back later.' : 'There is no set order. Come back to any tool whenever it feels useful.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toolCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) => SurfaceCard(
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              icon: icon,
              color: Theme.of(context).colorScheme.surface,
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text(buttonLabel),
        ),
      ],
    ),
  );
}
