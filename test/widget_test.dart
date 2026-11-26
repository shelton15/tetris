import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tetris/game/audio/sound_effects.dart';
import 'package:tetris/game/model/board.dart';
import 'package:tetris/game/model/game.dart';
import 'package:tetris/game/model/piece.dart';
import 'package:tetris/game/view/board_painter.dart';
import 'package:tetris/game/view/game_screen.dart';
import 'package:tetris/game/view_model/game_view_model.dart';
import 'package:tetris/game/view_model/settings_view_model.dart';
import 'package:tetris/settings/gesture_guide.dart';
import 'package:tetris/settings/settings_screen.dart';

GameViewModel seededViewModel() => GameViewModel(game: Game(random: Random(7)));

/// Starts every game with the bottom row one I-piece short of full, so the
/// first hard drop clears a line and the game has a real score.
class _OneLineGame extends Game {
  _OneLineGame() : super(random: Random(7));

  @override
  GameState start({int width = 10, int height = 20}) => GameState(
    board: Board.fromRows([for (var i = 0; i < height - 1; i++) '..........', '###....###']),
    active: ActivePiece.spawn(PieceType.i, width),
    next: PieceType.o,
  );
}

GameViewModel scoringViewModel() => GameViewModel(game: _OneLineGame());

/// Records what the game asked to play instead of playing it.
class _RecordingSounds implements SoundEffects {
  final played = <Sfx>[];

  @override
  void play(Sfx sfx) => played.add(sfx);

  @override
  Future<void> load() async {}

  @override
  Future<void> dispose() async {}
}

/// Pumps the screen with [vm]; tears both down at the end of the test so no
/// gravity timer is left pending.
Future<void> pumpScreen(WidgetTester tester, GameViewModel vm, {SettingsViewModel? settings}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(viewModel: vm, settings: settings ?? SettingsViewModel()),
    ),
  );
}

