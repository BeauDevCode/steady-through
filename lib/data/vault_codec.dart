import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:steady_through/model/app_data.dart';

/// Deliberately does not distinguish a wrong passphrase from altered data.
class VaultUnlockException implements Exception {
  const VaultUnlockException();

  @override
  String toString() =>
      'The vault could not be authenticated. Check the passphrase or use an intact encrypted copy.';
}

/// Versioned, bounded authenticated document format used for vaults and exports.
class VaultCodec {
  static const maxEnvelopeBytes = 12 * 1024 * 1024;
  static const maxDocumentBytes = 8 * 1024 * 1024;
  static const iterations = 600000;
  static const _format = 'steady-through-vault';

  static Future<Uint8List> encryptDocument(
    AppData data,
    String passphrase,
  ) async {
    final cipher = await VaultCipher.create(passphrase);
    try {
      return await cipher.encrypt(data);
    } finally {
      cipher.close();
    }
  }

  static Future<AppData> decryptDocument(
    Uint8List bytes,
    String passphrase,
  ) async {
    final opened = await openDocument(bytes, passphrase);
    opened.cipher.close();
    return opened.data;
  }

  /// Parse and bound untrusted metadata before performing any password work.
  static VaultEnvelope parseEnvelope(Uint8List bytes) {
    if (bytes.length > maxEnvelopeBytes) {
      throw const FormatException('The encrypted document is too large.');
    }
    final document = jsonDecode(utf8.decode(bytes));
    if (document is! Map<String, dynamic>) {
      throw const FormatException('Expected an encrypted document.');
    }
    const keys = {
      'format',
      'version',
      'cipher',
      'kdf',
      'iterations',
      'salt',
      'nonce',
      'ciphertext',
      'tag',
    };
    if (document.length != keys.length ||
        !document.keys.toSet().containsAll(keys) ||
        document['format'] != _format ||
        document['version'] is! int ||
        document['version'] != 1 ||
        document['cipher'] != 'AES-256-GCM' ||
        document['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        document['iterations'] is! int ||
        document['iterations'] != iterations) {
      throw const FormatException('Unsupported encrypted document format.');
    }
    final salt = _decodeBytes(document['salt'], 16, 'salt');
    final nonce = _decodeBytes(document['nonce'], 12, 'nonce');
    final tag = _decodeBytes(document['tag'], 16, 'tag');
    final ciphertext = _decodeBytes(document['ciphertext'], null, 'ciphertext');
    if (ciphertext.isEmpty || ciphertext.length > maxDocumentBytes) {
      throw const FormatException('Invalid encrypted document length.');
    }
    return VaultEnvelope(salt, nonce, ciphertext, tag);
  }

  /// Opens one independently salted document. The returned cipher belongs to
  /// the caller and must be closed when its unlocked session ends.
  static Future<OpenedVaultDocument> openDocument(
    Uint8List bytes,
    String passphrase,
  ) async {
    final envelope = parseEnvelope(bytes);
    final cipher = await VaultCipher.fromEnvelope(envelope, passphrase);
    try {
      return OpenedVaultDocument(
        await cipher.decryptEnvelope(envelope),
        cipher,
      );
    } catch (_) {
      cipher.close();
      rethrow;
    }
  }

  static Uint8List _decodeBytes(Object? value, int? length, String field) {
    if (value is! String) {
      throw FormatException('The encrypted $field must be base64.');
    }
    final decoded = base64Decode(value);
    // Reject alternate encodings so the authenticated metadata is unambiguous.
    if (base64Encode(decoded) != value ||
        (length != null && decoded.length != length)) {
      throw FormatException('Invalid encrypted $field.');
    }
    return decoded;
  }
}

/// Internal storage boundary shared by the codec, repository, and store.
/// Contains public metadata only; keys never appear in an envelope.
class VaultEnvelope {
  VaultEnvelope(this.salt, this.nonce, this.ciphertext, this.tag);

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List tag;

