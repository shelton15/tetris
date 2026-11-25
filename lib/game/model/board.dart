import 'piece.dart';

/// The well of settled blocks. Immutable: every change returns a new board.
class Board {
  Board.empty({this.width = 10, this.height = 20})
      : _cells = List.filled(width * height, null);

  Board._(this.width, this.height, this._cells);

  /// Builds a board from rows of text, top row first: `.` is empty, any other
  /// character is a settled block (stored as [PieceType.o]). Test helper.
  factory Board.fromRows(List<String> rows, {int width = 10}) {
    final cells = <PieceType?>[
      for (final row in rows)
        for (var c = 0; c < width; c++) row[c] == '.' ? null : PieceType.o,
    ];
    return Board._(width, rows.length, cells);
  }

  final int width;
  final int height;
  final List<PieceType?> _cells;

  PieceType? at(int row, int col) => _cells[row * width + col];

  bool isInside(int row, int col) =>
      row >= 0 && row < height && col >= 0 && col < width;

  /// True when every cell of [piece] is inside the well and unoccupied.
  bool fits(ActivePiece piece) => piece.cells
      .every((c) => isInside(c.row, c.col) && at(c.row, c.col) == null);

  /// Settles [piece] into the board.
  Board lock(ActivePiece piece) {
    final cells = List.of(_cells);
    for (final c in piece.cells) {
      cells[c.row * width + c.col] = piece.type;
    }
    return Board._(width, height, cells);
  }

  /// Removes full rows and drops the rows above them.
  ({Board board, int cleared}) clearFullRows() {
    final kept = <List<PieceType?>>[];
    for (var r = 0; r < height; r++) {
      final row = _cells.sublist(r * width, (r + 1) * width);
      if (row.contains(null)) kept.add(row);
    }
    final cleared = height - kept.length;
    if (cleared == 0) return (board: this, cleared: 0);
    final cells = [
      ...List<PieceType?>.filled(cleared * width, null),
      for (final row in kept) ...row,
    ];
    return (board: Board._(width, height, cells), cleared: cleared);
  }
}
