import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/data/data_portability.dart';
import 'package:steady_through/model/app_data.dart';

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
    'export sends a complete versioned JSON document to chosen file',
    () async {
      await controller.createEvent('Important event', '');
      await controller.addPerson('Alex', '555-0100');

      final location = await portability.exportData();

      expect(location, Uri.file('/chosen/steady-through-data.json'));
      expect(gateway.savedName, 'steady-through-data.json');
      expect(gateway.savedMimeType, 'application/json');
      final exported = AppData.fromJson(
        jsonDecode(utf8.decode(gateway.savedBytes!)) as Map<String, dynamic>,
      );
      expect(exported.events.single.title, 'Important event');
      expect(exported.people.single.phone, '555-0100');
    },
  );

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
}
