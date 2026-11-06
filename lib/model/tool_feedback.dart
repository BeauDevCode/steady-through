/// Explicit opinions about support tools, separate from feeling learning.
enum SupportTool { grounding, breathing, pathGame }

enum ToolRating { helpful, notThisTime }

class ToolFeedback {
  ToolFeedback({
    required this.id,
    required DateTime createdAt,
    required this.tool,
    required this.rating,
  }) : createdAt = createdAt.toUtc() {
    if (id.trim().isEmpty || id.length > 200) {
      throw const FormatException(
        'tool feedback id must contain 1 to 200 characters',
      );
    }
  }

  final String id;
  final DateTime createdAt;
  final SupportTool tool;
  final ToolRating rating;

  factory ToolFeedback.fromJson(Map<String, dynamic> json) {
    _keys(json, 'tool feedback', {'id', 'createdAt', 'tool', 'rating'});
    final id = json['id'];
    if (id is! String) {
      throw const FormatException('tool feedback id must be text');
    }
    return ToolFeedback(
      id: id,
      createdAt: _timestamp(json['createdAt']),
      tool: _choice(json['tool'], SupportTool.values, 'tool feedback.tool'),
      rating: _choice(
        json['rating'],
        ToolRating.values,
        'tool feedback.rating',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'tool': tool.name,
    'rating': rating.name,
  };
}

class ToolFeedbackData {
  ToolFeedbackData({
    this.showPrompts = true,
    this.useSuggestions = true,
    List<ToolFeedback> ratings = const [],
  }) : ratings = List<ToolFeedback>.unmodifiable(ratings) {
    if (this.ratings.length > maximumRatings) {
      throw const FormatException(
        'Tool feedback contains more than 1000 ratings',
      );
    }
    final ids = <String>{};
    for (final rating in this.ratings) {
      if (!ids.add(rating.id)) {
        throw const FormatException('Duplicate tool feedback id');
      }
    }
  }

  static const maximumRatings = 1000;
  static const retentionDays = 180;

  final bool showPrompts;
  final bool useSuggestions;
  final List<ToolFeedback> ratings;

  ToolFeedbackData copyWith({
    bool? showPrompts,
    bool? useSuggestions,
    List<ToolFeedback>? ratings,
  }) => ToolFeedbackData(
    showPrompts: showPrompts ?? this.showPrompts,
    useSuggestions: useSuggestions ?? this.useSuggestions,
    ratings: ratings ?? this.ratings,
  );

  ToolFeedbackData bounded(DateTime now) =>
      copyWith(ratings: _retained(ratings, now.toUtc()));

  /// Record only a chosen opinion. Skipping or finishing creates no record.
  ToolFeedbackData record(ToolFeedback rating, {DateTime? now}) {
    if (ratings.any((existing) => existing.id == rating.id)) {
      throw const FormatException('Duplicate tool feedback id');
    }
    final at = (now ?? DateTime.now()).toUtc();
    if (rating.createdAt.isAfter(at)) {
      throw const FormatException('Future tool feedback is not accepted');
    }
    // Bound the candidate before constructing a constrained data object.
    return copyWith(ratings: _retained([...ratings, rating], at));
  }

  /// Correct an opinion without manufacturing a new observation or time.
  ToolFeedbackData correct(String id, ToolRating rating) {
    final index = ratings.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      throw StateError('This tool rating is no longer available.');
    }
    final original = ratings[index];
    if (original.rating == rating) return this;
    final changed = [...ratings];
    changed[index] = ToolFeedback(
      id: original.id,
      createdAt: original.createdAt,
      tool: original.tool,
      rating: rating,
    );
    return copyWith(ratings: changed);
  }

  ToolFeedbackData remove(String id) {
    if (!ratings.any((entry) => entry.id == id)) {
      throw StateError('This tool rating is no longer available.');
    }
    return copyWith(ratings: ratings.where((entry) => entry.id != id).toList());
  }

  factory ToolFeedbackData.fromJson(Map<String, dynamic> json) {
    _keys(json, 'toolFeedback', {'showPrompts', 'useSuggestions', 'ratings'});
    final ratings = json['ratings'];
    if (ratings is! List) {
      throw const FormatException('toolFeedback.ratings must be a list');
    }
    if (ratings.length > maximumRatings) {
      throw const FormatException(
        'Tool feedback contains more than 1000 ratings',
      );
    }
    return ToolFeedbackData(
      showPrompts: _boolean(json['showPrompts'], 'toolFeedback.showPrompts'),
      useSuggestions: _boolean(
        json['useSuggestions'],
        'toolFeedback.useSuggestions',
      ),
      ratings: [
        for (final item in ratings)
          if (item is Map<String, dynamic>)
            ToolFeedback.fromJson(item)
          else
            throw const FormatException(
              'toolFeedback.ratings must contain objects',
            ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'showPrompts': showPrompts,
    'useSuggestions': useSuggestions,
    'ratings': ratings.map((rating) => rating.toJson()).toList(),
  };
}

List<ToolFeedback> _retained(Iterable<ToolFeedback> ratings, DateTime now) {
  final cutoff = now.subtract(
    const Duration(days: ToolFeedbackData.retentionDays),
  );
  final retained =
      ratings
          .where(
            (rating) =>
                !rating.createdAt.isBefore(cutoff) &&
                !rating.createdAt.isAfter(now),
          )
          .toList()
        ..sort((a, b) {
          final order = a.createdAt.compareTo(b.createdAt);
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
  return retained.length <= ToolFeedbackData.maximumRatings
      ? retained
      : retained.sublist(retained.length - ToolFeedbackData.maximumRatings);
}

void _keys(Map<String, dynamic> json, String field, Set<String> required) {
  final actual = json.keys.toSet();
  if (required.difference(actual).isNotEmpty ||
      actual.difference(required).isNotEmpty) {
    throw FormatException('$field has missing or unexpected fields');
  }
}

bool _boolean(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

T _choice<T extends Enum>(Object? value, List<T> choices, String field) {
  for (final choice in choices) {
    if (choice.name == value) return choice;
  }
  throw FormatException('$field has an unknown value');
}

DateTime _timestamp(Object? value) {
  const error = FormatException(
    'tool feedback.createdAt must be a valid timestamp with a time zone',
  );
  if (value is! String) throw error;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null) throw error;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final calendarDay = DateTime.utc(year, month, day);
  final zone = match[7]!;
  if (calendarDay.year != year ||
      calendarDay.month != month ||
      calendarDay.day != day ||
      int.parse(match[4]!) > 23 ||
      int.parse(match[5]!) > 59 ||
      int.parse(match[6]!) > 59 ||
      (zone != 'Z' &&
          (int.parse(zone.substring(1, 3)) > 23 ||
              int.parse(zone.substring(4, 6)) > 59))) {
    throw error;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw error;
  return parsed.toUtc();
}
