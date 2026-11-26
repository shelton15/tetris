import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../audio/sound_effects.dart';
import '../data/high_score_store.dart';
import '../model/game.dart';

/// Owns one running game: applies player commands to the [Game] rules,
/// drives gravity and the lock delay on timers, keeps the best score, and
/// notifies the view of every new state.
class GameViewModel extends ChangeNotifier {
  /// [sounds] is shared and owned by the caller; null plays nothing.
  GameViewModel({
    Game? game,
    HighScoreStore? highScores,
    bool Function()? hapticsEnabled,
    this._sounds,
    bool Function()? soundEnabled,
  }) : _game = game ?? Game(),
       _highScores = highScores ?? HighScoreStore(),
       _hapticsEnabled = hapticsEnabled ?? (() => true),
       _soundEnabled = soundEnabled ?? (() => true) {
    _state = _game.start();
    _scheduleGravity();
    _highScoreLoaded = _loadHighScore();
  }

  /// How long a grounded piece waits before it settles.
  static const lockDelay = Duration(milliseconds: 500);

  /// Moves or rotations that may restart [lockDelay] for one piece, so a
  /// piece cannot be stalled on the floor forever.
  static const maxLockResets = 15;

  final Game _game;
  final HighScoreStore _highScores;
  final bool Function() _hapticsEnabled;
  final SoundEffects? _sounds;
  final bool Function() _soundEnabled;
  late GameState _state;
  Timer? _gravity;
  Timer? _lockTimer;
  int _lockResets = 0;
  int _clearCount = 0;
  int _highScore = 0;
  bool _isNewHighScore = false;
  bool _disposed = false;
  int _gameNumber = 0;
  late final Future<void> _highScoreLoaded;

  GameState get state => _state;

  /// Best score on this device, including the current game once it ends.
  int get highScore => _highScore;

  /// True when the game just ended with a score above the previous best.
  bool get isNewHighScore => _isNewHighScore;

  /// Increments on every line clear, so the view can play its clear effect
  /// exactly once per clear.
  int get clearCount => _clearCount;

  void moveLeft() => _apply(_game.moveLeft, playerMoved: true);
  void moveRight() => _apply(_game.moveRight, playerMoved: true);
  void rotate() => _apply(_game.rotate, playerMoved: true, command: Sfx.rotate);
  void softDrop() => _apply(_game.softDrop, restartGravity: true);
  void hardDrop() => _apply(_game.hardDrop, restartGravity: true, command: Sfx.hardDrop);

  void pause() {
    if (_state.status == GameStatus.playing) _apply(_game.togglePause);
  }

  void resume() {
    if (_state.status == GameStatus.paused) _apply(_game.togglePause);
  }

  void restart() {
    _state = _game.start();
    _gameNumber++;
    _isNewHighScore = false;
    _lockResets = 0;
    _lockTimer?.cancel();
    _lockTimer = null;
    _scheduleGravity();
    notifyListeners();
  }

  /// Applies [action]; does nothing when the rules rejected it. [command]
  /// is the sound of the player's own action, played only if it took effect.
  void _apply(
    GameState Function(GameState) action, {
    bool restartGravity = false,
    bool playerMoved = false,
    Sfx? command,
  }) {
    final previous = _state;
    final next = action(previous);
    if (identical(next, previous)) return;
    _state = next;

    final locked = !identical(next.board, previous.board);
    if (locked) _lockResets = 0;
    if (next.clearedRows.isNotEmpty) _clearCount++;
    if (next.status == GameStatus.over && previous.status != GameStatus.over) _recordScore();
    _feedback(previous, next, command);

    if (restartGravity || next.status != previous.status || next.level != previous.level) {
      _scheduleGravity();
    }
    _updateLockTimer(playerMoved: playerMoved);
    notifyListeners();
  }

  /// Sound and haptics for one change, fired together on the frame it
  /// happens and only where they carry meaning: the player's own rotate or
  /// hard drop, then what the board did as a result. The biggest outcome
  /// wins (game over, four lines, a new level, a clear, a piece settling).
  void _feedback(GameState previous, GameState next, Sfx? command) {
    final ended = next.status == GameStatus.over && previous.status != GameStatus.over;
    final cleared = next.clearedRows.length;
    final settled = !identical(next.board, previous.board);
    final outcome = ended
        ? Sfx.gameOver
        : cleared >= 4
        ? Sfx.clearFour
        : next.level > previous.level
        ? Sfx.levelUp
        : cleared > 0
        ? Sfx.clear
        : settled && command == null
        ? Sfx.lock
        : null;

    if (_soundEnabled()) {
      if (command != null) _sounds?.play(command);
      if (outcome != null) _sounds?.play(outcome);
    }
    if (_hapticsEnabled()) {
      switch (outcome) {
        case Sfx.gameOver || Sfx.clearFour:
          HapticFeedback.heavyImpact();
        case Sfx.levelUp || Sfx.clear:
          HapticFeedback.mediumImpact();
        case _ when command == Sfx.hardDrop:
          HapticFeedback.lightImpact();
        case _:
      }
    }
  }

  void _scheduleGravity() {
    _gravity?.cancel();
    if (_state.status == GameStatus.playing) {
      _gravity = Timer(_state.dropInterval, () {
        _apply(_game.tick);
        _scheduleGravity();
      });
    }
  }

  /// Starts the lock countdown when the piece touches down, restarts it when
  /// the player slides or turns a grounded piece (up to [maxLockResets]),
  /// and cancels it whenever the piece is airborne or the game is not live.
  void _updateLockTimer({required bool playerMoved}) {
    if (_state.status != GameStatus.playing || !_state.isGrounded) {
      _lockTimer?.cancel();
      _lockTimer = null;
      return;
    }
    if (_lockTimer != null && !(playerMoved && _lockResets < maxLockResets)) return;
    if (_lockTimer != null) _lockResets++;
    _lockTimer?.cancel();
    _lockTimer = Timer(lockDelay, () {
      _lockTimer = null;
      _apply(_game.lock, restartGravity: true);
    });
  }

  Future<void> _loadHighScore() async {
    final stored = await _highScores.load();
    if (_disposed || stored <= _highScore) return;
    _highScore = stored;
    notifyListeners();
  }

  /// Waits for the stored best before comparing, so a fast first game can
  /// never overwrite a higher saved score.
  void _recordScore() {
    final score = _state.score;
    final game = _gameNumber;
    _highScoreLoaded.then((_) {
      if (_disposed || score <= _highScore) return;
      _highScore = score;
      _highScores.save(score);
      if (game == _gameNumber) _isNewHighScore = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _gravity?.cancel();
    _lockTimer?.cancel();
    super.dispose();
  }
}
