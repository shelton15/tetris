import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../game/view_model/settings_view_model.dart';
import 'gesture_guide.dart';

/// Preferences, laid out with each platform's own settings conventions:
/// inset grouped lists on Apple platforms, Material lists elsewhere.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsViewModel settings;

  static const _themeLabels = {
    ThemeMode.system: 'Automatic',
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
  };

  /// Icons that show what each appearance does: half-filled for "follows
  /// the device", sun for light, moon for dark.
  static const _themeIconsApple = {
    ThemeMode.system: CupertinoIcons.circle_lefthalf_fill,
    ThemeMode.light: CupertinoIcons.sun_max_fill,
    ThemeMode.dark: CupertinoIcons.moon_fill,
  };
  static const _themeIconsMaterial = {
    ThemeMode.system: Icons.brightness_auto_rounded,
    ThemeMode.light: Icons.light_mode_rounded,
    ThemeMode.dark: Icons.dark_mode_rounded,
  };

  static const _controlLabels = {ControlScheme.gestures: 'Gestures', ControlScheme.buttons: 'Buttons'};
  static const _controlIconsApple = {
    ControlScheme.gestures: CupertinoIcons.hand_draw_fill,
    ControlScheme.buttons: CupertinoIcons.game_controller_solid,
  };
  static const _controlIconsMaterial = {
    ControlScheme.gestures: Icons.swipe_rounded,
    ControlScheme.buttons: Icons.gamepad_rounded,
  };
  static const _buttonsHint = 'Buttons below the board move, drop and rotate. Hold an arrow to repeat.';

  static const _ghostHint = 'Outline where the falling piece will land';
  static const _hapticsHint = 'Vibrate on drops, line clears and game over';
  static const _soundHint = 'Effects for turns, drops, line clears and game over';
  // iPhone's silent switch mutes the effects; say so, so silence never looks broken.
  static const _soundHintApple = 'Drops and line clears. Silent mode mutes it.';

  @override
  Widget build(BuildContext context) {
    final isApple = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => isApple ? _buildCupertino(context) : _buildMaterial(context),
    );
  }

  Widget _buildCupertino(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      // Hosted inside a MaterialApp, so supply the Cupertino text style
      // that a CupertinoApp would normally provide.
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: SafeArea(
          child: ListView(
            children: [
              CupertinoListSection.insetGrouped(
                header: const Text('Appearance'),
                children: [
                  _cupertinoSegments(
                    value: settings.themeMode,
                    labels: _themeLabels,
                    icons: _themeIconsApple,
                    onChanged: (mode) => settings.themeMode = mode,
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('Controls'),
                footer: settings.controls == ControlScheme.buttons
                    ? Text(
                        _buttonsHint,
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      )
                    : null,
                children: [
                  _cupertinoSegments(
                    value: settings.controls,
                    labels: _controlLabels,
                    icons: _controlIconsApple,
                    onChanged: (c) => settings.controls = c,
                  ),
                  // Shows each gesture in motion, so the player learns them here
                  // rather than by trial on the board.
                  if (settings.controls == ControlScheme.gestures) const GestureGuide(isApple: true),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('Gameplay'),
                children: [
                  CupertinoListTile(
                    title: const Text('Ghost Piece'),
                    subtitle: const Text(_ghostHint),
                    trailing: CupertinoSwitch(
                      value: settings.showGhost,
                      onChanged: (v) => settings.showGhost = v,
                    ),
                  ),
                  CupertinoListTile(
                    title: const Text('Sound'),
                    subtitle: const Text(_soundHintApple),
                    trailing: CupertinoSwitch(
                      value: settings.sound,
                      onChanged: (v) => settings.sound = v,
                    ),
                  ),
                  CupertinoListTile(
                    title: const Text('Haptics'),
                    subtitle: const Text(_hapticsHint),
                    trailing: CupertinoSwitch(
                      value: settings.haptics,
                      onChanged: (v) => settings.haptics = v,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A full-width sliding segmented control whose segments pair an icon
  /// with a label.
  Widget _cupertinoSegments<T extends Object>({
    required T value,
    required Map<T, String> labels,
    required Map<T, IconData> icons,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: value,
          onValueChanged: (v) {
            if (v != null) onChanged(v);
          },
          children: {
            for (final e in labels.entries)
              e.key: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                // Shrinks rather than clipping at large text sizes.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(icons[e.key], size: 17), const SizedBox(width: 6), Text(e.value)],
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }

  Widget _buildMaterial(BuildContext context) {
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          header('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              // Keep each mode's own icon instead of swapping in a checkmark.
              showSelectedIcon: false,
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.themeMode = s.single,
              segments: [
                for (final e in _themeLabels.entries)
                  ButtonSegment(
                    value: e.key,
                    icon: Icon(_themeIconsMaterial[e.key]),
                    label: Text(e.key == ThemeMode.system ? 'System' : e.value),
                  ),
              ],
            ),
          ),
          header('Controls'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ControlScheme>(
              showSelectedIcon: false,
              selected: {settings.controls},
              onSelectionChanged: (s) => settings.controls = s.single,
              segments: [
                for (final e in _controlLabels.entries)
                  ButtonSegment(value: e.key, icon: Icon(_controlIconsMaterial[e.key]), label: Text(e.value)),
              ],
            ),
          ),
          if (settings.controls == ControlScheme.gestures)
            const Padding(padding: EdgeInsets.only(top: 12), child: GestureGuide(isApple: false))
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _buttonsHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          header('Gameplay'),
          SwitchListTile(
            title: const Text('Ghost piece'),
            subtitle: const Text(_ghostHint),
            value: settings.showGhost,
            onChanged: (v) => settings.showGhost = v,
          ),
          SwitchListTile(
            title: const Text('Sound'),
            subtitle: const Text(_soundHint),
            value: settings.sound,
            onChanged: (v) => settings.sound = v,
          ),
          SwitchListTile(
            title: const Text('Haptics'),
            subtitle: const Text(_hapticsHint),
            value: settings.haptics,
            onChanged: (v) => settings.haptics = v,
          ),
        ],
      ),
    );
  }
}
