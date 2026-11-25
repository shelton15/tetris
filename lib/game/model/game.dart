import 'dart:math';

import 'board.dart';
import 'piece.dart';
import 'piece_bag.dart';

enum GameStatus { playing, paused, over }

/// A snapshot of one game. Immutable; [Game] produces the next snapshot.
class GameState {
  const GameState({
    required this.board,
    required this.active,
    required this.next,
    this.score = 0,
    this.lines = 0,
    this.status = GameStatus.playing,
    this.clearedRows = const [],
  });

  final Board board;

  /// Rows removed by the lock that produced this state (pre-collapse
  /// indices). Empty on every other state, so a non-empty list marks the
  /// exact moment of a clear.
  final List<int> clearedRows;
  final ActivePiece active;
  final PieceType next;
  final int score;
  final int lines;
  final GameStatus status;

  /// Starts at 1 and rises every 10 cleared lines.
  int get level => lines ~/ 10 + 1;

  /// Time between automatic one-row drops: 15% faster per level, floored.
  Duration get dropInterval =>
      Duration(milliseconds: max(80, (800 * pow(0.85, level - 1)).round()));

  /// True when the active piece is resting on the floor or a block.
  bool get isGrounded => !board.fits(active.moved(dRow: 1));

  /// Where the active piece would land if hard-dropped.
  ActivePiece get ghost {
    var piece = active;
    while (board.fits(piece.moved(dRow: 1))) {
      piece = piece.moved(dRow: 1);
    }
    return piece;
  }

  GameState copyWith({
    Board? board,
    ActivePiece? active,
    PieceType? next,
    int? score,
    int? lines,
    GameStatus? status,
  }) =>
      GameState(
        board: board ?? this.board,
        active: active ?? this.active,
        next: next ?? this.next,
        score: score ?? this.score,
        lines: lines ?? this.lines,
        status: status ?? this.status,
      );
}

/// The rules. Each action takes a state and returns the next one; actions
/// on a game that is not [GameStatus.playing] return the state unchanged.
class Game {
  Game({Random? random}) : _bag = PieceBag(random);

  final PieceBag _bag;

  /// Points for clearing 1–4 rows at once, multiplied by the level.
  static const lineScores = [0, 100, 300, 500, 800];

  /// Column/row nudges tried, in order, when a rotation collides.
  static const _kicks = [(0, 0), (0, -1), (0, 1), (0, -2), (0, 2), (-1, 0)];

  GameState start({int width = 10, int height = 20}) {
    final board = Board.empty(width: width, height: height);
    return GameState(
      board: board,
      active: ActivePiece.spawn(_bag.next(), width),
      next: _bag.next(),
    );
  }

  GameState moveLeft(GameState s) => _shift(s, -1);
  GameState moveRight(GameState s) => _shift(s, 1);

  GameState rotate(GameState s) {
    if (s.status != GameStatus.playing) return s;
    final turned = s.active.rotated();
    for (final (dRow, dCol) in _kicks) {
      final candidate = turned.moved(dRow: dRow, dCol: dCol);
      if (s.board.fits(candidate)) return s.copyWith(active: candidate);
    }
    return s;
  }

  /// Gravity: drop one row. A grounded piece stays put; settling it is
  /// [lock]'s job, so the caller can give the player a moment to slide it.
  GameState tick(GameState s) {
    if (s.status != GameStatus.playing || s.isGrounded) return s;
    return s.copyWith(active: s.active.moved(dRow: 1));
  }

  /// Player-driven drop of one row; scores 1 point per row. Does nothing
  /// once grounded, so holding it never locks a piece early.
  GameState softDrop(GameState s) {
    if (s.status != GameStatus.playing || s.isGrounded) return s;
    return s.copyWith(active: s.active.moved(dRow: 1), score: s.score + 1);
  }

  /// Drops straight to the ghost position and locks; 2 points per row.
  GameState hardDrop(GameState s) {
    if (s.status != GameStatus.playing) return s;
    final landed = s.ghost;
    final dropped = landed.row - s.active.row;
    return lock(s.copyWith(active: landed, score: s.score + 2 * dropped));
  }

  GameState togglePause(GameState s) => switch (s.status) {
        GameStatus.playing => s.copyWith(status: GameStatus.paused),
        GameStatus.paused => s.copyWith(status: GameStatus.playing),
        GameStatus.over => s,
      };

  GameState _shift(GameState s, int dCol) {
    if (s.status != GameStatus.playing) return s;
    final moved = s.active.moved(dCol: dCol);
    return s.board.fits(moved) ? s.copyWith(active: moved) : s;
  }

  /// Settles the active piece, clears rows, scores, and spawns the next
  /// piece. The game ends when the new piece has no room to appear.
  GameState lock(GameState s) {
    if (s.status != GameStatus.playing) return s;
    final (:board, :rows) = s.board.lock(s.active).clearFullRows();
    final spawned = ActivePiece.spawn(s.next, board.width);
    return GameState(
      board: board,
      active: spawned,
      next: _bag.next(),
      score: s.score + lineScores[rows.length] * s.level,
      lines: s.lines + rows.length,
      clearedRows: rows,
      status: board.fits(spawned) ? GameStatus.playing : GameStatus.over,
    );
  }
}
