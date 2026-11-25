import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tetris/game/model/game.dart';
import 'package:tetris/game/view/board_painter.dart';
import 'package:tetris/game/view/game_screen.dart';
import 'package:tetris/game/view_model/game_view_model.dart';

GameViewModel seededViewModel() => GameViewModel(game: Game(random: Random(7)));

/// Pumps the screen with [vm]; tears both down at the end of the test so no
/// gravity timer is left pending.
Future<void> pumpScreen(WidgetTester tester, GameViewModel vm) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: GameScreen(viewModel: vm)));
}

void main() {
  group('GameViewModel', () {
    testWidgets('gravity drops the piece once per interval', (tester) async {
      final vm = seededViewModel();
      addTearDown(vm.dispose);
      final startRow = vm.state.active.row;
      await tester.pump(vm.state.dropInterval);
      expect(vm.state.active.row, startRow + 1);
    });

    testWidgets('pause stops gravity; resume restarts it', (tester) async {
      final vm = seededViewModel();
      addTearDown(vm.dispose);
      vm.pause();
      final row = vm.state.active.row;
      await tester.pump(const Duration(seconds: 5));
      expect(vm.state.active.row, row);
      vm.resume();
      await tester.pump(vm.state.dropInterval);
      expect(vm.state.active.row, row + 1);
    });

    testWidgets('hard drop scores and deals the next piece', (tester) async {
      final vm = seededViewModel();
      addTearDown(vm.dispose);
      final next = vm.state.next;
      vm.hardDrop();
      expect(vm.state.active.type, next);
      expect(vm.state.score, greaterThan(0));
      vm.restart();
      expect(vm.state.score, 0);
    });
  });

  group('GameScreen', () {
    testWidgets('shows score and progress', (tester) async {
      await pumpScreen(tester, seededViewModel());
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Level 1 · 0 lines'), findsOneWidget);
    });

    testWidgets('tap rotates, horizontal drag moves one column per cell', (tester) async {
      final vm = seededViewModel();
      await pumpScreen(tester, vm);
      final board = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardPainter);

      final rotation = vm.state.active.rotation;
      await tester.tap(board);
      expect(vm.state.active.rotation, (rotation + 1) % 4);

      final col = vm.state.active.col;
      final cell = tester.getSize(board).width / 10;
      await tester.drag(board, Offset(cell * 2, 0));
      expect(vm.state.active.col, col + 2);
    });

    testWidgets('keyboard moves, and P opens the pause sheet', (tester) async {
      final vm = seededViewModel();
      await pumpScreen(tester, vm);

      final col = vm.state.active.col;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(vm.state.active.col, col - 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      expect(vm.state.status, GameStatus.paused);
      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(vm.state.status, GameStatus.playing);
    });

    testWidgets('restart from the pause sheet starts a new game', (tester) async {
      final vm = seededViewModel();
      await pumpScreen(tester, vm);
      vm.hardDrop();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart game'));
      await tester.pumpAndSettle();
      expect(vm.state.status, GameStatus.playing);
      expect(vm.state.score, 0);
    });

    testWidgets('game over shows the result and Play again restarts', (tester) async {
      final vm = seededViewModel();
      await pumpScreen(tester, vm);
      while (vm.state.status != GameStatus.over) {
        vm.hardDrop();
      }
      await tester.pumpAndSettle();
      expect(find.text('Game over'), findsOneWidget);

      await tester.tap(find.text('Play again'));
      await tester.pumpAndSettle();
      expect(vm.state.status, GameStatus.playing);
      expect(find.text('Game over'), findsNothing);
    });
  });
}
