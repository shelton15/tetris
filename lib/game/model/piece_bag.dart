import 'dart:math';

import 'piece.dart';

/// Deals pieces from shuffled bags of all seven, so no shape is ever absent
/// for more than 12 pieces in a row.
class PieceBag {
  PieceBag([Random? random]) : _random = random ?? Random();

  final Random _random;
  final List<PieceType> _pending = [];

  PieceType next() {
    if (_pending.isEmpty) {
      _pending.addAll(List.of(PieceType.values)..shuffle(_random));
    }
    return _pending.removeAt(0);
  }
}
