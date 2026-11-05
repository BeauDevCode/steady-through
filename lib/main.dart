import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/data/file_app_repository.dart';
import 'package:steady_through/model/app_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _launch();
}

Future<void> _launch() async {
  try {
    final directory = await getApplicationSupportDirectory();
    final repository = FileAppRepository(directory);
    try {
      final data = await repository.load();
      runApp(SteadyThroughApp(controller: AppController(repository, data)));
    } on FormatException {
      // Keep the unreadable document untouched until the person confirms a reset.
      runApp(
        MaterialApp(
          title: 'Steady Through',
          home: StartupRecoveryScreen(
            onRetry: _launch,
            onReset: () async {
              final empty = AppData.empty();
              await repository.save(empty);
              runApp(
                SteadyThroughApp(controller: AppController(repository, empty)),
              );
            },
          ),
        ),
      );
    }
  } catch (_) {
    // Storage or OS access can fail independently of the saved document. A
    // retry leaves the document intact and avoids offering a destructive reset.
    runApp(
      MaterialApp(
        title: 'Steady Through',
        home: Scaffold(
          appBar: AppBar(title: const Text('Steady Through')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'The app could not open local storage. Your saved data has not been changed.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _launch,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown only when the local document is unreadable or uses an unknown version.
/// The reset callback is invoked after an explicit confirmation.
class StartupRecoveryScreen extends StatefulWidget {
  const StartupRecoveryScreen({super.key, required this.onReset, this.onRetry});

  final Future<void> Function() onReset;
  final Future<void> Function()? onRetry;

  @override
  State<StartupRecoveryScreen> createState() => _StartupRecoveryScreenState();
}

class _StartupRecoveryScreenState extends State<StartupRecoveryScreen> {
  bool _resetting = false;
  String? _error;

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete saved data?'),
        content: const Text(
          'This permanently replaces the saved data on this device with an empty app. You cannot undo it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep data'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete saved data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _resetting = true;
      _error = null;
    });
    try {
      await widget.onReset();
    } catch (_) {
      if (mounted) {
        setState(() {
          _resetting = false;
          _error = 'The reset did not finish. Your saved data may still be available. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Steady Through')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Your saved data could not be opened',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'The file may be damaged or from a newer app version. It has not been changed. You can try again or choose to erase it and start over.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.onRetry != null)
                    OutlinedButton(
                      onPressed: _resetting ? null : widget.onRetry,
                      child: const Text('Try again'),
                    ),
                  FilledButton(
                    onPressed: _resetting ? null : _confirmReset,
                    child: Text(_resetting ? 'Resetting…' : 'Reset local data'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
