import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/tool_feedback.dart';
import 'package:steady_through/model/tool_feedback_summary.dart';
import 'package:steady_through/learning/learning_data.dart';

final _now = DateTime.utc(2026, 11, 6, 12);
ToolFeedback _rating(
  String id, {
  DateTime? at,
  SupportTool tool = SupportTool.grounding,
  ToolRating rating = ToolRating.helpful,
}) => ToolFeedback(id: id, createdAt: at ?? _now, tool: tool, rating: rating);

Map<String, dynamic> _legacy(int version) => {
  'version': version,
  'events': [
    {
      'id': 'event',
      'title': 'A change',
      'createdAt': '2026-11-05T12:00:00Z',
      'actions': [
        {
          'id': 'step',
          'stage': 'plan',
          'title': 'My own next step',
          'done': true,
        },
      ],
      if (version >= 3) 'guidanceContext': 'laterLife',
    },
  ],
  'activeEventId': 'event',
  'people': [],
  'checkIns': [],
  'gameRounds': [],
  'theme': 'dark',
  'readingStyle': 'simple',
  if (version >= 2) 'learning': LearningData().toJson(),
};

void main() {
  test('schema1/2/3 migrate to4 without changing plans and guide choices', () {
    for (final version in [1, 2, 3]) {
      final data = AppData.fromJson(_legacy(version));
      expect(data.toJson()['version'], 4);
      expect(data.toolFeedback.ratings, isEmpty);
      expect(data.toolFeedback.showPrompts, isTrue);
      expect(data.toolFeedback.useSuggestions, isTrue);
      expect(data.events.single.actions.single.title, 'My own next step');
      expect(data.events.single.actions.single.done, isTrue);
      expect(
        data.events.single.guidanceContext,
        version == 3 ? GuidanceContext.laterLife : GuidanceContext.general,
      );
      expect(data.theme, ThemeChoice.dark);
      expect(data.readingStyle, ReadingStyle.simple);
      expect(AppData.fromJson(data.toJson()).toJson(), data.toJson());
    }
  });

  test('earlier schemas reject injected tool feedback', () {
    for (final version in [1, 2, 3]) {
      final json = _legacy(version)
        ..['toolFeedback'] = ToolFeedbackData().toJson();
      expect(() => AppData.fromJson(json), throwsFormatException);
    }
  });

  test(
    'schema4 requires valid feedback and guidance, unknown5 is rejected',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => j.remove('toolFeedback'),
        (j) => j['toolFeedback'] = null,
        (j) => j['toolFeedback'] = [],
        (j) => j['version'] = 5,
        (j) => ((j['events'] as List).single as Map).remove('guidanceContext'),
        (j) => ((j['events'] as List).single as Map)['guidanceContext'] =
            'unknown',
      ]) {
        final json = AppData.fromJson(_legacy(3)).toJson();
        mutate(json);
        expect(() => AppData.fromJson(json), throwsFormatException);
      }
    },
  );

  test('rating JSON is strict and offset timestamps normalize to UTC', () {
    final json = {
      'id': 'offset',
      'createdAt': '2026-11-06T14:00:00+02:00',
      'tool': 'breathing',
      'rating': 'notThisTime',
    };
    final value = ToolFeedback.fromJson(json);
    expect(value.createdAt, _now);
    expect(value.createdAt.isUtc, isTrue);
    expect(value.toJson(), {
      'id': 'offset',
      'createdAt': '2026-11-06T12:00:00.000Z',
      'tool': 'breathing',
      'rating': 'notThisTime',
    });
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (j) => j['id'] = ' ',
      (j) => j['id'] = 'x' * 201,
      (j) => j['tool'] = 'unknown',
      (j) => j['rating'] = 'skip',
      (j) => j['eventId'] = 'private',
      (j) => j['createdAt'] = '2026-02-30T12:00:00Z',
      (j) => j['createdAt'] = '2026-11-06T12:00:00',
      (j) => j['createdAt'] = '2026-11-06T24:00:00Z',
      (j) => j['createdAt'] = '2026-11-06T12:00:00+24:00',
    ]) {
      final bad = Map<String, dynamic>.from(json);
      mutation(bad);
      expect(() => ToolFeedback.fromJson(bad), throwsFormatException);
    }
  });

  test(
    'settings/list validation rejects duplicate ids and malformed values',
    () {
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (j) => j['showPrompts'] = 'true',
        (j) => j.remove('useSuggestions'),
        (j) => j['ratings'] = {},
        (j) => j['ratings'] = [null],
        (j) => j['extra'] = true,
        (j) => j['ratings'] = [_rating('a').toJson(), _rating('a').toJson()],
      ]) {
        final bad = ToolFeedbackData().toJson();
        mutation(bad);
        expect(() => ToolFeedbackData.fromJson(bad), throwsFormatException);
      }
      final data = ToolFeedbackData(ratings: [_rating('a')]);
      expect(() => data.ratings.clear(), throwsUnsupportedError);
      expect(
        () => ToolFeedbackData(
          ratings: [for (var i = 0; i < 1001; i++) _rating('$i')],
        ),
        throwsFormatException,
      );
    },
  );

  test('inclusive180day retention excludes future and deterministically orders ties', () {
    final data = ToolFeedbackData(
      showPrompts: false,
      useSuggestions: false,
      ratings: [
        _rating(
          'old',
          at: _now.subtract(const Duration(days: 180, microseconds: 1)),
        ),
        _rating('edge', at: _now.subtract(const Duration(days: 180))),
        _rating('future', at: _now.add(const Duration(seconds: 1))),
        _rating('z'),
        _rating('a'),
      ],
    ).bounded(_now);
    expect(data.ratings.map((r) => r.id), ['edge', 'a', 'z']);
    expect(data.showPrompts, isFalse);
    expect(data.useSuggestions, isFalse);
  });

  test(
    'record evicts earliest of1001 without allowing duplicate/future entries',
    () {
      final data = ToolFeedbackData(
        ratings: [
          for (var i = 0; i < 1000; i++)
            _rating('$i', at: _now.subtract(Duration(seconds: 1000 - i))),
        ],
      );
      final recorded = data.record(_rating('new'), now: _now);
      expect(recorded.ratings, hasLength(1000));
      expect(recorded.ratings.first.id, '1');
      expect(recorded.ratings.last.id, 'new');
      expect(() => data.record(_rating('0'), now: _now), throwsFormatException);
      expect(
        () => data.record(
          _rating('future', at: _now.add(const Duration(seconds: 1))),
          now: _now,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'correction preserves record identity/time/tool and remove targets one id',
    () {
      final original = _rating('a');
      final other = _rating('b', tool: SupportTool.breathing);
      final data = ToolFeedbackData(ratings: [original, other]);
      final changed = data.correct('a', ToolRating.notThisTime);
      expect(changed.ratings.first.toJson(), {
        'id': 'a',
        'createdAt': _now.toIso8601String(),
        'tool': 'grounding',
        'rating': 'notThisTime',
      });
      expect(changed.ratings.last, same(other));
      expect(data.ratings.first, same(original));
      expect(changed.remove('a').ratings.single, same(other));
      expect(() => data.correct('gone', ToolRating.helpful), throwsStateError);
      expect(() => data.remove('gone'), throwsStateError);
    },
  );

  test('summary explains counts and latest opinions rather than use-weighted ranking', () {
    final data = ToolFeedbackData(
      ratings: [
        _rating('g1', at: _now.subtract(const Duration(days: 2))),
        _rating('g2', at: _now.subtract(const Duration(days: 1))),
        _rating('b1', tool: SupportTool.breathing),
        _rating('g3', rating: ToolRating.notThisTime),
      ],
    );
    final summary = ToolFeedbackSummary.fromData(data, now: _now);
    expect(summary.counts(SupportTool.grounding).helpful, 2);
    expect(summary.counts(SupportTool.grounding).notThisTime, 1);
    expect(
      summary.counts(SupportTool.grounding).latest!.rating,
      ToolRating.notThisTime,
    );
    expect(summary.suggestion!.tool, SupportTool.breathing);
    expect(summary.ratings.first.id, 'g3');
    expect(
      ToolFeedbackSummary.fromData(
        data.copyWith(useSuggestions: false),
        now: _now,
      ).suggestion,
      isNull,
    );
    expect(
      ToolFeedbackSummary.fromData(
        data.remove('g3'),
        now: _now,
      ).counts(SupportTool.grounding).latest!.rating,
      ToolRating.helpful,
    );
  });
}
