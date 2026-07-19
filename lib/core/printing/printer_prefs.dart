import 'package:shared_preferences/shared_preferences.dart';

/// How receipts are printed.
///  - system: the USB / system thermal printer (Windows spooler). On a machine
///    with no such printer (e.g. a Mac while testing) it falls back to the
///    on-screen preview automatically — no errors.
///  - network: a network printer over TCP at [PrinterPrefs.getIp]:port.
enum PrinterMode { system, network }

/// Saved printer settings (mode + network IP/port). Persisted with
/// shared_preferences so they survive restarts.
class PrinterPrefs {
  static const _kMode = 'printer_mode';
  static const _kIp = 'printer_ip';
  static const _kPort = 'printer_port';
  static const _kName = 'printer_name';

  /// Default raw ESC/POS port for most network thermal printers.
  static const int defaultPort = 9100;

  static PrinterMode _modeFrom(String? s) =>
      s == 'network' ? PrinterMode.network : PrinterMode.system;
  static String modeName(PrinterMode m) =>
      m == PrinterMode.network ? 'network' : 'system';

  static Future<PrinterMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Default: system/USB printer (previews automatically where there is none).
    return _modeFrom(prefs.getString(_kMode));
  }

  static Future<String> getIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kIp) ?? '';
  }

  static Future<int> getPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPort) ?? defaultPort;
  }

  /// Chosen USB/system printer name. Empty string means "use the Windows
  /// default printer".
  static Future<String> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kName) ?? '';
  }

  static Future<void> save({
    required PrinterMode mode,
    required String ip,
    required int port,
    String name = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, modeName(mode));
    await prefs.setString(_kIp, ip.trim());
    await prefs.setInt(_kPort, port);
    await prefs.setString(_kName, name.trim());
  }
}
