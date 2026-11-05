import 'package:flutter_test/flutter_test.dart';
import 'package:steady_through/game/path_game.dart';

bool hasRoute(PathBoard board) {
  final visited = <int>{board.start};
  final pending = <int>[board.start];

  while (pending.isNotEmpty) {
    final cell = pending.removeAt(0);
    if (cell == board.goal) return true;
    final row = cell ~/ board.width;
    final column = cell % board.width;
    final neighbors = <int>[
      if (row > 0) cell - board.width,
      if (row < board.height - 1) cell + board.width,
      if (column > 0) cell - 1,
      if (column < board.width - 1) cell + 1,
    ];
    for (final neighbor in neighbors) {
      if (!board.blockedCells.contains(neighbor) && visited.add(neighbor)) {
        pending.add(neighbor);
      }
    }
  }
  return false;
}

void main() {
  test('every preset board has an open route from Start to Finish', () {
    expect(PathGame.boards, isNotEmpty);
    for (final board in PathGame.boards) {
      expect(board.width, 4);
      expect(board.height, 4);
      expect(board.blockedCells, isNot(contains(board.start)));
      expect(board.blockedCells, isNot(contains(board.goal)));
      expect(hasRoute(board), isTrue, reason: 'board ${board.id}');
    }
  });

  test('only adjacent open cells advance the path or move count', () {
    final game = PathGame();

    expect(game.moveTo(-1), isFalse);
    expect(game.moveTo(16), isFalse);
    expect(game.moveTo(5), isFalse); // A wall on the first board.
    expect(game.moveTo(2), isFalse); // A two-cell jump.
    expect(game.path, [0]);
    expect(game.moves, 0);

    expect(game.moveTo(1), isTrue);
    expect(game.moveTo(5), isFalse); // Adjacent, but blocked.
    expect(game.moveTo(3), isFalse);
    expect(game.path, [0, 1]);
    expect(game.currentCell, 1);
    expect(game.moves, 1);
    expect(game.backtracks, 0);
  });

  test('row wrapping is not an adjacent move', () {
    final game = PathGame();
    for (final cell in [1, 2, 3]) {
      expect(game.moveTo(cell), isTrue);
    }

    expect(game.moveTo(4), isFalse);
    expect(game.currentCell, 3);
    expect(game.moves, 3);
  });

  test('Finish requires reaching the goal and undo removes completion', () {
    final game = PathGame();
    expect(game.isComplete, isFalse);
    expect(game.moveTo(15), isFalse);
    for (final cell in [1, 2, 3, 7, 11]) {
      expect(game.moveTo(cell), isTrue);
      expect(game.isComplete, isFalse);
    }

    expect(game.moveTo(15), isTrue);
    expect(game.isComplete, isTrue);
    expect(game.moveTo(14), isFalse);
    expect(game.moves, 6);

    expect(game.undo(), isTrue);
    expect(game.isComplete, isFalse);
    expect(game.currentCell, 11);
    expect(game.backtracks, 1);
  });

  test('undo and restart at Start do not create false revisions', () {
    final game = PathGame();
    expect(game.undo(), isFalse);
    expect(game.restart(), isFalse);
    expect(game.path, [0]);
    expect(game.backtracks, 0);
    expect(game.restarts, 0);

    expect(game.moveTo(1), isTrue);
    expect(game.undo(), isTrue);
    expect(game.undo(), isFalse);
    expect(game.backtracks, 1);
    expect(game.moveTo(1), isTrue);
    expect(game.restart(), isTrue);
    expect(game.restart(), isFalse);
    expect(game.path, [0]);
    expect(game.moves, 2); // Accepted moves remain in the round summary.
    expect(game.backtracks, 1);
    expect(game.restarts, 1);
    expect(game.isComplete, isFalse);
  });

  test(
    'a new board resets round counts and the easier board is board zero',
    () {
      final game = PathGame();
      expect(game.moveTo(1), isTrue);
      expect(game.undo(), isTrue);
      game.startNewBoard();

      expect(game.boardId, 1);
      expect(game.path, [game.board.start]);
      expect(game.moves, 0);
      expect(game.backtracks, 0);
      expect(game.restarts, 0);
      expect(game.startEasierBoard(), isTrue);
      expect(game.boardId, 0);
      expect(game.path, [game.board.start]);
      expect(game.startEasierBoard(), isFalse);
    },
  );

  test('invalid board IDs are rejected and callers cannot alter the route', () {
    expect(() => PathGame(boardId: -1), throwsRangeError);
    expect(() => PathGame(boardId: PathGame.boards.length), throwsRangeError);

    final game = PathGame();
    expect(() => game.path.add(1), throwsUnsupportedError);
    expect(() => game.board.blockedCells.remove(5), throwsUnsupportedError);
  });
}
