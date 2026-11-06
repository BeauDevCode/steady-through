import 'dart:async';

import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/app/steady_through_app.dart';
import 'package:steady_through/app/vault_activity_policy.dart';
import 'package:steady_through/data/vault_store.dart';
import 'package:steady_through/features/vault/vault_unlock_screen.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/ui/steady_theme.dart';

class VaultGate extends StatefulWidget {
  const VaultGate({super.key, required this.store});
  final VaultStore store;
  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> with WidgetsBindingObserver {
  final _activity = VaultActivityPolicy();
  VaultSession? _vault;
  AppController? _controller;
  LearningSession? _learning;
  LearningSession? _pendingLearning;
  String? _warning;
  bool? _hasVault;
  bool _locking = false;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activity.handle(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      DateTime.now().toUtc(),
    );
    _checkStorage();
  }

  Future<void> _checkStorage() async {
    try {
      final exists = await widget.store.hasVault();
      if (mounted) {
        setState(() {
          _hasVault = exists;
          _storageError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _storageError = 'Local storage could not be opened. Your existing files have not been reset.',
        );
      }
    }
  }

  Future<void> _open(String passphrase) async {
    final epoch = _activity.lockEpoch;
    VaultSession? vault;
    AppController? controller;
    LearningSession? learning;
    try {
      vault = _hasVault == true
          ? await widget.store.unlock(passphrase)
          : await widget.store.create(passphrase);
      if (!mounted ||
          !_activity.canCompleteUnlock(epoch, DateTime.now().toUtc())) {
        throw StateError('Unlock expired while the app was away.');
      }
      controller = AppController(vault.repository, vault.initialData);
      var warning = vault.cleanupWarning;
      try {
        await controller.pruneLearning();
      } catch (_) {
        warning =
            '${warning ?? ''} Expired learning could not be fully removed from local recovery copies. Lock and unlock to try again.';
      }
      learning = LearningSession(controller);
      _pendingLearning = learning;
      await learning.initialize(active: _activity.active);
      if (!mounted ||
          !_activity.canCompleteUnlock(epoch, DateTime.now().toUtc())) {
        throw StateError('Unlock expired while the app was away.');
      }
      if (!_activity.active) await learning.suspend();
      setState(() {
        _vault = vault;
        _controller = controller;
        _learning = learning;
        _warning = warning;
        _hasVault = true;
      });
    } catch (_) {
      await learning?.close();
      await controller?.flush();
      controller?.dispose();
      vault?.close();
      // A failed creation may have left an authenticated staging/primary copy.
      // Recheck instead of repeatedly offering a creation that cannot succeed.
      await _checkStorage();
      rethrow;
    } finally {
      _pendingLearning = null;
    }
  }

  Future<void> _lock() async {
    if (_locking || _vault == null) return;
    setState(() => _locking = true);
    final controller = _controller!;
    final learning = _learning!;
    final vault = _vault!;
    await learning.close();
    await controller.flush();
    vault.close();
    if (mounted) {
      setState(() {
        _controller = null;
        _learning = null;
        _vault = null;
        _warning = null;
        _locking = false;
      });
    }
    controller.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldLock = _activity.handle(state, DateTime.now().toUtc());
    final session = _learning ?? _pendingLearning;
    if (session != null) {
      if (shouldLock) {
        if (_vault != null) {
          unawaited(_lock());
        } else {
          unawaited(session.suspend());
        }
      } else if (state == AppLifecycleState.resumed) {
        unawaited(session.activate());
      } else {
        unawaited(session.suspend());
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _reset(BuildContext context) async {
    var confirmation = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Permanently delete this vault?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This removes the encrypted vault, local backups, and any older app records on this device. It cannot recover a forgotten passphrase. Exported copies remain where you saved them. This cannot be undone.',
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE to confirm',
                  ),
                  onChanged: (value) => update(() => confirmation = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep vault'),
            ),
            FilledButton(
              onPressed: confirmation == 'DELETE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Delete vault'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.store.reset();
      await _checkStorage();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Deletion could not be fully verified. Some local data may remain. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Normal app locks await the write queue. Process termination is governed
    // by the OS; encrypted atomic saves protect completed writes.
    final learning = _learning;
    final controller = _controller;
    final vault = _vault;
    unawaited(_pendingLearning?.suspend() ?? Future<void>.value());
    if (!_locking) {
      unawaited(() async {
        await learning?.close();
        await controller?.flush();
        vault?.close();
        controller?.dispose();
      }());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_vault != null) {
      return Stack(
        textDirection: TextDirection.ltr,
        children: [
          SteadyThroughApp(
            controller: _controller!,
            learningSession: _learning,
            onLock: _lock,
            storageWarning: _warning,
          ),
          if (_activity.covered || _locking)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF10251C),
                child: Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFA6D7C1),
                    size: 48,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return MaterialApp(
      title: 'Steady Through',
      debugShowCheckedModeBanner: false,
      theme: steadyTheme(Brightness.light),
      darkTheme: steadyTheme(Brightness.dark),
      home: Builder(
        builder: (inside) {
          if (_storageError != null) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_storageError!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _checkStorage,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (_hasVault == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return VaultUnlockScreen(
            creating: !_hasVault!,
            onSubmit: _open,
            onReset: _hasVault! ? () => _reset(inside) : null,
          );
        },
      ),
    );
  }
}
