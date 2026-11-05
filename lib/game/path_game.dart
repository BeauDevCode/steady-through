class PathBoard {
  const PathBoard({
    required this.id,
    required this.width,
    required this.height,
    required this.start,
    required this.goal,
    required this.blockedCells,
  });

  final int id;
  final int width;
  final int height;
  final int start;
  final int goal;
  final Set<int> blockedCells;
}

class PathGame {
  PathGame({int boardId = 0}) : _boardId = boardId {
    if (boardId < 0 || boardId >= boards.length) {
      throw RangeError.range(boardId, 0, boards.length - 1, 'boardId');
    }
    _path = [board.start];
  }

  static const boards = <PathBoard>[
    PathBoard(
      id: 0,
      width: 4,
      height: 4,
      start: 0,
      goal: 15,
      blockedCells: {5},
    ),
    PathBoard(
      id: 1,
      width: 4,
      height: 4,
      start: 0,
      goal: 15,
      blockedCells: {4, 5, 11, 12},
    ),
    PathBoard(
      id: 2,
      width: 4,
      height: 4,
      start: 0,
      goal: 15,
      blockedCells: {1, 6, 8, 13},
    ),
  ];

  int _boardId;
  late List<int> _path;
  int _moves = 0;
  int _backtracks = 0;
  int _restarts = 0;

  PathBoard get board => boards[_boardId];
  int get boardId => _boardId;
  int get currentCell => _path.last;
  List<int> get path => List<int>.unmodifiable(_path);
  int get moves => _moves;
  int get backtracks => _backtracks;
  int get restarts => _restarts;
  bool get isComplete => currentCell == board.goal;

  bool moveTo(int cell) {
    if (isComplete || cell < 0 || cell >= board.width * board.height) {
      return false;
    }
    if (board.blockedCells.contains(cell)) return false;

    final rowDistance = (cell ~/ board.width - currentCell ~/ board.width)
        .abs();
    final columnDistance = (cell % board.width - currentCell % board.width)
        .abs();
    if (rowDistance + columnDistance != 1) return false;

    if (_path.length > 1 && cell == _path[_path.length - 2]) {
      _path.removeLast();
      _moves++;
      _backtracks++;
      return true;
    }

    _path.add(cell);
    _moves++;
    return true;
  }

  bool undo() {
    if (_path.length == 1) return false;
    _path.removeLast();
    _backtracks++;
    return true;
  }

  bool restart() {
    if (_path.length == 1) return false;
    _path = [board.start];
    _restarts++;
    return true;
  }

  void startNewBoard() {
    _boardId = (_boardId + 1) % boards.length;
    _resetRound();
  }

  bool startEasierBoard() {
    if (_boardId == 0) return false;
    _boardId = 0;
    _resetRound();
    return true;
  }

  void _resetRound() {
    _path = [board.start];
    _moves = 0;
    _backtracks = 0;
    _restarts = 0;
  }
}
