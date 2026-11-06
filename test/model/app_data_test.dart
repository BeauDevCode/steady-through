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
  group('guidance document migration', () {
    Map<String, dynamic> versionThree(String context) {
      final json = validDocument()
        ..['version'] = 3
        ..['learning'] = LearningData().toJson();
      (json['events'] as List).single['guidanceContext'] = context;
      return json;
    }

    test('reads and round-trips each explicit version-three context', () {
      for (final context in [
        'general',
        'schoolAndGrowing',
        'adultChanges',
        'caregiving',
        'laterLife',
      ]) {
        final decoded = AppData.fromJson(versionThree(context));
        final encoded = decoded.toJson();
        expect(encoded['version'], 4);
        expect((encoded['events'] as List).single['guidanceContext'], context);
        expect(AppData.fromJson(encoded).toJson(), encoded);
      }
    });

    test('legacy versions acquire General without changing stored actions', () {
      for (final version in [1, 2]) {
        final json = validDocument()..['version'] = version;
        if (version == 2) json['learning'] = LearningData().toJson();
        final originalActions = (json['events'] as List).single['actions'];
        final encoded = AppData.fromJson(json).toJson();
        expect(encoded['version'], 4);
        expect(
          (encoded['events'] as List).single['guidanceContext'],
          'general',
        );
        expect((encoded['events'] as List).single['actions'], originalActions);
        (json['events'] as List).single['guidanceContext'] = 'general';
        expect(() => AppData.fromJson(json), throwsFormatException);
      }
    });

    test('version three requires a valid context and valid learning', () {
      final missing = versionThree('general');
      (missing['events'] as List).single.remove('guidanceContext');
      expect(() => AppData.fromJson(missing), throwsFormatException);
      for (final value in [null, 1, true, 'General', 'unknown', '']) {
        final json = versionThree('general');
        (json['events'] as List).single['guidanceContext'] = value;
        expect(() => AppData.fromJson(json), throwsFormatException);
      }
      for (final value in [null, [], 'invalid']) {
        final json = versionThree('general')..['learning'] = value;
        expect(() => AppData.fromJson(json), throwsFormatException);
      }
      final invalidLearning = versionThree('general');
      (invalidLearning['learning'] as Map)['deviceOwnerConfirmed'] = 'yes';
      expect(() => AppData.fromJson(invalidLearning), throwsFormatException);
    });

    test('standalone event JSON accepts a context or defaults to General', () {
      final legacy = Map<String, dynamic>.from(
        (validDocument()['events'] as List).single as Map,
      );
      expect(
        SupportEvent.fromJson(legacy).toJson()['guidanceContext'],
        'general',
      );
      legacy['guidanceContext'] = 'caregiving';
      final event = SupportEvent.fromJson(legacy);
      expect(
        event
            .copyWith(title: 'Fictional revised event')
            .toJson()['guidanceContext'],
        'caregiving',
      );
    });
  });

  test('event context constructor and copies preserve or explicitly replace selection', () {
    final event = SupportEvent(
      id: 'fictional-context-event',
      title: 'Fictional event',
      createdAt: DateTime.utc(2026, 11, 6),
      guidanceContext: GuidanceContext.laterLife,
    );
    expect(
      event.copyWith(description: 'Fictional edit').guidanceContext,
      GuidanceContext.laterLife,
    );
    expect(
      event
          .copyWith(guidanceContext: GuidanceContext.adultChanges)
          .guidanceContext,
      GuidanceContext.adultChanges,
    );
    expect(
      () => SupportEvent.fromJson(event.toJson(), allowGuidance: false),
      throwsFormatException,
    );
    final legacy = event.toJson()..remove('guidanceContext');
    expect(
      SupportEvent.fromJson(legacy, allowGuidance: false).guidanceContext,
      GuidanceContext.general,
    );
  });

  group('SupportEvent.nextPendingAction', () {
    SupportEvent eventWith(List<PlanAction> actions) => SupportEvent(
      id: 'ordered-event',
      title: 'Moving house',
      createdAt: DateTime.utc(2026, 11, 5),
      actions: actions,
    );

    test('recommends late-added Orient before unfinished later stages', () {
      final event = eventWith([
        PlanAction(
          id: 'original',
          stage: JourneyStage.orient,
          title: 'Original orientation',
          done: true,
        ),
        PlanAction(
          id: 'settle',
          stage: JourneyStage.settle,
          title: 'Take a pause',
        ),
        PlanAction(
          id: 'late',
          stage: JourneyStage.orient,
          title: 'Check the moving date',
        ),
      ]);

      expect(event.nextPendingAction?.id, 'late');
      expect(event.actions.map((action) => action.id), [
        'original',
        'settle',
        'late',
      ]);
    });

    test('follows stage order even when actions are stored in reverse', () {
      var event = eventWith([
        PlanAction(
          id: 'reflect',
          stage: JourneyStage.reflect,
          title: 'Reflect',
        ),
        PlanAction(id: 'plan', stage: JourneyStage.plan, title: 'Plan'),
        PlanAction(
          id: 'support',
          stage: JourneyStage.support,
          title: 'Support',
        ),
        PlanAction(id: 'settle', stage: JourneyStage.settle, title: 'Settle'),
        PlanAction(id: 'orient', stage: JourneyStage.orient, title: 'Orient'),
      ]);

      for (final expectedId in [
        'orient',
        'settle',
        'support',
        'plan',
        'reflect',
      ]) {
        expect(event.nextPendingAction?.id, expectedId);
        event = event.copyWith(
          actions: [
            for (final action in event.actions)
              action.id == expectedId ? action.copyWith(done: true) : action,
          ],
        );
      }
      expect(event.nextPendingAction, isNull);
    });

    test('preserves stored order among unfinished actions in one stage', () {
      final event = eventWith([
        PlanAction(
          id: 'done',
          stage: JourneyStage.orient,
          title: 'Already done',
          done: true,
        ),
        PlanAction(
          id: 'z-first',
          stage: JourneyStage.orient,
          title: 'Z comes first',
        ),
        PlanAction(
          id: 'a-second',
          stage: JourneyStage.orient,
          title: 'A comes second',
        ),
      ]);

      expect(event.nextPendingAction?.id, 'z-first');
      final advanced = event.copyWith(
        actions: [
          for (final action in event.actions)
            action.id == 'z-first' ? action.copyWith(done: true) : action,
        ],
      );
      expect(advanced.nextPendingAction?.id, 'a-second');
    });

    test('returns null for an empty event', () {
      expect(eventWith([]).nextPendingAction, isNull);
    });

    test('returns null when all actions are done', () {
      final event = eventWith([
        PlanAction(
          id: 'done',
          stage: JourneyStage.reflect,
          title: 'Finished reflecting',
          done: true,
        ),
      ]);
      expect(event.nextPendingAction, isNull);
    });

    test('returns null for a completed event with unfinished actions', () {
      final event = eventWith([
        PlanAction(
          id: 'unfinished',
          stage: JourneyStage.orient,
          title: 'Still unfinished',
        ),
      ]).copyWith(completedAt: DateTime.utc(2026, 11, 6));
      expect(event.nextPendingAction, isNull);
      expect(
        event.copyWith(clearCompletedAt: true).nextPendingAction?.id,
        'unfinished',
      );
    });
  });

  test('version one migrates to an off-by-default learning document', () {
    final data = AppData.fromJson(validDocument());
    expect(data.learning.enabledSources, isEmpty);
    expect(data.learning.examples, isEmpty);
    expect(data.toJson()['version'], 4);
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

    expect(encoded['version'], 4);
    expect((encoded['events'] as List).single['title'], 'Starting a new job');
    expect(decoded.gameRounds.single.moves, 8);
    expect(decoded.checkIns.single.eventId, 'event-1');
  });

  test('rejects unsupported versions instead of guessing', () {
    final document = AppData.empty().toJson()..['version'] = 5;
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
