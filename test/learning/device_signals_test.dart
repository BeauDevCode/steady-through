import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/learning/device_signals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('steady_through/device_signals_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'missing native adapter stays unsupported and missing, not zero',
    () async {
      final signals = DeviceSignals(channel: channel);
      final capabilities = await signals.capabilities();
      expect(capabilities.usageSupported, isFalse);
      expect(capabilities.motionSupported, isFalse);
      expect(capabilities.usageGranted, isFalse);
      expect(capabilities.motionGranted, isFalse);
      expect(capabilities.platformNote, isNotEmpty);
      await signals.start(usage: true, motion: true);
      final reading = await signals.read();
      expect(reading.deviceSwitches, isNull);
      expect(reading.activeMinutes, isNull);
      expect(reading.vehicleMinutes, isNull);
      expect(reading.walkingMinutes, isNull);
      expect(reading.possibleVehicle, isFalse);
      expect(reading.usageStatus, 'unsupported');
      expect(reading.motionStatus, 'unsupported');
      expect(await signals.requestMotionPermission(), isFalse);
      await signals.openUsageSettings();
      await signals.stop();
    },
  );

  test(
    'construction and reading before start never activate or query collectors',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return <String, Object?>{'deviceSwitches': 8, 'activeMinutes': 2};
      });
      final signals = DeviceSignals(channel: channel);
      final reading = await signals.read();
      expect(calls, isEmpty);
      expect(reading.deviceSwitches, isNull);
      expect(reading.activeMinutes, isNull);
      expect(reading.usageStatus, 'paused');
      expect(reading.motionStatus, 'paused');
    },
  );

  test('usage consent exposes aggregates but filters motion even if native returns it', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'read') {
        return <String, Object?>{
          'deviceSwitches': 4,
          'activeMinutes': 12.5,
          'vehicleMinutes': 3.0,
          'walkingMinutes': 7.0,
          'possibleVehicle': true,
          'usageStatus': 'observing',
          'motionStatus': 'observing',
          'appNames': <String>['private value'],
        };
      }
      return null;
    });
    final signals = DeviceSignals(channel: channel);
    await signals.start(usage: true, motion: false);
    final reading = await signals.read();
    expect(reading.deviceSwitches, 4);
    expect(reading.activeMinutes, 12.5);
    expect(reading.vehicleMinutes, isNull);
    expect(reading.walkingMinutes, isNull);
    expect(reading.possibleVehicle, isFalse);
    expect(reading.usageStatus, 'observing');
    expect(reading.motionStatus, 'paused');
    expect(calls.map((call) => call.method), <String>['start', 'read']);
    expect(calls.first.arguments, <String, bool>{
      'usage': true,
      'motion': false,
    });
  });

  test('stopping immediately masks all source values and prevents subsequent native reads', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return <String, Object?>{'deviceSwitches': 5, 'activeMinutes': 5};
    });
    final signals = DeviceSignals(channel: channel);
    await signals.start(usage: true, motion: true);
    await signals.stop();
    final reading = await signals.read();
    expect(calls, <String>['start', 'stop']);
    expect(reading.deviceSwitches, isNull);
    expect(reading.activeMinutes, isNull);
    expect(reading.usageStatus, 'paused');
    expect(reading.motionStatus, 'paused');
  });

  test(
    'denied native readings preserve missingness and permission status',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'capabilities') {
          return <String, Object?>{
            'usageSupported': true,
            'motionSupported': true,
            'usageGranted': false,
            'motionGranted': false,
            'platformNote': 'Permission required',
          };
        }
        if (call.method == 'requestMotionPermission') return false;
        return <String, Object?>{
          'usageStatus': 'permission-denied',
          'motionStatus': 'permission-denied',
        };
      });
      final signals = DeviceSignals(channel: channel);
      final capabilities = await signals.capabilities();
      expect(capabilities.usageSupported, isTrue);
      expect(capabilities.usageGranted, isFalse);
      expect(await signals.requestMotionPermission(), isFalse);
      await signals.start(usage: true, motion: true);
      final reading = await signals.read();
      expect(reading.activeMinutes, isNull);
      expect(reading.walkingMinutes, isNull);
      expect(reading.usageStatus, 'permission-denied');
      expect(reading.motionStatus, 'permission-denied');
    },
  );

  test('malformed or impossible native aggregates stay missing', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <String, Object?>{
        'deviceSwitches': -2,
        'activeMinutes': double.infinity,
        'vehicleMinutes': 61.0,
        'walkingMinutes': -0.5,
        'usageStatus': 'observing',
        'motionStatus': 'observing',
      },
    );
    final signals = DeviceSignals(channel: channel);
    await signals.start(usage: true, motion: true);
    final reading = await signals.read();
    expect(reading.deviceSwitches, isNull);
    expect(reading.activeMinutes, isNull);
    expect(reading.vehicleMinutes, isNull);
    expect(reading.walkingMinutes, isNull);
  });

  test(
    'motion source preserves uncertain vehicle flag without inventing usage',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => <String, Object?>{
          'deviceSwitches': 4,
          'activeMinutes': 2.0,
          'vehicleMinutes': 1.5,
          'walkingMinutes': 0.25,
          'possibleVehicle': true,
          'usageStatus': 'observing',
          'motionStatus': 'observing',
        },
      );
      final signals = DeviceSignals(channel: channel);
      await signals.start(usage: false, motion: true);
      final reading = await signals.read();
      expect(reading.deviceSwitches, isNull);
      expect(reading.activeMinutes, isNull);
      expect(reading.usageStatus, 'paused');
      expect(reading.vehicleMinutes, 1.5);
      expect(reading.walkingMinutes, 0.25);
      expect(reading.possibleVehicle, isTrue);
    },
  );

  test(
    'native collector errors become unavailable readings rather than values',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'read') {
          throw PlatformException(code: 'source-unavailable');
        }
        return null;
      });
      final signals = DeviceSignals(channel: channel);
      await signals.start(usage: true, motion: false);
      final reading = await signals.read();
      expect(reading.deviceSwitches, isNull);
      expect(reading.usageStatus, 'unavailable');
      expect(reading.motionStatus, 'paused');
    },
  );

  test('an older failed start cannot poison a newer consent session', () async {
    final firstEntered = Completer<void>();
    final firstResult = Completer<Object?>();
    var startCount = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') {
        startCount++;
        if (startCount == 1) {
          firstEntered.complete();
          return firstResult.future;
        }
        return null;
      }
      return <String, Object?>{
        'deviceSwitches': 2,
        'activeMinutes': 1.0,
        'usageStatus': 'observing',
      };
    });
    final signals = DeviceSignals(channel: channel);
    final oldStart = signals.start(usage: true, motion: true);
    await firstEntered.future;
    await signals.start(usage: true, motion: false);
    firstResult.completeError(PlatformException(code: 'old-session-failure'));
    await oldStart;
    final reading = await signals.read();
    expect(reading.deviceSwitches, 2);
    expect(reading.activeMinutes, 1.0);
    expect(reading.usageStatus, 'observing');
    expect(reading.motionStatus, 'paused');
  });
}
