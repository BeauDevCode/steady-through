import 'package:flutter/material.dart';
import 'package:steady_through/model/app_data.dart';

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
  final Future<void> Function(String title, String description) onSave;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.event?.description ?? '',
    );
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
      await widget.onSave(_titleController.text, _descriptionController.text);
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit event' : 'Create event')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
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
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Event title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Give this event a title.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Optional description',
                        border: OutlineInputBorder(),
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
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save event'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
