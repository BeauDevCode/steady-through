import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/data/vault_store.dart';
import 'package:steady_through/model/app_data.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('steady-encrypted-'));
  tearDown(() => temp.deleteSync(recursive: true));

  test(
    'saves replace encrypted records with a fresh nonce each time',
    () async {
      final session = await VaultStore(temp)
          .create('a long private passphrase');
      addTearDown(session.close);
      await session.repository.save(
        AppData(
          people: [TrustedPerson(id: 'p1', name: 'Secret Alex')],
        ),
      );
      final file = File('${temp.path}/steady-through.vault');
      final firstText = await file.readAsString();
      final first = jsonDecode(firstText) as Map<String, dynamic>;
      await session.repository.save(
        AppData.empty().copyWith(theme: ThemeChoice.dark),
      );
      final second =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(firstText, isNot(contains('Secret Alex')));
      expect(first['nonce'], isNot(second['nonce']));
      expect((await session.repository.load()).theme, ThemeChoice.dark);
      expect(
        await File('${temp.path}/steady-through.vault.tmp').exists(),
        isFalse,
      );
    },
  );

  test('closed sessions reject reads and writes', () async {
    final session = await VaultStore(temp).create('a long private passphrase');
    session.close();
    await expectLater(session.repository.load(), throwsStateError);
    await expectLater(
      session.repository.save(AppData.empty()),
      throwsStateError,
    );
  });

  test(
    'purge removes encrypted residuals and every stale legacy copy',
    () async {
      final session = await VaultStore(temp)
          .create('a long private passphrase');
      addTearDown(session.close);
      await session.repository.save(AppData.empty());
      final current = File('${temp.path}/steady-through.vault');
      await current.copy('${current.path}.bak');
      await current.copy('${current.path}.tmp');
      for (final suffix in ['', '.bak', '.tmp']) {
        await File('${temp.path}/steady-through.json$suffix')
            .writeAsString('private old records');
      }

      await session.repository.purgeResidualData();
      expect(await current.exists(), isTrue);
      for (final name in [
        'steady-through.vault.bak',
        'steady-through.vault.tmp',
        'steady-through.json',
        'steady-through.json.bak',
        'steady-through.json.tmp',
      ]) {
        expect(await File('${temp.path}/$name').exists(), isFalse);
      }
    },
  );
}
