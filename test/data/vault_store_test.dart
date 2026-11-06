import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/data/file_app_repository.dart';
import 'package:steady_through/data/vault_codec.dart';
import 'package:steady_through/data/vault_store.dart';
import 'package:steady_through/model/app_data.dart';

const _passphrase = 'a long private passphrase';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('steady-vault-'));
  tearDown(() => temp.deleteSync(recursive: true));

  test(
    'creating a vault migrates records and removes all plaintext copies',
    () async {
      final data = AppData(
        people: [TrustedPerson(id: 'p1', name: 'Private Alex')],
      );
      await FileAppRepository(temp).save(data);
      await File('${temp.path}/steady-through.json.bak')
          .writeAsString(jsonEncode(data.toJson()));
      await File('${temp.path}/steady-through.json.tmp')
          .writeAsString(jsonEncode(data.toJson()));
      final store = VaultStore(temp);
      expect(await store.hasVault(), isFalse);

      final session = await store.create(_passphrase);
      addTearDown(session.close);
      expect(session.initialData.people.single.name, 'Private Alex');
      expect(session.cleanupWarning, isNull);
      expect(await store.hasVault(), isTrue);
      final saved = await File('${temp.path}/steady-through.vault')
          .readAsBytes();
      expect(
        (await VaultCodec.decryptDocument(
          saved,
          _passphrase,
        )).people.single.name,
        'Private Alex',
      );
      for (final suffix in ['', '.bak', '.tmp']) {
        expect(
          await File('${temp.path}/steady-through.json$suffix').exists(),
          isFalse,
        );
      }
    },
  );

  test('invalid legacy data is preserved without creating a vault', () async {
    final legacy = File('${temp.path}/steady-through.json');
    await legacy.writeAsString('{broken');
    await expectLater(
      VaultStore(temp).create(_passphrase),
      throwsFormatException,
    );
    expect(await legacy.readAsString(), '{broken');
    expect(await VaultStore(temp).hasVault(), isFalse);
  });

  test(
    'sole valid legacy temporary document migrates its private records',
    () async {
      final legacy = File('${temp.path}/steady-through.json.tmp');
      await legacy.writeAsString(
        jsonEncode(
          AppData(
            people: [TrustedPerson(id: 'p1', name: 'Only surviving Alex')],
            theme: ThemeChoice.dark,
          ).toJson(),
        ),
      );

      final session = await VaultStore(temp).create(_passphrase);
      addTearDown(session.close);
      expect(session.initialData.people.single.name, 'Only surviving Alex');
      expect(session.initialData.theme, ThemeChoice.dark);
      expect(session.cleanupWarning, contains('unfinished save'));
      final saved = await File('${temp.path}/steady-through.vault')
          .readAsBytes();
      expect(
        (await VaultCodec.decryptDocument(
          saved,
          _passphrase,
        )).people.single.name,
        'Only surviving Alex',
      );
      expect(await legacy.exists(), isFalse);
    },
  );

  test('sole invalid legacy temporary document aborts migration without deleting it', () async {
    final legacy = File('${temp.path}/steady-through.json.tmp');
    await legacy.writeAsString('{private unfinished document');

    await expectLater(
      VaultStore(temp).create(_passphrase),
      throwsFormatException,
    );
    expect(await legacy.readAsString(), '{private unfinished document');
    expect(await VaultStore(temp).hasVault(), isFalse);
    expect(await File('${temp.path}/steady-through.vault').exists(), isFalse);
  });

  test(
    'legacy backup recovery is identified before plaintext cleanup',
    () async {
      final legacy = File('${temp.path}/steady-through.json.bak');
      await legacy.writeAsString(
        jsonEncode(
          AppData(
            people: [TrustedPerson(id: 'p1', name: 'Backup Alex')],
          ).toJson(),
        ),
      );

      final session = await VaultStore(temp).create(_passphrase);
      addTearDown(session.close);
      expect(session.initialData.people.single.name, 'Backup Alex');
      expect(session.cleanupWarning, contains('backup'));
      expect(await legacy.exists(), isFalse);
    },
  );

  test('cleanup failure is visible and retried after a later unlock', () async {
    await FileAppRepository(temp)
        .save(AppData.empty().copyWith(theme: ThemeChoice.dark));
    final store = VaultStore(
      temp,
      legacyCleanup: (file) async {
        throw FileSystemException('Permission denied', file.path);
      },
    );
    final created = await store.create(_passphrase);
    expect(created.initialData.theme, ThemeChoice.dark);
    expect(created.cleanupWarning, isNotNull);
    expect(await File('${temp.path}/steady-through.json').exists(), isTrue);
    created.close();

    final unlocked = await VaultStore(temp).unlock(_passphrase);
    addTearDown(unlocked.close);
    expect(unlocked.initialData.theme, ThemeChoice.dark);
    expect(unlocked.cleanupWarning, isNull);
    expect(await File('${temp.path}/steady-through.json').exists(), isFalse);
  });

  test(
    'wrong passphrase leaves encrypted and legacy copies untouched',
    () async {
      final session = await VaultStore(temp).create(_passphrase);
      session.close();
      final vault = File('${temp.path}/steady-through.vault');
      final before = await vault.readAsBytes();
      final legacy = File('${temp.path}/steady-through.json');
      await legacy.writeAsString('keep until authenticated');
      await expectLater(
        VaultStore(temp).unlock('another long passphrase'),
        throwsA(isA<VaultUnlockException>()),
      );
      expect(await vault.readAsBytes(), before);
      expect(await legacy.readAsString(), 'keep until authenticated');
    },
  );

  test('create refuses to overwrite an existing encrypted vault', () async {
    final session = await VaultStore(temp).create(_passphrase);
    session.close();
    final before = await File('${temp.path}/steady-through.vault')
        .readAsBytes();
    await expectLater(
      VaultStore(temp).create('another long passphrase'),
      throwsStateError,
    );
    expect(
      await File('${temp.path}/steady-through.vault').readAsBytes(),
      before,
    );
  });

  test('backup-only vault can unlock and save a recoverable primary', () async {
    final session = await VaultStore(temp).create(_passphrase);
    await session.repository.save(
      AppData.empty().copyWith(theme: ThemeChoice.dark),
    );
    session.close();
    await File('${temp.path}/steady-through.vault')
        .rename('${temp.path}/steady-through.vault.bak');

    final store = VaultStore(temp);
    expect(await store.hasVault(), isTrue);
    final recovered = await store.unlock(_passphrase);
    expect(recovered.initialData.theme, ThemeChoice.dark);
    expect(recovered.cleanupWarning, contains('backup'));
    await recovered.repository.save(
      recovered.initialData.copyWith(readingStyle: ReadingStyle.simple),
    );
    recovered.close();
    final reopened = await store.unlock(_passphrase);
    addTearDown(reopened.close);
    expect(reopened.initialData.theme, ThemeChoice.dark);
    expect(reopened.initialData.readingStyle, ReadingStyle.simple);
  });

  test(
    'a corrupted primary can recover authenticated backup without reset',
    () async {
      final created = await VaultStore(temp).create(_passphrase);
      await created.repository.save(
        AppData.empty().copyWith(theme: ThemeChoice.dark),
      );
      created.close();
      await File('${temp.path}/steady-through.vault')
          .copy('${temp.path}/steady-through.vault.bak');
      await File('${temp.path}/steady-through.vault')
          .writeAsString('{tampered');

      final recovered = await VaultStore(temp).unlock(_passphrase);
      addTearDown(recovered.close);
      expect(recovered.initialData.theme, ThemeChoice.dark);
      expect(
        await File('${temp.path}/steady-through.vault').readAsString(),
        '{tampered',
      );
    },
  );

  test(
    'temporary-only encrypted data is treated as a vault and recovered safely',
    () async {
      final session = await VaultStore(temp).create(_passphrase);
      await session.repository.save(
        AppData.empty().copyWith(theme: ThemeChoice.dark),
      );
      session.close();
      await File('${temp.path}/steady-through.vault.bak').delete();
      await File('${temp.path}/steady-through.vault')
          .rename('${temp.path}/steady-through.vault.tmp');
      final store = VaultStore(temp);
      expect(await store.hasVault(), isTrue);
      await expectLater(store.create(_passphrase), throwsStateError);
      final recovered = await store.unlock(_passphrase);
      expect(recovered.cleanupWarning, contains('unfinished save'));
      await recovered.repository.save(
        recovered.initialData.copyWith(readingStyle: ReadingStyle.simple),
      );
      recovered.close();
      final reopened = await store.unlock(_passphrase);
      addTearDown(reopened.close);
      expect(reopened.initialData.theme, ThemeChoice.dark);
      expect(reopened.initialData.readingStyle, ReadingStyle.simple);
    },
  );

  test(
    'authenticated primary unlock removes old encrypted residual copies',
    () async {
      final created = await VaultStore(temp).create(_passphrase);
      await created.repository.save(
        AppData.empty().copyWith(theme: ThemeChoice.dark),
      );
      await created.repository.save(AppData.empty());
      created.close();
      final primary = File('${temp.path}/steady-through.vault');
      final backup = File('${primary.path}.bak');
      final staging = File('${primary.path}.tmp');
      expect(await backup.exists(), isTrue);
      await primary.copy(staging.path);
      await File('${temp.path}/steady-through.json')
          .writeAsString('old private records');

      final unlocked = await VaultStore(temp).unlock(_passphrase);
      addTearDown(unlocked.close);
      expect(unlocked.initialData.theme, ThemeChoice.system);
      expect(unlocked.cleanupWarning, isNull);
      expect(await primary.exists(), isTrue);
      expect(await backup.exists(), isFalse);
      expect(await staging.exists(), isFalse);
      expect(await File('${temp.path}/steady-through.json').exists(), isFalse);
    },
  );

  test(
    'recovered backup unlock preserves every encrypted recovery copy',
    () async {
      final created = await VaultStore(temp).create(_passphrase);
      await created.repository.save(
        AppData.empty().copyWith(theme: ThemeChoice.dark),
      );
      created.close();
      final primary = File('${temp.path}/steady-through.vault');
      final backup = File('${primary.path}.bak');
      final staging = File('${primary.path}.tmp');
      await primary.copy(backup.path);
      await primary.copy(staging.path);
      await primary.writeAsString('{tampered primary');
      final beforeBackup = await backup.readAsBytes();
      final beforeStaging = await staging.readAsBytes();

      final recovered = await VaultStore(temp).unlock(_passphrase);
      addTearDown(recovered.close);
      expect(recovered.initialData.theme, ThemeChoice.dark);
      expect(recovered.cleanupWarning, contains('backup'));
      expect(await primary.readAsString(), '{tampered primary');
      expect(await backup.readAsBytes(), beforeBackup);
      expect(await staging.readAsBytes(), beforeStaging);
    },
  );

  test(
    'primary unlock reports residual cleanup failure and retries next unlock',
    () async {
      final created = await VaultStore(temp).create(_passphrase);
      created.close();
      final obstruction = Directory('${temp.path}/steady-through.vault.bak');
      await obstruction.create();
      await File('${obstruction.path}/occupied')
          .writeAsString('unrecognized directory data');

      final unlocked = await VaultStore(temp).unlock(_passphrase);
      expect(unlocked.initialData.theme, ThemeChoice.system);
      expect(unlocked.cleanupWarning, isNotNull);
      expect(await obstruction.exists(), isTrue);
      unlocked.close();

      await obstruction.delete(recursive: true);
      final primary = File('${temp.path}/steady-through.vault');
      await primary.copy('${primary.path}.bak');
      final retried = await VaultStore(temp).unlock(_passphrase);
      addTearDown(retried.close);
      expect(retried.cleanupWarning, isNull);
      expect(await File('${primary.path}.bak').exists(), isFalse);
    },
  );

  test(
    'explicit reset removes encrypted and legacy files before new setup',
    () async {
      final session = await VaultStore(temp).create(_passphrase);
      session.close();
      final primary = File('${temp.path}/steady-through.vault');
      await primary.copy('${primary.path}.bak');
      await primary.copy('${primary.path}.tmp');
      for (final suffix in ['', '.bak', '.tmp']) {
        await File('${temp.path}/steady-through.json$suffix')
            .writeAsString('old private data');
      }
      final store = VaultStore(temp);
      await store.reset();
      expect(await store.hasVault(), isFalse);
      expect(await temp.list().toList(), isEmpty);
      final recreated = await store.create('a new private passphrase');
      addTearDown(recreated.close);
      expect(recreated.initialData.people, isEmpty);
    },
  );

  test('explicit reset reports a path it could not remove', () async {
    await Directory('${temp.path}/steady-through.vault').create();
    await File('${temp.path}/steady-through.vault/private-fragment')
        .writeAsString('keep for safe cleanup');
    await expectLater(
      VaultStore(temp).reset(),
      throwsA(isA<FileSystemException>()),
    );
    expect(await VaultStore(temp).hasVault(), isTrue);
    expect(
      await File('${temp.path}/steady-through.vault/private-fragment')
          .readAsString(),
      'keep for safe cleanup',
    );
  });
}
