import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:steady_through/ui/steady_ui.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/people/phone_actions.dart';
import 'package:steady_through/features/people/trusted_people_section.dart';
import 'package:steady_through/ui/view_activity.dart';

/// A route action that also works when a tool is opened above the app shell.
class HelpNowButton extends StatelessWidget {
  const HelpNowButton({
    super.key,
    this.onOpen,
    this.openHelp,
    this.simpleWords = false,
    this.controller,
  });

  final VoidCallback? onOpen;
  final VoidCallback? openHelp;
  final bool simpleWords;
  final AppController? controller;

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
          builder: (_) => Scaffold(
            body: HelpScreen(simpleWords: simpleWords, controller: controller),
          ),
        ),
      );
    },
    icon: const Icon(Icons.support_agent),
    label: const Text('Help now'),
  );
}

/// General help information. The app shell or a tool route supplies a Scaffold.
class HelpScreen extends StatelessWidget {
  const HelpScreen({
    super.key,
    this.simpleWords = false,
    this.controller,
    this.phoneActions = const UrlLauncherPhoneActions(),
  });

  final bool simpleWords;
  final AppController? controller;
  final PhoneActions phoneActions;

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

  @override
  Widget build(BuildContext context) => SteadyPage(
    maxWidth: 900,
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
      const Eyebrow('Support is available'),
      const SizedBox(height: 12),
      Text('Help now', style: Theme.of(context).textTheme.headlineMedium),
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
                const _HelpCopyButton(),
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
      if (controller != null)
        TrustedPeopleSection(
          controller: controller!,
          phoneActions: phoneActions,
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
            ? 'You can ask someone you trust to help you read this.'
            : 'You deserve support. Choose the option that fits where you are.',
      ),
      const SizedBox(height: 12),
      Text(
        simpleWords
            ? 'This app can help you make a plan. It does not give medical care.'
            : 'Steady Through offers general self-help and organization. It does not diagnose or provide medical care.',
      ),
    ],
  );

  Widget _helpCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: icon),
                const SizedBox(width: 16),
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
    ),
  );
}

class _HelpCopyButton extends StatefulWidget {
  const _HelpCopyButton();

  @override
  State<_HelpCopyButton> createState() => _HelpCopyButtonState();
}

class _HelpCopyButtonState extends State<_HelpCopyButton> {
  final _activity = ViewActivity();
  bool _copying = false;

  Future<void> _copy() async {
    if (_copying || !_activity.active) return;
    final epoch = _activity.epoch;
    setState(() => _copying = true);
    try {
      String message;
      try {
        await Clipboard.setData(const ClipboardData(text: '988'));
        message = '988 copied.';
      } catch (_) {
        message = 'Could not copy 988. The number is still shown here; you can enter it manually.';
      }
      if (mounted &&
          _activity.accepts(epoch) &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  void dispose() {
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _copying ? null : _copy,
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    icon: const Icon(Icons.copy_outlined),
    label: const Text('Copy 988'),
  );
}
