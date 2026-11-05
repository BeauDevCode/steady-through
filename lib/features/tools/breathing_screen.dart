import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/model/app_data.dart';

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key, required this.controller, this.onOpenHelp});

  final AppController controller;
  final VoidCallback? onOpenHelp;

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> {
  Timer? _paceTimer;
  bool _started = false;
  bool _inhale = true;

  void _startPace() {
    _paceTimer?.cancel();
    setState(() {
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
    _paceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simple = widget.controller.data.readingStyle == ReadingStyle.simple;
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
              const SizedBox(height: 20),
              Text(
                'Breathing pace',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                simple
                    ? 'Breathe in and out in a way that feels comfortable. A trusted adult or helper can read along.'
                    : 'If you like, follow the circle as it gently grows and shrinks. Breathe comfortably; there is no need to hold your breath.',
              ),
              const SizedBox(height: 28),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(seconds: 3),
                      curve: Curves.easeInOut,
                      width: _started && _inhale ? 164 : 112,
                      height: _started && _inhale ? 164 : 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Center(
                        child: Text(
                          _started
                              ? (_inhale
                                    ? 'Breathe in gently'
                                    : 'Breathe out gently')
                              : 'Your pace',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!_started)
                    FilledButton(
                      onPressed: _startPace,
                      child: const Text('Start pace'),
                    ),
                  if (_started)
                    OutlinedButton(
                      onPressed: _pausePace,
                      child: const Text('Pause pace'),
                    ),
                  TextButton(onPressed: _stop, child: const Text('Stop')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
