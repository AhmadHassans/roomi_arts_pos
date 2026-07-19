import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when the shop data was last backed up, and when a "remind me
/// later" snooze expires, so the app can nudge the owner about once a month.
///
/// This only tracks reminder state — the actual backup/restore logic is
/// untouched (see BackupView / AppDatabase).
class BackupPrefs {
  BackupPrefs._();

  static const _kLast = 'last_backup_iso';
  static const _kSnooze = 'backup_snooze_iso';

  /// Remind again after roughly a month with no backup.
  static const int remindAfterDays = 30;

  /// "Remind me later" hides the nudge for this many days.
  static const int snoozeDays = 3;

  /// Date of the last successful backup, or null if none has been taken.
  static Future<DateTime?> getLastBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kLast);
    return s == null ? null : DateTime.tryParse(s);
  }

  /// Record a successful backup at [when] (defaults to now).
  static Future<void> setLastBackup([DateTime? when]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLast, (when ?? DateTime.now()).toIso8601String());
  }

  /// Snooze the reminder for [snoozeDays] from now.
  static Future<void> snooze() async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(const Duration(days: snoozeDays));
    await prefs.setString(_kSnooze, until.toIso8601String());
  }

  /// Whether to show the backup reminder now: true if no backup has ever been
  /// taken or it is older than [remindAfterDays] — unless a snooze is still
  /// active.
  static Future<bool> shouldRemind() async {
    final prefs = await SharedPreferences.getInstance();

    final snoozeStr = prefs.getString(_kSnooze);
    final snooze = snoozeStr == null ? null : DateTime.tryParse(snoozeStr);
    if (snooze != null && DateTime.now().isBefore(snooze)) return false;

    final lastStr = prefs.getString(_kLast);
    final last = lastStr == null ? null : DateTime.tryParse(lastStr);
    if (last == null) return true; // never backed up
    return DateTime.now().difference(last).inDays >= remindAfterDays;
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// "20 July 2026".
  static String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
}