/// Soft-drops until the active piece rests on the floor.
void landPiece(GameViewModel vm) {
  while (!vm.state.isGrounded) {
    vm.softDrop();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GameViewModel', () {
    testWidgets('a grounded piece locks after the lock delay', (tester) async {
      final vm = seededViewModel();
      addTearDown(vm.dispose);
      landPiece(vm);
      final board = vm.state.board;
      await tester.pump(GameViewModel.lockDelay - const Duration(milliseconds: 50));
      expect(vm.state.board, same(board));
      await tester.pump(const Duration(milliseconds: 60));
      expect(vm.state.board, isNot(same(board)));
    });

    testWidgets('sliding a grounded piece restarts the lock delay, up to a cap', (tester) async {
      final vm = seededViewModel();
      addTearDown(vm.dispose);
      landPiece(vm);
      final board = vm.state.board;
      await tester.pump(const Duration(milliseconds: 400));
      vm.moveLeft();
      await tester.pump(const Duration(milliseconds: 400));
      expect(vm.state.board, same(board), reason: 'the move bought more time');

      for (var i = 0; i < GameViewModel.maxLockResets + 2; i++) {
        i.isEven ? vm.moveRight() : vm.moveLeft();
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(vm.state.board, isNot(same(board)), reason: 'stalling is capped');
    });

    testWidgets('game over records a new best score', (tester) async {
      SharedPreferences.setMockInitialValues({'high_score': 10});
      final vm = scoringViewModel();
      addTearDown(vm.dispose);
      await tester.pump();
      expect(vm.highScore, 10);
      while (vm.state.status != GameStatus.over) {
        vm.hardDrop();
      }
      await tester.pump();
      expect(vm.isNewHighScore, isTrue);
      expect(vm.highScore, vm.state.score);
      expect((await SharedPreferences.getInstance()).getInt('high_score'), vm.state.score);
    });

    testWidgets('a lower score keeps the saved best', (tester) async {
      SharedPreferences.setMockInitialValues({'high_score': 1000000});
      final vm = seededViewModel();
      addTearDown(vm.dispose);
      while (vm.state.status != GameStatus.over) {
        vm.hardDrop();
      }
      await tester.pump();
      expect(vm.isNewHighScore, isFalse);
      expect(vm.highScore, 1000000);
    });

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

    testWidgets('score comes only from cleared lines', (tester) async {
      final vm = scoringViewModel();
      addTearDown(vm.dispose);
      vm.moveLeft();
      vm.moveRight();
      vm.softDrop();
      expect(vm.state.score, 0, reason: 'moves and drops earn nothing');
      final next = vm.state.next;
      vm.hardDrop();
      expect(vm.state.active.type, next);
      expect(vm.state.lines, 1);
      expect(vm.state.score, 100);
      vm.restart();
      expect(vm.state.score, 0);
    });

    testWidgets('sounds follow what each move did', (tester) async {
      final sounds = _RecordingSounds();
      final vm = GameViewModel(game: _OneLineGame(), sounds: sounds);
      addTearDown(vm.dispose);

      vm.moveLeft();
      expect(sounds.played, isEmpty, reason: 'sliding is silent');
      vm.rotate();
      expect(sounds.played, [Sfx.rotate]);

      sounds.played.clear();
      vm.rotate(); // back to flat, so the drop below fills the row
      sounds.played.clear();
      vm.moveRight();
      vm.hardDrop();
      expect(sounds.played, [Sfx.hardDrop, Sfx.clear]);

      sounds.played.clear();
      landPiece(vm);
      await tester.pump(GameViewModel.lockDelay);
      expect(sounds.played, [Sfx.lock], reason: 'a piece settling on its own clacks');

      sounds.played.clear();
      while (vm.state.status != GameStatus.over) {
        vm.hardDrop();
      }
      expect(sounds.played.last, Sfx.gameOver);
    });

    testWidgets('sound off plays nothing', (tester) async {
      final sounds = _RecordingSounds();
      final vm = GameViewModel(game: _OneLineGame(), sounds: sounds, soundEnabled: () => false);
      addTearDown(vm.dispose);
      vm.rotate();
      vm.hardDrop();
      expect(sounds.played, isEmpty);
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
      final vm = scoringViewModel();
      await pumpScreen(tester, vm);
      while (vm.state.status != GameStatus.over) {
        vm.hardDrop();
      }
      await tester.pumpAndSettle();
      expect(find.text('Game over'), findsOneWidget);
      expect(find.text('New best score'), findsOneWidget);

      await tester.tap(find.text('Play again'));
      await tester.pumpAndSettle();
      expect(vm.state.status, GameStatus.playing);
      expect(find.text('Game over'), findsNothing);
    });
  });

  group('Settings', () {
    BoardPainter painter(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardPainter),
                )
                .painter!
            as BoardPainter;

    testWidgets('gear opens settings; the ghost switch hides the ghost', (tester) async {
      final vm = seededViewModel();
      final settings = SettingsViewModel();
      await pumpScreen(tester, vm, settings: settings);
      expect(painter(tester).showGhost, isTrue);

      await tester.tap(find.byTooltip('Settings'));
      // The gesture guide loops forever, so pump through the page
      // transition instead of waiting for everything to settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(vm.state.status, GameStatus.paused);
      expect(find.text('Paused'), findsNothing, reason: 'no pause sheet over settings');

      await tester.ensureVisible(find.text('Ghost piece'));
      await tester.tap(find.text('Ghost piece'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(settings.showGhost, isFalse);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget, reason: 'returning offers Resume');
      expect(painter(tester).showGhost, isFalse);
    });

    testWidgets('choosing gestures plays a guide that steps through each gesture', (tester) async {
      final settings = SettingsViewModel();
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(settings: settings)));
      await tester.pump();
      expect(find.byType(GestureGuide), findsOneWidget);
      expect(find.text('Tap'), findsOneWidget);
      expect(find.text('Rotates the piece'), findsOneWidget);

      await tester.pump(GestureGuide.stepDuration);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Swipe sideways'), findsOneWidget);

      await tester.pump(GestureGuide.stepDuration * 2);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Flick down'), findsOneWidget);

      settings.controls = ControlScheme.buttons;
      await tester.pump();
      expect(find.byType(GestureGuide), findsNothing, reason: 'buttons mode shows its hint instead');
    });

    testWidgets('with reduced motion the guide is a still list of all gestures', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SettingsScreen(settings: SettingsViewModel()),
          ),
        ),
      );
      await tester.pumpAndSettle(); // settles: nothing loops
      for (final title in ['Tap', 'Swipe sideways', 'Drag down', 'Flick down']) {
        expect(find.textContaining(title), findsOneWidget);
      }
    });

    testWidgets('button controls replace gestures and repeat while held', (tester) async {
      final vm = seededViewModel();
      await pumpScreen(tester, vm, settings: SettingsViewModel(controls: ControlScheme.buttons));
      final board = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardPainter);

      final rotation = vm.state.active.rotation;
      await tester.tap(board);
      expect(vm.state.active.rotation, rotation, reason: 'board gestures are off');

      await tester.tap(find.bySemanticsLabel('Rotate'));
      expect(vm.state.active.rotation, (rotation + 1) % 4);

      final col = vm.state.active.col;
      await tester.tap(find.bySemanticsLabel('Move left'));
      expect(vm.state.active.col, col - 1, reason: 'acts on touch-down, once per tap');

      final hold = await tester.startGesture(tester.getCenter(find.bySemanticsLabel('Move right')));
      await tester.pump(const Duration(milliseconds: 300));
      await hold.up();
      expect(vm.state.active.col, greaterThan(col), reason: 'holding repeats');
      final settled = vm.state.active.col;
      await tester.pump(const Duration(milliseconds: 300));
      expect(vm.state.active.col, settled, reason: 'releasing stops the repeat');
    });

    testWidgets('gesture mode shows no button pad', (tester) async {
      await pumpScreen(tester, seededViewModel());
      expect(find.bySemanticsLabel('Rotate'), findsNothing);
    });

    test('choices are saved and restored', () async {
      final saved = await SettingsViewModel.load();
      saved
        ..themeMode = ThemeMode.dark
        ..showGhost = false
        ..haptics = false
        ..sound = false
        ..controls = ControlScheme.buttons;
      final restored = await SettingsViewModel.load();
      expect(restored.themeMode, ThemeMode.dark);
      expect(restored.showGhost, isFalse);
      expect(restored.haptics, isFalse);
      expect(restored.sound, isFalse);
      expect(restored.controls, ControlScheme.buttons);
    });
  });
}
