import 'package:shared_preferences/shared_preferences.dart';

class Progress {
  final SharedPreferences prefs;
  Progress(this.prefs);
  int get unlocked => prefs.getInt('unlocked') ?? 1;
  bool canPlay(int n) => n >= 1 && n <= 16;
  double? best(int n) => prefs.getDouble('extendedBest$n');
  Future<void> win(int n, double time) async {
    if (best(n) == null || time < best(n)!) {
      await prefs.setDouble('extendedBest$n', time);
    }
    if (n >= unlocked && n < 16) await prefs.setInt('unlocked', n + 1);
  }

  bool flag(String key, [bool fallback = true]) =>
      prefs.getBool(key) ?? fallback;
  Future<void> toggle(String key, bool value) => prefs.setBool(key, value);
  double get sensitivity => prefs.getDouble('sensitivityV4') ?? 7.0;
}
