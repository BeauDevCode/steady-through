import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/data_portability.dart';
import 'package:steady_through/features/people/people_screen.dart';
import 'package:steady_through/model/app_data.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String? destination;

  @override
  Widget build(BuildContext context) {
    if (destination != null) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => destination = null),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to More'),
            ),
          ),
          Expanded(
            child: destination == 'people'
                ? PeopleScreen(controller: widget.controller)
                : SettingsScreen(controller: widget.controller),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('More', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Keep trusted people nearby and choose how the app works for you.',
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('People'),
          subtitle: const Text('Saved names and phone numbers'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => destination = 'people'),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          subtitle: const Text('Appearance, privacy, and data'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => destination = 'settings'),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller, this.portability});

  final AppController controller;
  final DataPortability? portability;

  DataPortability get _portability =>
      portability ?? DataPortability(controller);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Choose what feels easiest to read and use.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Theme'),
          subtitle: Text(_themeName(controller.data.theme)),
          leading: const Icon(Icons.palette_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _chooseTheme(context),
        ),
        ListTile(
          title: const Text('Reading style'),
          subtitle: Text(_readingName(controller.data.readingStyle)),
          leading: const Icon(Icons.text_fields),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _chooseReadingStyle(context),
        ),
        if (controller.data.readingStyle == ReadingStyle.simple)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Simple words are on. A trusted helper can read along with you.',
            ),
          ),
        const Divider(height: 32),
        Text('Your data', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'You choose where an exported JSON file is saved. Anyone with that file may be able to read it.',
        ),
        ListTile(
          title: const Text('Export data'),
          subtitle: const Text(
            'Save a copy of events, check-ins, people, game history, and settings',
          ),
          leading: const Icon(Icons.file_download_outlined),
          onTap: () => _export(context),
        ),
        ListTile(
          title: const Text('Import data'),
          subtitle: const Text(
            'Choose a JSON file; review before replacing current data',
          ),
          leading: const Icon(Icons.file_upload_outlined),
          onTap: () => _import(context),
        ),
        ListTile(
          title: const Text('Clear game history'),
          subtitle: Text('${controller.data.gameRounds.length} saved rounds'),
          leading: const Icon(Icons.restart_alt),
          onTap: controller.data.gameRounds.isEmpty
              ? null
              : () => _clearGameHistory(context),
        ),
        ListTile(
          title: const Text('Delete all data'),
          subtitle: const Text('Remove all local records and reset settings'),
          leading: const Icon(Icons.delete_forever_outlined),
          onTap: () => _deleteAll(context),
        ),
        const Divider(height: 32),
        Text(
          'Privacy and safety',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your entries are stored on this device, without an account or analytics. Exported files are outside app storage. Uninstalling the app can remove local data.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Steady Through offers general support and planning. It cannot diagnose, treat, or monitor a condition or danger. If you are in immediate physical danger, contact local emergency services.',
        ),
      ],
    ),
  );

  String _themeName(ThemeChoice choice) => switch (choice) {
    ThemeChoice.system => 'System',
    ThemeChoice.light => 'Light',
    ThemeChoice.dark => 'Dark',
  };

  String _readingName(ReadingStyle style) => switch (style) {
    ReadingStyle.standard => 'Standard',
    ReadingStyle.simple => 'Simple words',
  };

  Future<void> _chooseTheme(BuildContext context) async {
    final selected = await showDialog<ThemeChoice>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose theme'),
        children: [
          for (final choice in ThemeChoice.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, choice),
              child: Text(_themeName(choice)),
            ),
        ],
      ),
    );
    if (selected != null) {
      try {
        await controller.setTheme(selected);
      } catch (_) {
        if (context.mounted) {
          _message(context, 'Could not save your theme. Please try again.');
        }
      }
    }
  }

  Future<void> _chooseReadingStyle(BuildContext context) async {
    final selected = await showDialog<ReadingStyle>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose reading style'),
        children: [
          for (final style in ReadingStyle.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, style),
              child: Text(_readingName(style)),
            ),
        ],
      ),
    );
    if (selected != null) {
      try {
        await controller.setReadingStyle(selected);
      } catch (_) {
        if (context.mounted) {
          _message(
            context,
            'Could not save your reading style. Please try again.',
          );
        }
      }
    }
  }

  Future<void> _export(BuildContext context) async {
    try {
      final savedAt = await _portability.exportData();
      if (context.mounted) {
        _message(
          context,
          savedAt == null
              ? 'Export cancelled.'
              : 'Data saved to the chosen file.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _message(context, 'Could not export data. Please try again.');
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final imported = await _portability.importData(
        confirm: (replacement) async {
          if (!context.mounted) return false;
          return await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Replace all local data?'),
                  content: Text(
                    'This file has ${replacement.events.length} events, '
                    '${replacement.people.length} people, and '
                    '${replacement.checkIns.length} check-ins. '
                    'Importing it will replace everything currently saved on this device.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Keep current data'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Replace all data'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
      );
      if (context.mounted && imported) {
        _message(context, 'Data imported.');
      }
    } on FormatException {
      if (context.mounted) {
        _message(
          context,
          'Could not import this file. Your current data was kept.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _message(
          context,
          'Could not read this file. Your current data was kept.',
        );
      }
    }
  }

  Future<void> _clearGameHistory(BuildContext context) async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear game history?'),
        content: const Text(
          'Saved round summaries will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep history'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (clear == true) {
      try {
        await controller.clearGameRounds();
      } catch (_) {
        if (context.mounted) {
          _message(context, 'Could not clear game history. Please try again.');
        }
      }
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'All events, actions, check-ins, people, game history, and preferences on this device will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep data'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (delete == true) {
      try {
        await controller.clearAll();
      } catch (_) {
        if (context.mounted) {
          _message(
            context,
            'Deletion could not be fully verified. Some local data may remain. Please try again.',
          );
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
