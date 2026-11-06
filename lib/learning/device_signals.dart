import 'package:flutter/services.dart';

/// Whether a native source exists and whether its separate OS grant is present.
/// These flags do not represent the person's in-app consent.
class SignalCapabilities {
  const SignalCapabilities({
    this.usageSupported = false,
    this.motionSupported = false,
    this.usageGranted = false,
    this.motionGranted = false,
    this.platformNote = '',
  });

  final bool usageSupported;
  final bool motionSupported;
  final bool usageGranted;
  final bool motionGranted;
  final String platformNote;
}

/// Only counts, durations and uncertain movement context cross this boundary.
/// A null aggregate means missing evidence; it must not be replaced with zero.
class DeviceSignalReading {
  const DeviceSignalReading({
    this.deviceSwitches,
    this.activeMinutes,
    this.vehicleMinutes,
    this.walkingMinutes,
    this.possibleVehicle = false,
    this.usageStatus = 'paused',
    this.motionStatus = 'paused',
  });

  final int? deviceSwitches;
  final double? activeMinutes;
  final double? vehicleMinutes;
  final double? walkingMinutes;
  final bool possibleVehicle;
  final String usageStatus;
  final String motionStatus;
}

/// Session-scoped adapter. Construction never requests a permission or starts a
/// collector. The owner must call stop on lock, backgrounding and consent loss.
class DeviceSignals {
  DeviceSignals({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('steady_through/device_signals');

  final MethodChannel _channel;
  bool _usage = false;
  bool _motion = false;
  bool _adapterMissing = false;
  bool _startFailed = false;
  int _generation = 0;

  Future<SignalCapabilities> capabilities() async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'capabilities',
      );
      if (value == null) return _unavailableCapabilities;
      return SignalCapabilities(
        usageSupported: value['usageSupported'] == true,
        motionSupported: value['motionSupported'] == true,
        usageGranted:
            value['usageSupported'] == true && value['usageGranted'] == true,
        motionGranted:
            value['motionSupported'] == true && value['motionGranted'] == true,
        platformNote: value['platformNote'] is String
            ? value['platformNote'] as String
            : '',
      );
    } on MissingPluginException {
      return _unavailableCapabilities;
    } on PlatformException {
      return const SignalCapabilities(
        platformNote: 'Device sources are temporarily unavailable.',
      );
    }
  }

  static const _unavailableCapabilities = SignalCapabilities(
    platformNote: 'System usage and motion sources are unavailable on this platform. Manual and in-app sources remain available.',
  );

  /// Opens Android's usage-access settings only after an explicit user action.
  Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageSettings');
    } on MissingPluginException {
      // There is no equivalent grant on unsupported platforms.
    }
  }

  Future<bool> requestMotionPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestMotionPermission') ==
          true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> start({required bool usage, required bool motion}) async {
    _generation++;
    final generation = _generation;
    _usage = usage;
    _motion = motion;
    _startFailed = false;
    _adapterMissing = false;
    try {
      await _channel.invokeMethod<void>('start', <String, bool>{
        'usage': usage,
        'motion': motion,
      });
    } on MissingPluginException {
      if (generation == _generation) _adapterMissing = true;
    } on PlatformException {
      if (generation == _generation) _startFailed = true;
    }
  }

  Future<DeviceSignalReading> read() async {
    if (!_usage && !_motion) return const DeviceSignalReading();
    if (_adapterMissing) return _emptyReading('unsupported');
    if (_startFailed) return _emptyReading('unavailable');
    final generation = _generation;
    try {
      final value = await _channel.invokeMapMethod<String, Object?>('read');
      if (generation != _generation) return const DeviceSignalReading();
      if (value == null) return _emptyReading('unavailable');
      final usageStatus = _usage ? _status(value['usageStatus']) : 'paused';
      final motionStatus = _motion ? _status(value['motionStatus']) : 'paused';
      final usageReadable = _usage && _readable(usageStatus);
      final motionReadable = _motion && _readable(motionStatus);
      return DeviceSignalReading(
        deviceSwitches: usageReadable
            ? _switches(value['deviceSwitches'])
            : null,
        activeMinutes: usageReadable ? _minutes(value['activeMinutes']) : null,
        vehicleMinutes: motionReadable
            ? _minutes(value['vehicleMinutes'])
            : null,
        walkingMinutes: motionReadable
            ? _minutes(value['walkingMinutes'])
            : null,
        possibleVehicle: motionReadable && value['possibleVehicle'] == true,
        usageStatus: usageStatus,
        motionStatus: motionStatus,
      );
    } on MissingPluginException {
      if (generation != _generation) return const DeviceSignalReading();
      return _emptyReading('unsupported');
    } on PlatformException {
      if (generation != _generation) return const DeviceSignalReading();
      return _emptyReading('unavailable');
    }
  }

  Future<void> stop() async {
    _generation++;
    _usage = false;
    _motion = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Unsupported platforms never installed a collector.
    }
  }

  DeviceSignalReading _emptyReading(String status) => DeviceSignalReading(
    usageStatus: _usage ? status : 'paused',
    motionStatus: _motion ? status : 'paused',
  );

  static bool _readable(String value) =>
      const {'observing', 'session-only', 'last-hour'}.contains(value);

  static String _status(Object? value) =>
      const {
        'observing',
        'session-only',
        'last-hour',
        'paused',
        'unsupported',
        'unavailable',
        'permission-denied',
        'awaiting-data',
      }.contains(value)
      ? value as String
      : 'unavailable';

  static int? _switches(Object? value) {
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        value > 10000 ||
        value != value.roundToDouble()) {
      return null;
    }
    return value.toInt();
  }

  static double? _minutes(Object? value) {
    if (value is! num || !value.isFinite || value < 0 || value > 60) {
      return null;
    }
    return value.toDouble();
  }
}
