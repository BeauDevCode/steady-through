import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/data/vault_codec.dart';
import 'package:steady_through/model/app_data.dart';

const _passphrase = 'a long private passphrase';

void main() {
  test(
    'encrypted export round-trips without readable personal records',
    () async {
      final data = AppData(
        people: [TrustedPerson(id: 'p1', name: 'Private Alex')],
      );
      final bytes = await VaultCodec.encryptDocument(data, _passphrase);

      expect(utf8.decode(bytes), isNot(contains('Private Alex')));
      final restored = await VaultCodec.decryptDocument(bytes, _passphrase);
      expect(restored.people.single.name, 'Private Alex');
    },
  );

  test('each independent export has a new salt and nonce', () async {
    final first = jsonDecode(
      utf8.decode(
        await VaultCodec.encryptDocument(AppData.empty(), _passphrase),
      ),
    ) as Map<String, dynamic>;
    final second = jsonDecode(
      utf8.decode(
        await VaultCodec.encryptDocument(AppData.empty(), _passphrase),
      ),
    ) as Map<String, dynamic>;
    expect(first['salt'], isNot(second['salt']));
    expect(first['nonce'], isNot(second['nonce']));
    expect(base64Decode(first['salt'] as String), hasLength(16));
    expect(base64Decode(first['nonce'] as String), hasLength(12));
  });

  test(
    'wrong passphrase and modified ciphertext fail authentication',
    () async {
      final bytes = await VaultCodec.encryptDocument(
        AppData.empty(),
        _passphrase,
      );
      await expectLater(
        VaultCodec.decryptDocument(bytes, 'another long passphrase'),
        throwsA(isA<VaultUnlockException>()),
      );

      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final ciphertext = base64Decode(envelope['ciphertext'] as String);
      ciphertext[0] ^= 1;
      envelope['ciphertext'] = base64Encode(ciphertext);
      await expectLater(
        VaultCodec.decryptDocument(
          Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
          _passphrase,
        ),
        throwsA(isA<VaultUnlockException>()),
      );
    },
  );

  test('changing authenticated salt cannot yield a document', () async {
    final bytes = await VaultCodec.encryptDocument(
      AppData.empty(),
      _passphrase,
    );
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final salt = base64Decode(envelope['salt'] as String);
    salt[0] ^= 1;
    envelope['salt'] = base64Encode(salt);
    await expectLater(
      VaultCodec.decryptDocument(
        Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
        _passphrase,
      ),
      throwsA(isA<VaultUnlockException>()),
    );
  });

  test(
    'untrusted KDF work factor is rejected before expensive derivation',
    () async {
      final malformed = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'steady-through-vault',
            'version': 1,
            'cipher': 'AES-256-GCM',
            'kdf': 'PBKDF2-HMAC-SHA256',
            'iterations': 2147483647,
            'salt': base64Encode(List.filled(16, 1)),
            'nonce': base64Encode(List.filled(12, 2)),
            'ciphertext': 'AQ==',
            'tag': base64Encode(List.filled(16, 3)),
          }),
        ),
      );
      await expectLater(
        VaultCodec.decryptDocument(
          malformed,
          _passphrase,
        ).timeout(const Duration(seconds: 2)),
        throwsFormatException,
      );
    },
  );

  test(
    'oversized encrypted documents are rejected before JSON parsing',
    () async {
      final malicious = Uint8List(12 * 1024 * 1024 + 1);
      await expectLater(
        VaultCodec.decryptDocument(malicious, _passphrase),
        throwsFormatException,
      );
    },
  );

  test(
    'new encrypted documents require a twelve character passphrase',
    () async {
      await expectLater(
        VaultCodec.encryptDocument(AppData.empty(), 'short'),
        throwsArgumentError,
      );
    },
  );
}
