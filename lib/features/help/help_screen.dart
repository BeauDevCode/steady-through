import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// A route action that also works when a tool is opened above the app shell.
class HelpNowButton extends StatelessWidget {
  const HelpNowButton({
    super.key,
    this.onOpen,
    this.openHelp,
    this.simpleWords = false,
  });

  final VoidCallback? onOpen;
  final VoidCallback? openHelp;
  final bool simpleWords;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () {
      onOpen?.call();
      if (openHelp != null) {
        openHelp!();
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: HelpScreen(simpleWords: simpleWords)),
        ),
      );
    },
    icon: const Icon(Icons.support_agent),
    label: const Text('Help now'),
  );
}

/// General help information. The app shell or a tool route supplies a Scaffold.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.simpleWords = false});

  final bool simpleWords;

  Future<void> _openNumber(BuildContext context, String scheme) async {
    final uri = Uri(scheme: scheme, path: '988');
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // Some desktop devices have no phone or message handler.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open a phone or message app here. You can copy 988 instead.',
          ),
        ),
      );
    }
  }

  Future<void> _copyNumber(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: '988'));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('988 copied.')));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Help now', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 12),
            Text(
              simpleWords
                  ? 'You can ask someone you trust to help you read this.'
                  : 'You deserve support. Choose the option that fits where you are.',
            ),
            const SizedBox(height: 20),
            _helpCard(
              context,
              title: 'Immediate danger',
              icon: Icons.warning_amber_rounded,
              child: Text(
                simpleWords
                    ? 'If you are in danger now, call local emergency services.'
                    : 'If you or someone nearby is in immediate physical danger, contact local emergency services now.',
              ),
            ),
            _helpCard(
              context,
              title: 'Crisis support in the U.S.',
              icon: Icons.phone_in_talk_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    simpleWords
                        ? 'In the U.S., call or text 988 for crisis help (U.S. only).'
                        : 'Call or text 988 for the 988 Suicide & Crisis Lifeline (U.S. only).',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openNumber(context, 'tel'),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Call 988'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openNumber(context, 'sms'),
                        icon: const Icon(Icons.sms_outlined),
                        label: const Text('Text 988'),
                      ),
                      TextButton.icon(
                        onPressed: () => _copyNumber(context),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy 988'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _helpCard(
              context,
              title: 'Outside the U.S.',
              icon: Icons.public,
              child: Text(
                simpleWords
                    ? 'Call a crisis service or emergency number where you live.'
                    : 'Use your local crisis service or local emergency number.',
              ),
            ),
            _helpCard(
              context,
              title: 'More support',
              icon: Icons.people_outline,
              child: Text(
                simpleWords
                    ? 'If things feel worse or daily life is hard, talk to a health professional or someone you trust.'
                    : 'If distress is getting worse or making daily life hard, consider talking with a health professional. You can also reach out to a trusted person.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              simpleWords
                  ? 'This app can help you make a plan. It does not give medical care.'
                  : 'Steady Through offers general self-help and organization. It does not diagnose or provide medical care.',
            ),
          ],
        ),
      ),
    ),
  );

  Widget _helpCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
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
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
