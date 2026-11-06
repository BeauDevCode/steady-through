import '../learning/learning_data.dart';
import 'guidance_context.dart';

export 'guidance_context.dart';

/// The versioned, offline data document used by Steady Through.
///
/// JSON parsing rejects malformed values so an import can be validated in full
/// before it replaces the person's current data.
enum JourneyStage { orient, settle, support, plan, reflect }

enum ThemeChoice { system, light, dark }

enum ReadingStyle { standard, simple }

enum RoundFeeling { calm, tense, neither }

class PlanAction {
  PlanAction({
    required this.id,
    required this.stage,
    required this.title,
    this.done = false,
  }) {
    _requireText(id, 'action.id');
    _requireText(title, 'action.title');
  }

  final String id;
  final JourneyStage stage;
  final String title;
  final bool done;

  factory PlanAction.fromJson(Map<String, dynamic> json) {
    _checkKeys(json, 'action', {'id', 'stage', 'title', 'done'});
    return PlanAction(
      id: _text(json['id'], 'action.id'),
      stage: _choice(json['stage'], JourneyStage.values, 'action.stage'),
      title: _text(json['title'], 'action.title'),
      done: _boolean(json['done'], 'action.done'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'stage': stage.name,
    'title': title,
    'done': done,
  };

  PlanAction copyWith({
    String? id,
    JourneyStage? stage,
    String? title,
    bool? done,
  }) => PlanAction(
    id: id ?? this.id,
    stage: stage ?? this.stage,
    title: title ?? this.title,
    done: done ?? this.done,
  );
}

class SupportEvent {
  SupportEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    this.completedAt,
    this.guidanceContext = GuidanceContext.general,
    List<PlanAction> actions = const [],
  }) : actions = List<PlanAction>.unmodifiable(actions) {
    _requireText(id, 'event.id');
    _requireText(title, 'event.title');
    if (completedAt != null && completedAt!.isBefore(createdAt)) {
      throw const FormatException('event.completedAt precedes createdAt');
    }
    _uniqueIds(this.actions.map((action) => action.id), 'event.actions');
  }

  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? completedAt;
  final GuidanceContext guidanceContext;
  final List<PlanAction> actions;

  /// The next unfinished action in path order, retaining order within a stage.
  PlanAction? get nextPendingAction {
    if (completedAt != null) return null;
    for (final stage in JourneyStage.values) {
      for (final action in actions) {
        if (action.stage == stage && !action.done) return action;
      }
    }
    return null;
  }

  factory SupportEvent.fromJson(
    Map<String, dynamic> json, {
    bool allowGuidance = true,
  }) {
    _checkKeys(
      json,
      'event',
      {'id', 'title', 'createdAt', 'actions'},
      optional: {
        'description',
        'completedAt',
        if (allowGuidance) 'guidanceContext',
      },
    );
    return SupportEvent(
      id: _text(json['id'], 'event.id'),
      title: _text(json['title'], 'event.title'),
      description: json.containsKey('description')
          ? _string(json['description'], 'event.description')
          : '',
      createdAt: _date(json['createdAt'], 'event.createdAt'),
      completedAt: _optionalDate(json['completedAt'], 'event.completedAt'),
      guidanceContext: json.containsKey('guidanceContext')
          ? _choice(
              json['guidanceContext'],
              GuidanceContext.values,
              'event.guidanceContext',
            )
          : GuidanceContext.general,
      actions: _objects(json['actions'], 'event.actions', PlanAction.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'guidanceContext': guidanceContext.name,
    'actions': actions.map((action) => action.toJson()).toList(),
  };

  SupportEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    List<PlanAction>? actions,
    GuidanceContext? guidanceContext,
  }) => SupportEvent(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    actions: actions ?? this.actions,
    guidanceContext: guidanceContext ?? this.guidanceContext,
  );
}

class TrustedPerson {
  TrustedPerson({required this.id, required this.name, this.phone}) {
    _requireText(id, 'person.id');
    _requireText(name, 'person.name');
  }

