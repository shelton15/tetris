import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tetris/game/model/board.dart';
import 'package:tetris/game/model/game.dart';
import 'package:tetris/game/model/piece.dart';
import 'package:tetris/game/model/piece_bag.dart';

/// A 10×20 board whose bottom rows are [bottom]; everything above is empty.
Board boardWith(List<String> bottom) => Board.fromRows([
      for (var i = 0; i < 20 - bottom.length; i++) '..........',
      ...bottom,
    ]);

GameState stateWith(Board board, ActivePiece active, {PieceType next = PieceType.t}) =>
    GameState(board: board, active: active, next: next);

void main() {
  group('PieceType', () {
    test('every rotation has 4 cells inside its box', () {
      for (final type in PieceType.values) {
        for (var r = 0; r < 4; r++) {
          final cells = type.cells(r);
          expect(cells.toSet(), hasLength(4), reason: '$type r$r');
          for (final c in cells) {
            expect(c.row, inInclusiveRange(0, type.boxSize - 1));
            expect(c.col, inInclusiveRange(0, type.boxSize - 1));
          }
        }
      }
    });

    test('four clockwise turns return to the spawn state', () {
      for (final type in PieceType.values) {
        expect(type.cells(4), type.cells(0));
      }
    });

    test('non-O shapes have distinct rotation states', () {
      expect(PieceType.t.cells(1).toSet(), isNot(PieceType.t.cells(0).toSet()));
      expect(PieceType.i.cells(1), [
        (row: 0, col: 2), (row: 1, col: 2), (row: 2, col: 2), (row: 3, col: 2),
      ]);
    });

    test('spawn is centred', () {
      expect(ActivePiece.spawn(PieceType.i, 10).col, 3);
      expect(ActivePiece.spawn(PieceType.o, 10).col, 4);
      expect(ActivePiece.spawn(PieceType.t, 10).col, 3);
    });
  });

  group('Board', () {
    test('fits rejects walls, floor and settled blocks', () {
      final board = boardWith(['#.........']);
      const o = PieceType.o;
      expect(board.fits(const ActivePiece(o, row: 0, col: 0)), isTrue);
      expect(board.fits(const ActivePiece(o, row: 0, col: -1)), isFalse);
      expect(board.fits(const ActivePiece(o, row: 0, col: 9)), isFalse);
      expect(board.fits(const ActivePiece(o, row: 19, col: 4)), isFalse);
      expect(board.fits(const ActivePiece(o, row: 18, col: 0)), isFalse);
      expect(board.fits(const ActivePiece(o, row: 18, col: 1)), isTrue);
    });

    test('clears full rows and shifts the rest down', () {
      final board = boardWith([
        '#.........',
        '##########',
        '.#.#.#.#.#',
        '##########',
      ]);
      final result = board.clearFullRows();
      expect(result.rows, [17, 19]);
      expect(result.board.at(19, 1), isNotNull);
      expect(result.board.at(19, 0), isNull);
      expect(result.board.at(18, 0), isNotNull);
      expect(result.board.at(17, 0), isNull);
    });

    test('no full rows returns the same board', () {
      final board = boardWith(['#########.']);
      expect(identical(board.clearFullRows().board, board), isTrue);
    });
  });

  test('PieceBag deals every shape once per 7', () {
    final bag = PieceBag(Random(1));
    for (var round = 0; round < 3; round++) {
      final dealt = {for (var i = 0; i < 7; i++) bag.next()};
      expect(dealt, PieceType.values.toSet());
    }
  });

  group('Game', () {
    final game = Game(random: Random(1));

    test('start spawns a piece and a preview', () {
      final s = game.start();
      expect(s.status, GameStatus.playing);
      expect(s.board.fits(s.active), isTrue);
      expect(s.active.row, 0);
      expect(s.level, 1);
    });

    test('moves are blocked by walls', () {
      var s = stateWith(Board.empty(), const ActivePiece(PieceType.o, row: 0, col: 0));
      s = game.moveLeft(s);
      expect(s.active.col, 0);
      s = game.moveRight(s);
      expect(s.active.col, 1);
    });

    test('rotation kicks off the wall', () {
      // Vertical I hugging the right wall: rotating flat needs a nudge left.
      final s = stateWith(
        Board.empty(),
        const ActivePiece(PieceType.i, row: 5, col: 7, rotation: 1),
      );
      final r = game.rotate(s);
      expect(r.active.rotation, 2);
      expect(r.active.col, 6);
      expect(r.board.fits(r.active), isTrue);
    });

    test('rotation is refused when no kick fits', () {
      // Vertical I in a 1-wide shaft: no flat position fits anywhere.
      final shaft = Board.fromRows([
        for (var i = 0; i < 20; i++) '####.#####',
      ]);
      final s = stateWith(shaft, const ActivePiece(PieceType.i, row: 4, col: 2, rotation: 1));
      expect(game.rotate(s), same(s));
    });

    test('hard drop locks, clears a line and scores', () {
      final s = stateWith(
        boardWith(['###....###']),
        ActivePiece.spawn(PieceType.i, 10),
        next: PieceType.o,
      );
      final after = game.hardDrop(s);
      expect(after.lines, 1);
      expect(after.clearedRows, [19]);
      expect(game.moveLeft(after).clearedRows, isEmpty);
      expect(after.score, 18 * 2 + 100);
      expect(after.active.type, PieceType.o);
      expect(after.board.at(19, 0), isNull, reason: 'the full row was removed');
    });

    test('tick falls, then waits on the floor until locked', () {
      var s = stateWith(Board.empty(), const ActivePiece(PieceType.o, row: 17, col: 0));
      s = game.tick(s);
      expect(s.active.row, 18);
      expect(s.isGrounded, isTrue);
      expect(game.tick(s), same(s));
      expect(game.softDrop(s), same(s), reason: 'soft drop never locks');
      s = game.lock(s);
      expect(s.board.at(19, 0), PieceType.o);
      expect(s.active.type, PieceType.t);
    });

    test('game ends when the next piece cannot spawn', () {
      final board = Board.fromRows([
        '..........',
        '....##....',
        for (var i = 0; i < 18; i++) '..........',
      ]);
      final s = stateWith(board, const ActivePiece(PieceType.o, row: 18, col: 0),
          next: PieceType.o);
      final over = game.lock(game.tick(s));
      expect(over.status, GameStatus.over);
      expect(game.moveLeft(over), same(over));
    });

    test('paused games ignore input until resumed', () {
      final s = game.togglePause(game.start());
      expect(s.status, GameStatus.paused);
      expect(game.tick(s), same(s));
      expect(game.togglePause(s).status, GameStatus.playing);
    });

    test('level rises every 10 lines and drops speed up', () {
      final s = game.start();
      expect(s.copyWith(lines: 9).level, 1);
      expect(s.copyWith(lines: 10).level, 2);
      expect(s.copyWith(lines: 10).dropInterval, lessThan(s.dropInterval));
      expect(s.copyWith(lines: 500).dropInterval, const Duration(milliseconds: 80));
    });

    test('score multiplies by level', () {
      final s = stateWith(
        boardWith(['###....###']),
        ActivePiece.spawn(PieceType.i, 10),
      ).copyWith(lines: 20);
      final after = game.hardDrop(s);
      expect(after.score, 18 * 2 + 100 * 3);
    });
  });
}
