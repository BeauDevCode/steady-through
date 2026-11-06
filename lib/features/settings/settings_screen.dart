import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/data_portability.dart';
import 'package:steady_through/features/people/people_screen.dart';
import 'package:steady_through/features/vault/passphrase_dialog.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/ui/steady_ui.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({
    super.key,
    required this.controller,
    this.onOpenInsights,
    this.onLock,
  });

  final AppController controller;
  final VoidCallback? onOpenInsights;
  final Future<void> Function()? onLock;

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
    final colors = Theme.of(context).colorScheme;
    return SteadyPage(
      children: [
        const Eyebrow('Make it yours'),
        const SizedBox(height: 12),
        const SectionHeading(
          title: 'More',
          subtitle: 'Keep trusted people nearby and choose how the app works for you.',
        ),
        const SizedBox(height: 28),
        ResponsiveColumns(
          minWidth: 300,
          children: [
            if (widget.onOpenInsights != null)
              _MoreCard(
                title: 'Insights',
                subtitle: 'Your patterns and learning sources',
                description: 'Reflect on your own labels and choose what the app can learn from.',
                icon: Icons.auto_awesome_outlined,
                color: colors.primaryContainer,
                onTap: widget.onOpenInsights!,
              ),
            _MoreCard(
              title: 'People',
              subtitle: 'Saved names and phone numbers',
              description: 'A place for the people you trust.',
              icon: Icons.people_outline,
              color: colors.primaryContainer,
              onTap: () => setState(() => destination = 'people'),
            ),
            _MoreCard(
              title: 'Settings',
              subtitle: 'Appearance, privacy, and data',
              description: 'Choose what feels easiest to read and use.',
              icon: Icons.tune_outlined,
              color: colors.secondaryContainer,
              onTap: () => setState(() => destination = 'settings'),
            ),
          ],
        ),
        if (widget.onLock != null) ...[
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                try {
                  await widget.onLock!();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not lock the vault. Please try again.',
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Lock vault'),
            ),
          ),
        ],
        const SizedBox(height: 28),
        SurfaceCard(
          color: colors.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(icon: Icons.lock_outline, size: 40),
              const SizedBox(height: 16),
              Text(
                'Your space, at your pace',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your entries are encrypted on this device. Save a protected backup or remove your data in Settings.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, color: color, size: 56),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingAction extends StatelessWidget {
  const _SettingAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = onTap == null
        ? colors.onSurfaceVariant
        : destructive
        ? colors.error
        : colors.onSurface;
    return Material(
      color: filled ? colors.surfaceContainerLow : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (constraints.maxWidth >= 360) ...[
                  ExcludeSemantics(
                    child: IconBadge(
                      icon: icon,
                      color: destructive
                          ? colors.errorContainer
                          : colors.primaryContainer,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: foreground),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: onTap == null ? colors.outlineVariant : foreground,
                ),
              ],
            ),
          ),
        ),
      ),
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
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final simple = controller.data.readingStyle == ReadingStyle.simple;
      return SteadyPage(
        children: [
          const Eyebrow('Your preferences'),
          const SizedBox(height: 12),
          const SectionHeading(
            title: 'Settings',
            subtitle: 'Choose what feels easiest to read and use.',
          ),
          const SizedBox(height: 28),
          ResponsiveColumns(
            minWidth: 340,
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _SettingAction(
                      title: 'Theme',
                      subtitle: _themeName(controller.data.theme),
                      icon: Icons.palette_outlined,
                      onTap: () => _chooseTheme(context),
                    ),
                    const Divider(height: 20),
                    _SettingAction(
                      title: 'Reading style',
                      subtitle: _readingName(controller.data.readingStyle),
                      icon: Icons.text_fields,
                      onTap: () => _chooseReadingStyle(context),
                    ),
                    if (simple) ...[
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Simple words are on. A trusted helper can read along with you.',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SurfaceCard(
                color: colors.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(
                      icon: Icons.shield_outlined,
                      color: colors.surface,
                      size: 44,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Privacy and safety',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your notes, events, people, settings, and learning records are encrypted in a passphrase-protected vault on this device, without an account or analytics. Exported backups are encrypted too. Uninstalling the app can remove local data.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Steady Through offers general support and planning. It cannot diagnose, treat, or monitor a condition or danger. If you are in immediate physical danger, contact local emergency services.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Save an encrypted .steady backup with its own passphrase. Keep the passphrase somewhere safe; there is no recovery service.',
                ),
                const SizedBox(height: 20),
                ResponsiveColumns(
                  minWidth: 300,
                  children: [
                    _SettingAction(
                      title: 'Export data',
                      subtitle: 'Protect events, check-ins, people, game history, settings, and learning in an encrypted backup',
                      icon: Icons.file_download_outlined,
                      onTap: () => _export(context),
                      filled: true,
                    ),
                    _SettingAction(
                      title: 'Import data',
                      subtitle: 'Choose a .steady backup or a legacy JSON file; review before replacing current data',
                      icon: Icons.file_upload_outlined,
                      onTap: () => _import(context),
                      filled: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                ResponsiveColumns(
                  minWidth: 300,
                  children: [
                    _SettingAction(
                      title: 'Clear game history',
                      subtitle:
                          '${controller.data.gameRounds.length} saved rounds',
                      icon: Icons.restart_alt,
                      onTap: controller.data.gameRounds.isEmpty
                          ? null
                          : () => _clearGameHistory(context),
                      filled: true,
                    ),
                    _SettingAction(
                      title: 'Delete all data',
                      subtitle: 'Remove all local records and reset settings',
                      icon: Icons.delete_forever_outlined,
                      onTap: () => _deleteAll(context),
                      filled: true,
                      destructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
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
      final passphrase = await showVaultPassphraseDialog(
        context,
        creating: true,
        title: 'Protect your backup',
      );
      if (passphrase == null || !context.mounted) return;
      final savedAt = await _portability.exportData(passphrase: passphrase);
      if (context.mounted) {
        _message(
          context,
          savedAt == null
              ? 'Export cancelled.'
              : 'Encrypted backup saved to the chosen file.',
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
        requestPassphrase: () async {
          if (!context.mounted) return null;
          return showVaultPassphraseDialog(
            context,
            creating: false,
            title: 'Unlock your backup',
          );
        },
        confirm: (replacement) async {
          if (!context.mounted) return false;
          return await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  scrollable: true,
                  title: const Text('Replace all local data?'),
                  content: Text(
                    'This file has ${replacement.events.length} events, '
                    '${replacement.people.length} people, and '
                    '${replacement.checkIns.length} check-ins, and '
                    '${replacement.learning.examples.length} learning examples. '
                    'Importing it will replace everything currently saved on this device. '
                    'Device usage and motion sources stay off until you enable them on this device.',
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
        _savedMessage(context, 'Data imported.');
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
        if (context.mounted) {
          _savedMessage(context, 'Game history cleared from the active vault.');
        }
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
          'This clears all events, actions, check-ins, people, game history, learning records, and preferences from the active vault. Older local recovery copies are removed when cleanup succeeds. Backups you exported remain where you saved them.',
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
        if (context.mounted) {
          _savedMessage(context, 'Data cleared from the active vault.');
        }
      } catch (_) {
        if (context.mounted) {
          _message(
            context,
            'Deletion could not be fully verified. Your active records are unchanged. Please try again.',
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

  void _savedMessage(BuildContext context, String message) {
    final warning = controller.cleanupWarning;
    _message(context, warning == null ? message : '$message $warning');
  }
}
