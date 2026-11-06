import 'package:flutter/material.dart';

/// Requests a passphrase without authenticating or changing any data.
/// Returning null always means the caller must leave the pending action alone.
Future<String?> showVaultPassphraseDialog(
  BuildContext context, {
  required bool creating,
  String? title,
}) => showDialog<String>(
  context: context,
  animationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (context) => _PassphraseDialog(
    creating: creating,
    title: title ?? (creating ? 'Protect your backup' : 'Unlock your backup'),
  ),
);

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.creating, required this.title});
  final bool creating;
  final String title;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _passphrase.clear();
    _confirmation.clear();
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _continue() {
    if (_formKey.currentState!.validate()) {
      // Preserve exact characters: spaces can be part of a valid passphrase.
      Navigator.of(context).pop(_passphrase.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      icon: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              widget.creating ? Icons.lock_outline : Icons.key_outlined,
              color: colors.onPrimaryContainer,
              size: 28,
            ),
          ),
        ),
      ),
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.creating
                    ? 'Choose several words you can remember. Spaces and punctuation are welcome.'
                    : 'Enter the passphrase you used to protect this data. Your entries stay in place until you review and confirm.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('vault-passphrase'),
                controller: _passphrase,
                autofocus: true,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: widget.creating
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Passphrase',
                  helperText: widget.creating ? '12 characters or more.' : null,
                  errorMaxLines: 3,
                ),
                validator: (value) {
                  if (widget.creating && (value?.runes.length ?? 0) < 12) {
                    return 'Use a passphrase of at least 12 characters.';
                  }
                  if (value == null || value.isEmpty) {
                    return 'Enter your passphrase.';
                  }
                  return null;
                },
                onFieldSubmitted: widget.creating ? null : (_) => _continue(),
              ),
              if (widget.creating) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('vault-confirm-passphrase'),
                  controller: _confirmation,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Confirm passphrase',
                    errorMaxLines: 3,
                  ),
                  validator: (value) => value == _passphrase.text
                      ? null
                      : 'The passphrases do not match.',
                  onFieldSubmitted: (_) => _continue(),
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'We cannot recover a forgotten passphrase. Keep it somewhere safe.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSecondaryContainer),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _continue,
          child: Text(
            widget.creating ? 'Create encrypted backup' : 'Unlock backup',
          ),
        ),
      ],
    );
  }
}
