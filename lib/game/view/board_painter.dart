import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../model/board.dart';
import '../model/game.dart';
import '../model/piece.dart';

/// Colours for the well, plus one original hue per shape. Every shape also
/// carries its own inner mark, so pieces read without relying on colour.
class BoardColors {
  const BoardColors._(this.well, this.emptyCell, this.flash);

  factory BoardColors.of(Brightness brightness) => brightness == Brightness.dark
      ? const BoardColors._(Color(0xFF16181D), Color(0xFF1D2027), Color(0xFFFFFFFF))
      : const BoardColors._(Color(0xFFE3E5EB), Color(0xFFF1F2F5), Color(0xFF5B8DEF));

  final Color well;
  final Color emptyCell;
  final Color flash;

  static const Map<PieceType, Color> pieces = {
    PieceType.i: Color(0xFF5B8DEF), // periwinkle
    PieceType.o: Color(0xFFE86A92), // rose
    PieceType.t: Color(0xFF3FBF9B), // mint
    PieceType.s: Color(0xFFF0A23B), // amber
    PieceType.z: Color(0xFF8C7CF0), // lavender
    PieceType.j: Color(0xFFEE7B57), // coral
    PieceType.l: Color(0xFF38AED6), // sky
  };
}

/// Draws one rounded block with a soft top bevel and its shape's mark.
void paintBlock(Canvas canvas, Rect cell, PieceType type) {
  final gap = math.max(1.0, cell.width * 0.06);
  final r = cell.deflate(gap);
  final radius = Radius.circular(r.width * 0.2);
  canvas.drawRRect(RRect.fromRectAndRadius(r, radius), Paint()..color = BoardColors.pieces[type]!);
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.45),
      topLeft: radius,
      topRight: radius,
    ),
    Paint()..color = const Color(0x24FFFFFF),
  );
  _paintMark(canvas, r, type);
}

void _paintMark(Canvas canvas, Rect r, PieceType type) {
  final c = r.center;
  final s = r.width * 0.18;
  final paint = Paint()
    ..color = const Color(0x66FFFFFF)
    ..strokeWidth = math.max(1.0, r.width * 0.09)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  switch (type) {
    case PieceType.i:
      canvas.drawLine(c.translate(-s, 0), c.translate(s, 0), paint);
    case PieceType.o:
      canvas.drawRect(Rect.fromCenter(center: c, width: s * 1.6, height: s * 1.6), paint);
    case PieceType.t:
      canvas.drawCircle(c, s * 0.55, paint..style = PaintingStyle.fill);
    case PieceType.s:
      canvas.drawLine(c.translate(-s, s), c.translate(s, -s), paint);
    case PieceType.z:
      canvas.drawLine(c.translate(-s, -s), c.translate(s, s), paint);
    case PieceType.j:
      canvas.drawLine(c.translate(0, -s), c.translate(0, s), paint);
    case PieceType.l:
      canvas.drawCircle(c, s * 0.85, paint);
  }
}

/// Paints the well: empty cells, settled blocks, the ghost, the falling
/// piece, and a fading light over rows that were just cleared.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.state,
    required this.colors,
    required this.flash,
    this.flashRows = const [],
    this.showGhost = true,
  }) : super(repaint: flash);

  final GameState state;
  final BoardColors colors;
  final Animation<double> flash;
  final List<int> flashRows;
  final bool showGhost;

  @override
  void paint(Canvas canvas, Size size) {
    final Board board = state.board;
    final cell = size.width / board.width;
    Rect rectAt(int row, int col) => Rect.fromLTWH(col * cell, row * cell, cell, cell);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.35)),
      Paint()..color = colors.well,
    );

    final empty = Paint()..color = colors.emptyCell;
    for (var row = 0; row < board.height; row++) {
      for (var col = 0; col < board.width; col++) {
        final type = board.at(row, col);
        if (type != null) {
          paintBlock(canvas, rectAt(row, col), type);
        } else {
          final r = rectAt(row, col).deflate(math.max(1.0, cell * 0.06));
          canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.2)), empty);
        }
      }
    }

    if (state.status != GameStatus.over && showGhost) {
      final ghostPaint = Paint()
        ..color = BoardColors.pieces[state.active.type]!.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, cell * 0.06);
      for (final c in state.ghost.cells) {
        final r = rectAt(c.row, c.col).deflate(cell * 0.1);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.2)), ghostPaint);
      }
    }
    if (state.status != GameStatus.over) {
      for (final c in state.active.cells) {
        paintBlock(canvas, rectAt(c.row, c.col), state.active.type);
      }
    }

    final t = 1 - flash.value;
    if (t > 0 && flashRows.isNotEmpty) {
      final light = Paint()..color = colors.flash.withValues(alpha: 0.55 * t);
      for (final row in flashRows) {
        canvas.drawRect(Rect.fromLTWH(0, row * cell, size.width, cell), light);
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      !identical(old.state, state) || old.colors != colors ||
      old.flashRows != flashRows ||
      old.showGhost != showGhost;
}

/// The small preview of the next shape, centred in a 4×2 box.
class NextPiecePainter extends CustomPainter {
  const NextPiecePainter(this.type);

  final PieceType type;

  @override
  void paint(Canvas canvas, Size size) {
    final cells = type.cells(0);
    final minRow = cells.map((c) => c.row).reduce(math.min);
    final minCol = cells.map((c) => c.col).reduce(math.min);
    final rows = cells.map((c) => c.row).reduce(math.max) - minRow + 1;
    final cols = cells.map((c) => c.col).reduce(math.max) - minCol + 1;
    final cell = math.min(size.width / 4, size.height / 2);
    final origin = Offset((size.width - cols * cell) / 2, (size.height - rows * cell) / 2);
    for (final c in cells) {
      paintBlock(
        canvas,
        Rect.fromLTWH(origin.dx + (c.col - minCol) * cell, origin.dy + (c.row - minRow) * cell, cell, cell),
        type,
      );
    }
  }

  @override
  bool shouldRepaint(NextPiecePainter old) => old.type != type;
}
