import 'package:flutter/material.dart';
import 'package:steady_through/ui/steady_ui.dart';

class VaultUnlockScreen extends StatefulWidget {
  const VaultUnlockScreen({
    super.key,
    required this.creating,
    required this.onSubmit,
    this.onReset,
  });
  final bool creating;
  final Future<void> Function(String passphrase) onSubmit;
  final Future<void> Function()? onReset;
  @override
  State<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends State<VaultUnlockScreen> {
  final _form = GlobalKey<FormState>();
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _showingHelp = false;
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_passphrase.text);
      if (mounted) {
        _passphrase.clear();
        _confirmation.clear();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = widget.creating
              ? 'The vault could not be created. Your saved data was kept. Please try again.'
              : 'The vault could not be opened. Check your passphrase or try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPassphraseHelp() async {
    if (_busy || _showingHelp || widget.onReset == null) return;
    _showingHelp = true;
    try {
      final startOver = await showDialog<bool>(
        context: context,
        requestFocus: true,
        builder: (dialogContext) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 560),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          scrollable: true,
          title: Text(
            'Help with your passphrase',
            style: Theme.of(dialogContext).textTheme.headlineSmall
                ?.copyWith(fontSize: 22),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'There is no account or server recovery. Check whether you kept a safe copy of your vault passphrase.',
              ),
              SizedBox(height: 16),
              Text(
                'An exported .steady backup uses the separate export passphrase you chose for it. That passphrase does not unlock this vault.',
              ),
              SizedBox(height: 16),
              Text(
                'If you can open a vault, go to More → Settings → Import data to restore a backup. You will be asked before replacing its records.',
              ),
              SizedBox(height: 16),
              Text(
                'If this vault stays locked, check any backup you already have and its export passphrase on another installation first. Keep this vault until you know the backup opens.',
              ),
              SizedBox(height: 16),
              Text(
                'Without your vault passphrase or a usable backup, its records cannot be recovered.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Start over…'),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back to unlock'),
            ),
          ],
        ),
      );
      if (startOver == true && mounted && !_busy) {
        await widget.onReset?.call();
      }
    } finally {
      _showingHelp = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 20),
                  label: Text(
                    widget.creating ? 'Create private vault' : 'Unlock vault',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: SteadyPage(
          maxWidth: 1000,
          children: [
            const SizedBox(height: 12),
            GentleReveal(
              child: SurfaceCard(
                color: colors.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBadge(icon: Icons.lock_outline_rounded, size: 52),
                    const SizedBox(height: 18),
                    const Eyebrow('Steady Through • yours to keep'),
                    const SizedBox(height: 10),
                    Text(
                      widget.creating
                          ? 'Your own private space.'
                          : 'Welcome back.',
                      style: text.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.creating
                          ? 'Create a passphrase to encrypt your notes and personal learning on this device.'
                          : 'Your notes and personal learning are encrypted. Use your passphrase to open them.',
                      style: text.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.creating ? 'Choose a passphrase' : 'Open your vault',
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.creating
                        ? 'Use at least 12 characters. A few unrelated words can be easier to remember. There is no recovery service, so keep a safe copy.'
                        : 'Your passphrase stays with you. It is never sent to a server.',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passphrase,
                    obscureText: !_visible,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: widget.creating
                        ? TextInputAction.next
                        : TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Passphrase',
                      suffixIcon: IconButton(
                        tooltip: _visible
                            ? 'Hide passphrase'
                            : 'Show passphrase',
                        onPressed: () => setState(() => _visible = !_visible),
                        icon: Icon(
                          _visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        widget.creating && (value?.runes.length ?? 0) < 12
                        ? 'Use at least 12 characters.'
                        : (value?.isEmpty ?? true)
                        ? 'Enter your passphrase.'
                        : null,
                    onFieldSubmitted: (_) {
                      if (!widget.creating) _submit();
                    },
                  ),
                  if (widget.creating) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: !_visible,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: const InputDecoration(
                        labelText: 'Confirm passphrase',
                      ),
                      validator: (value) => value != _passphrase.text
                          ? 'The passphrases do not match.'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                  if (!widget.creating && widget.onReset != null) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _busy ? null : _showPassphraseHelp,
                      child: const Text('Forgot your passphrase?'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Everything in the app is free. Device permissions are your choice. Your vault stays on this device.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
