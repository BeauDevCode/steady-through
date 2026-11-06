import 'package:flutter/material.dart';
import 'package:steady_through/learning/learning_data.dart';

String feelingName(FeelingLabel label) => switch (label) {
  FeelingLabel.calm => 'Calm',
  FeelingLabel.tense => 'Tense',
  FeelingLabel.low => 'Low',
  FeelingLabel.energized => 'Energized',
  FeelingLabel.unsure => 'Unsure',
};

IconData feelingIcon(FeelingLabel label) => switch (label) {
  FeelingLabel.calm => Icons.spa_outlined,
  FeelingLabel.tense => Icons.waves_rounded,
  FeelingLabel.low => Icons.cloud_outlined,
  FeelingLabel.energized => Icons.wb_sunny_outlined,
  FeelingLabel.unsure => Icons.help_outline_rounded,
};

String momentTime(BuildContext context, DateTime timestamp) {
  final local = timestamp.toLocal();
  final locale = MaterialLocalizations.of(context);
  return '${locale.formatMediumDate(local)}, ${locale.formatYear(local)} · ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

String momentContext(SignalSnapshot snapshot) {
  final sources = snapshot.features.keys
      .map((key) => signalMetrics[key])
      .toSet();
  if (snapshot.possibleVehicle) sources.add(SignalSource.motion);
  final included = <String>[
    if (sources.contains(SignalSource.inApp)) 'In-app activity',
    if (sources.contains(SignalSource.deviceUsage)) 'Device usage',
    if (sources.contains(SignalSource.motion)) 'Motion context',
  ];
  return included.isEmpty
      ? 'No aggregate readings saved'
      : included.join(' · ');
}

String metricDescription(String metric, double value) {
  final number = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  final unit = switch (metric) {
    'tapCount' => 'taps',
    'navigationChanges' => 'navigation changes',
    'backtracks' => 'game backtracks',
    'restarts' => 'game restarts',
    'deviceSwitches' => 'app activations',
    'activeMinutes' => 'active minutes',
    'vehicleMinutes' => 'possible vehicle minutes',
    'walkingMinutes' => 'walking minutes',
    _ => metric,
  };
  return '$number $unit';
}