  Map<String, Object> get metadata => {
    'format': VaultCodec._format,
    'version': 1,
    'cipher': 'AES-256-GCM',
    'kdf': 'PBKDF2-HMAC-SHA256',
    'iterations': VaultCodec.iterations,
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
  };

  List<int> get authenticatedMetadata => utf8.encode(jsonEncode(metadata));

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        ...metadata,
        'ciphertext': base64Encode(ciphertext),
        'tag': base64Encode(tag),
      }),
    ),
  );
}

class OpenedVaultDocument {
  OpenedVaultDocument(this.data, this.cipher);

  final AppData data;
  final VaultCipher cipher;
}

/// Holds a derived key for exactly one unlocked local session. Closing destroys
/// its owned key bytes and clears the reference. Dart/OS memory copies and an
/// already compromised unlocked device are outside this protection boundary.
class VaultCipher {
  VaultCipher._(this._salt, Uint8List key)
    : _key = SecretKeyData(key, overwriteWhenDestroyed: true);

  final Uint8List _salt;
  SecretKeyData? _key;

  static Future<VaultCipher> create(String passphrase) async {
    if (passphrase.runes.length < 12) {
      throw ArgumentError('Use a passphrase of at least 12 characters.');
    }
    final salt = _randomBytes(16);
    return VaultCipher._(salt, await _deriveKeyOutsideUi(passphrase, salt));
  }

  static Future<VaultCipher> fromEnvelope(
    VaultEnvelope envelope,
    String passphrase,
  ) async => VaultCipher._(
    Uint8List.fromList(envelope.salt),
    await _deriveKeyOutsideUi(passphrase, envelope.salt),
  );

  void ensureOpen() {
    if (_key == null) throw StateError('The vault is locked.');
  }

  void close() {
    _key?.destroy();
    _key = null;
  }

  Future<Uint8List> encrypt(AppData data) async {
    ensureOpen();
    final document = data.toJson();
    AppData.fromJson(document);
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(document)));
    if (plaintext.length > VaultCodec.maxDocumentBytes) {
      throw const FormatException('The data document is too large.');
    }
    final envelope = VaultEnvelope(
      _salt,
      _randomBytes(12),
      Uint8List(0),
      Uint8List(0),
    );
    try {
      final box = await AesGcm.with256bits().encrypt(
        plaintext,
        secretKey: _key!,
        nonce: envelope.nonce,
        aad: envelope.authenticatedMetadata,
      );
      ensureOpen();
      return VaultEnvelope(
        _salt,
        envelope.nonce,
        Uint8List.fromList(box.cipherText),
        Uint8List.fromList(box.mac.bytes),
      ).encode();
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  Future<AppData> decrypt(Uint8List bytes) =>
      decryptEnvelope(VaultCodec.parseEnvelope(bytes));

  Future<AppData> decryptEnvelope(VaultEnvelope envelope) async {
    ensureOpen();
    if (!_sameBytes(envelope.salt, _salt)) {
      throw const VaultUnlockException();
    }
    List<int> plaintext;
    try {
      plaintext = await AesGcm.with256bits().decrypt(
        SecretBox(
          envelope.ciphertext,
          nonce: envelope.nonce,
          mac: Mac(envelope.tag),
        ),
        secretKey: _key!,
        aad: envelope.authenticatedMetadata,
      );
    } on SecretBoxAuthenticationError {
      throw const VaultUnlockException();
    }
    try {
      ensureOpen();
      final document = jsonDecode(utf8.decode(plaintext));
      if (document is! Map<String, dynamic>) {
        throw const FormatException('The decrypted document is invalid.');
      }
      return AppData.fromJson(document);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

// Keep this closure in a top-level helper so it captures only password/salt,
// never a repository, widget, file handle, or another session's key.
Future<Uint8List> _deriveKeyOutsideUi(String passphrase, List<int> salt) =>
    Isolate.run(() async {
      final key = await Pbkdf2.hmacSha256(
        iterations: VaultCodec.iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: passphrase, nonce: salt);
      try {
        return Uint8List.fromList(await key.extractBytes());
      } finally {
        key.destroy();
      }
    }, debugName: 'steady-through-vault-kdf');
