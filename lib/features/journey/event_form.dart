import 'package:flutter/material.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/event_guidance.dart';
import 'package:steady_through/features/journey/guidance_picker.dart';
import 'package:steady_through/ui/steady_ui.dart';

@immutable
class EventFormSubmission {
  EventFormSubmission({
    required this.title,
    required this.description,
    required this.guidanceContext,
    required List<String>? starterStepIds,
  }) : starterStepIds = starterStepIds == null
           ? null
           : List<String>.unmodifiable(starterStepIds);

  final String title;
  final String description;
  final GuidanceContext guidanceContext;
  final List<String>? starterStepIds;
}

/// Creates or edits an event. Saving is owned by the caller so the same form
/// works with the app's durable controller and in widget tests.
class EventForm extends StatefulWidget {
  const EventForm({
    super.key,
    this.event,
    this.simpleWords = false,
    required this.onSave,
  });

  final SupportEvent? event;
  final bool simpleWords;
  final Future<void> Function(EventFormSubmission submission) onSave;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _saving = false;
  String? _saveError;
  late GuidanceContext _guidanceContext;
  late List<String> _starterStepIds;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.event?.description ?? '',
    );
    _guidanceContext = widget.event?.guidanceContext ?? GuidanceContext.general;
    _starterStepIds = guideFor(_guidanceContext).starterSteps
        .map((step) => step.id)
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(
        EventFormSubmission(
          title: _titleController.text,
          description: _descriptionController.text,
          guidanceContext: _guidanceContext,
          starterStepIds: widget.event == null ? _starterStepIds : null,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'The event could not be saved. Please try again.';
        });
      }
    }
  }

  Future<void> _chooseGuide() async {
    final selected = await showGuidancePicker(
      context,
      selected: _guidanceContext,
      simpleWords: widget.simpleWords,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (selected != _guidanceContext) {
        _guidanceContext = selected;
        _starterStepIds = guideFor(selected).starterSteps
            .map((step) => step.id)
            .toList();
      }
    });
  }

  Future<void> _chooseSteps() async {
    final selected = await showStarterStepsPicker(
      context,
      guidanceContext: _guidanceContext,
      simpleWords: widget.simpleWords,
      selectedIds: _starterStepIds,
    );
    if (selected != null && mounted) setState(() => _starterStepIds = selected);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit event' : 'Create event')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save event'),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SteadyPage(
          maxWidth: 760,
          children: [
            const Eyebrow('Your next chapter'),
            const SizedBox(height: 12),
            Text(
              isEditing
                  ? 'Make room for what changed.'
                  : 'Start where you are.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.simpleWords
                        ? 'Name what is happening. You can leave details blank.'
                        : 'Give this moment a name you will recognize later. You can keep the details private.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _titleController,
                    readOnly: _saving,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Event title',
                      hintText: 'A new school, a move, caring for someone…',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Give this event a title.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const ExcludeSemantics(child: Text('Optional description')),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Optional description',
                    child: TextFormField(
                      key: const ValueKey('event-description-field'),
                      controller: _descriptionController,
                      readOnly: _saving,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuidanceCard(
              guidanceContext: _guidanceContext,
              simpleWords: widget.simpleWords,
              onChooseGuide: _saving ? null : _chooseGuide,
              onChooseSteps: isEditing || _saving ? null : _chooseSteps,
              selectionNote: isEditing
                  ? 'Your saved steps stay as they are.'
                  : '${_starterStepIds.length} starter ${_starterStepIds.length == 1 ? 'step' : 'steps'} selected',
            ),
          ],
        ),
      ),
    );
  }
}
