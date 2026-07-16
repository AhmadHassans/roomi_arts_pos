import 'package:shared_preferences/shared_preferences.dart';

/// Saved network-printer settings (IP + port). Persisted with
/// shared_preferences so they survive restarts.
class PrinterPrefs {
  static const _kIp = 'printer_ip';
  static const _kPort = 'printer_port';

  /// Default raw ESC/POS port for most network thermal printers.
  static const int defaultPort = 9100;

  static Future<String> getIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kIp) ?? '';
  }

  static Future<int> getPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPort) ?? defaultPort;
  }

  static Future<void> save({required String ip, required int port}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIp, ip.trim());
    await prefs.setInt(_kPort, port);
  }
}
