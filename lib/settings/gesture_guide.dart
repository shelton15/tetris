import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../game/model/piece.dart';
import '../game/view/board_painter.dart';

/// One gesture the guide demonstrates.
enum _Move {
  tap('Tap', 'Rotates the piece', CupertinoIcons.hand_point_right_fill, Icons.touch_app_rounded),
  swipe(
    'Swipe sideways',
    'Moves one column for each cell you slide',
    CupertinoIcons.arrow_left_right,
    Icons.swap_horiz_rounded,
  ),
  drag(
    'Drag down',
    'Soft drop: lowers it row by row',
    CupertinoIcons.arrow_down,
    Icons.arrow_downward_rounded,
  ),
  flick(
    'Flick down',
    'Hard drop: sends it straight to the bottom',
    CupertinoIcons.arrow_down_to_line,
    Icons.vertical_align_bottom_rounded,
  );

  const _Move(this.title, this.detail, this.appleIcon, this.materialIcon);

  final String title;
  final String detail;
  final IconData appleIcon;
  final IconData materialIcon;
}

/// A looping demonstration of the touch gestures: a finger on a small board
/// taps, swipes, drags and flicks while a caption names each gesture and
/// what it does. With reduced motion on it shows the same four gestures as
/// a still list.
class GestureGuide extends StatefulWidget {
  const GestureGuide({super.key, required this.isApple});

  final bool isApple;

  /// Time spent demonstrating each gesture.
  static const stepDuration = Duration(milliseconds: 2600);

  static final semanticsLabel = [for (final m in _Move.values) '${m.title}: ${m.detail}.'].join(' ');

  @override
  State<GestureGuide> createState() => _GestureGuideState();
}

class _GestureGuideState extends State<GestureGuide> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: GestureGuide.stepDuration * _Move.values.length,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  IconData _icon(_Move m) => widget.isApple ? m.appleIcon : m.materialIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final guide = MediaQuery.disableAnimationsOf(context)
        ? _StillList(icon: _icon)
        : AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final progress = _loop.value * _Move.values.length;
              final move = _Move.values[progress.floor() % _Move.values.length];
              return Row(
                children: [
                  CustomPaint(
                    size: const Size(
                      _DemoPainter.cols * _DemoPainter.cell,
                      _DemoPainter.rows * _DemoPainter.cell,
                    ),
                    painter: _DemoPainter(
                      move: move,
                      t: progress - progress.floor(),
                      colors: BoardColors.of(theme.brightness),
                      finger: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          layoutBuilder: (current, previous) =>
                              Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                          child: Column(
                            key: ValueKey(move),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_icon(move), color: theme.colorScheme.primary, size: 26),
                              const SizedBox(height: 8),
                              Text(
                                move.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                move.detail,
                                style: theme.textTheme.bodyMedium?.copyWith(color: muted, letterSpacing: 0),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            for (final m in _Move.values)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(right: 6),
                                width: m == move ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: m == move
                                      ? theme.colorScheme.primary
                                      : muted.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
    return Semantics(
      label: GestureGuide.semanticsLabel,
      child: ExcludeSemantics(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: guide),
      ),
    );
  }
}

class _StillList extends StatelessWidget {
  const _StillList({required this.icon});

  final IconData Function(_Move) icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final m in _Move.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon(m), color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${m.title}  ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: m.detail,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Draws one frame of the demo: a small well, a T piece, and a fingertip.
/// [t] runs 0→1 through the current [move]; every move starts from the same
/// spot so each one reads on its own.
class _DemoPainter extends CustomPainter {
  _DemoPainter({required this.move, required this.t, required this.colors, required this.finger});

  static const cols = 6;
  static const rows = 9;
  static const cell = 17.0;

  final _Move move;
  final double t;
  final BoardColors colors;
  final Color finger;

  static double _ease(double t, double from, double to) =>
      Curves.easeInOutCubic.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(cell * 0.35)),
      Paint()..color = colors.well,
    );
    final empty = Paint()..color = colors.emptyCell;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell).deflate(1);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(cell * 0.2)), empty);
      }
    }

    // Piece and fingertip positions, in cells.
    var col = 1, row = 1, rotation = 0;
    Offset from, to;
    double pressAt, moveFrom, moveTo;
    switch (move) {
      case _Move.tap:
        from = to = const Offset(2.5, 2);
        pressAt = 0.3;
        moveFrom = moveTo = pressAt;
        if (t >= 0.35) rotation = 1;
      case _Move.swipe:
        from = const Offset(2.5, 4.5);
        to = const Offset(4.5, 4.5);
        pressAt = 0.15;
        moveFrom = 0.25;
        moveTo = 0.7;
        col += ((to.dx - from.dx) * _ease(t, moveFrom, moveTo)).round();
      case _Move.drag:
        from = const Offset(2.5, 3);
        to = const Offset(2.5, 6.5);
        pressAt = 0.15;
        moveFrom = 0.25;
        moveTo = 0.8;
        row += ((to.dy - from.dy) * _ease(t, moveFrom, moveTo)).floor();
      case _Move.flick:
        from = const Offset(2.5, 2.5);
        to = const Offset(2.5, 6.5);
        pressAt = 0.15;
        moveFrom = 0.3;
        moveTo = 0.42;
        if (t >= moveTo) row = rows - 2;
    }

    final piece = ActivePiece(PieceType.t, row: row, col: col, rotation: rotation);
    for (final c in piece.cells) {
      paintBlock(canvas, Rect.fromLTWH(c.col * cell, c.row * cell, cell, cell), PieceType.t);
    }

    // Fingertip: fades in, presses, travels, lifts, fades out.
    final opacity = t < 0.1 ? t / 0.1 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
    final down = t >= pressAt && t <= math.max(moveTo, pressAt) + 0.08;
    final travel = _ease(t, moveFrom, moveTo);
    final center = Offset.lerp(from, to, move == _Move.tap ? 0 : travel)! * cell;

    if (move == _Move.flick && t > moveFrom && t < moveTo + 0.25) {
      final fade = t < moveTo ? 1.0 : 1 - (t - moveTo) / 0.25;
      canvas.drawLine(
        from * cell,
        center,
        Paint()
          ..color = finger.withValues(alpha: 0.25 * fade * opacity)
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }
    if (move == _Move.tap && t >= pressAt && t < pressAt + 0.35) {
      final p = (t - pressAt) / 0.35;
      canvas.drawCircle(
        center,
        10 + 14 * p,
        Paint()
          ..color = finger.withValues(alpha: 0.5 * (1 - p) * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(center, down ? 9 : 11, Paint()..color = finger.withValues(alpha: 0.28 * opacity));
    canvas.drawCircle(
      center,
      down ? 9 : 11,
      Paint()
        ..color = finger.withValues(alpha: 0.7 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_DemoPainter old) =>
      old.t != t || old.move != move || old.colors != colors || old.finger != finger;
}
