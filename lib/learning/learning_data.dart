/// On-device aggregate signals and labels chosen explicitly by the person.
/// Missing readings remain absent; they are never substituted with zero.
enum SignalSource { checkIns, inApp, deviceUsage, motion }

enum FeelingLabel { calm, tense, low, energized, unsure }

const signalMetrics = <String, SignalSource>{
  'tapCount': SignalSource.inApp,
  'navigationChanges': SignalSource.inApp,
  'backtracks': SignalSource.inApp,
  'restarts': SignalSource.inApp,
  'deviceSwitches': SignalSource.deviceUsage,
  'activeMinutes': SignalSource.deviceUsage,
  'vehicleMinutes': SignalSource.motion,
  'walkingMinutes': SignalSource.motion,
};

class SignalSnapshot {
  SignalSnapshot({
    required this.observedAt,
    Map<String, double> features = const {},
    this.possibleVehicle = false,
  }) : features = Map<String, double>.unmodifiable(features) {
    for (final entry in this.features.entries) {
      _validateMetric(entry.key, entry.value);
    }
  }

  final DateTime observedAt;
  final Map<String, double> features;
  final bool possibleVehicle;

  SignalSnapshot forSources(Set<SignalSource> sources) => SignalSnapshot(
    observedAt: observedAt,
    features: {
      for (final entry in features.entries)
        if (sources.contains(signalMetrics[entry.key])) entry.key: entry.value,
    },
    possibleVehicle: sources.contains(SignalSource.motion) && possibleVehicle,
  );

