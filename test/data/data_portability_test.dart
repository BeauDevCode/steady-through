import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/data/data_portability.dart';
import 'package:steady_through/data/vault_codec.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/tool_feedback.dart';

class _MemoryRepository implements AppRepository {
  AppData value = AppData.empty();

  @override
  Future<AppData> load() async => value;

  @override
  Future<void> save(AppData next) async => value = next;
}

class _Gateway implements DataPortabilityGateway {
  Uint8List? picked;
  Uint8List? savedBytes;
  String? savedName;
  String? savedMimeType;
  Uri? saveResult = Uri.file('/chosen/steady-through-data.json');

  @override
  Future<Uint8List?> pickJsonBytes() async => picked;

  @override
  Future<Uri?> saveJsonFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    savedName = fileName;
    savedBytes = bytes;
    savedMimeType = mimeType;
    return saveResult;
  }
}

class _NativeSaveProbe extends FilePickerPlatform {
  final calls = <String>[];

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls.add('save');
    return null; // The person cancelled the native save dialog.
  }

  @override
  Future<void> clearTemporaryFiles() async {
    calls.add('clear');
    throw UnsupportedError('Cleanup is unavailable on this platform');
  }
}

final class _LargePickedFile extends PlatformFile {
  @override
  String get name => 'oversized.steady';
  @override
  Uri get uri => Uri.file('/picked/oversized.steady');
  @override
  Never get xFile => throw UnsupportedError('This file is a stream');
  @override
  int? lengthSync() => null;
  @override
  Future<int?> length() async => null;
  @override
  Future<Uint8List> readAsBytes() async => Uint8List(12 * 1024 * 1024 + 1);
  @override
  Stream<Uint8List> readAsByteStream() async* {
    yield Uint8List(12 * 1024 * 1024);
    yield Uint8List(1);
    throw StateError('The oversized stream should have been cancelled.');
  }
}

class _NativePickProbe extends FilePickerPlatform {
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => _LargePickedFile();

  @override
  Future<void> clearTemporaryFiles() async {}
}

