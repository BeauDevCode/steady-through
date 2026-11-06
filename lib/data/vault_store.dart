import 'dart:convert';
import 'dart:io';

import 'package:steady_through/data/encrypted_app_repository.dart';
import 'package:steady_through/data/vault_codec.dart';
import 'package:steady_through/model/app_data.dart';

class VaultSession {
  VaultSession(this.initialData, this.repository, {this.cleanupWarning});

  final AppData initialData;
  final EncryptedAppRepository repository;

  /// Includes residual plaintext cleanup and authenticated recovery notices.
  /// Display this in the unlocked app; neither condition silently resets data.
  final String? cleanupWarning;

  void close() => repository.close();
}

class VaultStore {
  VaultStore(this.root, {Future<void> Function(File)? legacyCleanup})
    : _legacyCleanup = legacyCleanup ?? deleteVaultFile;

  final Directory root;
  final Future<void> Function(File) _legacyCleanup;

  Future<bool> hasVault() async {
    await root.create(recursive: true);
    // Listing forces storage/access failures to surface instead of becoming a
    // misleading first-launch state. Include orphaned encrypted staging files.
    final entries = await root.list(followLinks: false).toList();
    final paths = {
      for (final suffix in ['', '.bak', '.tmp']) vaultFile(root, suffix).path,
    };
    return entries.any((entry) => paths.contains(entry.path));
  }

  Future<VaultSession> create(String passphrase) async {
    if (await hasVault()) {
      throw StateError(
        'An encrypted vault already exists. Unlock or explicitly reset it.',
      );
    }
    // Legacy validation happens before encryption or cleanup. An invalid old
    // document must remain available rather than turning into an empty vault.
    final legacy = await _loadLegacyForMigration();
    final cipher = await VaultCipher.create(passphrase);
    final repository = EncryptedAppRepository(
      root,
      cipher,
      legacyCleanup: _legacyCleanup,
    );
    try {
      await repository.save(legacy.data);
      final readBack = await repository.load();
      final cleanup = await _cleanupLegacy();
      final warnings = <String>[
        if (legacy.warning != null) legacy.warning!,
        ?cleanup,
      ];
      return VaultSession(
        readBack,
        repository,
        cleanupWarning: warnings.isEmpty ? null : warnings.join(' '),
      );
    } catch (_) {
      repository.close();
      rethrow;
    }
  }

  Future<VaultSession> unlock(String passphrase) async {
    if (!await hasVault()) {
      throw StateError('There is no encrypted vault to unlock.');
    }
    for (final suffix in ['', '.bak', '.tmp']) {
      final file = vaultFile(root, suffix);
      if (!await file.exists()) continue;
      OpenedVaultDocument opened;
      try {
        opened = await VaultCodec.openDocument(
          await readBoundedVault(file),
          passphrase,
        );
      } on VaultUnlockException {
        continue;
      } on FormatException {
        continue;
      }
      final repository = EncryptedAppRepository(
        root,
        opened.cipher,
        recoveredPath: suffix.isEmpty ? null : file.path,
        legacyCleanup: _legacyCleanup,
      );
      String? cleanup;
      if (suffix.isEmpty) {
        try {
          // Authentication proves the committed primary is usable. Remove
          // older encrypted records as well as leftover plaintext, including
          // residuals from a previously failed clear or retention prune.
          await repository.purgeResidualData();
          cleanup = null;
        } on FileSystemException {
          cleanup = 'The vault is unlocked, but older saved copies could not all be removed. Cleanup will be retried when you next unlock the primary vault.';
        }
      } else {
        // Recovery copies remain intact until an explicit save succeeds.
        cleanup = await _cleanupLegacy();
      }
      final warnings = <String>[
        if (suffix.isNotEmpty)
          'An authenticated ${suffix == '.bak' ? 'backup' : 'unfinished save'} was recovered. It may contain earlier records. The original encrypted files were kept.',
        ?cleanup,
      ];
      return VaultSession(
        opened.data,
        repository,
        cleanupWarning: warnings.isEmpty ? null : warnings.join(' '),
      );
    }
    // No candidate was authenticated; preserve every file for another attempt.
    throw const VaultUnlockException();
  }

  /// Permanently removes the known vault and legacy paths. The UI must obtain
  /// explicit destructive confirmation and close any unlocked session first.
  /// It never recursively removes an unexpected directory at a data-file path.
  Future<void> reset() async {
    await root.create(recursive: true);
    final failures = <String>[];
    for (final file in [
      for (final suffix in ['', '.bak', '.tmp']) vaultFile(root, suffix),
      ...legacyVaultFiles(root),
    ]) {
      try {
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          await file.delete();
        }
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          failures.add(file.path);
        }
      } catch (_) {
        failures.add(file.path);
      }
    }
    if (failures.isNotEmpty) {
      throw FileSystemException(
        'The vault reset was incomplete; some saved data remains',
        failures.join(', '),
      );
    }
  }

  Future<({AppData data, String? warning})> _loadLegacyForMigration() async {
    final files = legacyVaultFiles(root);
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      if (await FileSystemEntity.type(file.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        continue;
      }
      // Keep the legacy primary/backup priority, but include a sole staging
      // document left by an interrupted first save. An existing invalid or
      // inaccessible candidate is an error, never proof that no records exist.
      if (await file.length() > VaultCodec.maxDocumentBytes) {
        throw const FormatException('The legacy document is too large.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > VaultCodec.maxDocumentBytes) {
        throw const FormatException('The legacy document is too large.');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'The legacy document must contain a JSON object.',
        );
      }
      return (
        data: AppData.fromJson(decoded),
        warning: index == 0
            ? null
            : 'Records were migrated from an older unencrypted ${index == 1 ? 'backup' : 'unfinished save'} because the primary document was missing. Check that the recovered records are complete.',
      );
    }
    return (data: AppData.empty(), warning: null);
  }

  Future<String?> _cleanupLegacy() async {
    final failures = <String>[];
    for (final file in legacyVaultFiles(root)) {
      try {
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          await _legacyCleanup(file);
        }
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          failures.add(file.path.split(Platform.pathSeparator).last);
        }
      } catch (_) {
        failures.add(file.path.split(Platform.pathSeparator).last);
      }
    }
    return failures.isEmpty
        ? null
        : 'The encrypted vault is ready, but older unencrypted copies could not be removed (${failures.join(', ')}). Cleanup will be retried when you unlock.';
  }
}
