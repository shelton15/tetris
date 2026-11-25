import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../view_model/game_view_model.dart';

/// On-screen buttons for players who prefer them to gestures. Movement sits
/// under the left thumb and dropping and rotating under the right.
class ControlPad extends StatelessWidget {
  const ControlPad({super.key, required this.viewModel, required this.isApple});

  final GameViewModel viewModel;
  final bool isApple;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    IconData icon(IconData apple, IconData material) => isApple ? apple : material;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          ControlButton(
            label: 'Move left',
            icon: icon(CupertinoIcons.arrow_left, Icons.arrow_back_rounded),
            onPressed: vm.moveLeft,
            repeats: true,
          ),
          const SizedBox(width: 12),
          ControlButton(
            label: 'Move right',
            icon: icon(CupertinoIcons.arrow_right, Icons.arrow_forward_rounded),
            onPressed: vm.moveRight,
            repeats: true,
          ),
          const Spacer(),
          ControlButton(
            label: 'Soft drop',
            icon: icon(CupertinoIcons.arrow_down, Icons.arrow_downward_rounded),
            onPressed: vm.softDrop,
            repeats: true,
          ),
          const SizedBox(width: 12),
          ControlButton(
            label: 'Hard drop',
            icon: icon(CupertinoIcons.arrow_down_to_line, Icons.vertical_align_bottom_rounded),
            onPressed: vm.hardDrop,
          ),
          const SizedBox(width: 12),
          ControlButton(
            label: 'Rotate',
            icon: icon(CupertinoIcons.arrow_clockwise, Icons.rotate_right_rounded),
            onPressed: vm.rotate,
            prominent: true,
          ),
        ],
      ),
    );
  }
}

/// A round game button that acts the instant it is touched, not on release,
/// and, when [repeats] is set, keeps acting while held.
class ControlButton extends StatefulWidget {
  const ControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.repeats = false,
    this.prominent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool repeats;

  /// Draws the button in the accent colour (used for the most-pressed one).
  final bool prominent;

  /// Hold this long before repeating starts, then repeat at [repeatInterval].
  static const repeatDelay = Duration(milliseconds: 170);
  static const repeatInterval = Duration(milliseconds: 50);

  static const size = 58.0;

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool _pressed = false;
  Timer? _repeat;

  void _down(PointerDownEvent _) {
    setState(() => _pressed = true);
    widget.onPressed();
    if (widget.repeats) {
      _repeat = Timer(ControlButton.repeatDelay, () {
        _repeat = Timer.periodic(ControlButton.repeatInterval, (_) => widget.onPressed());
      });
    }
  }

  void _up([PointerEvent? _]) {
    _repeat?.cancel();
    _repeat = null;
    if (mounted && _pressed) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = widget.prominent ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final foreground = widget.prominent ? scheme.onPrimaryContainer : scheme.onSurface;
    final instant = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: Listener(
          onPointerDown: _down,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: instant ? Duration.zero : const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: instant ? Duration.zero : const Duration(milliseconds: 90),
              width: ControlButton.size,
              height: ControlButton.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pressed
                    ? Color.alphaBlend(foreground.withValues(alpha: 0.12), background)
                    : background,
              ),
              child: Icon(widget.icon, color: foreground, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
