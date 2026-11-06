import 'package:flutter/material.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/event_guidance.dart';
import 'package:steady_through/ui/steady_ui.dart';

const _stageLabels = <JourneyStage, String>{
  JourneyStage.orient: 'Get oriented',
  JourneyStage.settle: 'Settle',
  JourneyStage.support: 'Find support',
  JourneyStage.plan: 'Make a plan',
  JourneyStage.reflect: 'Reflect',
};

Future<GuidanceContext?> showGuidancePicker(
  BuildContext context, {
  required GuidanceContext selected,
  required bool simpleWords,
}) => showDialog<GuidanceContext>(
  context: context,
  builder: (_) => _GuidancePicker(selected: selected, simpleWords: simpleWords),
);

Future<List<String>?> showStarterStepsPicker(
  BuildContext context, {
  required GuidanceContext guidanceContext,
  required bool simpleWords,
  required List<String> selectedIds,
  List<PlanAction> existingActions = const [],
}) => showDialog<List<String>>(
  context: context,
  builder: (_) => StarterStepsPickerDialog(
    guidanceContext: guidanceContext,
    simpleWords: simpleWords,
    selectedIds: selectedIds,
    existingActions: existingActions,
  ),
);

class _GuidancePicker extends StatefulWidget {
  const _GuidancePicker({required this.selected, required this.simpleWords});
  final GuidanceContext selected;
  final bool simpleWords;
  @override
  State<_GuidancePicker> createState() => _GuidancePickerState();
}

class _GuidancePickerState extends State<_GuidancePicker> {
  late GuidanceContext _selected = widget.selected;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose a guide'),
    scrollable: true,
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.simpleWords
                ? 'Choose what fits this event. You can change it later.'
                : 'Choose ideas that fit this event. This is optional, and you can change it later.',
          ),
          const SizedBox(height: 12),
          RadioGroup<GuidanceContext>(
            groupValue: _selected,
            onChanged: (value) {
              if (value != null) setState(() => _selected = value);
            },
            child: Column(
              children: [
                for (final choice in GuidanceContext.values)
                  RadioListTile<GuidanceContext>(
                    value: choice,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      widget.simpleWords
                          ? guideFor(choice).simpleLabel
                          : guideFor(choice).label,
                    ),
                    subtitle: Text(
                      widget.simpleWords
                          ? guideFor(choice).simpleDescription
                          : guideFor(choice).description,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_selected),
        child: const Text('Use guide'),
      ),
    ],
  );
}

/// The same picker can save a Path batch before dismissing. A failed write
/// leaves its local selection and error visible so the person can retry.
class StarterStepsPickerDialog extends StatefulWidget {
  const StarterStepsPickerDialog({
    super.key,
    required this.guidanceContext,
    required this.simpleWords,
    required this.selectedIds,
    this.existingActions = const [],
    this.onSave,
  });
  final GuidanceContext guidanceContext;
  final bool simpleWords;
  final List<String> selectedIds;
  final List<PlanAction> existingActions;
  final Future<void> Function(List<String>)? onSave;
  @override
  State<StarterStepsPickerDialog> createState() =>
      _StarterStepsPickerDialogState();
}

class _StarterStepsPickerDialogState extends State<StarterStepsPickerDialog> {
  late final _guide = guideFor(widget.guidanceContext);
  late final Set<String> _existing = {
    for (final step in _guide.starterSteps)
      if (widget.existingActions.any(step.matchesAction)) step.id,
  };
  late final Set<String> _selected = widget.selectedIds
      .where((id) => !_existing.contains(id))
      .toSet();
  bool _saving = false;
  String? _error;

  List<String> get _selectedStepIds => [
    for (final step in _guide.starterSteps)
      if (_selected.contains(step.id) && !_existing.contains(step.id)) step.id,
  ];

  Future<void> _save() async {
    if (_saving) return;
    final ids = _selectedStepIds;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave?.call(ids);
      if (mounted) Navigator.of(context).pop(ids);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The steps could not be saved. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedStepIds.length;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Choose starter steps'),
        scrollable: true,
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.simpleWords
                    ? 'Pick any steps you want. You can pick none or add your own later.'
                    : 'Choose any ideas that fit. Choosing none is fine; you can add your own steps later.',
              ),
              const SizedBox(height: 12),
              for (final step in _guide.starterSteps)
                CheckboxListTile(
                  value: _selected.contains(step.id),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(step.text(simpleWords: widget.simpleWords)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_stageLabels[step.stage]!),
                      if (_existing.contains(step.id))
                        const Text('Already in your path'),
                    ],
                  ),
                  onChanged: _saving || _existing.contains(step.id)
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _selected.add(step.id);
                          } else {
                            _selected.remove(step.id);
                          }
                        }),
                ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  '$selectedCount ${selectedCount == 1 ? 'step' : 'steps'} selected',
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Use selected steps'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact context panel shared by creation and the saved Path. Its copy is
/// bundled, and changing a guide never changes the person's saved actions.
class GuidanceCard extends StatelessWidget {
  const GuidanceCard({
    super.key,
    required this.guidanceContext,
    required this.simpleWords,
    this.onChooseGuide,
    this.onChooseSteps,
    this.selectionNote,
  });
  final GuidanceContext guidanceContext;
  final bool simpleWords;
  final VoidCallback? onChooseGuide;
  final VoidCallback? onChooseSteps;
  final String? selectionNote;

  @override
  Widget build(BuildContext context) {
    final guide = guideFor(guidanceContext);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final card = SurfaceCard(
      padding: const EdgeInsets.all(16),
      color: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: Icons.explore_outlined,
                size: 34,
                color: colors.primaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your guide',
                      style: text.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      simpleWords ? guide.simpleLabel : guide.label,
                      style: text.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(simpleWords ? guide.simpleDescription : guide.description),
          const SizedBox(height: 6),
          Text(
            simpleWords ? guide.simpleHelperNote : guide.helperNote,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (selectionNote != null) ...[
            const SizedBox(height: 8),
            Text(selectionNote!, style: text.labelLarge),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (onChooseGuide != null)
                TextButton(
                  onPressed: onChooseGuide,
                  child: const Text('Choose guide'),
                ),
              if (onChooseSteps != null)
                TextButton.icon(
                  onPressed: onChooseSteps,
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: const Text('Choose starter steps'),
                ),
            ],
          ),
        ],
      ),
    );
    // A zero-duration AnimatedSize can notify its layout listener from inside
    // performLayout when this card changes size (for example, while saving).
    if (MediaQuery.disableAnimationsOf(context)) return card;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      curve: Curves.easeOutCubic,
      child: card,
    );
  }
}
