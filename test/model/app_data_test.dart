import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/learning/learning_data.dart';

Map<String, dynamic> validDocument() => {
  'version': 1,
  'events': [
    {
      'id': 'event-1',
      'title': 'Starting a new job',
      'description': 'First week',
      'createdAt': '2026-11-05T12:00:00.000Z',
      'completedAt': null,
      'actions': [
        {
          'id': 'action-1',
          'stage': 'orient',
          'title': 'Write down what I know',
          'done': false,
        },
      ],
    },
  ],
  'activeEventId': 'event-1',
  'people': [
    {'id': 'person-1', 'name': 'Sam', 'phone': '5550100'},
  ],
  'checkIns': [
    {
      'id': 'check-1',
      'eventId': 'event-1',
      'createdAt': '2026-11-05T12:30:00.000Z',
      'feeling': 'Unsure',
      'intensity': 3,
      'note': 'I can ask one question.',
    },
  ],
  'gameRounds': [
    {
      'id': 'round-1',
      'createdAt': '2026-11-05T12:45:00.000Z',
      'boardId': 0,
      'moves': 8,
      'backtracks': 1,
      'restarts': 0,
      'feeling': 'neither',
    },
  ],
  'theme': 'dark',
  'readingStyle': 'simple',
};

void main() {
  test('version one migrates to an off-by-default learning document', () {
    final data = AppData.fromJson(validDocument());
    expect(data.learning.enabledSources, isEmpty);
    expect(data.learning.examples, isEmpty);
    expect(data.toJson()['version'], 2);
    expect(data.toJson()['learning'], isA<Map<String, dynamic>>());
  });

  test('version two strictly requires and validates learning', () {
    final json = validDocument()..['version'] = 2;
    expect(() => AppData.fromJson(json), throwsFormatException);
    json['learning'] = LearningData().toJson();
    expect(AppData.fromJson(json).learning.examples, isEmpty);
    (json['learning'] as Map)['deviceOwnerConfirmed'] = 'yes';
    expect(() => AppData.fromJson(json), throwsFormatException);
  });

  test(
    'learning survives unrelated data copies and rejects v1 learning injection',
    () {
      final learning = LearningData(enabledSources: {SignalSource.checkIns});
      final data = AppData.empty()
          .copyWith(learning: learning)
          .copyWith(theme: ThemeChoice.dark);
      expect(data.learning.enabledSources, {SignalSource.checkIns});
      final legacy = validDocument()..['learning'] = learning.toJson();
      expect(() => AppData.fromJson(legacy), throwsFormatException);
    },
  );

  test('reads an event, check-in, person, round, and preferences', () {
    final data = AppData.fromJson(validDocument());

    expect(data.activeEventId, 'event-1');
    expect(data.events.single.title, 'Starting a new job');
    expect(data.events.single.actions.single.stage, JourneyStage.orient);
    expect(data.people.single.phone, '5550100');
    expect(data.checkIns.single.intensity, 3);
    expect(data.gameRounds.single.feeling, RoundFeeling.neither);
    expect(data.theme, ThemeChoice.dark);
    expect(data.readingStyle, ReadingStyle.simple);
  });

  test('writes stable JSON that can be read back', () {
    final original = AppData.fromJson(validDocument());
    final encoded = original.toJson();
    final decoded = AppData.fromJson(encoded);

    expect(encoded['version'], 2);
    expect((encoded['events'] as List).single['title'], 'Starting a new job');
    expect(decoded.gameRounds.single.moves, 8);
    expect(decoded.checkIns.single.eventId, 'event-1');
  });

  test('rejects unsupported versions instead of guessing', () {
    final document = validDocument()..['version'] = 3;
    expect(() => AppData.fromJson(document), throwsFormatException);
  });

  test('rejects duplicate event IDs', () {
    final document = validDocument();
    (document['events'] as List).add(
      Map<String, dynamic>.from((document['events'] as List).single),
    );
    expect(() => AppData.fromJson(document), throwsFormatException);
  });

  test('rejects an active event that is missing', () {
    final document = validDocument()..['activeEventId'] = 'missing';
    expect(() => AppData.fromJson(document), throwsFormatException);
  });

  test('rejects a check-in for a missing event', () {
    final document = validDocument();
    (document['checkIns'] as List).single['eventId'] = 'missing';
    expect(() => AppData.fromJson(document), throwsFormatException);
  });

  test('rejects an intensity outside 1 through 5', () {
    final document = validDocument();
    (document['checkIns'] as List).single['intensity'] = 6;
    expect(() => AppData.fromJson(document), throwsFormatException);
  });

  test('rejects impossible game revision counts', () {
    final document = validDocument();
    final round =
        (document['gameRounds'] as List).single as Map<String, dynamic>;
    round['moves'] = 0;
    round['backtracks'] = 1;
    expect(() => AppData.fromJson(document), throwsFormatException);

    round['backtracks'] = 0;
    round['restarts'] = 1;
    expect(() => AppData.fromJson(document), throwsFormatException);
  });

  test('starts empty with explicit version and default preferences', () {
    final empty = AppData.empty();

    expect(empty.events, isEmpty);
    expect(empty.activeEventId, isNull);
    expect(empty.people, isEmpty);
    expect(empty.checkIns, isEmpty);
    expect(empty.gameRounds, isEmpty);
    expect(empty.theme, ThemeChoice.system);
    expect(empty.readingStyle, ReadingStyle.standard);
    expect(AppData.fromJson(empty.toJson()).events, isEmpty);
  });

  test('rejects duplicate nested and top-level IDs', () {
    for (final collection in ['people', 'checkIns', 'gameRounds']) {
      final document = validDocument();
      final entries = document[collection] as List;
      document[collection] = [
        ...entries,
        Map<String, dynamic>.from(entries.single as Map),
      ];
      expect(
        () => AppData.fromJson(document),
        throwsFormatException,
        reason: collection,
      );
    }

    final document = validDocument();
    final event = (document['events'] as List).single as Map;
    final actions = event['actions'] as List;
    event['actions'] = [
      ...actions,
      Map<String, dynamic>.from(actions.single as Map),
    ];
    expect(() => AppData.fromJson(document), throwsFormatException);
  });

  test('rejects malformed fields without leaking cast errors', () {
    final cases = <void Function(Map<String, dynamic>)>[
      (document) => document.remove('theme'),
      (document) => document['events'] = 'invalid',
      (document) => document['theme'] = 'sunset',
      (document) => document['readingStyle'] = 1,
      (document) => (document['events'] as List).single['title'] = ' ',
      (document) =>
          (document['events'] as List).single['createdAt'] = 'yesterday',
      (document) => (document['events'] as List).single['createdAt'] =
          '2026-11-05T12:00:00+99:99',
      (document) =>
          ((document['events'] as List).single['actions'] as List)
                  .single['stage'] =
              'unknown',
      (document) =>
          ((document['events'] as List).single['actions'] as List)
                  .single['done'] =
              'false',
      (document) => (document['checkIns'] as List).single['intensity'] = 0,
      (document) => (document['gameRounds'] as List).single['moves'] = -1,
      (document) =>
          (document['gameRounds'] as List).single['feeling'] = 'unknown',
      (document) => document['unexpected'] = true,
    ];

    for (final corrupt in cases) {
      final document = validDocument();
      corrupt(document);
      expect(() => AppData.fromJson(document), throwsFormatException);
    }
  });

  test('copies defensively and supports clearing optional selections', () {
    final original = AppData.fromJson(validDocument());
    final events = [...original.events];
    final copied = original.copyWith(events: events, clearActiveEventId: true);
    events.clear();

    expect(copied.events, hasLength(1));
    expect(copied.activeEventId, isNull);
    expect(original.activeEventId, 'event-1');
    expect(() => copied.events.clear(), throwsUnsupportedError);
    expect(() => copied.events.single.actions.clear(), throwsUnsupportedError);
  });
}
