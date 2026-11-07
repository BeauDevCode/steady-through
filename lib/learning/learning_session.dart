import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:steady_through/app/app_controller.dart';

import 'device_signals.dart';
import 'learning_data.dart';
import 'pattern_engine.dart';

/// Only aggregate, consented inputs live here. Individual taps and app names
/// are never retained. A labelled snapshot enters the encrypted app document.
class LearningSession extends ChangeNotifier {
  LearningSession(this.controller, {DeviceSignals? signals})
    : signals = signals ?? DeviceSignals() {
    _signature = _sourceSignature;
    _knownRoundIds = controller.data.gameRounds
        .map((round) => round.id)
        .toSet();
    _replacementRevision = controller.replacementRevision;
    controller.addListener(_onDataChanged);
  }
  final AppController controller;
  final DeviceSignals signals;
  final PersonalPatternEngine _engine = PersonalPatternEngine();
  SignalCapabilities capabilities = const SignalCapabilities();
  DeviceSignalReading reading = const DeviceSignalReading();
  String? sourceError;
  bool _stopUnconfirmed = false;
  Future<void> _sync = Future<void>.value();
  Timer? _poll;
  Future<void>? _refreshing;
  bool _foreground = true;
  Future<void>? _closing;
  bool _closed = false;
  late String _signature;
  late Set<String> _knownRoundIds;
  late int _replacementRevision;
  int _generation = 0;
  int _taps = 0, _navigation = 0, _backtracks = 0, _restarts = 0;
  LearningExample? _undoableMoment;

  LearningExample? get undoableMoment => _closed ? null : _undoableMoment;

  LearningData get data => controller.data.learning;
  bool get paused => data.pausedByUser || !_foreground;
  String get _sourceSignature =>
      '${(data.enabledSources.map((s) => s.name).toList()..sort()).join(',')}:${data.pausedByUser}';

  SignalSnapshot get snapshot => SignalSnapshot(
    observedAt: DateTime.now().toUtc(),
    features: {
      if (!paused && data.enabledSources.contains(SignalSource.inApp)) ...{
        'tapCount': _taps.toDouble(),
        'navigationChanges': _navigation.toDouble(),
        'backtracks': _backtracks.toDouble(),
        'restarts': _restarts.toDouble(),
      },
      if (!paused &&
          data.enabledSources.contains(SignalSource.deviceUsage)) ...{
        if (reading.deviceSwitches != null)
          'deviceSwitches': reading.deviceSwitches!.toDouble(),
        if (reading.activeMinutes != null)
          'activeMinutes': reading.activeMinutes!,
      },
      if (!paused && data.enabledSources.contains(SignalSource.motion)) ...{
        if (reading.vehicleMinutes != null)
          'vehicleMinutes': reading.vehicleMinutes!,
        if (reading.walkingMinutes != null)
          'walkingMinutes': reading.walkingMinutes!,
      },
    },
    possibleVehicle:
        !paused &&
        data.enabledSources.contains(SignalSource.motion) &&
        reading.possibleVehicle,
  );

  PatternInsight get insight => _engine.assess(data, snapshot);

  Future<void> initialize({bool active = true}) async {
    _foreground = active;
    capabilities = await signals.capabilities();
    await _queueSync();
  }

  void recordTap() {
    if (_closed ||
        paused ||
        !data.enabledSources.contains(SignalSource.inApp)) {
      return;
    }
    if (_taps < 10000) _taps++;
    notifyListeners();
  }

  void recordNavigation() {
    if (_closed ||
        paused ||
        !data.enabledSources.contains(SignalSource.inApp)) {
      return;
    }
    if (_navigation < 10000) _navigation++;
    notifyListeners();
  }

  void _onDataChanged() {
    if (_closed) return;
    final replaced = _replacementRevision != controller.replacementRevision;
    _replacementRevision = controller.replacementRevision;
    if (replaced ||
        !data.examples.any((example) => identical(example, _undoableMoment))) {
      _undoableMoment = null;
    }
    if (replaced || _signature != _sourceSignature) {
      _signature = _sourceSignature;
      _resetWindow();
      _queueSync();
    }
    final rounds = controller.data.gameRounds;
    if (!replaced &&
        !paused &&
        data.enabledSources.contains(SignalSource.inApp)) {
      for (final round in rounds.where(
        (round) => !_knownRoundIds.contains(round.id),
      )) {
        _backtracks = (_backtracks + round.backtracks).clamp(0, 10000);
        _restarts = (_restarts + round.restarts).clamp(0, 10000);
      }
    }
    _knownRoundIds = rounds.map((round) => round.id).toSet();
    notifyListeners();
  }

  Future<void> setSources(
    Set<SignalSource> sources, {
    bool deviceOwnerConfirmed = false,
  }) async {
    final selectedSources = Set<SignalSource>.of(sources);
    if ((selectedSources.contains(SignalSource.deviceUsage) ||
            selectedSources.contains(SignalSource.motion)) &&
        !deviceOwnerConfirmed) {
      throw ArgumentError(
        'Confirm that this is your device before enabling a system source.',
      );
    }
    await controller.updateLearning(
      (current) => current.copyWith(
        enabledSources: selectedSources,
        deviceOwnerConfirmed: deviceOwnerConfirmed,
      ),
      isActive: () => !_closed,
    );
    await _sync;
  }

