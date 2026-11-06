import 'package:flutter/material.dart';
import 'package:steady_through/model/tool_feedback.dart';

String toolName(SupportTool tool) => switch (tool) {
  SupportTool.grounding => 'Grounding',
  SupportTool.breathing => 'Breathing pace',
  SupportTool.pathGame => 'Path game',
};
IconData toolIcon(SupportTool tool) => switch (tool) {
  SupportTool.grounding => Icons.visibility_outlined,
  SupportTool.breathing => Icons.air,
  SupportTool.pathGame => Icons.route_outlined,
};
String ratingName(ToolRating rating) => switch (rating) {
  ToolRating.helpful => 'Helpful',
  ToolRating.notThisTime => 'Not this time',
};
String feedbackDate(BuildContext context, DateTime time) {
  final local = time.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}
