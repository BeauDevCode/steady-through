import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_ui.dart';

class GroundingScreen extends StatefulWidget {
  const GroundingScreen({
    super.key,
    required this.controller,
    this.onOpenHelp,
    this.backLabel = 'Back to Tools',
  });

  final AppController controller;
  final VoidCallback? onOpenHelp;
  final String backLabel;

  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  int _step = 0;

  static const _prompts = [
    'Take a moment to look around. Name one thing you can see.',
    'Notice where your feet meet the floor or where your body rests.',
    'Listen for one sound nearby. You can keep your eyes open.',
    'Think of one small action you might choose next.',
  ];

  static const _simplePrompts = [
    'Look around. What is one thing you can see?',
    'Feel your feet on the floor, or feel where you sit.',
    'What is one sound you can hear? Keep your eyes open if you like.',
    'What is one small thing you can do next?',
  ];

  static const _icons = [
    Icons.visibility_outlined,
    Icons.spa_outlined,
    Icons.hearing_outlined,
    Icons.arrow_forward,
  ];

  void _advance() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    final simple = widget.controller.data.readingStyle == ReadingStyle.simple;
    final finished = _step >= _prompts.length;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SteadyPage(
      maxWidth: 900,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(widget.backLabel),
            ),
            HelpNowButton(simpleWords: simple, openHelp: widget.onOpenHelp),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeading(
          title: 'Grounding',
          subtitle: 'You can take your time, skip any step, or stop. There is no right answer.',
        ),
        if (simple) ...[
          const SizedBox(height: 8),
          const Text('A trusted adult or helper can read along with you.'),
        ],
        const SizedBox(height: 24),
        SurfaceCard(
          color: colors.secondaryContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: finished ? Icons.check : _icons[_step],
                    color: colors.surface,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      finished
                          ? 'Finished'
                          : 'Step ${_step + 1} of ${_prompts.length}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (var index = 0; index < _prompts.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= _step
                                ? colors.secondary
                                : colors.secondary.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(
                  finished
                      ? 'You can return to this exercise whenever you want.'
                      : (simple ? _simplePrompts[_step] : _prompts[_step]),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: finished
                        ? () => Navigator.of(context).pop()
                        : _advance,
                    child: Text(finished ? 'Done' : 'Next'),
                  ),
                  if (!finished)
                    OutlinedButton(
                      onPressed: _advance,
                      child: const Text('Skip'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
