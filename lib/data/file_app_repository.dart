import 'dart:convert';
import 'dart:io';

import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';

class FileAppRepository implements AppRepository, ResidualDataRepository {
  FileAppRepository(this.root, {Future<void> Function(File)? backupCleanup})
    : _backupCleanup = backupCleanup ?? _deleteBackup;

  final Directory root;
  final Future<void> Function(File) _backupCleanup;

  static Future<void> _deleteBackup(File file) async {
    await file.delete();
  }

  File get _dataFile =>
      File('${root.path}${Platform.pathSeparator}steady-through.json');
  File get _backupFile =>
      File('${root.path}${Platform.pathSeparator}steady-through.json.bak');
  File get _tempFile =>
      File('${root.path}${Platform.pathSeparator}steady-through.json.tmp');

  @override
  Future<AppData> load() async {
    // A path occupied by a file or inaccessible to the app is a storage
    // failure, not an empty document or corrupt JSON.
    await root.create(recursive: true);
    await root.list().toList();
    final file = await _dataFile.exists() ? _dataFile : _backupFile;
    if (!await file.exists()) return AppData.empty();

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The data file must contain a JSON object.');
    }
    return AppData.fromJson(decoded);
  }

  @override
  Future<void> save(AppData value) async {
    // Validate before touching the previous copy.
    final document = value.toJson();
    AppData.fromJson(document);
    await root.create(recursive: true);
    await _tempFile.writeAsString(jsonEncode(document), flush: true);

    final hadCurrent = await _dataFile.exists();
    if (hadCurrent) {
      if (await _backupFile.exists()) await _backupFile.delete();
      await _dataFile.rename(_backupFile.path);
    }

    try {
      await _tempFile.rename(_dataFile.path);
    } catch (_) {
      if (hadCurrent &&
          !await _dataFile.exists() &&
          await _backupFile.exists()) {
        await _backupFile.rename(_dataFile.path);
      }
      rethrow;
    }

    // The primary file is committed after the rename. Cleanup cannot turn a
    // successful save into a failure seen by the controller.
    try {
      if (await _backupFile.exists()) await _backupCleanup(_backupFile);
    } catch (_) {
      // The next save removes a stale backup before rotating the primary.
    }
  }

  @override
  Future<void> purgeResidualData() async {
    final entries = await root.list(followLinks: false).toList();
    if (entries.any((entry) => entry.path == _backupFile.path)) {
      await _backupCleanup(_backupFile);
    }
    if (entries.any((entry) => entry.path == _tempFile.path)) {
      await _tempFile.delete();
    }
    final remaining = await root.list(followLinks: false).toList();
    if (remaining.any(
      (entry) => entry.path == _backupFile.path || entry.path == _tempFile.path,
    )) {
      throw FileSystemException('Residual saved data remains', root.path);
    }
  }
}
