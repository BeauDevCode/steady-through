import 'package:steady_through/game/path_game.dart';
import 'package:steady_through/model/app_data.dart';

class GameFeedback {
  static String? cue(PathGame game) {
    if (game.restarts < 2 && game.backtracks < 2) return null;

    final nextOption = game.boardId == 0
        ? 'start another round'
        : 'try an easier route';
    if (game.restarts >= 2) {
      return 'You restarted ${game.restarts} times. You can take a break or $nextOption when you want.';
    }
    return 'You backtracked ${game.backtracks} times. You can take a break or $nextOption when you want.';
  }

  static String? pattern(List<GameRound> rounds) {
    if (rounds.length < 3) return null;

    final newestFirst = List<GameRound>.of(rounds)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent = newestFirst.take(5);
    var calm = 0;
    var tense = 0;
    var neither = 0;
    for (final round in recent) {
      switch (round.feeling) {
        case RoundFeeling.calm:
          calm++;
        case RoundFeeling.tense:
          tense++;
        case RoundFeeling.neither:
          neither++;
      }
    }

    return 'In your last ${calm + tense + neither} rounds, you marked calm $calm ${_timeWord(calm)}, tense $tense ${_timeWord(tense)}, and neither $neither ${_timeWord(neither)}.';
  }

  static String _timeWord(int count) => count == 1 ? 'time' : 'times';
}
