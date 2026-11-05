import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/model/app_data.dart';

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

  void _advance() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    final simple = widget.controller.data.readingStyle == ReadingStyle.simple;
    final finished = _step >= _prompts.length;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
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
                  HelpNowButton(
                    simpleWords: simple,
                    openHelp: widget.onOpenHelp,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Grounding',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'You can take your time, skip any step, or stop. There is no right answer.',
              ),
              if (simple) ...[
                const SizedBox(height: 8),
                const Text(
                  'A trusted adult or helper can read along with you.',
                ),
              ],
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finished
                            ? 'Finished'
                            : 'Step ${_step + 1} of ${_prompts.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        finished
                            ? 'You can return to this exercise whenever you want.'
                            : (simple
                                  ? _simplePrompts[_step]
                                  : _prompts[_step]),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
      ),
    );
  }
}
