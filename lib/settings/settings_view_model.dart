import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player preferences, persisted on the device. Every change is saved
/// immediately and broadcast to listeners (the app theme, the board, the
/// game's haptics).
class SettingsViewModel extends ChangeNotifier {
  /// Defaults, not persisted. Used by [load] and by tests.
  SettingsViewModel({
    this._themeMode = ThemeMode.system,
    this._showGhost = true,
    this._haptics = true,
    this._prefs,
  });

  /// Reads saved preferences; call before `runApp` so the first frame
  /// already has the right theme.
  static Future<SettingsViewModel> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_themeKey);
    return SettingsViewModel(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == mode, orElse: () => ThemeMode.system),
      showGhost: prefs.getBool(_ghostKey) ?? true,
      haptics: prefs.getBool(_hapticsKey) ?? true,
      prefs: prefs,
    );
  }

  static const _themeKey = 'theme_mode';
  static const _ghostKey = 'show_ghost';
  static const _hapticsKey = 'haptics';

  final SharedPreferences? _prefs;
  ThemeMode _themeMode;
  bool _showGhost;
  bool _haptics;

  ThemeMode get themeMode => _themeMode;
  bool get showGhost => _showGhost;
  bool get haptics => _haptics;

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    _prefs?.setString(_themeKey, value.name);
    notifyListeners();
  }

  set showGhost(bool value) {
    if (value == _showGhost) return;
    _showGhost = value;
    _prefs?.setBool(_ghostKey, value);
    notifyListeners();
  }

  set haptics(bool value) {
    if (value == _haptics) return;
    _haptics = value;
    _prefs?.setBool(_hapticsKey, value);
    notifyListeners();
  }
}