  final String id;
  final String name;
  final String? phone;

  factory TrustedPerson.fromJson(Map<String, dynamic> json) {
    _checkKeys(json, 'person', {'id', 'name'}, optional: {'phone'});
    return TrustedPerson(
      id: _text(json['id'], 'person.id'),
      name: _text(json['name'], 'person.name'),
      phone: _optionalString(json['phone'], 'person.phone'),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone};

  TrustedPerson copyWith({
    String? id,
    String? name,
    String? phone,
    bool clearPhone = false,
  }) => TrustedPerson(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: clearPhone ? null : (phone ?? this.phone),
  );
}

class CheckIn {
  CheckIn({
    required this.id,
    required this.eventId,
    required this.createdAt,
    required this.feeling,
    this.intensity,
    this.note,
  }) {
    _requireText(id, 'checkIn.id');
    _requireText(eventId, 'checkIn.eventId');
    _requireText(feeling, 'checkIn.feeling');
    if (intensity != null && (intensity! < 1 || intensity! > 5)) {
      throw const FormatException('checkIn.intensity must be 1 through 5');
    }
  }

  final String id;
  final String eventId;
  final DateTime createdAt;
  final String feeling;
  final int? intensity;
  final String? note;

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    _checkKeys(
      json,
      'checkIn',
      {'id', 'eventId', 'createdAt', 'feeling'},
      optional: {'intensity', 'note'},
    );
    return CheckIn(
      id: _text(json['id'], 'checkIn.id'),
      eventId: _text(json['eventId'], 'checkIn.eventId'),
      createdAt: _date(json['createdAt'], 'checkIn.createdAt'),
      feeling: _text(json['feeling'], 'checkIn.feeling'),
      intensity: _optionalInteger(json['intensity'], 'checkIn.intensity'),
      note: _optionalString(json['note'], 'checkIn.note'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'createdAt': createdAt.toIso8601String(),
    'feeling': feeling,
    'intensity': intensity,
    'note': note,
  };

  CheckIn copyWith({
    String? id,
    String? eventId,
    DateTime? createdAt,
    String? feeling,
    int? intensity,
    bool clearIntensity = false,
    String? note,
    bool clearNote = false,
  }) => CheckIn(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    createdAt: createdAt ?? this.createdAt,
    feeling: feeling ?? this.feeling,
    intensity: clearIntensity ? null : (intensity ?? this.intensity),
    note: clearNote ? null : (note ?? this.note),
  );
}

class GameRound {
  GameRound({
    required this.id,
    required this.createdAt,
    required this.boardId,
    required this.moves,
    required this.backtracks,
    required this.restarts,
    required this.feeling,
  }) {
    _requireText(id, 'gameRound.id');
    if (boardId < 0 || moves < 0 || backtracks < 0 || restarts < 0) {
      throw const FormatException('gameRound counts must not be negative');
    }
    if (backtracks + restarts > moves) {
      throw const FormatException('gameRound revisions exceed moves');
    }
  }

  final String id;
  final DateTime createdAt;
  final int boardId;
  final int moves;
  final int backtracks;
  final int restarts;
  final RoundFeeling feeling;

