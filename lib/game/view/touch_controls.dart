import 'package:material_ui/material_ui.dart';

import '../view_model/game_view_model.dart';

/// Touch input over the play area.
///
/// - Tap rotates.
/// - Horizontal drag moves the piece one column per cell of finger travel,
///   so the piece tracks the finger 1:1.
/// - Downward drag soft-drops one row per cell of travel; a fast downward
///   flick hard-drops.
///
/// The axis is locked on the first movement, so a drag never both moves
/// and drops.
class TouchControls extends StatefulWidget {
  const TouchControls({super.key, required this.viewModel, required this.cellSize, required this.child});

  final GameViewModel viewModel;
  final double cellSize;
  final Widget child;

  /// Release speed (logical px/s) above which a downward swipe hard-drops.
  static const flickVelocity = 1400.0;

  @override
  State<TouchControls> createState() => _TouchControlsState();
}

enum _Axis { horizontal, down, none }

class _TouchControlsState extends State<TouchControls> {
  Offset _origin = Offset.zero;
  _Axis? _axis;
  int _applied = 0;

  void _onPanDown(DragDownDetails d) {
    _origin = d.localPosition;
    _axis = null;
    _applied = 0;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final delta = d.localPosition - _origin;
    _axis ??= delta.dx.abs() > delta.dy.abs()
        ? _Axis.horizontal
        : (delta.dy > 0 ? _Axis.down : _Axis.none);

    final vm = widget.viewModel;
    switch (_axis!) {
      case _Axis.horizontal:
        final target = (delta.dx / widget.cellSize).round();
        while (_applied < target) {
          vm.moveRight();
          _applied++;
        }
        while (_applied > target) {
          vm.moveLeft();
          _applied--;
        }
      case _Axis.down:
        final target = (delta.dy / widget.cellSize).floor();
        while (_applied < target) {
          vm.softDrop();
          _applied++;
        }
      case _Axis.none:
        break;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_axis == _Axis.down && d.velocity.pixelsPerSecond.dy > TouchControls.flickVelocity) {
      widget.viewModel.hardDrop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.viewModel.rotate,
      onPanDown: _onPanDown,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: widget.child,
    );
  }
}
