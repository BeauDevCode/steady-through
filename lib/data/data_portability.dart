import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/vault_codec.dart';
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
      dialogTitle: 'Choose a Steady Through data file',
      type: FileType.custom,
      allowedExtensions: ['steady', 'json'],
    );
    if (file == null) return null;
    try {
      final reportedLength = file.lengthSync();
      if (reportedLength != null &&
          reportedLength > VaultCodec.maxEnvelopeBytes) {
        throw const FormatException('The selected document is too large.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (builder.length + chunk.length > VaultCodec.maxEnvelopeBytes) {
          throw const FormatException('The selected document is too large.');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
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
    Future<String?> Function()? requestPassphrase,
  }) async {
    final bytes = await _gateway.pickJsonBytes();
    if (bytes == null) return false;

    if (bytes.length > VaultCodec.maxEnvelopeBytes) {
      throw const FormatException('The selected document is too large.');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The selected file is not a data document.');
    }
    final AppData replacement;
    if (decoded['format'] == 'steady-through-vault') {
      // Bound metadata before requesting a password or starting its KDF.
      VaultCodec.parseEnvelope(bytes);
      final passphrase = await requestPassphrase?.call();
      if (passphrase == null) return false;
      replacement = await VaultCodec.decryptDocument(bytes, passphrase);
    } else {
      replacement = AppData.fromJson(decoded);
    }
    if (!await confirm(replacement)) return false;

    await controller.replaceData(replacement);
    return true;
  }

  Future<Uri?> exportData({required String passphrase}) async {
    await controller.pruneLearning();
    final bytes = await VaultCodec.encryptDocument(controller.data, passphrase);
    return _gateway.saveJsonFile(
      fileName: 'steady-through-data.steady',
      bytes: bytes,
      mimeType: 'application/octet-stream',
    );
  }
}
