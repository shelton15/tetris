/// The seven four-square shapes and their rotation states.
///
/// Coordinates are `(row, col)` inside each shape's bounding box, row 0 at
/// the top. Rotation states are derived by turning the spawn state clockwise
/// inside its box, so every shape rotates around a fixed centre.
library;

typedef Cell = ({int row, int col});

enum PieceType {
  i(4, [(row: 1, col: 0), (row: 1, col: 1), (row: 1, col: 2), (row: 1, col: 3)]),
  o(2, [(row: 0, col: 0), (row: 0, col: 1), (row: 1, col: 0), (row: 1, col: 1)]),
  t(3, [(row: 0, col: 1), (row: 1, col: 0), (row: 1, col: 1), (row: 1, col: 2)]),
  s(3, [(row: 0, col: 1), (row: 0, col: 2), (row: 1, col: 0), (row: 1, col: 1)]),
  z(3, [(row: 0, col: 0), (row: 0, col: 1), (row: 1, col: 1), (row: 1, col: 2)]),
  j(3, [(row: 0, col: 0), (row: 1, col: 0), (row: 1, col: 1), (row: 1, col: 2)]),
  l(3, [(row: 0, col: 2), (row: 1, col: 0), (row: 1, col: 1), (row: 1, col: 2)]);

  const PieceType(this.boxSize, this._spawnCells);

  /// Side length of the square box the shape rotates in.
  final int boxSize;
  final List<Cell> _spawnCells;

  /// Cells for rotation state 0–3 (clockwise), relative to the box origin.
  List<Cell> cells(int rotation) => _rotations[this]![rotation % 4];

  static final Map<PieceType, List<List<Cell>>> _rotations = {
    for (final type in PieceType.values) type: _buildRotations(type),
  };

  static List<List<Cell>> _buildRotations(PieceType type) {
    final states = <List<Cell>>[List.unmodifiable(type._spawnCells)];
    for (var r = 1; r < 4; r++) {
      final n = type.boxSize;
      states.add(List.unmodifiable([for (final c in states.last) (row: c.col, col: n - 1 - c.row)]));
    }
    return List.unmodifiable(states);
  }
}

/// A shape placed on the board: its box's top-left corner and rotation.
class ActivePiece {
  const ActivePiece(this.type, {required this.row, required this.col, this.rotation = 0});

  /// Spawns centred horizontally at the top of a board [boardWidth] wide.
  factory ActivePiece.spawn(PieceType type, int boardWidth) =>
      ActivePiece(type, row: 0, col: (boardWidth - type.boxSize) ~/ 2);

  final PieceType type;
  final int row;
  final int col;
  final int rotation;

  /// Absolute board cells this piece covers.
  Iterable<Cell> get cells => type.cells(rotation).map((c) => (row: row + c.row, col: col + c.col));

  ActivePiece moved({int dRow = 0, int dCol = 0}) =>
      ActivePiece(type, row: row + dRow, col: col + dCol, rotation: rotation);

  ActivePiece rotated() => ActivePiece(type, row: row, col: col, rotation: (rotation + 1) % 4);
}
