import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class PhoneActions {
  Future<bool> openPhone(String number);
  Future<bool> openSms(String number);
}

class UrlLauncherPhoneActions implements PhoneActions {
  const UrlLauncherPhoneActions();

  Future<bool> _open(String scheme, String number) async {
    try {
      final uri = Uri(scheme: scheme, path: number);
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openPhone(String number) => _open('tel', number);

  @override
  Future<bool> openSms(String number) => _open('sms', number);
}

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({
    super.key,
    required this.controller,
    this.phoneActions = const UrlLauncherPhoneActions(),
  });

  final AppController controller;
  final PhoneActions phoneActions;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final people = controller.data.people;
      final simple = controller.data.readingStyle == ReadingStyle.simple;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('People', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            simple
                ? 'Save people you trust. Their numbers stay on this device.'
                : 'Keep the names and phone numbers of people you trust. Numbers are entered by you and stay on this device.',
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _addPerson(context),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add person'),
            ),
          ),
          const SizedBox(height: 16),
          if (people.isEmpty)
            const Text(
              'No people saved yet. Add someone you would feel comfortable contacting.',
            ),
          for (final person in people) _personCard(context, person),
        ],
      );
    },
  );

  Widget _personCard(BuildContext context, TrustedPerson person) {
    final phone = person.phone?.trim() ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(person.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(phone.isEmpty ? 'No phone number saved' : phone),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (phone.isNotEmpty) ...[
                  IconButton(
                    tooltip: 'Call ${person.name}',
                    icon: const Icon(Icons.call_outlined),
                    onPressed: () =>
                        _open(context, phone, phoneActions.openPhone, 'phone'),
                  ),
                  IconButton(
                    tooltip: 'Text ${person.name}',
                    icon: const Icon(Icons.sms_outlined),
                    onPressed: () =>
                        _open(context, phone, phoneActions.openSms, 'text'),
                  ),
                  IconButton(
                    tooltip: 'Copy ${person.name}’s number',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: phone));
                      if (context.mounted) _message(context, 'Number copied.');
                    },
                  ),
                ],
                IconButton(
                  tooltip: 'Remove ${person.name}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removePerson(context, person),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    String phone,
    Future<bool> Function(String) open,
    String kind,
  ) async {
    final opened = await open(phone);
    if (!context.mounted || opened) return;
    _message(
      context,
      'Could not open a $kind app. You can copy the visible number.',
    );
  }

  Future<void> _addPerson(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var name = '';
    var phone = '';
    var saving = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add person'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Name'),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) => name = value,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a name.'
                        : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Phone number (optional)',
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) => phone = value,
                  ),
                  if (saveError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      saveError!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        saveError = null;
                      });
                      try {
                        await controller.addPerson(name, phone);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            saveError =
                                'Could not save this person. Please try again.';
                          });
                        }
                      }
                    },
              child: const Text('Save person'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePerson(BuildContext context, TrustedPerson person) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove person?'),
        content: Text('Remove ${person.name} from your saved people?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep person'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove person'),
          ),
        ],
      ),
    );
    if (remove == true) {
      try {
        await controller.deletePerson(person.id);
      } catch (_) {
        if (context.mounted) {
          _message(context, 'Could not remove this person. Please try again.');
        }
      }
    }
  }

  void _message(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
