import 'package:shared_preferences/shared_preferences.dart';

/// Tiny wrapper for small on/off settings. Right now only tracks whether the
/// one-time "How to use" help has been shown.
class AppPrefs {
  static const _kHelpShown = 'help_shown';

  static Future<bool> helpAlreadyShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHelpShown) ?? false;
  }

  static Future<void> markHelpShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHelpShown, true);
  }
}