Uint8List _jsonFile(Object json) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  late _MemoryRepository repository;
  late AppController controller;
  late _Gateway gateway;
  late DataPortability portability;

  setUp(() {
    repository = _MemoryRepository();
    controller = AppController(repository, AppData.empty());
    gateway = _Gateway();
    portability = DataPortability(controller, gateway: gateway);
  });
  tearDown(() => controller.dispose());

  test('encrypted restore preserves guidance and chosen steps while resetting system consent', () async {
    await controller.setTheme(ThemeChoice.dark);
    await controller.setReadingStyle(ReadingStyle.simple);
    await controller.createEvent(
      'Fictional caregiving plan',
      'A synthetic support arrangement.',
      guidanceContext: GuidanceContext.caregiving,
      starterStepIds: ['caregiving.orient', 'caregiving.plan'],
    );
    expect(controller.activeEvent!.actions, hasLength(2));
    final originalId = controller.activeEvent!.id;
    final editedActionId = controller.activeEvent!.actions.first.id;
    await controller.renameAction(
      originalId,
      editedActionId,
      'Arrange fictional Tuesday cover',
    );
    await controller.setActionDone(originalId, editedActionId, true);
    await controller.addAction(
      originalId,
      JourneyStage.reflect,
      'Write one fictional helpful detail',
    );
    final eventSnapshot = controller.activeEvent!.toJson();
    await controller.updateLearning(
      LearningData(
        enabledSources: SignalSource.values.toSet(),
        deviceOwnerConfirmed: true,
        pausedByUser: true,
      ),
    );

    for (final tool in SupportTool.values) {
      for (final rating in ToolRating.values) {
        await controller.recordToolFeedback(tool, rating, expectedRevision: 0);
      }
    }
    await controller.updateToolFeedbackOptions(
      showPrompts: false,
      useSuggestions: false,
      expectedRevision: 0,
    );
    final feedbackSnapshot = controller.data.toolFeedback.toJson();

    await portability.exportData(passphrase: 'a separate export passphrase');
    final exported = await VaultCodec.decryptDocument(
      gateway.savedBytes!,
      'a separate export passphrase',
    );
    expect(exported.toolFeedback.toJson(), feedbackSnapshot);
    expect(exported.events.single.toJson(), eventSnapshot);
    expect(exported.theme, ThemeChoice.dark);
    expect(exported.readingStyle, ReadingStyle.simple);
    expect(exported.learning.enabledSources, SignalSource.values.toSet());
    expect(exported.learning.deviceOwnerConfirmed, isTrue);
    expect(exported.learning.pausedByUser, isTrue);

    await controller.createEvent('Fictional later event', 'Replace on import');
    gateway.picked = gateway.savedBytes;
    var confirmations = 0;
    expect(
      await portability.importData(
        requestPassphrase: () async => 'a separate export passphrase',
        confirm: (replacement) async {
          confirmations++;
          expect(replacement.toolFeedback.toJson(), feedbackSnapshot);
          expect(replacement.events.single.toJson(), eventSnapshot);
          expect(
            replacement.learning.enabledSources,
            SignalSource.values.toSet(),
          );
          expect(replacement.learning.deviceOwnerConfirmed, isTrue);
          return true;
        },
      ),
      isTrue,
    );

    expect(confirmations, 1);
    expect(controller.data.toolFeedback.toJson(), feedbackSnapshot);
    expect(controller.data.events, hasLength(1));
    expect(controller.data.activeEventId, originalId);
    expect(controller.activeEvent!.actions, hasLength(3));
    expect(controller.activeEvent!.toJson(), eventSnapshot);
    expect(controller.data.theme, ThemeChoice.dark);
    expect(controller.data.readingStyle, ReadingStyle.simple);
    expect(controller.data.learning.enabledSources, {
      SignalSource.checkIns,
      SignalSource.inApp,
    });
    expect(controller.data.learning.deviceOwnerConfirmed, isFalse);
    expect(controller.data.learning.pausedByUser, isTrue);
    expect(repository.value.toJson(), controller.data.toJson());

    await controller.clearLearning();
    expect(controller.data.toolFeedback.toJson(), feedbackSnapshot);
    expect(controller.activeEvent!.toJson(), eventSnapshot);
    expect(controller.data.activeEventId, originalId);
    expect(controller.data.theme, ThemeChoice.dark);
    expect(controller.data.readingStyle, ReadingStyle.simple);
    expect(controller.data.learning.toJson(), LearningData().toJson());
    expect(repository.value.toJson(), controller.data.toJson());
  });

  test(
    'invalid version four guidance context is rejected before confirmation',
    () async {
      await controller.createEvent('Fictional existing event', 'Keep this');
      final visibleBefore = controller.data.toJson();
      final savedBefore = repository.value.toJson();
      final document = controller.data.toJson();
      expect(document['version'], 4);
      (document['events'] as List).first['guidanceContext'] =
          'unsupported-context';
      gateway.picked = _jsonFile(document);
      var confirmations = 0;

      await expectLater(
        portability.importData(
          confirm: (_) async {
            confirmations++;
            return true;
          },
        ),
        throwsFormatException,
      );

      expect(confirmations, 0);
      expect(controller.data.toJson(), visibleBefore);
      expect(repository.value.toJson(), savedBefore);
    },
  );

  test('invalid import leaves existing data and storage untouched', () async {
    await controller.createEvent('Keep this', '');
    final before = controller.data.toJson();
    gateway.picked = _jsonFile({...AppData.empty().toJson(), 'version': 99});
    var confirmations = 0;

    await expectLater(
      portability.importData(
        confirm: (_) async {
          confirmations++;
          return true;
        },
      ),
      throwsFormatException,
    );

    expect(confirmations, 0);
    expect(controller.data.toJson(), before);
    expect(repository.value.toJson(), before);
  });

  test('malformed nested record never reaches confirmation', () async {
    gateway.picked = _jsonFile({
      ...AppData.empty().toJson(),
      'checkIns': [
        {
          'id': 'orphan',
          'eventId': 'missing',
          'createdAt': '2026-11-05T00:00:00Z',
          'feeling': 'Uneasy',
        },
      ],
    });
    var confirmations = 0;

    await expectLater(
      portability.importData(
        confirm: (_) async {
          confirmations++;
          return true;
        },
      ),
      throwsFormatException,
    );

    expect(confirmations, 0);
    expect(controller.data.checkIns, isEmpty);
  });

  test(
    'cancelled picker and declined confirmation preserve current data',
    () async {
      await controller.createEvent('Existing', '');
      final before = controller.data.toJson();
      var confirmations = 0;

      expect(
        await portability.importData(
          confirm: (_) async {
            confirmations++;
            return true;
          },
        ),
        isFalse,
      );
      expect(confirmations, 0);

      gateway.picked = _jsonFile(
        AppData(
          people: [TrustedPerson(id: 'p1', name: 'Alex', phone: '555-0100')],
        ).toJson(),
      );
      expect(
        await portability.importData(confirm: (_) async => false),
        isFalse,
      );
      expect(controller.data.toJson(), before);
      expect(repository.value.toJson(), before);
    },
  );

  test('confirmed import replaces the complete local document', () async {
    await controller.createEvent('Old event', '');
    gateway.picked = _jsonFile(
      AppData(
        people: [TrustedPerson(id: 'p1', name: 'Alex', phone: '555-0100')],
        theme: ThemeChoice.dark,
      ).toJson(),
    );

    expect(
      await portability.importData(
        confirm: (replacement) async {
          expect(replacement.people.single.name, 'Alex');
          return true;
        },
      ),
      isTrue,
    );

    expect(controller.data.events, isEmpty);
    expect(controller.data.people.single.name, 'Alex');
    expect(repository.value.theme, ThemeChoice.dark);
  });

  test('unreadable JSON bytes do not replace current data', () async {
    await controller.createEvent('Keep this', '');
    gateway.picked = Uint8List.fromList([0xff, 0xfe]);

    await expectLater(
      portability.importData(confirm: (_) async => true),
      throwsFormatException,
    );
    expect(controller.activeEvent?.title, 'Keep this');
  });

  test(
    'export sends complete encrypted records to the chosen steady file',
    () async {
      await controller.createEvent('Important event', '');
      await controller.addPerson('Alex', '555-0100');

      final location = await portability.exportData(
        passphrase: 'a separate export passphrase',
      );

      expect(location, Uri.file('/chosen/steady-through-data.json'));
      expect(gateway.savedName, 'steady-through-data.steady');
      expect(gateway.savedMimeType, 'application/octet-stream');
      expect(
        utf8.decode(gateway.savedBytes!),
        isNot(contains('Important event')),
      );
      final exported = await VaultCodec.decryptDocument(
        gateway.savedBytes!,
        'a separate export passphrase',
      );
      expect(exported.events.single.title, 'Important event');
      expect(exported.people.single.phone, '555-0100');
    },
  );

  test(
    'encrypted import decrypts before asking to replace local records',
    () async {
      gateway.picked = await VaultCodec.encryptDocument(
        AppData(
          people: [TrustedPerson(id: 'p1', name: 'Private Alex')],
        ),
        'a separate export passphrase',
      );
      expect(
        await portability.importData(
          requestPassphrase: () async => 'a separate export passphrase',
          confirm: (replacement) async {
            expect(replacement.people.single.name, 'Private Alex');
            return true;
          },
        ),
        isTrue,
      );
      expect(controller.data.people.single.name, 'Private Alex');
    },
  );

  test(
    'wrong import passphrase preserves current data without confirmation',
    () async {
      await controller.createEvent('Keep this', '');
      gateway.picked = await VaultCodec.encryptDocument(
        AppData.empty(),
        'a separate export passphrase',
      );
      var confirmations = 0;
      await expectLater(
        portability.importData(
          requestPassphrase: () async => 'another long passphrase',
          confirm: (_) async {
            confirmations++;
            return true;
          },
        ),
        throwsA(isA<VaultUnlockException>()),
      );
      expect(confirmations, 0);
      expect(controller.activeEvent?.title, 'Keep this');
    },
  );

  test('cancelled encrypted import passphrase leaves records intact', () async {
    await controller.createEvent('Keep this', '');
    gateway.picked = await VaultCodec.encryptDocument(
      AppData.empty(),
      'a separate export passphrase',
    );
    expect(
      await portability.importData(
        requestPassphrase: () async => null,
        confirm: (_) async => throw StateError('Must not confirm'),
      ),
      isFalse,
    );
    expect(controller.activeEvent?.title, 'Keep this');
  });

  test('native export clears temporary data after a cancelled save', () async {
    final previous = FilePickerPlatform.instance;
    final probe = _NativeSaveProbe();
    FilePickerPlatform.instance = probe;
    addTearDown(() => FilePickerPlatform.instance = previous);

    final result = await const FilePickerDataPortabilityGateway().saveJsonFile(
      fileName: 'steady-through-data.json',
      bytes: Uint8List.fromList(utf8.encode('{"version":1}')),
      mimeType: 'application/json',
    );

    expect(result, isNull);
    expect(probe.calls, ['save', 'clear']);
  });

  test(
    'native import stops an oversized stream before reading the whole file',
    () async {
      final previous = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _NativePickProbe();
      addTearDown(() => FilePickerPlatform.instance = previous);
      await expectLater(
        const FilePickerDataPortabilityGateway().pickJsonBytes(),
        throwsFormatException,
      );
    },
  );
}
