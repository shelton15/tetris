import 'package:shared_preferences/shared_preferences.dart';

/// Persists the best score on this device.
class HighScoreStore {
  static const _key = 'high_score';

  Future<int> load() async => (await SharedPreferences.getInstance()).getInt(_key) ?? 0;

  Future<void> save(int score) async => (await SharedPreferences.getInstance()).setInt(_key, score);
}
