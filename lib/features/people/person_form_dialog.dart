import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/view_activity.dart';

Future<void> showPersonForm(
  BuildContext context,
  AppController controller, {
  TrustedPerson? person,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => PersonFormDialog(controller: controller, person: person),
);

class PersonFormDialog extends StatefulWidget {
  const PersonFormDialog({super.key, required this.controller, this.person});
  final AppController controller;
  final TrustedPerson? person;
  @override
  State<PersonFormDialog> createState() => _PersonFormDialogState();
}

class _PersonFormDialogState extends State<PersonFormDialog> {
  final _form = GlobalKey<FormState>();
  final _activity = ViewActivity();
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late final _phone = TextEditingController(text: widget.person?.phone ?? '');
  late final int _revision;
  bool _saving = false;
  bool _closed = false;
  bool _invalidated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _revision = widget.controller.replacementRevision;
    _activity.addListener(_paused);
  }

  void _paused() {
    if (mounted) setState(() => _invalidated = true);
  }

  bool _visible(int epoch) =>
      mounted &&
      !_closed &&
      !_invalidated &&
      _activity.accepts(epoch) &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  void _cancel() {
    _closed = true;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_saving || _invalidated || !_activity.active || _closed) return;
    if (!_form.currentState!.validate()) return;
    final epoch = _activity.epoch;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final person = widget.person;
      if (person == null) {
        await widget.controller.addPerson(
          _name.text,
          _phone.text,
          expectedRevision: _revision,
          isActive: () => _visible(epoch),
        );
      } else {
        await widget.controller.updatePerson(
          person.id,
          _name.text,
          _phone.text,
          expected: person,
          expectedRevision: _revision,
          isActive: () => _visible(epoch),
        );
      }
      if (mounted && _visible(epoch)) {
        _closed = true;
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (_visible(epoch)) {
        setState(
          () => _error = 'Could not save this person. Please try again, or close this view and review your saved people.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _closed = true;
    _activity.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _closed = true;
    },
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.person == null ? 'Add person' : 'Edit person'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                readOnly: _saving,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: ExcludeSemantics(child: Text('Phone number (optional)')),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Phone number (optional)',
                child: TextFormField(
                  key: const ValueKey('person-phone-field'),
                  controller: _phone,
                  readOnly: _saving,
                  decoration: const InputDecoration(),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
              ),
              if (_invalidated)
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'This view paused. Close it and reopen your saved person before saving.',
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _invalidated || !_activity.active
              ? null
              : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Save person'),
        ),
      ],
    ),
  );
}
