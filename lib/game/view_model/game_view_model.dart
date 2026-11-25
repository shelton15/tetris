import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../model/game.dart';

/// Owns one running game: applies player commands to the [Game] rules,
/// drives gravity on a timer, and notifies the view of every new state.
class GameViewModel extends ChangeNotifier {
  GameViewModel({Game? game}) : _game = game ?? Game() {
    _state = _game.start();
    _scheduleGravity();
  }

  final Game _game;
  late GameState _state;
  Timer? _gravity;
  int _clearCount = 0;

  GameState get state => _state;

  /// Increments on every line clear, so the view can play its clear effect
  /// exactly once per clear.
  int get clearCount => _clearCount;

  void moveLeft() => _apply(_game.moveLeft);
  void moveRight() => _apply(_game.moveRight);
  void rotate() => _apply(_game.rotate);
  void softDrop() => _apply(_game.softDrop, restartGravity: true);

  void hardDrop() {
    if (_apply(_game.hardDrop, restartGravity: true)) {
      HapticFeedback.lightImpact();
    }
  }

  void pause() {
    if (_state.status == GameStatus.playing) _apply(_game.togglePause);
  }

  void resume() {
    if (_state.status == GameStatus.paused) _apply(_game.togglePause);
  }

  void restart() {
    _state = _game.start();
    _scheduleGravity();
    notifyListeners();
  }

  /// Applies [action]; returns false when the rules rejected it.
  bool _apply(GameState Function(GameState) action, {bool restartGravity = false}) {
    final previous = _state;
    final next = action(previous);
    if (identical(next, previous)) return false;
    _state = next;
    if (next.clearedRows.isNotEmpty) {
      _clearCount++;
      HapticFeedback.mediumImpact();
    }
    if (restartGravity || next.status != previous.status || next.level != previous.level) {
      _scheduleGravity();
    }
    notifyListeners();
    return true;
  }

  void _scheduleGravity() {
    _gravity?.cancel();
    if (_state.status == GameStatus.playing) {
      _gravity = Timer(_state.dropInterval, () => _apply(_game.tick, restartGravity: true));
    }
  }

  @override
  void dispose() {
    _gravity?.cancel();
    super.dispose();
  }
}
