import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/game/game_feedback.dart';
import 'package:steady_through/game/path_game.dart';
import 'package:steady_through/model/app_data.dart';

GameRound round(
  int index,
  RoundFeeling feeling, {
  int moves = 6,
  int backtracks = 0,
  int restarts = 0,
}) => GameRound(
  id: 'round-$index',
  createdAt: DateTime.utc(2026, 11, index),
  boardId: 0,
  moves: moves,
  backtracks: backtracks,
  restarts: restarts,
  feeling: feeling,
);

void main() {
  test('one revision is quiet, repeated backtracks offer a neutral option', () {
    final game = PathGame();
    expect(GameFeedback.cue(game), isNull);
    game.moveTo(1);
    game.undo();
    expect(GameFeedback.cue(game), isNull);
    game.moveTo(1);
    game.undo();

    final cue = GameFeedback.cue(game);
    expect(cue, isNotNull);
    expect(cue, contains('backtrack'));
    expect(cue, contains('break'));
    expect(cue!.toLowerCase(), isNot(contains('stressed')));
    expect(cue.toLowerCase(), isNot(contains('score')));
  });

  test('repeated restarts on a harder board offer an easier route', () {
    final game = PathGame(boardId: 1);
    for (var i = 0; i < 2; i++) {
      expect(game.moveTo(1), isTrue);
      expect(game.restart(), isTrue);
    }

    final cue = GameFeedback.cue(game);
    expect(cue, isNotNull);
    expect(cue, contains('restart'));
    expect(cue, contains('easier route'));
    expect(cue!.toLowerCase(), isNot(contains('diagnos')));
  });

  test('history waits for at least three answers from the player', () {
    expect(GameFeedback.pattern([]), isNull);
    expect(GameFeedback.pattern([round(1, RoundFeeling.tense)]), isNull);
    expect(
      GameFeedback.pattern([
        round(1, RoundFeeling.tense),
        round(2, RoundFeeling.calm),
      ]),
      isNull,
    );
  });

  test('history describes only chosen feelings, not move-based stress', () {
    final answers = [
      round(1, RoundFeeling.calm, moves: 100, backtracks: 20, restarts: 5),
      round(2, RoundFeeling.tense, moves: 1),
      round(3, RoundFeeling.neither, moves: 80, backtracks: 10),
    ];
    final sameAnswersDifferentMoves = [
      round(1, RoundFeeling.calm),
      round(2, RoundFeeling.tense, moves: 90, backtracks: 30),
      round(3, RoundFeeling.neither),
    ];

    final pattern = GameFeedback.pattern(answers);
    expect(pattern, isNotNull);
    expect(pattern, GameFeedback.pattern(sameAnswersDifferentMoves));
    expect(pattern, contains('you marked'));
    expect(pattern, contains('calm'));
    expect(pattern, contains('tense'));
    expect(pattern, contains('neither'));
    expect(pattern!.toLowerCase(), isNot(contains('diagnos')));
    expect(pattern.toLowerCase(), isNot(contains('stress score')));
  });

  test('history uses the five most recent answers by date', () {
    final answers = [
      round(6, RoundFeeling.calm),
      round(1, RoundFeeling.tense),
      round(4, RoundFeeling.neither),
      round(3, RoundFeeling.calm),
      round(5, RoundFeeling.calm),
      round(2, RoundFeeling.tense),
    ];

    final pattern = GameFeedback.pattern(answers);
    expect(pattern, contains('last 5 rounds'));
    expect(pattern, contains('calm 3'));
    expect(pattern, contains('tense 1'));
    expect(pattern, contains('neither 1'));
  });

  test('history can describe a move pattern the player labeled themselves', () {
    final answers = [
      round(1, RoundFeeling.tense, backtracks: 3),
      round(2, RoundFeeling.calm, backtracks: 0),
      round(3, RoundFeeling.tense, backtracks: 2),
      round(4, RoundFeeling.calm, backtracks: 0),
    ];

    final pattern = GameFeedback.pattern(answers);
    expect(pattern, contains('changed direction more often'));
    expect(pattern, contains('you marked tense'));
    expect(pattern, contains('not a stress measure'));
  });
}
