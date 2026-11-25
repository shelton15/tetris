import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../settings/settings_screen.dart';
import '../view_model/settings_view_model.dart';
import '../model/game.dart';
import '../view_model/game_view_model.dart';
import 'board_painter.dart';
import 'control_pad.dart';
import 'touch_controls.dart';

/// The play screen: score bar, board, touch and keyboard input, the pause
/// sheet, and the game-over state. All game logic lives in [GameViewModel].
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.settings, this.viewModel});

  final SettingsViewModel settings;

  /// Injected in tests; otherwise the screen creates and owns its own.
  final GameViewModel? viewModel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late final GameViewModel _vm =
      widget.viewModel ?? GameViewModel(hapticsEnabled: () => widget.settings.haptics);
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  late final AppLifecycleListener _lifecycle;
  final FocusNode _focus = FocusNode(debugLabel: 'game');
  int _seenClears = 0;
  List<int> _flashRows = const [];
  bool _sheetOpen = false;

  bool get _isApple => switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onStateChanged);
    // Pause the moment the app stops being in front.
    _lifecycle = AppLifecycleListener(onInactive: _vm.pause, onHide: _vm.pause);
  }

  @override
  void dispose() {
    _vm.removeListener(_onStateChanged);
    _lifecycle.dispose();
    _flash.dispose();
    _focus.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (_vm.clearCount != _seenClears) {
      _seenClears = _vm.clearCount;
      _flashRows = _vm.state.clearedRows;
      if (!MediaQuery.disableAnimationsOf(context)) _flash.forward(from: 0);
    }
    if (_vm.state.status == GameStatus.paused && !_sheetOpen) _showPauseSheet();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final first = event is KeyDownEvent;
    final over = _vm.state.status == GameStatus.over;
    final VoidCallback? action = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => _vm.moveLeft,
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => _vm.moveRight,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => _vm.softDrop,
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.keyW ||
      LogicalKeyboardKey.keyX when first => _vm.rotate,
      LogicalKeyboardKey.space when first => over ? _vm.restart : _vm.hardDrop,
      LogicalKeyboardKey.enter when first && over => _vm.restart,
      LogicalKeyboardKey.keyP || LogicalKeyboardKey.escape when first => _vm.pause,
      _ => null,
    };
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  Future<void> _showPauseSheet() async {
    _sheetOpen = true;
    final restart = await (_isApple ? _showCupertinoPauseSheet() : _showMaterialPauseSheet());
    _sheetOpen = false;
    if (!mounted) return;
    restart == true ? _vm.restart() : _vm.resume();
    _focus.requestFocus();
  }

  /// Pauses quietly while settings is open, then offers the pause sheet on
  /// return so play resumes only when the player is ready.
  Future<void> _openSettings() async {
    final wasPlaying = _vm.state.status == GameStatus.playing;
    _sheetOpen = true;
    _vm.pause();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: widget.settings)));
    _sheetOpen = false;
    if (!mounted) return;
    if (wasPlaying && _vm.state.status == GameStatus.paused) {
      _showPauseSheet();
    } else {
      _focus.requestFocus();
    }
  }

  Future<bool?> _showCupertinoPauseSheet() {
    final s = _vm.state;
    return showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Paused'),
        message: Text('${formatScore(s.score)} points · Best ${formatScore(_vm.highScore)}'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart Game'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Resume'),
        ),
      ),
    );
  }

  Future<bool?> _showMaterialPauseSheet() {
    final s = _vm.state;
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Paused', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${formatScore(s.score)} points · Best ${formatScore(_vm.highScore)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Resume')),
                // Restart sits apart from Resume so it is never hit by accident.
                const SizedBox(height: 32),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Restart game'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BoardColors.of(Theme.of(context).brightness);
    return Scaffold(
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: ListenableBuilder(
            listenable: Listenable.merge([_vm, widget.settings]),
            builder: (context, _) {
              final state = _vm.state;
              final buttons = widget.settings.controls == ControlScheme.buttons;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
                    child: _ScoreBar(
                      state: state,
                      isApple: _isApple,
                      onPause: _vm.pause,
                      onSettings: _openSettings,
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final cell = math
                            .min(
                              (box.maxWidth - 24) / state.board.width,
                              (box.maxHeight - 12) / state.board.height,
                            )
                            .floorToDouble();
                        return TouchControls(
                          enabled: !buttons,
                          viewModel: _vm,
                          cellSize: cell,
                          child: Center(
                            child: SizedBox(
                              width: cell * state.board.width,
                              height: cell * state.board.height,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Semantics(
                                    label: 'Board',
                                    hint: buttons
                                        ? null
                                        : 'Tap to rotate. Swipe sideways to move. Swipe down to drop.',
                                    child: CustomPaint(
                                      painter: BoardPainter(
                                        state: state,
                                        colors: colors,
                                        flash: _flash,
                                        flashRows: _flashRows,
                                        showGhost: widget.settings.showGhost,
                                      ),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 220),
                                    child: state.status == GameStatus.over
                                        ? _GameOver(
                                            state: state,
                                            highScore: _vm.highScore,
                                            isNewHighScore: _vm.isNewHighScore,
                                            isApple: _isApple,
                                            onRestart: _vm.restart,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (buttons) ControlPad(viewModel: _vm, isApple: _isApple),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 12480 → "12,480".
String formatScore(int value) =>
    value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

const _tabular = [FontFeature.tabularFigures()];

String _progressLine(GameState s) => 'Level ${s.level} · ${s.lines} ${s.lines == 1 ? 'line' : 'lines'}';

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.state,
    required this.isApple,
    required this.onPause,
    required this.onSettings,
  });

  final GameState state;
  final bool isApple;
  final VoidCallback onPause;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatScore(state.score),
                  semanticsLabel: '${state.score} points',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.1,
                    fontFeatures: _tabular,
                  ),
                ),
                Text(
                  _progressLine(state),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
          ),
        ),
        Semantics(
          label: 'Next piece',
          child: SizedBox(width: 56, height: 28, child: CustomPaint(painter: NextPiecePainter(state.next))),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Settings',
          iconSize: 26,
          onPressed: onSettings,
          icon: Icon(isApple ? CupertinoIcons.gear_alt_fill : Icons.settings_rounded),
        ),
        IconButton(
          tooltip: 'Pause',
          iconSize: 28,
          onPressed: state.status == GameStatus.playing ? onPause : null,
          icon: Icon(isApple ? CupertinoIcons.pause_fill : Icons.pause_rounded),
        ),
      ],
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver({
    required this.state,
    required this.highScore,
    required this.isNewHighScore,
    required this.isApple,
    required this.onRestart,
  });

  final GameState state;
  final int highScore;
  final bool isNewHighScore;
  final bool isApple;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = isApple
        ? CupertinoButton.filled(onPressed: onRestart, child: const Text('Play Again'))
        : FilledButton(onPressed: onRestart, child: const Text('Play again'));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Game over', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              formatScore(state.score),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                fontFeatures: _tabular,
              ),
            ),
            Text(
              _progressLine(state),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              isNewHighScore ? 'New best score' : 'Best ${formatScore(highScore)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isNewHighScore ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontFeatures: _tabular,
              ),
            ),
            const SizedBox(height: 28),
            button,
          ],
        ),
      ),
    );
  }
}
