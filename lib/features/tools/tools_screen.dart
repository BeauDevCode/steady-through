import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/tools/breathing_screen.dart';
import 'package:steady_through/features/tools/grounding_screen.dart';
import 'package:steady_through/features/tools/path_game_screen.dart';
import 'package:steady_through/model/app_data.dart';

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
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (showHelpNow) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: HelpNowButton(
                    simpleWords: simple,
                    openHelp: onOpenHelp,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text('Tools', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 12),
              Text(
                simple ? 'Pick a tool. You can stop at any time.' : 'Choose what feels useful right now. Every tool is optional.',
              ),
              const SizedBox(height: 20),
              _toolCard(
                context,
                icon: Icons.visibility_outlined,
                title: 'Notice this moment',
                description: simple
                    ? 'Look around and pick one next thing to do.'
                    : 'A short, self-paced way to notice your surroundings and choose one next action.',
                buttonLabel: 'Grounding',
                onPressed: () => _open(
                  context,
                  GroundingScreen(
                    controller: controller,
                    onOpenHelp: onOpenHelp,
                  ),
                ),
              ),
              _toolCard(
                context,
                icon: Icons.air,
                title: 'Follow a gentle rhythm',
                description: simple
                    ? 'Watch a circle grow and shrink as you breathe.'
                    : 'An optional visual pace for breathing comfortably. Stop whenever you want.',
                buttonLabel: 'Breathing pace',
                onPressed: () => _open(
                  context,
                  BreathingScreen(
                    controller: controller,
                    onOpenHelp: onOpenHelp,
                  ),
                ),
              ),
              _toolCard(
                context,
                icon: Icons.route,
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
        ),
      ),
    );
  }

  Widget _toolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 12),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    ),
  );
}