  factory GameRound.fromJson(Map<String, dynamic> json) {
    _checkKeys(json, 'gameRound', {
      'id',
      'createdAt',
      'boardId',
      'moves',
      'backtracks',
      'restarts',
      'feeling',
    });
    return GameRound(
      id: _text(json['id'], 'gameRound.id'),
      createdAt: _date(json['createdAt'], 'gameRound.createdAt'),
      boardId: _integer(json['boardId'], 'gameRound.boardId'),
      moves: _integer(json['moves'], 'gameRound.moves'),
      backtracks: _integer(json['backtracks'], 'gameRound.backtracks'),
      restarts: _integer(json['restarts'], 'gameRound.restarts'),
      feeling: _choice(
        json['feeling'],
        RoundFeeling.values,
        'gameRound.feeling',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'boardId': boardId,
    'moves': moves,
    'backtracks': backtracks,
    'restarts': restarts,
    'feeling': feeling.name,
  };

  GameRound copyWith({
    String? id,
    DateTime? createdAt,
    int? boardId,
    int? moves,
    int? backtracks,
    int? restarts,
    RoundFeeling? feeling,
  }) => GameRound(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    boardId: boardId ?? this.boardId,
    moves: moves ?? this.moves,
    backtracks: backtracks ?? this.backtracks,
    restarts: restarts ?? this.restarts,
    feeling: feeling ?? this.feeling,
  );
}

class AppData {
  AppData({
    List<SupportEvent> events = const [],
    this.activeEventId,
    List<TrustedPerson> people = const [],
    List<CheckIn> checkIns = const [],
    List<GameRound> gameRounds = const [],
    this.theme = ThemeChoice.system,
    this.readingStyle = ReadingStyle.standard,
    LearningData? learning,
  }) : learning = learning ?? LearningData(),
       events = List<SupportEvent>.unmodifiable(events),
       people = List<TrustedPerson>.unmodifiable(people),
       checkIns = List<CheckIn>.unmodifiable(checkIns),
       gameRounds = List<GameRound>.unmodifiable(gameRounds) {
    _uniqueIds(this.events.map((event) => event.id), 'events');
    _uniqueIds(
      this.events.expand((event) => event.actions).map((action) => action.id),
      'actions',
    );
    _uniqueIds(this.people.map((person) => person.id), 'people');
    _uniqueIds(this.checkIns.map((entry) => entry.id), 'checkIns');
    _uniqueIds(this.gameRounds.map((round) => round.id), 'gameRounds');
    final eventIds = this.events.map((event) => event.id).toSet();
    if (activeEventId != null && !eventIds.contains(activeEventId)) {
      throw const FormatException('activeEventId does not name an event');
    }
    if (this.checkIns.any((entry) => !eventIds.contains(entry.eventId))) {
      throw const FormatException('checkIn.eventId does not name an event');
    }
  }

  final List<SupportEvent> events;
  final String? activeEventId;
  final List<TrustedPerson> people;
  final List<CheckIn> checkIns;
  final List<GameRound> gameRounds;
  final ThemeChoice theme;
  final ReadingStyle readingStyle;
  final LearningData learning;

  factory AppData.empty() => AppData();

  factory AppData.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int || (version != 1 && version != 2 && version != 3)) {
      throw const FormatException('Unsupported data version');
    }
    _checkKeys(json, 'appData', {
      'version',
      'events',
      'activeEventId',
      'people',
      'checkIns',
      'gameRounds',
      'theme',
      'readingStyle',
      if (version >= 2) 'learning',
    });
    final learningJson = json['learning'];
    if (version >= 2 && learningJson is! Map<String, dynamic>) {
      throw const FormatException('learning must be an object');
    }
    return AppData(
      learning: version == 1
          ? LearningData()
          : LearningData.fromJson(learningJson as Map<String, dynamic>),
      events: _objects(json['events'], 'events', (eventJson) {
        if (version == 3 && !eventJson.containsKey('guidanceContext')) {
          throw const FormatException('event is missing guidanceContext');
        }
        return SupportEvent.fromJson(eventJson, allowGuidance: version == 3);
      }),
      activeEventId: _optionalString(json['activeEventId'], 'activeEventId'),
      people: _objects(json['people'], 'people', TrustedPerson.fromJson),
      checkIns: _objects(json['checkIns'], 'checkIns', CheckIn.fromJson),
      gameRounds: _objects(
        json['gameRounds'],
        'gameRounds',
        GameRound.fromJson,
      ),
      theme: _choice(json['theme'], ThemeChoice.values, 'theme'),
      readingStyle: _choice(
        json['readingStyle'],
        ReadingStyle.values,
        'readingStyle',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 3,
    'learning': learning.toJson(),
    'events': events.map((event) => event.toJson()).toList(),
    'activeEventId': activeEventId,
    'people': people.map((person) => person.toJson()).toList(),
    'checkIns': checkIns.map((entry) => entry.toJson()).toList(),
    'gameRounds': gameRounds.map((round) => round.toJson()).toList(),
    'theme': theme.name,
    'readingStyle': readingStyle.name,
  };

  AppData copyWith({
    List<SupportEvent>? events,
    String? activeEventId,
    bool clearActiveEventId = false,
    List<TrustedPerson>? people,
    List<CheckIn>? checkIns,
    List<GameRound>? gameRounds,
    ThemeChoice? theme,
    ReadingStyle? readingStyle,
    LearningData? learning,
  }) => AppData(
    learning: learning ?? this.learning,
    events: events ?? this.events,
    activeEventId: clearActiveEventId
        ? null
        : (activeEventId ?? this.activeEventId),
    people: people ?? this.people,
    checkIns: checkIns ?? this.checkIns,
    gameRounds: gameRounds ?? this.gameRounds,
    theme: theme ?? this.theme,
    readingStyle: readingStyle ?? this.readingStyle,
  );
}

void _checkKeys(
  Map<String, dynamic> json,
  String context,
  Set<String> required, {
  Set<String> optional = const {},
}) {
  final missing = required.difference(json.keys.toSet());
  if (missing.isNotEmpty) {
    throw FormatException('$context is missing ${missing.join(', ')}');
  }
  final unexpected = json.keys.toSet().difference({...required, ...optional});
  if (unexpected.isNotEmpty) {
    throw FormatException('$context has unexpected ${unexpected.join(', ')}');
  }
}

String _string(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string');
  return value;
}

String _text(Object? value, String field) {
  final result = _string(value, field);
  _requireText(result, field);
  return result;
}

void _requireText(String value, String field) {
  if (value.trim().isEmpty) throw FormatException('$field must not be empty');
}

String? _optionalString(Object? value, String field) =>
    value == null ? null : _string(value, field);

bool _boolean(Object? value, String field) {
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

int _integer(Object? value, String field) {
  if (value is! int) throw FormatException('$field must be an integer');
  return value;
}

int? _optionalInteger(Object? value, String field) =>
    value == null ? null : _integer(value, field);

DateTime _date(Object? value, String field) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})?$',
      ).hasMatch(value)) {
    throw FormatException('$field must be an ISO 8601 timestamp');
  }
  final parsed = DateTime.tryParse(value);
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final calendarDay = DateTime.utc(year, month, day);
  final offset = value.substring(value.length - 6);
  final invalidOffset =
      (offset.startsWith('+') || offset.startsWith('-')) &&
      (int.parse(offset.substring(1, 3)) > 23 ||
          int.parse(offset.substring(4, 6)) > 59);
  if (parsed == null ||
      calendarDay.year != year ||
      calendarDay.month != month ||
      calendarDay.day != day ||
      invalidOffset ||
      int.parse(value.substring(11, 13)) > 23 ||
      int.parse(value.substring(14, 16)) > 59 ||
      int.parse(value.substring(17, 19)) > 59) {
    throw FormatException('$field must be a valid timestamp');
  }
  return parsed;
}

DateTime? _optionalDate(Object? value, String field) =>
    value == null ? null : _date(value, field);

T _choice<T extends Enum>(Object? value, List<T> choices, String field) {
  if (value is String) {
    for (final choice in choices) {
      if (choice.name == value) return choice;
    }
  }
  throw FormatException('$field has an unknown value');
}

List<T> _objects<T>(
  Object? value,
  String field,
  T Function(Map<String, dynamic>) decode,
) {
  if (value is! List) throw FormatException('$field must be a list');
  return [
    for (final item in value)
      if (item is Map<String, dynamic>)
        decode(item)
      else
        throw FormatException('$field must contain objects'),
  ];
}

void _uniqueIds(Iterable<String> ids, String field) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) throw FormatException('$field has duplicate id $id');
  }
}
