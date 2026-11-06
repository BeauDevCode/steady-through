import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/data/app_repository.dart';
import 'package:steady_through/learning/device_signals.dart';
import 'package:steady_through/learning/learning_data.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/model/app_data.dart';

class _MemoryRepository implements AppRepository {
  @override
  Future<AppData> load() async => AppData.empty();
  @override
  Future<void> save(AppData value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/session-signals');
  late AppController controller;
  late LearningSession session;
  late List<String> calls;
  var motionSupported = false;
  var possibleVehicle = false;
  var failStop = false;
  setUp(() {
    calls = [];
    motionSupported = false;
    possibleVehicle = false;
    failStop = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'stop' && failStop) {
            throw PlatformException(code: 'stop-failed');
          }
          if (call.method == 'capabilities') {
            return {
              'usageSupported': true,
              'usageGranted': true,
              'motionSupported': motionSupported,
              'motionGranted': motionSupported,
            };
          }
          if (call.method == 'read') {
            return {
              'deviceSwitches': 4,
              'activeMinutes': 12.0,
              'usageStatus': 'last-hour',
              'motionStatus': motionSupported ? 'session-only' : 'unsupported',
              if (motionSupported) 'possibleVehicle': possibleVehicle,
              if (motionSupported) 'vehicleMinutes': 0.0,
            };
          }
          return null;
        });
    controller = AppController(_MemoryRepository(), AppData.empty());
    session = LearningSession(
      controller,
      signals: DeviceSignals(channel: channel),
    );
  });
  tearDown(() async {
    await session.close();
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'a label refreshes motion and rejects vehicle context between polls',
    () async {
      motionSupported = true;
      await session.initialize();
      await session.setSources({
        SignalSource.checkIns,
        SignalSource.motion,
      }, deviceOwnerConfirmed: true);
      expect(session.snapshot.possibleVehicle, isFalse);
      possibleVehicle = true;
      await expectLater(
        session.saveFeeling(FeelingLabel.calm),
        throwsStateError,
      );
      expect(controller.data.learning.examples, isEmpty);
      expect(session.snapshot.possibleVehicle, isTrue);
    },
  );

  test(
    'imported historical rounds never become live interaction counts',
    () async {
      await session.setSources({SignalSource.inApp});
      final historical = GameRound(
        id: 'older-round',
        createdAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        boardId: 0,
        moves: 8,
        backtracks: 3,
        restarts: 2,
        feeling: RoundFeeling.calm,
      );
      await controller.replaceData(
        controller.data.copyWith(gameRounds: [historical]),
      );
      expect(session.snapshot.features['backtracks'], 0);
      expect(session.snapshot.features['restarts'], 0);
      await controller.recordRound(
        GameRound(
          id: 'live-round',
          createdAt: DateTime.now().toUtc(),
          boardId: 0,
          moves: 8,
          backtracks: 1,
          restarts: 1,
          feeling: RoundFeeling.calm,
        ),
      );
      expect(session.snapshot.features['backtracks'], 1);
      expect(session.snapshot.features['restarts'], 1);
    },
  );

  test('vehicle context suppresses saved-history mutations', () async {
    motionSupported = true;
    await session.initialize();
    await session.setSources({
      SignalSource.checkIns,
      SignalSource.motion,
    }, deviceOwnerConfirmed: true);
    await session.saveFeeling(FeelingLabel.calm);
    final id = controller.data.learning.examples.single.id;
    possibleVehicle = true;
    await session.refresh();
    await expectLater(
      session.relabelMoment(id, FeelingLabel.low),
      throwsStateError,
    );
    await expectLater(session.deleteMoment(id), throwsStateError);
    await expectLater(session.undoSavedFeeling(), throwsStateError);
    expect(controller.data.learning.examples.single.label, FeelingLabel.calm);
  });

  test('a stop failure preserves pause but explicitly warns collection is unconfirmed', () async {
    await session.setSources({SignalSource.inApp});
    failStop = true;
    await session.pause();
    expect(session.paused, isTrue);
    expect(session.sourceError, contains('could not confirm'));
    expect(session.sourceError, contains('stopped'));
    failStop = false;
    await session.suspend();
    expect(session.sourceError, isNull);
  });

  test('sources start off and taps are aggregate only after consent', () async {
    await session.initialize();
    session.recordTap();
    expect(session.snapshot.features, isEmpty);
    expect(calls.where((call) => call == 'start'), isEmpty);
    await session.setSources({SignalSource.inApp});
    session.recordTap();
    session.recordTap();
    session.recordNavigation();
    expect(session.snapshot.features['tapCount'], 2);
    expect(session.snapshot.features['navigationChanges'], 1);
    await session.saveFeeling(FeelingLabel.calm);
    expect(
      controller.data.learning.examples.single.snapshot.features['tapCount'],
      2,
    );
    expect(session.snapshot.features['tapCount'], 0);
  });

  test('system source requires owner confirmation and revocation removes live readings', () async {
    await session.initialize();
    await expectLater(
      session.setSources({SignalSource.deviceUsage}),
      throwsArgumentError,
    );
    expect(controller.data.learning.enabledSources, isEmpty);
    await session.setSources({
      SignalSource.deviceUsage,
    }, deviceOwnerConfirmed: true);
    await session.refresh();
    expect(session.snapshot.features['deviceSwitches'], 4);
    await session.setSources({});
    expect(session.snapshot.features, isEmpty);
    expect(calls, contains('stop'));
  });

  test(
    'clearing learning leaves event notes intact and stops sources',
    () async {
      await controller.createEvent('A private event', '');
      await session.setSources({SignalSource.checkIns});
      await session.saveFeeling(FeelingLabel.tense);
      await session.clear();
      expect(controller.data.events.single.title, 'A private event');
      expect(controller.data.learning.examples, isEmpty);
      expect(controller.data.learning.enabledSources, isEmpty);
      await expectLater(
        session.saveFeeling(FeelingLabel.calm),
        throwsStateError,
      );
    },
  );
  test('a deliberate pause survives foreground changes and excludes paused game rounds', () async {
    await session.setSources({SignalSource.inApp});
    await session.pause();
    await controller.recordRound(
      GameRound(
        id: 'paused-round',
        createdAt: DateTime.now().toUtc(),
        boardId: 0,
        moves: 8,
        backtracks: 2,
        restarts: 0,
        feeling: RoundFeeling.calm,
      ),
    );
    await session.suspend();
    await session.activate();
    expect(session.paused, isTrue);
    expect(controller.data.learning.pausedByUser, isTrue);
    await session.resume();
    expect(session.snapshot.features['backtracks'], 0);
  });
}
