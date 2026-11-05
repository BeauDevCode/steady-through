import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/model/app_data.dart';

/// The small native-file boundary. The selected file is read before any data
/// is changed, so picker cancellation and read errors leave local data alone.
abstract class DataPortabilityGateway {
  Future<Uint8List?> pickJsonBytes();

  Future<Uri?> saveJsonFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
}

class FilePickerDataPortabilityGateway implements DataPortabilityGateway {
  const FilePickerDataPortabilityGateway();

  @override
  Future<Uint8List?> pickJsonBytes() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a Steady Through JSON file',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    try {
      return await file.readAsBytes();
    } finally {
      // On iOS the picker gives us an app-owned copy. Clear that temporary
      // copy only after it has been read. Other platforms may make this a no-op.
      await _clearPickerTemporaryFiles();
    }
  }

  @override
  Future<Uri?> saveJsonFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      return await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        dialogTitle: 'Save your Steady Through data',
      );
    } finally {
      // On iOS saveFile exports an app-owned temporary copy. The selected
      // destination is a separate copy and remains after cleanup.
      await _clearPickerTemporaryFiles();
    }
  }
}

Future<void> _clearPickerTemporaryFiles() async {
  try {
    await FilePicker.clearTemporaryFiles();
  } catch (_) {
    // Unsupported cleanup must not hide a read or save result or error.
  }
}

class DataPortability {
  DataPortability(this.controller, {DataPortabilityGateway? gateway})
    : _gateway = gateway ?? const FilePickerDataPortabilityGateway();

  final AppController controller;
  final DataPortabilityGateway _gateway;

  /// Returns false for a cancelled picker or a declined replacement. A parse
  /// or read error is surfaced so the UI can explain that nothing was changed.
  Future<bool> importData({
    required Future<bool> Function(AppData replacement) confirm,
  }) async {
    final bytes = await _gateway.pickJsonBytes();
    if (bytes == null) return false;

    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The selected file is not a data document.');
    }
    final replacement = AppData.fromJson(decoded);
    if (!await confirm(replacement)) return false;

    await controller.replaceData(replacement);
    return true;
  }

  Future<Uri?> exportData() {
    final bytes = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(controller.data.toJson()),
      ),
    );
    return _gateway.saveJsonFile(
      fileName: 'steady-through-data.json',
      bytes: bytes,
      mimeType: 'application/json',
    );
  }
}
