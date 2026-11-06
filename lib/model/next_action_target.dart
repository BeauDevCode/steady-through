/// An ephemeral address for one existing action, scoped to its data document.
class NextActionTarget {
  const NextActionTarget({
    required this.eventId,
    required this.actionId,
    required this.replacementRevision,
  });

  final String eventId;
  final String actionId;
  final int replacementRevision;
}
