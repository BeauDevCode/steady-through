import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_ui.dart';
import 'package:steady_through/ui/view_activity.dart';

import 'person_form_dialog.dart';
import 'phone_actions.dart';

class PersonCard extends StatefulWidget {
  const PersonCard({
    super.key,
    required this.controller,
    required this.person,
    this.phoneActions = const UrlLauncherPhoneActions(),
    this.showManagement = true,
  });
  final AppController controller;
  final TrustedPerson person;
  final PhoneActions phoneActions;
  final bool showManagement;
  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard> {
  final _activity = ViewActivity();
  bool _pending = false;

  bool _visible(int epoch) =>
      mounted &&
      _activity.accepts(epoch) &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  bool _current(TrustedPerson person, int revision, int epoch) =>
      _visible(epoch) &&
      widget.controller.replacementRevision == revision &&
      widget.controller.data.people.any(
        (current) => current.id == person.id && identical(current, person),
      );

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Semantics(liveRegion: true, child: Text(message))),
    );
  }

  Future<void> _handoff({
    Future<bool> Function(String)? open,
    String? kind,
  }) async {
    if (_pending || !_activity.active) return;
    final person = widget.person;
    final revision = widget.controller.replacementRevision;
    final epoch = _activity.epoch;
    final number = person.phone?.trim() ?? '';
    if (number.isEmpty || !_current(person, revision, epoch)) return;
    setState(() => _pending = true);
    try {
      // Recheck immediately before crossing the external OS boundary.
      if (!_current(person, revision, epoch)) return;
      if (open == null) {
        await Clipboard.setData(ClipboardData(text: number));
        if (_current(person, revision, epoch)) _message('Number copied.');
      } else {
        final opened = await open(number);
        if (!opened && _current(person, revision, epoch)) {
          _message(
            'Could not open a $kind app. You can copy the visible number.',
          );
        }
      }
    } catch (_) {
      if (_current(person, revision, epoch)) {
        _message(
          open == null
              ? 'Could not copy the number. You can read the visible number instead.'
              : 'Could not open a $kind app. You can copy the visible number.',
        );
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  void dispose() {
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final phone = person.phone?.trim() ?? '';
    final colors = Theme.of(context).colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const IconBadge(icon: Icons.person_outline, size: 44),
              if (widget.showManagement) ...[
                IconButton(
                  tooltip: 'Edit ${person.name}',
                  icon: const Icon(Icons.edit_outlined),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => showPersonForm(
                    context,
                    widget.controller,
                    person: person,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${person.name}',
                  icon: const Icon(Icons.delete_outline),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _RemovePersonDialog(
                      controller: widget.controller,
                      person: person,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(person.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            phone.isEmpty ? 'No phone number saved' : phone,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tooltip(
                  message: 'Call ${person.name}',
                  child: OutlinedButton.icon(
                    onPressed: _pending
                        ? null
                        : () => _handoff(
                            open: widget.phoneActions.openPhone,
                            kind: 'phone',
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                Tooltip(
                  message: 'Text ${person.name}',
                  child: OutlinedButton.icon(
                    onPressed: _pending
                        ? null
                        : () => _handoff(
                            open: widget.phoneActions.openSms,
                            kind: 'text',
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.sms_outlined, size: 18),
                    label: const Text('Text'),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy ${person.name}’s number',
                  icon: const Icon(Icons.copy_outlined),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _pending ? null : () => _handoff(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RemovePersonDialog extends StatefulWidget {
  const _RemovePersonDialog({required this.controller, required this.person});
  final AppController controller;
  final TrustedPerson person;
  @override
  State<_RemovePersonDialog> createState() => _RemovePersonDialogState();
}

class _RemovePersonDialogState extends State<_RemovePersonDialog> {
  final _activity = ViewActivity();
  late final int _revision;
  bool _closed = false, _busy = false, _invalidated = false;
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

  bool _valid(int epoch) =>
      mounted &&
      !_closed &&
      !_invalidated &&
      _activity.accepts(epoch) &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  void _cancel() {
    _closed = true;
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    if (_busy || _closed || _invalidated || !_activity.active) return;
    final epoch = _activity.epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.deletePerson(
        widget.person.id,
        expected: widget.person,
        expectedRevision: _revision,
        isActive: () => _valid(epoch),
      );
      if (_valid(epoch)) _cancel();
    } catch (_) {
      if (_valid(epoch)) {
        setState(
          () => _error = 'Could not remove this person. Please try again, or close this view and review your saved people.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _closed = true;
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _closed = true;
    },
    child: AlertDialog(
      scrollable: true,
      title: const Text('Remove person?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Remove ${widget.person.name} from your saved people?'),
          const SizedBox(height: 12),
          const Text('Copies you exported separately remain outside this app.'),
          if (_invalidated)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'This view paused. Close it and review your saved people before continuing.',
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Keep person'),
        ),
        FilledButton(
          onPressed: _busy || _invalidated || !_activity.active
              ? null
              : _remove,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Remove person'),
        ),
      ],
    ),
  );
}
