import 'package:material_ui/material_ui.dart';

import 'game/audio/sound_effects.dart';
import 'game/view/game_screen.dart';
import 'game/view_model/settings_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sounds load in the background; the first frame does not wait for them.
  final sounds = SoundEffects()..load();
  runApp(CairnApp(settings: await SettingsViewModel.load(), sounds: sounds));
}

class CairnApp extends StatelessWidget {
  const CairnApp({super.key, required this.settings, this.sounds});

  final SettingsViewModel settings;
  final SoundEffects? sounds;

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B8DEF), brightness: brightness),
      scaffoldBackgroundColor: dark ? const Color(0xFF0E0F12) : const Color(0xFFF7F7FA),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Cairn',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: settings.themeMode,
        home: GameScreen(settings: settings, sounds: sounds),
      ),
    );
  }
}
