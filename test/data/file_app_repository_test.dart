import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/data/file_app_repository.dart';
import 'package:steady_through/model/app_data.dart';

void main() {
  late Directory temp;
  late FileAppRepository repository;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('steady-through-test-');
    repository = FileAppRepository(temp);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('first load returns an empty document', () async {
    final data = await repository.load();
    expect(data.events, isEmpty);
    expect(data.activeEventId, isNull);
  });

  test('saved data survives a new repository instance', () async {
    final data = AppData.empty().copyWith(theme: ThemeChoice.dark);
    await repository.save(data);

    final reloaded = await FileAppRepository(temp).load();
    expect(reloaded.theme, ThemeChoice.dark);
  });

  test('invalid JSON is reported and left untouched', () async {
    final file = File('${temp.path}/steady-through.json');
    await file.writeAsString('{not json');

    await expectLater(repository.load(), throwsFormatException);
    expect(await file.readAsString(), '{not json');
  });

  test('valid save replaces the file with complete JSON', () async {
    await repository.save(AppData.empty().copyWith(theme: ThemeChoice.light));
    await repository.save(AppData.empty().copyWith(theme: ThemeChoice.dark));

    final file = File('${temp.path}/steady-through.json');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(json['theme'], 'dark');
    expect(json['version'], 1);
    expect(await FileAppRepository(temp).load(), isA<AppData>());
  });
}
