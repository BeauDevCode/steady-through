import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/tools/feedback/tool_feedback_prompt.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/tool_feedback.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/ui/steady_ui.dart';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({
    super.key,
    required this.controller,
    this.onOpenHelp,
    this.safetySession,
  });

  final AppController controller;
  final LearningSession? safetySession;
  final VoidCallback? onOpenHelp;

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with WidgetsBindingObserver {
  Timer? _paceTimer;
  bool _started = false;
  bool _inhale = true;
  bool _hasStarted = false;
  bool _finished = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pausePace();
  }

  void _finish() {
    _paceTimer?.cancel();
    _paceTimer = null;
    setState(() {
      _started = false;
      _finished = true;
    });
  }

  void _startPace() {
    _paceTimer?.cancel();
    setState(() {
      if (!_hasStarted || _finished) _attempt++;
      _hasStarted = true;
      _finished = false;
      _started = true;
      _inhale = true;
    });
    _paceTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _inhale = !_inhale);
    });
  }

  void _pausePace() {
    _paceTimer?.cancel();
    _paceTimer = null;
    if (mounted) setState(() => _started = false);
  }

  void _stop() {
    _paceTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simple = widget.controller.data.readingStyle == ReadingStyle.simple;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SteadyPage(
      maxWidth: 1040,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Tools'),
            ),
            HelpNowButton(
              onOpen: _pausePace,
              openHelp: widget.onOpenHelp,
              simpleWords: simple,
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeading(
          title: 'Breathing pace',
          subtitle: simple
              ? 'Breathe in and out in a way that feels comfortable. A trusted adult or helper can read along.'
              : 'If you like, follow the circle as it gently grows and shrinks. Breathe comfortably; there is no need to hold your breath.',
        ),
        const SizedBox(height: 28),
        ResponsiveColumns(
          minWidth: 300,
          children: [
            SurfaceCard(
              color: colors.primaryContainer,
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!_started)
                        FilledButton.icon(
                          onPressed: _startPace,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(_finished ? 'Start again' : 'Start pace'),
                        ),
                      if (_started)
                        OutlinedButton.icon(
                          onPressed: _pausePace,
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause pace'),
                        ),
                      if (_hasStarted && !_finished)
                        OutlinedButton(
                          onPressed: _finish,
                          child: const Text('Done for now'),
                        ),
                      TextButton(onPressed: _stop, child: const Text('Stop')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.primary.withValues(alpha: .16),
                          ),
                        ),
                        child: Center(
                          child: _paceCircle(colors, reducedMotion),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _started
                          ? (_inhale
                                ? 'Breathe in gently'
                                : 'Breathe out gently')
                          : 'Your pace',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: Icons.air, color: colors.primaryContainer),
                  const SizedBox(height: 22),
                  Text(
                    simple
                        ? 'Go at your own pace'
                        : 'Make room for a quiet moment',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    simple
                        ? 'The circle is a guide. You do not have to match it.'
                        : 'Let the circle offer a gentle guide. You can follow your own rhythm whenever that feels more comfortable.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  Text(
                    simple ? 'Pause, stop, or ask for help whenever you want.' : 'Pause whenever you need. Stop or open Help now at any point.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_finished) ...[
          const SizedBox(height: 20),
          ToolFeedbackPrompt(
            key: ValueKey(_attempt),
            controller: widget.controller,
            tool: SupportTool.breathing,
            safetySession: widget.safetySession,
          ),
        ],
      ],
    );
  }

  Widget _paceCircle(ColorScheme colors, bool reducedMotion) {
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      color: colors.primary.withValues(alpha: .18),
      border: Border.all(color: colors.primary.withValues(alpha: .28)),
    );
    final center = Center(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
    if (reducedMotion) {
      return Container(
        width: 150,
        height: 150,
        decoration: decoration,
        child: center,
      );
    }
    final diameter = _started && _inhale ? 184.0 : 116.0;
    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      width: diameter,
      height: diameter,
      decoration: decoration,
      child: center,
    );
  }
}
