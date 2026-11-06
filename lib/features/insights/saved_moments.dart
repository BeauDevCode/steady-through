import 'package:flutter/material.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/learning/learning_summary.dart';
import 'package:steady_through/ui/steady_ui.dart';

import 'moment_dialogs.dart';
import 'moment_display.dart';

class SavedMomentsCard extends StatefulWidget {
  const SavedMomentsCard({
    super.key,
    required this.session,
    required this.disabled,
    required this.onChanged,
    this.onOpenHelp,
  });
  final LearningSession session;
  final bool disabled;
  final VoidCallback onChanged;
  final VoidCallback? onOpenHelp;
  @override
  State<SavedMomentsCard> createState() => _SavedMomentsCardState();
}

class _SavedMomentsCardState extends State<SavedMomentsCard> {
  String? _feedback;

  Future<void> _change(
    BuildContext context,
    LearningExample moment,
    bool deleting,
  ) async {
    final changed = await changeSavedMoment(
      context,
      widget.session,
      moment,
      deleting: deleting,
    );
    if (changed == true && mounted) {
      widget.onChanged();
      setState(
        () => _feedback =
            '${deleting ? 'Deleted ${feelingName(moment.label)}' : 'Updated the feeling'} from ${momentTime(context, moment.createdAt)}. ${widget.session.controller.cleanupWarning ?? ''}'
                .trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      if (widget.session.insight.isVehicleContext) {
        return const SizedBox.shrink();
      }
      final summary = LearningSummary.fromData(widget.session.data);
      final colors = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Your saved moments',
            subtitle:
                'Feelings you chose. A little history, always yours to change.',
            action: summary.moments.length > 3
                ? OutlinedButton.icon(
                    onPressed: widget.disabled
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => _SavedMomentsPage(
                                session: widget.session,
                                onChanged: widget.onChanged,
                                onOpenHelp: widget.onOpenHelp,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.history_rounded),
                    label: Text('View all ${summary.moments.length}'),
                  )
                : null,
          ),
          const SizedBox(height: 20),
          SurfaceCard(
            color: colors.secondaryContainer.withValues(alpha: .45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('In your own words'),
                const SizedBox(height: 10),
                Text(
                  summary.recentCount == 0
                      ? 'A place to look back'
                      : '${summary.recentCount} ${summary.recentCount == 1 ? 'moment' : 'moments'} in the past 7 days',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (summary.recentCount == 0)
                  const Text(
                    'Your saved feelings will appear here. There is no schedule to keep and nothing to catch up on.',
                  )
                else ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      for (final label in FeelingLabel.values)
                        if (summary.recentCounts.containsKey(label))
                          Text(
                            '${feelingName(label)} ${summary.recentCounts[label]}',
                          ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A summary of your self-reports, not a prediction of how you feel now.',
                  ),
                ],
              ],
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_feedback!)),
          ],
          if (summary.moments.isNotEmpty) ...[
            const SizedBox(height: 16),
            ResponsiveColumns(
              minWidth: 300,
              children: [
                for (final moment in summary.moments.take(3))
                  _MomentTile(
                    moment: moment,
                    enabled: !widget.disabled,
                    onEdit: () => _change(context, moment, false),
                    onDelete: () => _change(context, moment, true),
                  ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

class _MomentTile extends StatelessWidget {
  const _MomentTile({
    required this.moment,
    required this.onEdit,
    required this.onDelete,
    this.enabled = true,
  });
  final LearningExample moment;
  final VoidCallback onEdit, onDelete;
  final bool enabled;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    key: ValueKey('moment-${moment.id}'),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconBadge(icon: feelingIcon(moment.label), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feelingName(moment.label),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(momentTime(context, moment.createdAt)),
        const SizedBox(height: 8),
        Text(
          momentContext(moment.snapshot),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: enabled
                  ? () => viewSavedMoment(context, moment)
                  : null,
              child: const Text('View moment'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: enabled ? onEdit : null,
              child: const Text('Edit feeling'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: enabled ? onDelete : null,
              child: const Text('Delete'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SavedMomentsPage extends StatefulWidget {
  const _SavedMomentsPage({
    required this.session,
    required this.onChanged,
    this.onOpenHelp,
  });
  final LearningSession session;
  final VoidCallback onChanged;
  final VoidCallback? onOpenHelp;
  @override
  State<_SavedMomentsPage> createState() => _SavedMomentsPageState();
}

class _SavedMomentsPageState extends State<_SavedMomentsPage> {
  String? _feedback;
  Future<void> _change(LearningExample moment, bool deleting) async {
    final changed = await changeSavedMoment(
      context,
      widget.session,
      moment,
      deleting: deleting,
    );
    if (changed == true && mounted) {
      widget.onChanged();
      setState(
        () => _feedback =
            '${deleting ? 'Deleted ${feelingName(moment.label)}' : 'Updated the feeling'} from ${momentTime(context, moment.createdAt)}. ${widget.session.controller.cleanupWarning ?? ''}'
                .trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final vehicle = widget.session.insight.isVehicleContext;
      final moments = LearningSummary.fromData(widget.session.data).moments;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saved moments'),
          actions: [
            if (widget.onOpenHelp != null)
              TextButton(
                onPressed: widget.onOpenHelp,
                child: const Text('Help now'),
              ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: vehicle
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Return when safely stopped to manage saved moments.',
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(20),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${moments.length} saved ${moments.length == 1 ? 'moment' : 'moments'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Your chosen feelings, newest first. Times are shown in your local time. History stays available with sources off.',
                                ),
                                if (_feedback != null) ...[
                                  const SizedBox(height: 12),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(_feedback!),
                                  ),
                                ],
                                if (moments.isEmpty) ...[
                                  const SizedBox(height: 24),
                                  const Text(
                                    'No saved moments. Your next chosen feeling can start a new history.',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          sliver: SliverList.builder(
                            itemCount: moments.length,
                            itemBuilder: (context, index) {
                              final moment = moments[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MomentTile(
                                  moment: moment,
                                  onEdit: () => _change(moment, false),
                                  onDelete: () => _change(moment, true),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}
