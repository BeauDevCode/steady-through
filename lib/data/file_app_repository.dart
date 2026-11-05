import 'dart:convert';
import 'dart:io';

import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/model/app_data.dart';

class FileAppRepository implements AppRepository {
  FileAppRepository(this.root);

  final Directory root;

  File get _dataFile => File('${root.path}${Platform.pathSeparator}steady-through.json');
  File get _backupFile => File('${root.path}${Platform.pathSeparator}steady-through.json.bak');
  File get _tempFile => File('${root.path}${Platform.pathSeparator}steady-through.json.tmp');

  @override
  Future<AppData> load() async {
    final file = await _dataFile.exists() ? _dataFile : _backupFile;
    if (!await file.exists()) return AppData.empty();

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('The data file must contain a JSON object.');
      }
      return AppData.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Unable to read saved data: $error');
    }
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
      if (hadCurrent && !await _dataFile.exists() && await _backupFile.exists()) {
        await _backupFile.rename(_dataFile.path);
      }
      rethrow;
    }

    if (await _backupFile.exists()) await _backupFile.delete();
  }
}
