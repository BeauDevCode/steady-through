import 'package:flutter/material.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/learning/pattern_engine.dart';
import 'package:steady_through/ui/steady_ui.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({
    super.key,
    required this.session,
    this.onGrounding,
    this.onOpenPath,
    this.onOpenHelp,
  });

  final LearningSession session;
  final VoidCallback? onGrounding;
  final VoidCallback? onOpenPath;
  final VoidCallback? onOpenHelp;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _working = false;
  FeelingLabel? _selectedFeeling;
  String? _feedback;
  bool _feedbackIsError = false;
  CalibrationReport? _lastReview;

  LearningSession get session => widget.session;

  @override
  void didUpdateWidget(covariant InsightsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _selectedFeeling = null;
      _feedback = null;
      _lastReview = null;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final insight = session.insight;
      final animate = !MediaQuery.disableAnimationsOf(context);
      return SteadyPage(
        children: [
          GentleReveal(
            child: SectionHeading(
              title: 'A little space to notice',
              subtitle: 'Your patterns, in your own words. Choose what to share with your private learning space.',
              action: OutlinedButton.icon(
                onPressed: _working ? null : _togglePause,
                icon: Icon(
                  session.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
                label: Text(
                  session.paused ? 'Resume learning' : 'Pause learning',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSize(
            duration: animate
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            alignment: Alignment.topCenter,
            child: insight.isVehicleContext
                ? _reflection(context, insight)
                : AnimatedSwitcher(
                    duration: animate
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                    child: _reflection(context, insight),
                  ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 16),
            _notice(
              context,
              _feedback!,
              icon: _feedbackIsError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              isError: _feedbackIsError,
            ),
          ],
          if (session.sourceError != null) ...[
            const SizedBox(height: 16),
            _notice(
              context,
              session.sourceError!,
              icon: Icons.sensors_off_rounded,
              isError: true,
            ),
          ],
          const SizedBox(height: 32),
          const SectionHeading(
            title: 'You choose the sources',
            subtitle: 'Every source starts off. Turn on only what feels useful; turn it off whenever you want.',
          ),
          const SizedBox(height: 20),
          ResponsiveColumns(
            minWidth: 340,
            children: [
              for (final source in SignalSource.values)
                _sourceCard(context, source),
            ],
          ),
          const SizedBox(height: 20),
          _notice(
            context,
            'Free to use. Planning, tools, people and help stay available with every source off. Saved learning stays in your encrypted local vault.',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 32),
          SectionHeading(
            title: 'A glimpse of this session',
            subtitle: 'Aggregate counts and minutes only. Missing or denied readings appear as unavailable.',
            action: TextButton.icon(
              onPressed: _working || session.paused
                  ? null
                  : () => _run(
                      session.refresh,
                      error: 'Could not refresh device readings. You can keep using the rest of the app.',
                    ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh readings'),
            ),
          ),
          const SizedBox(height: 20),
          _aggregateTiles(context),
          if (session.capabilities.platformNote.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              session.capabilities.platformNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 32),
          _calibrationCard(context),
          const SizedBox(height: 24),
          SurfaceCard(
            color: colors.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('A fresh start, when you choose'),
                const SizedBox(height: 10),
                Text(
                  'Clear your learning',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Remove learning examples, personal calibration and source choices. Your events, people, check-ins and game history stay available.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _working ? null : _clearLearning,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Clear learning'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _reflection(BuildContext context, PatternInsight insight) {
    final colors = Theme.of(context).colorScheme;
    final vehicle = insight.isVehicleContext;
    final canLabel =
        !session.paused && session.data.enabledSources.isNotEmpty && !_working;
    final title = session.paused && !vehicle
        ? 'Learning is paused'
        : switch (insight.status) {
            PatternStatus.insufficientEvidence => 'Not enough evidence yet',
            PatternStatus.uncertain => 'There is no clear match yet',
            PatternStatus.tentativeMatch =>
              'A tentative match: ${_feeling(insight.label!)}',
            PatternStatus.selfReportedTrend => 'Your self-reported trend',
            PatternStatus.possibleVehicle => 'Return when safely stopped',
          };
    return SurfaceCard(
      key: ValueKey('${insight.status.name}-${session.paused}'),
      color: vehicle ? colors.secondaryContainer : colors.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: vehicle
                    ? Icons.directions_car_outlined
                    : Icons.spa_outlined,
                color: colors.surface.withValues(alpha: .75),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Eyebrow(vehicle ? 'A gentle pause' : 'Your reflection'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(insight.evidence, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text(
            insight.suggestion,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (!vehicle) ...[
            const SizedBox(height: 12),
            const Text(
              'This is a personal reflection, not a diagnosis. Only you can say what fits.',
            ),
            const SizedBox(height: 24),
            Text(
              'How do you feel right now?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              session.paused
                  ? 'Resume when you want to save a feeling.'
                  : session.data.enabledSources.isEmpty
                  ? 'Choose Feeling check-ins below to begin with just your own words. No device permission is needed.'
                  : 'Choose a feeling to save one example. A different choice adds your correction as a new example.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final label in FeelingLabel.values)
                  _feelingButton(context, label, enabled: canLabel),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onGrounding != null)
                  TextButton.icon(
                    onPressed: widget.onGrounding,
                    icon: const Icon(Icons.self_improvement_outlined),
                    label: const Text('Try grounding'),
                  ),
                if (widget.onOpenPath != null)
                  TextButton.icon(
                    onPressed: widget.onOpenPath,
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Open the path'),
                  ),
                if (widget.onOpenHelp != null)
                  TextButton.icon(
                    onPressed: widget.onOpenHelp,
                    icon: const Icon(Icons.favorite_border_rounded),
                    label: const Text('Get help'),
                  ),
              ],
            ),
          ] else if (widget.onOpenHelp != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: widget.onOpenHelp,
              icon: const Icon(Icons.favorite_border_rounded),
              label: const Text('Get help'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feelingButton(
    BuildContext context,
    FeelingLabel label, {
    required bool enabled,
  }) {
    final selected = _selectedFeeling == label;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: OutlinedButton.icon(
        onPressed: enabled ? () => _saveFeeling(label) : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? colors.surface
              : colors.surface.withValues(alpha: .45),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        icon: Icon(
          selected ? Icons.check_rounded : _feelingIcon(label),
          size: 20,
        ),
        label: Text(_feeling(label)),
      ),
    );
  }

  Widget _sourceCard(BuildContext context, SignalSource source) {
    final colors = Theme.of(context).colorScheme;
    final enabled = session.data.enabledSources.contains(source);
    final supported = switch (source) {
      SignalSource.deviceUsage => session.capabilities.usageSupported,
      SignalSource.motion => session.capabilities.motionSupported,
      _ => true,
    };
    final granted = switch (source) {
      SignalSource.deviceUsage => session.capabilities.usageGranted,
      SignalSource.motion => session.capabilities.motionGranted,
      _ => true,
    };
    final status = !supported
        ? 'Unavailable on this device'
        : !enabled
        ? 'Off · your choice'
        : session.paused
        ? 'Paused'
        : !granted
        ? 'Needs your permission'
        : switch (source) {
            SignalSource.deviceUsage => _status(session.reading.usageStatus),
            SignalSource.motion => _status(session.reading.motionStatus),
            SignalSource.checkIns => 'Ready for your chosen labels',
            SignalSource.inApp => 'Counting this app session',
          };
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      color: enabled ? colors.surface : colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: _sourceIcon(source),
                color: source == SignalSource.motion
                    ? colors.secondaryContainer
                    : colors.primaryContainer,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: ValueKey('source-${source.name}'),
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: _working || (!supported && !enabled)
                ? null
                : (value) => _setSource(source, value),
            title: Text(
              _sourceName(source),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_sourceScope(source)),
            ),
          ),
          if (source == SignalSource.deviceUsage &&
              supported &&
              enabled &&
              !granted) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _working
                  ? null
                  : () => _run(
                      session.requestUsageAccess,
                      success: 'Choose usage access in system settings, then return and refresh readings. Other app features remain available.',
                      error: 'Could not open usage access settings. You can leave this source off.',
                    ),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open usage access settings'),
            ),
          ],
          if (source == SignalSource.motion &&
              supported &&
              enabled &&
              !granted) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _working ? null : _requestMotion,
              icon: const Icon(Icons.accessibility_new_rounded),
              label: const Text('Allow motion access'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aggregateTiles(BuildContext context) {
    final snapshot = session.snapshot;
    final features = snapshot.features;
    final usage =
        session.data.enabledSources.contains(SignalSource.deviceUsage) &&
        !session.paused;
    final motion =
        session.data.enabledSources.contains(SignalSource.motion) &&
        !session.paused;
    final inApp =
        session.data.enabledSources.contains(SignalSource.inApp) &&
        !session.paused;
    return ResponsiveColumns(
      minWidth: 200,
      children: [
        _metric(
          context,
          'App activations',
          usage ? session.reading.deviceSwitches?.toString() : null,
          Icons.swap_horiz_rounded,
          'Supported device usage window',
        ),
        _metric(
          context,
          'Active minutes',
          usage ? _minutes(session.reading.activeMinutes) : null,
          Icons.timer_outlined,
          'Session or last-hour estimate',
        ),
        _metric(
          context,
          'Walking minutes',
          motion ? _minutes(session.reading.walkingMinutes) : null,
          Icons.directions_walk_rounded,
          'Uncertain motion summary',
        ),
        _metric(
          context,
          'Vehicle minutes',
          motion ? _minutes(session.reading.vehicleMinutes) : null,
          Icons.directions_car_outlined,
          'May include passengers',
        ),
        _metric(
          context,
          'In-app taps',
          inApp ? features['tapCount']?.toInt().toString() : null,
          Icons.touch_app_outlined,
          'Count only; no touch locations',
        ),
        _metric(
          context,
          'Navigation changes',
          inApp ? features['navigationChanges']?.toInt().toString() : null,
          Icons.alt_route_rounded,
          'Within Steady Through only',
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context,
    String title,
    String? value,
    IconData icon,
    String detail,
  ) => SurfaceCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          value ?? 'Unavailable',
          style: value == null
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _calibrationCard(BuildContext context) {
    final data = session.data;
    final calibration = data.calibration;
    final since =
        calibration.lastReviewedAt ??
        calibration.startedAt ??
        data.firstExampleAt;
    final days = since == null
        ? 0
        : DateTime.now().toUtc().difference(since).inDays.clamp(0, 60);
    final report = _lastReview;
    final reviewedReason = report?.reason ?? calibration.lastReviewReason;
    return SurfaceCard(
      color: Theme.of(context).colorScheme.secondaryContainer
          .withValues(alpha: .5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Room to learn over time'),
          const SizedBox(height: 12),
          Text(
            'A thoughtful 60-day review',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Time alone does not make a pattern reliable. A local review compares earlier examples with later ones and a simple baseline. It adopts an update only when evidence and improvement checks pass.',
          ),
          const SizedBox(height: 20),
          Semantics(
            label: 'Calibration window',
            value: '$days of 60 days',
            child: LinearProgressIndicator(
              value: days / 60,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            since == null
                ? 'Your first saved feeling starts the review window.'
                : days >= 60
                ? 'The 60-day window is ready for an evidence check.'
                : 'Day $days of 60 in this review window',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text('${data.examples.length} saved examples'),
              Text('Personal model revision ${calibration.revision}'),
              if (calibration.lastAdoptedAt != null)
                Text('Last update ${_date(calibration.lastAdoptedAt!)}'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Personal comparisons need at least 20 labelled moments over 7 days, with at least 5 examples of two feelings and comparable readings. A manual-only source can show your self-reported trend.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Learning keeps at most 180 days or 1,000 examples, whichever limit is reached first.',
          ),
          if (reviewedReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              report?.adopted == true
                  ? 'A local update was adopted'
                  : 'Review evidence',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(reviewedReason),
            const SizedBox(height: 8),
            Text(
              '${report?.trainingCount ?? calibration.trainingCount} earlier examples · ${report?.heldOutCount ?? calibration.heldOutCount} later examples',
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _working ? null : _review,
            icon: const Icon(Icons.auto_graph_rounded),
            label: const Text('Review learning'),
          ),
        ],
      ),
    );
  }

  Widget _notice(
    BuildContext context,
    String text, {
    required IconData icon,
    bool isError = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: isError,
      child: SurfaceCard(
        padding: const EdgeInsets.all(18),
        color: isError ? colors.errorContainer : colors.surfaceContainerLow,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isError ? colors.onErrorContainer : colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isError ? colors.onErrorContainer : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String error,
    String? success,
  }) async {
    if (_working) return;
    setState(() {
      _working = true;
      _feedback = null;
    });
    try {
      await action();
      if (mounted && success != null) {
        setState(() {
          final warning = session.controller.cleanupWarning;
          _feedback = warning == null ? success : '$success $warning';
          _feedbackIsError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback = error;
          _feedbackIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _saveFeeling(FeelingLabel label) => _run(
    () async {
      await session.saveFeeling(label);
      if (mounted) setState(() => _selectedFeeling = label);
    },
    error: 'Could not save this feeling. Your saved learning is unchanged. Please try again when you are safely stopped.',
    success:
        'Saved ${_feeling(label)}. You can choose another feeling if that fits better.',
  );

  Future<void> _togglePause() => _run(
    session.paused ? session.resume : session.pause,
    error: 'Could not update learning. Please try again.',
  );

  Future<void> _setSource(SignalSource source, bool enabled) async {
    var ownerConfirmed = session.data.deviceOwnerConfirmed;
    if (enabled &&
        (source == SignalSource.deviceUsage || source == SignalSource.motion)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Your device, your choice'),
          content: SingleChildScrollView(
            child: Text(
              'Confirm that this is your device and you want to enable ${_sourceName(source).toLowerCase()}. ${_sourceScope(source)}\n\nOnly aggregate summaries are used during an unlocked app session. No app names, typed content, screenshots or GPS routes are stored. The system permission is a separate choice.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep off'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('This is my device'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      ownerConfirmed = true;
    }
    final sources = {...session.data.enabledSources};
    if (enabled) {
      sources.add(source);
    } else {
      sources.remove(source);
    }
    await _run(
      () => session.setSources(sources, deviceOwnerConfirmed: ownerConfirmed),
      error: 'Could not save this source choice. Your previous choices are unchanged. Please try again.',
    );
  }

  Future<void> _requestMotion() => _run(() async {
    final granted = await session.requestMotionAccess();
    if (mounted) {
      setState(() {
        _feedback = granted
            ? 'Motion access is allowed. Your source choice still controls collection.'
            : 'Motion access is off. You can keep using the rest of the app without it.';
        _feedbackIsError = false;
      });
    }
  }, error: 'Could not request motion access. You can leave this source off.');

  Future<void> _review() => _run(
    () async {
      final report = await session.review();
      if (mounted) setState(() => _lastReview = report);
    },
    error: 'Could not save the learning review. Your personal model is unchanged. Please try again.',
  );

  Future<void> _clearLearning() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear your learning?'),
        content: const Text(
          'This removes learning examples and personal calibration, and turns every learning source off. Your events, people, check-ins and game history stay available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep learning'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear learning'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () async {
        await session.clear();
        if (mounted) {
          setState(() {
            _selectedFeeling = null;
            _lastReview = null;
          });
        }
      },
      error: 'Learning cleanup could not be fully verified. Some saved copies may remain. Please try again.',
      success: 'Learning cleared. Every source is off; your other saved records remain available.',
    );
  }

  static String _feeling(FeelingLabel label) => switch (label) {
    FeelingLabel.calm => 'Calm',
    FeelingLabel.tense => 'Tense',
    FeelingLabel.low => 'Low',
    FeelingLabel.energized => 'Energized',
    FeelingLabel.unsure => 'Unsure',
  };

  static IconData _feelingIcon(FeelingLabel label) => switch (label) {
    FeelingLabel.calm => Icons.spa_outlined,
    FeelingLabel.tense => Icons.waves_rounded,
    FeelingLabel.low => Icons.cloud_outlined,
    FeelingLabel.energized => Icons.wb_sunny_outlined,
    FeelingLabel.unsure => Icons.help_outline_rounded,
  };

  static String _sourceName(SignalSource source) => switch (source) {
    SignalSource.checkIns => 'Feeling check-ins',
    SignalSource.inApp => 'In-app activity',
    SignalSource.deviceUsage => 'Device usage',
    SignalSource.motion => 'Motion context',
  };

  static IconData _sourceIcon(SignalSource source) => switch (source) {
    SignalSource.checkIns => Icons.edit_note_rounded,
    SignalSource.inApp => Icons.touch_app_outlined,
    SignalSource.deviceUsage => Icons.devices_rounded,
    SignalSource.motion => Icons.directions_walk_rounded,
  };

  static String _sourceScope(SignalSource source) => switch (source) {
    SignalSource.checkIns => 'Only the feeling labels you choose here. A simple way to begin without device access.',
    SignalSource.inApp => 'Counts of taps, navigation changes, backtracks and restarts inside Steady Through. No touch locations or typed content.',
    SignalSource.deviceUsage => 'Supported app-activation counts and active minutes. No app names, window titles or content are stored.',
    SignalSource.motion => 'Uncertain walking and possible vehicle minutes. No location, routes or driver identification.',
  };

  static String _status(String status) => switch (status) {
    'observing' => 'Observing aggregate readings',
    'session-only' => 'This session only',
    'last-hour' => 'Last 60 minutes',
    'permission-denied' => 'Permission is off',
    'awaiting-data' => 'Waiting for a supported reading',
    'paused' => 'Ready when this session resumes',
    _ => 'Reading unavailable',
  };

  static String? _minutes(double? value) => value?.toStringAsFixed(1);
  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