  factory SignalSnapshot.fromJson(Map<String, dynamic> json) {
    _keys(json, 'snapshot', {'observedAt', 'features', 'possibleVehicle'});
    return SignalSnapshot(
      observedAt: _date(json['observedAt'], 'snapshot.observedAt'),
      features: _metrics(json['features'], 'snapshot.features'),
      possibleVehicle: _bool(
        json['possibleVehicle'],
        'snapshot.possibleVehicle',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'observedAt': observedAt.toIso8601String(),
    'features': Map<String, double>.from(features),
    'possibleVehicle': possibleVehicle,
  };
}

class LearningExample {
  LearningExample({
    required this.id,
    required this.createdAt,
    required this.label,
    required this.snapshot,
  }) {
    if (id.trim().isEmpty || id.length > 200) {
      throw const FormatException(
        'learning example id must contain 1 to 200 characters',
      );
    }
    if (snapshot.observedAt.isAfter(createdAt)) {
      throw const FormatException(
        'learning snapshot must not follow its label',
      );
    }
  }

  final String id;
  final DateTime createdAt;
  final FeelingLabel label;
  final SignalSnapshot snapshot;

  factory LearningExample.fromJson(Map<String, dynamic> json) {
    _keys(json, 'learning example', {'id', 'createdAt', 'label', 'snapshot'});
    final id = json['id'];
    if (id is! String) {
      throw const FormatException('learning example id must be text');
    }
    return LearningExample(
      id: id,
      createdAt: _date(json['createdAt'], 'learning example.createdAt'),
      label: _choice(
        json['label'],
        FeelingLabel.values,
        'learning example.label',
      ),
      snapshot: SignalSnapshot.fromJson(
        _object(json['snapshot'], 'learning example.snapshot'),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'label': label.name,
    'snapshot': snapshot.toJson(),
  };
}

/// Frozen aggregate parameters from an adopted chronological calibration.
/// These describe personal comparisons, not clinical probabilities.
class CalibratedPattern {
  CalibratedPattern({
    required this.trainedFrom,
    required this.trainedThrough,
    required this.distinctDays,
    required Map<FeelingLabel, Map<String, double>> centroids,
    required Map<String, double> scales,
    required Map<FeelingLabel, int> sampleCounts,
  }) : centroids = Map.unmodifiable({
         for (final entry in centroids.entries)
           entry.key: Map<String, double>.unmodifiable(entry.value),
       }),
       scales = Map<String, double>.unmodifiable(scales),
       sampleCounts = Map<FeelingLabel, int>.unmodifiable(sampleCounts) {
    if (trainedThrough.isBefore(trainedFrom) ||
        distinctDays < 7 ||
        this.centroids.length < 2 ||
        this.scales.length < 2 ||
        this.centroids.containsKey(FeelingLabel.unsure) ||
        this.sampleCounts.length != this.centroids.length) {
      throw const FormatException('Invalid calibrated pattern coverage');
    }
    for (final entry in this.scales.entries) {
      if (!signalMetrics.containsKey(entry.key) ||
          !entry.value.isFinite ||
          entry.value <= 0) {
        throw const FormatException('Invalid calibrated pattern scale');
      }
    }
    for (final entry in this.centroids.entries) {
      if ((this.sampleCounts[entry.key] ?? 0) < 5 ||
          !_sameKeys(entry.value, this.scales)) {
        throw const FormatException(
          'Invalid calibrated pattern class coverage',
        );
      }
      for (final feature in entry.value.entries) {
        _validateMetric(feature.key, feature.value, aggregate: true);
      }
    }
  }

  final DateTime trainedFrom;
  final DateTime trainedThrough;
  final int distinctDays;
  final Map<FeelingLabel, Map<String, double>> centroids;
  final Map<String, double> scales;
  final Map<FeelingLabel, int> sampleCounts;

  factory CalibratedPattern.fromJson(Map<String, dynamic> json) {
    _keys(json, 'calibrated pattern', {
      'trainedFrom',
      'trainedThrough',
      'distinctDays',
      'centroids',
      'scales',
      'sampleCounts',
    });
    final centroidsJson = _object(
      json['centroids'],
      'calibrated pattern.centroids',
    );
    final countsJson = _object(
      json['sampleCounts'],
      'calibrated pattern.sampleCounts',
    );
    return CalibratedPattern(
      trainedFrom: _date(json['trainedFrom'], 'calibrated pattern.trainedFrom'),
      trainedThrough: _date(
        json['trainedThrough'],
        'calibrated pattern.trainedThrough',
      ),
      distinctDays: _int(
        json['distinctDays'],
        'calibrated pattern.distinctDays',
      ),
      centroids: {
        for (final entry in centroidsJson.entries)
          _choice(
            entry.key,
            FeelingLabel.values,
            'calibrated pattern.label',
          ): _metrics(
            entry.value,
            'calibrated pattern.centroid',
            aggregate: true,
          ),
      },
      scales: _metrics(
        json['scales'],
        'calibrated pattern.scales',
        scales: true,
      ),
      sampleCounts: {
        for (final entry in countsJson.entries)
          _choice(
            entry.key,
            FeelingLabel.values,
            'calibrated pattern.sampleCounts.label',
          ): _int(
            entry.value,
            'calibrated pattern.sampleCounts',
          ),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'trainedFrom': trainedFrom.toIso8601String(),
    'trainedThrough': trainedThrough.toIso8601String(),
    'distinctDays': distinctDays,
    'centroids': {
      for (final entry in centroids.entries)
        entry.key.name: Map<String, double>.from(entry.value),
    },
    'scales': Map<String, double>.from(scales),
    'sampleCounts': {
      for (final entry in sampleCounts.entries) entry.key.name: entry.value,
    },
  };
}

class CalibrationState {
  CalibrationState({
    this.startedAt,
    this.lastReviewedAt,
    this.lastAdoptedAt,
    this.revision = 0,
    this.model,
    this.trainingCount = 0,
    this.heldOutCount = 0,
    this.candidateCorrect = 0,
    this.baselineCorrect = 0,
    this.lastReviewReason = '',
  }) {
    if (trainingCount < 0 ||
        heldOutCount < 0 ||
        candidateCorrect < 0 ||
        baselineCorrect < 0 ||
        trainingCount + heldOutCount > LearningData.maximumExamples ||
        candidateCorrect > heldOutCount ||
        baselineCorrect > heldOutCount ||
        lastReviewReason.length > 2048 ||
        (lastReviewedAt == null &&
            (trainingCount != 0 ||
                heldOutCount != 0 ||
                lastReviewReason.isNotEmpty)) ||
        revision < 0 ||
        (revision == 0) != (model == null) ||
        (model == null) != (lastAdoptedAt == null) ||
        (lastReviewedAt != null &&
            startedAt != null &&
            lastReviewedAt!.isBefore(startedAt!)) ||
        (lastAdoptedAt != null &&
            (lastReviewedAt == null ||
                lastAdoptedAt!.isAfter(lastReviewedAt!))) ||
        (model != null && lastAdoptedAt!.isBefore(model!.trainedThrough))) {
      throw const FormatException('Invalid calibration state');
    }
  }

  final DateTime? startedAt;
  final DateTime? lastReviewedAt;
  final DateTime? lastAdoptedAt;
  final int revision;
  final CalibratedPattern? model;
  final int trainingCount;
  final int heldOutCount;
  final int candidateCorrect;
  final int baselineCorrect;
  final String lastReviewReason;

  DateTime? get nextReviewAt =>
      (lastReviewedAt ?? startedAt)?.add(const Duration(days: 60));

  CalibrationState copyWith({
    DateTime? startedAt,
    DateTime? lastReviewedAt,
    DateTime? lastAdoptedAt,
    int? revision,
    CalibratedPattern? model,
    int? trainingCount,
    int? heldOutCount,
    int? candidateCorrect,
    int? baselineCorrect,
    String? lastReviewReason,
  }) => CalibrationState(
    startedAt: startedAt ?? this.startedAt,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    lastAdoptedAt: lastAdoptedAt ?? this.lastAdoptedAt,
    revision: revision ?? this.revision,
    model: model ?? this.model,
    trainingCount: trainingCount ?? this.trainingCount,
    heldOutCount: heldOutCount ?? this.heldOutCount,
    candidateCorrect: candidateCorrect ?? this.candidateCorrect,
    baselineCorrect: baselineCorrect ?? this.baselineCorrect,
    lastReviewReason: lastReviewReason ?? this.lastReviewReason,
  );

  factory CalibrationState.fromJson(Map<String, dynamic> json) {
    _keys(json, 'calibration', {
      'startedAt',
      'lastReviewedAt',
      'lastAdoptedAt',
      'revision',
      'model',
      'trainingCount',
      'heldOutCount',
      'candidateCorrect',
      'baselineCorrect',
      'lastReviewReason',
    });
    return CalibrationState(
      startedAt: _optionalDate(json['startedAt'], 'calibration.startedAt'),
      lastReviewedAt: _optionalDate(
        json['lastReviewedAt'],
        'calibration.lastReviewedAt',
      ),
      lastAdoptedAt: _optionalDate(
        json['lastAdoptedAt'],
        'calibration.lastAdoptedAt',
      ),
      revision: _int(json['revision'], 'calibration.revision'),
      trainingCount: _int(json['trainingCount'], 'calibration.trainingCount'),
      heldOutCount: _int(json['heldOutCount'], 'calibration.heldOutCount'),
      candidateCorrect: _int(
        json['candidateCorrect'],
        'calibration.candidateCorrect',
      ),
      baselineCorrect: _int(
        json['baselineCorrect'],
        'calibration.baselineCorrect',
      ),
      lastReviewReason: _string(
        json['lastReviewReason'],
        'calibration.lastReviewReason',
      ),
      model: json['model'] == null
          ? null
          : CalibratedPattern.fromJson(
              _object(json['model'], 'calibration.model'),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt?.toIso8601String(),
    'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    'lastAdoptedAt': lastAdoptedAt?.toIso8601String(),
    'revision': revision,
    'model': model?.toJson(),
    'trainingCount': trainingCount,
    'heldOutCount': heldOutCount,
    'candidateCorrect': candidateCorrect,
    'baselineCorrect': baselineCorrect,
    'lastReviewReason': lastReviewReason,
  };
}

class LearningData {
  LearningData({
    Set<SignalSource> enabledSources = const {},
    List<LearningExample> examples = const [],
    this.deviceOwnerConfirmed = false,
    this.pausedByUser = false,
    CalibrationState? calibration,
  }) : enabledSources = Set<SignalSource>.unmodifiable(enabledSources),
       examples = List<LearningExample>.unmodifiable(examples),
       calibration = calibration ?? CalibrationState() {
    if (!deviceOwnerConfirmed &&
        (this.enabledSources.contains(SignalSource.deviceUsage) ||
            this.enabledSources.contains(SignalSource.motion))) {
      throw const FormatException(
        'System sources require device-owner confirmation',
      );
    }
    if (this.examples.length > maximumExamples) {
      throw const FormatException('Learning contains more than 1000 examples');
    }
    final ids = <String>{};
    for (final example in this.examples) {
      if (!ids.add(example.id)) {
        throw const FormatException('Duplicate learning example id');
      }
    }
  }

  static const maximumExamples = 1000;
  static const retentionDays = 180;
  final Set<SignalSource> enabledSources;
  final List<LearningExample> examples;
  final bool deviceOwnerConfirmed;
  final bool pausedByUser;
  final CalibrationState calibration;

  DateTime? get firstExampleAt {
    if (examples.isEmpty) return null;
    return examples
        .map((e) => e.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  LearningData copyWith({
    Set<SignalSource>? enabledSources,
    List<LearningExample>? examples,
    bool? deviceOwnerConfirmed,
    bool? pausedByUser,
    CalibrationState? calibration,
  }) => LearningData(
    enabledSources: enabledSources ?? this.enabledSources,
    examples: examples ?? this.examples,
    deviceOwnerConfirmed: deviceOwnerConfirmed ?? this.deviceOwnerConfirmed,
    pausedByUser: pausedByUser ?? this.pausedByUser,
    calibration: calibration ?? this.calibration,
  );

  LearningData bounded(DateTime now) {
    final retained = _retained(examples, now);
    return copyWith(
      examples: retained,
      calibration: retained.length == examples.length
          ? calibration
          : _withoutDerivedEvidence(retained),
    );
  }

  /// Correct a report, without manufacturing a new observation or timestamp.
  LearningData relabel(String id, FeelingLabel label) {
    final index = examples.indexWhere((example) => example.id == id);
    if (index < 0) {
      throw StateError('This saved moment is no longer available.');
    }
    final original = examples[index];
    if (original.label == label) return this;
    final changed = [...examples];
    changed[index] = LearningExample(
      id: original.id,
      createdAt: original.createdAt,
      label: label,
      snapshot: original.snapshot,
    );
    return copyWith(
      examples: changed,
      calibration: _withoutDerivedEvidence(changed),
    );
  }

  LearningData remove(String id) {
    if (!examples.any((example) => example.id == id)) {
      throw StateError('This saved moment is no longer available.');
    }
    final retained = examples.where((example) => example.id != id).toList();
    return copyWith(
      examples: retained,
      calibration: _withoutDerivedEvidence(retained),
    );
  }

  CalibrationState _withoutDerivedEvidence(List<LearningExample> remaining) =>
      remaining.isEmpty
      ? CalibrationState()
      : CalibrationState(
          startedAt: calibration.startedAt,
          lastReviewedAt: calibration.lastReviewedAt,
        );

  /// Only an explicit label action calls this. Any enabled source permits that
  /// action; only metrics covered by its own source consent are retained.
  LearningData record(LearningExample example, {DateTime? now}) {
    if (enabledSources.isEmpty) {
      throw StateError('Choose a learning source before adding a label');
    }
    if (examples.any((e) => e.id == example.id)) {
      throw const FormatException('Duplicate learning example id');
    }
    final at = now ?? DateTime.now();
    if (example.createdAt.isAfter(at) ||
        example.snapshot.observedAt.isAfter(at)) {
      throw const FormatException('Future learning examples are not accepted');
    }
    final safe = LearningExample(
      id: example.id,
      createdAt: example.createdAt,
      label: example.label,
      snapshot: example.snapshot.forSources(enabledSources),
    );
    final retained = _retained([...examples, safe], at);
    final evicted = retained.length < examples.length + 1;
    final currentCalibration = evicted
        ? _withoutDerivedEvidence(retained)
        : calibration;
    return copyWith(
      examples: retained,
      calibration: currentCalibration.startedAt == null
          ? currentCalibration.copyWith(startedAt: at)
          : currentCalibration,
    );
  }

  factory LearningData.fromJson(Map<String, dynamic> json) {
    _keys(json, 'learning', {
      'enabledSources',
      'examples',
      'deviceOwnerConfirmed',
      'calibration',
      if (json.containsKey('pausedByUser')) 'pausedByUser',
    });
    final sourcesJson = json['enabledSources'];
    if (sourcesJson is! List) {
      throw const FormatException('learning.enabledSources must be a list');
    }
    final sources = <SignalSource>{};
    for (final value in sourcesJson) {
      if (!sources.add(
        _choice(value, SignalSource.values, 'learning.enabledSources'),
      )) {
        throw const FormatException('Duplicate enabled learning source');
      }
    }
    final examplesJson = json['examples'];
    if (examplesJson is! List) {
      throw const FormatException('learning.examples must be a list');
    }
    return LearningData(
      enabledSources: sources,
      examples: [
        for (final item in examplesJson)
          LearningExample.fromJson(_object(item, 'learning.examples')),
      ],
      deviceOwnerConfirmed: _bool(
        json['deviceOwnerConfirmed'],
        'learning.deviceOwnerConfirmed',
      ),
      pausedByUser: json.containsKey('pausedByUser')
          ? _bool(json['pausedByUser'], 'learning.pausedByUser')
          : false,
      calibration: CalibrationState.fromJson(
        _object(json['calibration'], 'learning.calibration'),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabledSources': [
      for (final source in SignalSource.values)
        if (enabledSources.contains(source)) source.name,
    ],
    'examples': examples.map((e) => e.toJson()).toList(),
    'deviceOwnerConfirmed': deviceOwnerConfirmed,
    'pausedByUser': pausedByUser,
    'calibration': calibration.toJson(),
  };
}

List<LearningExample> _retained(
  Iterable<LearningExample> examples,
  DateTime now,
) {
  final cutoff = now.subtract(const Duration(days: LearningData.retentionDays));
  final retained =
      examples
          .where(
            (e) =>
                !e.createdAt.isBefore(cutoff) &&
                !e.snapshot.observedAt.isBefore(cutoff) &&
                !e.createdAt.isAfter(now),
          )
          .toList()
        ..sort((a, b) {
          final order = a.createdAt.compareTo(b.createdAt);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
  return retained.length <= LearningData.maximumExamples
      ? retained
      : retained.sublist(retained.length - LearningData.maximumExamples);
}

void _validateMetric(String key, double value, {bool aggregate = false}) {
  final source = signalMetrics[key];
  final duration = key.endsWith('Minutes');
  if (source == null ||
      !value.isFinite ||
      value < 0 ||
      value > (duration ? 1440 : 1000000) ||
      (!duration && !aggregate && value.truncateToDouble() != value)) {
    throw FormatException('Invalid aggregate metric $key');
  }
}

Map<String, double> _metrics(
  Object? value,
  String field, {
  bool aggregate = false,
  bool scales = false,
}) {
  final object = _object(value, field);
  return {
    for (final entry in object.entries)
      entry.key: _metricValue(
        entry.key,
        entry.value,
        field,
        aggregate: aggregate,
        scales: scales,
      ),
  };
}

double _metricValue(
  String key,
  Object? value,
  String field, {
  bool aggregate = false,
  bool scales = false,
}) {
  if (value is! num) throw FormatException('$field must contain numbers');
  final number = value.toDouble();
  if (scales) {
    if (!signalMetrics.containsKey(key) ||
        !number.isFinite ||
        number <= 0 ||
        number > 1000000) {
      throw FormatException('$field contains an invalid scale');
    }
  } else {
    _validateMetric(key, number, aggregate: aggregate);
  }
  return number;
}

bool _sameKeys(Map a, Map b) =>
    a.length == b.length && a.keys.every(b.containsKey);
Map<String, dynamic> _object(Object? value, String field) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$field must be an object');
  }
  return value;
}

void _keys(Map<String, dynamic> json, String field, Set<String> required) {
  if (required.difference(json.keys.toSet()).isNotEmpty ||
      json.keys.toSet().difference(required).isNotEmpty) {
    throw FormatException('$field has missing or unexpected fields');
  }
}

bool _bool(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

int _int(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer');
  return value;
}

T _choice<T extends Enum>(Object? value, List<T> values, String field) {
  for (final choice in values) {
    if (value == choice.name) return choice;
  }
  throw FormatException('$field has an unknown value');
}

DateTime? _optionalDate(Object? value, String field) =>
    value == null ? null : _date(value, field);
DateTime _date(Object? value, String field) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})?$',
      ).hasMatch(value)) {
    throw FormatException('$field must be an ISO timestamp');
  }
  final parsed = DateTime.tryParse(value);
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final calendar = DateTime.utc(year, month, day);
  final offset = value.substring(value.length - 6);
  if (parsed == null ||
      calendar.year != year ||
      calendar.month != month ||
      calendar.day != day ||
      int.parse(value.substring(11, 13)) > 23 ||
      int.parse(value.substring(14, 16)) > 59 ||
      int.parse(value.substring(17, 19)) > 59 ||
      ((offset.startsWith('+') || offset.startsWith('-')) &&
          (int.parse(offset.substring(1, 3)) > 23 ||
              int.parse(offset.substring(4, 6)) > 59))) {
    throw FormatException('$field must be a valid timestamp');
  }
  return parsed;
}

String _string(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  return value;
}
