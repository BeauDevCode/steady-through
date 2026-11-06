import 'dart:io';
import 'dart:typed_data';

import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/data/vault_codec.dart';
import 'package:steady_through/model/app_data.dart';

/// A repository available only through an authenticated unlocked vault session.
/// Every durable copy, including the crash recovery files, is encrypted.
class EncryptedAppRepository implements AppRepository, ResidualDataRepository {
  EncryptedAppRepository(
    this.root,
    this._cipher, {
    this._recoveredPath,
    Future<void> Function(File)? legacyCleanup,
  }) : _legacyCleanup = legacyCleanup ?? deleteVaultFile;

  final Directory root;
  final VaultCipher _cipher;
  final Future<void> Function(File) _legacyCleanup;
  String? _recoveredPath;

  File get _primary => vaultFile(root);
  File get _backup => vaultFile(root, '.bak');
  File get _temporary => vaultFile(root, '.tmp');

  void close() => _cipher.close();

  @override
  Future<AppData> load() async {
    _cipher.ensureOpen();
    for (final file in [_primary, _backup, _temporary]) {
      if (!await file.exists()) continue;
      try {
        final data = await _cipher.decrypt(await readBoundedVault(file));
        _recoveredPath = file.path == _primary.path ? null : file.path;
        return data;
      } on VaultUnlockException {
        // Read-only recovery: only an independently authenticated copy wins.
      } on FormatException {
        // A failed candidate remains untouched for recovery outside the app.
      }
    }
    throw const VaultUnlockException();
  }

  @override
  Future<void> save(AppData value) async {
    _cipher.ensureOpen();
    final bytes = await _cipher.encrypt(value);
    _cipher.ensureOpen();
    await root.create(recursive: true);

    // A .tmp file may be the sole authenticated survivor of an interrupted
    // first save. Preserve it before reusing the staging path.
    if (_recoveredPath == _temporary.path) {
      await _backup.writeAsBytes(
        await readBoundedVault(_temporary),
        flush: true,
      );
      await _cipher.decrypt(await readBoundedVault(_backup));
      _recoveredPath = _backup.path;
    }
    _cipher.ensureOpen();
    await _temporary.writeAsBytes(bytes, flush: true);
    // The new staging document must authenticate before rotating any old copy.
    await _cipher.decrypt(await readBoundedVault(_temporary));
    _cipher.ensureOpen();

    final hadPrimary = await _primary.exists();
    final recoveringBackup = _recoveredPath == _backup.path;
    var rotatedPrimary = false;
    if (hadPrimary && !recoveringBackup) {
      if (await _backup.exists()) await _backup.delete();
      await _primary.rename(_backup.path);
      rotatedPrimary = true;
    } else if (hadPrimary) {
      // This primary failed authentication; keep the authenticated backup.
      await _primary.delete();
    }

    try {
      await _temporary.rename(_primary.path);
      _recoveredPath = null;
    } catch (_) {
      if (rotatedPrimary &&
          !await _primary.exists() &&
          await _backup.exists()) {
        await _backup.rename(_primary.path);
      }
      rethrow;
    }
    // Keep the previous encrypted document for crash recovery until a primary
    // unlock authenticates the committed copy, or the controller explicitly
    // purges residuals after clearing or pruning records.
  }

  @override
  Future<void> purgeResidualData() async {
    _cipher.ensureOpen();
    final failures = <String>[];
    for (final file in [_backup, _temporary, ...legacyVaultFiles(root)]) {
      try {
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          if (file.path.endsWith('.json') || file.path.contains('.json.')) {
            await _legacyCleanup(file);
          } else {
            await file.delete();
          }
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
        'Some saved data could not be removed',
        failures.join(', '),
      );
    }
  }
}

File vaultFile(Directory root, [String suffix = '']) =>
    File('${root.path}${Platform.pathSeparator}steady-through.vault$suffix');

List<File> legacyVaultFiles(Directory root) => [
  for (final suffix in ['', '.bak', '.tmp'])
    File('${root.path}${Platform.pathSeparator}steady-through.json$suffix'),
];

Future<void> deleteVaultFile(File file) async {
  await file.delete();
}

Future<Uint8List> readBoundedVault(File file) async {
  if (await file.length() > VaultCodec.maxEnvelopeBytes) {
    throw const FormatException('The encrypted document is too large.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.length > VaultCodec.maxEnvelopeBytes) {
    throw const FormatException('The encrypted document is too large.');
  }
  return bytes;
}
