import 'package:material_ui/material_ui.dart';

import 'game/view/game_screen.dart';

void main() => runApp(const CairnApp());

class CairnApp extends StatelessWidget {
  const CairnApp({super.key});

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B8DEF), brightness: brightness),
      scaffoldBackgroundColor: dark ? const Color(0xFF0E0F12) : const Color(0xFFF7F7FA),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cairn',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const GameScreen(),
    );
  }
}
