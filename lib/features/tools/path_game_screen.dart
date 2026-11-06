import 'dart:math';

import 'package:flutter/material.dart';
import 'package:steady_through/app/app_controller.dart';
import 'package:steady_through/features/help/help_screen.dart';
import 'package:steady_through/features/tools/feedback/tool_feedback_prompt.dart';
import 'package:steady_through/features/tools/grounding_screen.dart';
import 'package:steady_through/game/game_feedback.dart';
import 'package:steady_through/game/path_game.dart';
import 'package:steady_through/model/app_data.dart';
import 'package:steady_through/model/tool_feedback.dart';
import 'package:steady_through/learning/learning_session.dart';
import 'package:steady_through/ui/steady_ui.dart';

class PathGameScreen extends StatefulWidget {
  const PathGameScreen({
    super.key,
    required this.controller,
    this.safetySession,
    this.onOpenHelp,
    this.onOpenPath,
  });

  final AppController controller;
  final LearningSession? safetySession;
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
  int _feedbackAttempt = 0;

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
      _feedbackAttempt++;
      _savedFeeling = null;
      _saveError = null;
    });
  }

  void _easierBoard() {
    setState(() {
      _game.startEasierBoard();
      _feedbackAttempt++;
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
            safetySession: widget.safetySession,
            backLabel: 'Back to game',
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SteadyPage(
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
              controller: widget.controller,
              simpleWords: simple,
              openHelp: widget.onOpenHelp,
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeading(
          title: 'Path game',
          subtitle: simple
              ? 'Find a way from Start to Finish. Tap a square next to your place. Take your time.'
              : 'Move from Start to Finish one square at a time. There is no timer, score, or failure state. You can stop whenever you want.',
        ),
        const SizedBox(height: 28),
        ResponsiveColumns(
          minWidth: 360,
          children: [
            SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Route ${_game.boardId + 1}',
                          style: theme.textTheme.titleLarge,
                        ),
                        const Eyebrow('Take your time'),
                      ],
                    ),
                  ),
                  _board(context),
                  const SizedBox(height: 20),
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
                                _feedbackAttempt++;
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
                                _feedbackAttempt++;
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
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_game.isComplete)
                  _roundResult(context)
                else
                  SurfaceCard(
                    color: colors.primaryContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBadge(
                          icon: Icons.route_outlined,
                          color: colors.surface,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          simple ? 'Take one step' : 'One square at a time',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          simple
                              ? 'Tap an open square next to your place. You can go back.'
                              : 'Choose an open square next to your current place. You can explore, go back, or try another route.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 20,
                          runSpacing: 16,
                          children: [
                            _legendItem(
                              context,
                              Icons.radio_button_checked,
                              'Your place',
                            ),
                            _legendItem(context, Icons.flag_outlined, 'Start'),
                            _legendItem(
                              context,
                              Icons.sports_score_outlined,
                              'Finish',
                            ),
                            _legendItem(context, Icons.block, 'Closed square'),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (cue != null) ...[
                  const SizedBox(height: 20),
                  SurfaceCard(
                    color: colors.secondaryContainer,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cue, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 12),
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
                ],
              ],
            ),
          ],
        ),
        if (pattern != null) ...[
          const SizedBox(height: 28),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your saved rounds', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(pattern, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
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
    );
  }

  Widget _legendItem(BuildContext context, IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );

  Widget _board(BuildContext context) {
    final board = _game.board;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SizedBox(
          width: min(constraints.maxWidth, 420.0),
          child: AspectRatio(
            aspectRatio: board.width / board.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  child: CustomPaint(
                    painter: _RouteBoardPainter(
                      board: board,
                      path: _game.path,
                      colors: colors,
                    ),
                  ),
                ),
                FocusTraversalGroup(
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: board.width * board.height,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: board.width,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, cell) {
                      final blocked = board.blockedCells.contains(cell);
                      final current = cell == _game.currentCell;
                      final start = cell == board.start;
                      final finish = cell == board.goal;
                      final visited = _game.path.contains(cell);
                      final available = _canMoveTo(cell);
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
                      final foreground = current
                          ? colors.onPrimary
                          : finish
                          ? colors.onSecondaryContainer
                          : blocked
                          ? colors.onSurfaceVariant
                          : colors.primary;
                      final cellColor = current
                          ? colors.primary
                          : blocked
                          ? colors.surfaceContainerHighest
                          : finish
                          ? colors.secondaryContainer
                          : visited || start
                          ? colors.primaryContainer
                          : colors.surface;
                      return Semantics(
                        label: label,
                        selected: current,
                        child: Tooltip(
                          message: label,
                          child: OutlinedButton(
                            key: ValueKey('cell-$cell'),
                            onPressed: available ? () => _move(cell) : null,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: foreground,
                              disabledForegroundColor: foreground,
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              side: BorderSide(
                                color: current
                                    ? colors.primary
                                    : available
                                    ? colors.primary.withValues(alpha: .65)
                                    : colors.outlineVariant,
                                width: available ? 1.5 : 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Center(
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cellColor,
                                    ),
                                    child: Icon(
                                      icon,
                                      size:
                                          blocked || current || start || finish
                                          ? 24
                                          : visited
                                          ? 10
                                          : 12,
                                      color: foreground,
                                    ),
                                  ),
                                ),
                                if (current && (start || finish))
                                  Positioned(
                                    top: 5,
                                    left: 5,
                                    child: Icon(
                                      start
                                          ? Icons.flag_outlined
                                          : Icons.sports_score_outlined,
                                      size: 12,
                                      color: foreground,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundResult(BuildContext context) => SurfaceCard(
    color: Theme.of(context).colorScheme.primaryContainer,
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
        const SizedBox(height: 20),
        ToolFeedbackPrompt(
          key: ValueKey(_feedbackAttempt),
          controller: widget.controller,
          tool: SupportTool.pathGame,
          safetySession: widget.safetySession,
        ),
      ],
    ),
  );

  String _feelingLabel(RoundFeeling feeling) => switch (feeling) {
    RoundFeeling.calm => 'Calm',
    RoundFeeling.tense => 'Tense',
    RoundFeeling.neither => 'Neither',
  };
}

/// Paint the connected route beneath the real, focusable cell buttons.
class _RouteBoardPainter extends CustomPainter {
  _RouteBoardPainter({
    required this.board,
    required this.path,
    required this.colors,
  });

  final PathBoard board;
  final List<int> path;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 8.0;
    final cellWidth = (size.width - gap * (board.width - 1)) / board.width;
    final cellHeight = (size.height - gap * (board.height - 1)) / board.height;
    Offset center(int cell) => Offset(
      (cell % board.width) * (cellWidth + gap) + cellWidth / 2,
      (cell ~/ board.width) * (cellHeight + gap) + cellHeight / 2,
    );
    final visited = path.toSet();
    for (var cell = 0; cell < board.width * board.height; cell++) {
      final color = cell == path.last
          ? colors.primary
          : board.blockedCells.contains(cell)
          ? colors.surfaceContainerHighest
          : cell == board.goal
          ? colors.secondaryContainer
          : visited.contains(cell) || cell == board.start
          ? colors.primaryContainer
          : colors.surface;
      final rect = Rect.fromLTWH(
        (cell % board.width) * (cellWidth + gap),
        (cell ~/ board.width) * (cellHeight + gap),
        cellWidth,
        cellHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        Paint()..color = color,
      );
    }
    if (path.length > 1) {
      final route = Path()
        ..moveTo(center(path.first).dx, center(path.first).dy);
      for (final cell in path.skip(1)) {
        final point = center(cell);
        route.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        route,
        Paint()
          ..color = colors.primary.withValues(alpha: .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RouteBoardPainter oldDelegate) {
    if (oldDelegate.board != board ||
        oldDelegate.colors != colors ||
        oldDelegate.path.length != path.length) {
      return true;
    }
    for (var index = 0; index < path.length; index++) {
      if (path[index] != oldDelegate.path[index]) return true;
    }
    return false;
  }
}
