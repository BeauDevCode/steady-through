import 'dart:math';

import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/tools/grounding_screen.dart';
import 'package:steady_through/game/game_feedback.dart';
import 'package:steady_through/game/path_game.dart';
import 'package:steady_through/model/app_data.dart';

class PathGameScreen extends StatefulWidget {
  const PathGameScreen({
    super.key,
    required this.controller,
    this.onOpenHelp,
    this.onOpenPath,
  });

  final AppController controller;
  final VoidCallback? onOpenHelp;
  final VoidCallback? onOpenPath;

  @override
  State<PathGameScreen> createState() => _PathGameScreenState();
}

class _PathGameScreenState extends State<PathGameScreen> {
  final _random = Random.secure();
  final PathGame _game = PathGame();
  RoundFeeling? _savedFeeling;
  bool _saving = false;
  String? _saveError;

  bool _canMoveTo(int cell) {
    final board = _game.board;
    if (_game.isComplete || board.blockedCells.contains(cell)) return false;
    final rowDistance = (cell ~/ board.width - _game.currentCell ~/ board.width)
        .abs();
    final columnDistance =
        (cell % board.width - _game.currentCell % board.width).abs();
    return rowDistance + columnDistance == 1;
  }

  void _move(int cell) {
    setState(() {
      _game.moveTo(cell);
    });
  }

  void _newBoard() {
    setState(() {
      _game.startNewBoard();
      _savedFeeling = null;
      _saveError = null;
    });
  }

  void _easierBoard() {
    setState(() {
      _game.startEasierBoard();
      _savedFeeling = null;
      _saveError = null;
    });
  }

  void _openGrounding() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: GroundingScreen(
            controller: widget.controller,
            onOpenHelp: widget.onOpenHelp,
          ),
        ),
      ),
    );
  }

  String _newRoundId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _chooseFeeling(RoundFeeling feeling) async {
    if (!_game.isComplete || _saving || _savedFeeling != null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final round = GameRound(
      id: _newRoundId(),
      createdAt: DateTime.now().toUtc(),
      boardId: _game.boardId,
      moves: _game.moves,
      backtracks: _game.backtracks,
      restarts: _game.restarts,
      feeling: feeling,
    );
    try {
      await widget.controller.recordRound(round);
      if (mounted) {
        setState(() => _savedFeeling = feeling);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = 'This round could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear game history?'),
        content: const Text(
          'This removes the saved round summaries and your answers. Your current round will stay open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep history'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.clearGameRounds();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Game history could not be cleared. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final simple = widget.controller.data.readingStyle == ReadingStyle.simple;
    final cue = !_game.isComplete ? GameFeedback.cue(_game) : null;
    final pattern = GameFeedback.pattern(widget.controller.data.gameRounds);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Tools'),
                  ),
                  HelpNowButton(
                    simpleWords: simple,
                    openHelp: widget.onOpenHelp,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Path game',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                simple
                    ? 'Find a way from Start to Finish. Tap a square next to your place. Take your time.'
                    : 'Move from Start to Finish one square at a time. There is no timer, score, or failure state. You can stop whenever you want.',
              ),
              const SizedBox(height: 16),
              Text(
                'Route ${_game.boardId + 1}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              _board(context),
              const SizedBox(height: 10),
              const Text(
                'Filled circle: your place. Flag: Start. Checkered flag: Finish. Block symbol: closed square.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _game.path.length > 1 &&
                            !_saving &&
                            _savedFeeling == null
                        ? () => setState(() {
                            _game.undo();
                            _saveError = null;
                          })
                        : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _game.path.length > 1 &&
                            !_saving &&
                            _savedFeeling == null
                        ? () => setState(() {
                            _game.restart();
                            _saveError = null;
                          })
                        : null,
                    icon: const Icon(Icons.replay),
                    label: const Text('Restart'),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _newBoard,
                    child: const Text('New board'),
                  ),
                ],
              ),
              if (cue != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cue),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: _openGrounding,
                              child: const Text('Take a break'),
                            ),
                            if (_game.boardId > 0)
                              TextButton(
                                onPressed: _easierBoard,
                                child: const Text('Easier route'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_game.isComplete) ...[
                const SizedBox(height: 20),
                _roundResult(context),
              ],
              if (pattern != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Your saved rounds',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(pattern),
              ],
              if (widget.controller.data.gameRounds.isNotEmpty) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _clearHistory,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear game history'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(BuildContext context) {
    final board = _game.board;
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SizedBox(
          width: min(constraints.maxWidth, 360.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: board.width * board.height,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: board.width,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, cell) {
              final blocked = board.blockedCells.contains(cell);
              final current = cell == _game.currentCell;
              final start = cell == board.start;
              final finish = cell == board.goal;
              final visited = _game.path.contains(cell);
              final label =
                  '${blocked
                      ? 'Closed square'
                      : current
                      ? 'Current square'
                      : finish
                      ? 'Finish'
                      : start
                      ? 'Start'
                      : 'Open square'}, row ${cell ~/ board.width + 1}, column ${cell % board.width + 1}';
              final icon = blocked
                  ? Icons.block
                  : current
                  ? Icons.radio_button_checked
                  : finish
                  ? Icons.sports_score_outlined
                  : start
                  ? Icons.flag_outlined
                  : visited
                  ? Icons.circle
                  : Icons.circle_outlined;
              return Semantics(
                label: label,
                child: Tooltip(
                  message: label,
                  child: OutlinedButton(
                    key: ValueKey('cell-$cell'),
                    onPressed: _canMoveTo(cell) ? () => _move(cell) : null,
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    child: Icon(icon),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _roundResult(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You reached Finish',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'This round had ${_game.moves} moves, ${_game.backtracks} backtracks, and ${_game.restarts} restarts.',
          ),
          const SizedBox(height: 12),
          if (_savedFeeling == null) ...[
            Text(
              'How did this round feel?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your answer is optional. Moves alone do not tell us how you felt.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final feeling in RoundFeeling.values)
                  OutlinedButton(
                    onPressed: _saving ? null : () => _chooseFeeling(feeling),
                    child: Text(_feelingLabel(feeling)),
                  ),
              ],
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ] else ...[
            Text(
              'You marked this round ${_feelingLabel(_savedFeeling!).toLowerCase()}.',
            ),
            const SizedBox(height: 8),
            Text(
              _savedFeeling == RoundFeeling.tense
                  ? widget.controller.activeEvent != null &&
                            widget.onOpenPath != null
                        ? 'Since you said it felt tense, you could try grounding or choose one small next step in your event path.'
                        : 'Since you said it felt tense, you could try grounding or take a short break.'
                  : widget.controller.activeEvent != null &&
                        widget.onOpenPath != null
                  ? 'If you want, try another round or return to your event path.'
                  : 'If you want, try another round.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_savedFeeling == RoundFeeling.tense)
                  OutlinedButton(
                    onPressed: _openGrounding,
                    child: const Text('Try grounding'),
                  ),
                FilledButton(
                  onPressed: _newBoard,
                  child: const Text('Another round'),
                ),
                if (widget.controller.activeEvent != null &&
                    widget.onOpenPath != null)
                  OutlinedButton(
                    onPressed: widget.onOpenPath,
                    child: const Text('Go to event path'),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  String _feelingLabel(RoundFeeling feeling) => switch (feeling) {
    RoundFeeling.calm => 'Calm',
    RoundFeeling.tense => 'Tense',
    RoundFeeling.neither => 'Neither',
  };
}