  Future<void> _queueSync() {
    final generation = ++_generation;
    _sync = _sync.then((_) async {
      if (_closed || generation != _generation) return;
      var stopped = false;
      try {
        _poll?.cancel();
        await signals.stop();
        stopped = true;
        _stopUnconfirmed = false;
        sourceError = null;
        if (_closed || paused || generation != _generation) {
          if (!_closed) notifyListeners();
          return;
        }
        final usage = data.enabledSources.contains(SignalSource.deviceUsage);
        final motion = data.enabledSources.contains(SignalSource.motion);
        if (usage || motion) {
          await signals.start(usage: usage, motion: motion);
          await refresh();
          if (!_closed && !paused && generation == _generation) {
            _poll = Timer.periodic(Duration(seconds: motion ? 5 : 60), (_) {
              unawaited(
                refresh().catchError((Object _) {
                  if (!_closed) {
                    sourceError = 'Readings are temporarily unavailable. Please try again.';
                    notifyListeners();
                  }
                }),
              );
            });
          }
        }
      } catch (_) {
        _stopUnconfirmed = !stopped;
        sourceError = stopped
            ? 'A device source could not be updated. Pause learning and try again.'
            : 'The app could not confirm that device collection stopped. Move the app to the background, then try again.';
      }
      if (!_closed) notifyListeners();
    });
    return _sync;
  }

  Future<void> refresh() {
    if (_closed || paused) return Future.value();
    return _refreshing ??= _readSignals().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<void> _readSignals() async {
    final generation = _generation;
    final nextCapabilities = await signals.capabilities();
    final next = await signals.read();
    if (_closed || paused || generation != _generation) return;
    capabilities = nextCapabilities;
    reading = next;
    if (!_stopUnconfirmed) sourceError = null;
    notifyListeners();
  }

  Future<void> requestUsageAccess() async {
    await signals.openUsageSettings();
  }

  Future<bool> requestMotionAccess() async {
    final granted = await signals.requestMotionPermission();
    capabilities = await signals.capabilities();
    await _queueSync();
    return granted;
  }

  Future<void> saveFeeling(FeelingLabel label) async {
    final revision = controller.replacementRevision;
    final generation = _generation;
    bool ownsObservation() =>
        !_closed &&
        !paused &&
        generation == _generation &&
        revision == controller.replacementRevision &&
        data.enabledSources.isNotEmpty &&
        !snapshot.possibleVehicle;
    if (_closed || paused || data.enabledSources.isEmpty) {
      throw StateError('Choose a source before saving a personal example.');
    }
    if (data.enabledSources.contains(SignalSource.motion)) {
      // An observation already in flight can predate this action. Join it,
      // then request a fresh native classification before accepting a label.
      await _refreshing;
      await refresh();
      if (!ownsObservation()) {
        throw StateError('Learning is not active.');
      }
    }
    final current = snapshot;
    if (current.possibleVehicle) {
      throw StateError('Return to reflection when safely stopped.');
    }
    final saved = await controller.recordLearning(
      label,
      current,
      expectedRevision: revision,
      isActive: ownsObservation,
    );
    if (!_closed &&
        generation == _generation &&
        revision == controller.replacementRevision) {
      if (data.examples.any((example) => identical(example, saved))) {
        _undoableMoment = saved;
      }
      _resetWindow();
      notifyListeners();
    }
  }

  void _requireHistoryAccess() {
    if (_closed || !_foreground) {
      throw StateError('Unlock and return to the app to manage saved moments.');
    }
    if (snapshot.possibleVehicle) {
      throw StateError('Return to reflection when safely stopped.');
    }
  }

  Future<void> relabelMoment(String id, FeelingLabel label) async {
    _requireHistoryAccess();
    await controller.relabelLearningExample(id, label);
  }

  Future<void> deleteMoment(String id) async {
    _requireHistoryAccess();
    await controller.deleteLearningExample(id);
  }

  Future<void> undoSavedFeeling() async {
    _requireHistoryAccess();
    final saved = undoableMoment;
    if (saved == null) throw StateError('There is no saved feeling to undo.');
    await controller.deleteLearningExample(saved.id, expected: saved);
  }

  Future<CalibrationReport> review() => controller.reviewLearning();

  Future<void> clear() async {
    await controller.clearLearning();
    await _sync;
    _resetWindow();
    notifyListeners();
  }

  void _resetWindow() {
    _taps = 0;
    _navigation = 0;
    _backtracks = 0;
    _restarts = 0;
    reading = const DeviceSignalReading();
  }

  Future<void> _stopNative() async {
    _generation++;
    _poll?.cancel();
    _resetWindow();
    try {
      await signals.stop();
      _stopUnconfirmed = false;
      sourceError = null;
    } catch (_) {
      _stopUnconfirmed = true;
      sourceError = 'A device source did not confirm that it stopped.';
    }
    if (!_closed) notifyListeners();
  }

  Future<void> pause() async {
    await controller.updateLearning(
      (current) => current.copyWith(pausedByUser: true),
      isActive: () => !_closed,
    );
    await _sync;
  }

  Future<void> resume() async {
    await controller.updateLearning(
      (current) => current.copyWith(pausedByUser: false),
      isActive: () => !_closed,
    );
    await _sync;
  }

  Future<void> suspend() async {
    _foreground = false;
    await _stopNative();
  }

  Future<void> activate() async {
    if (_closed) return;
    _foreground = true;
    await _queueSync();
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _undoableMoment = null;
    controller.removeListener(_onDataChanged);
    await _stopNative();
    dispose();
  }
}
