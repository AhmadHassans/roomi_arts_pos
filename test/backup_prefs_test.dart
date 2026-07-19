// Verifies the monthly backup-reminder logic in BackupPrefs.
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/backup/backup_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reminds when no backup has ever been taken', () async {
    expect(await BackupPrefs.shouldRemind(), isTrue);
    expect(await BackupPrefs.getLastBackup(), isNull);
  });

  test('does not remind right after a backup', () async {
    await BackupPrefs.setLastBackup(DateTime.now());
    expect(await BackupPrefs.shouldRemind(), isFalse);
  });

  test('reminds again once the backup is older than 30 days', () async {
    await BackupPrefs.setLastBackup(
        DateTime.now().subtract(const Duration(days: 31)));
    expect(await BackupPrefs.shouldRemind(), isTrue);
  });

  test('snooze hides the reminder even with no backup', () async {
    await BackupPrefs.snooze();
    expect(await BackupPrefs.shouldRemind(), isFalse);
  });

  test('a fresh backup clears an old-backup reminder', () async {
    await BackupPrefs.setLastBackup(
        DateTime.now().subtract(const Duration(days: 40)));
    expect(await BackupPrefs.shouldRemind(), isTrue);
    await BackupPrefs.setLastBackup(); // back up now
    expect(await BackupPrefs.shouldRemind(), isFalse);
  });

  test('fmtDate reads like "20 July 2026"', () {
    expect(BackupPrefs.fmtDate(DateTime(2026, 7, 20)), '20 July 2026');
  });
}
