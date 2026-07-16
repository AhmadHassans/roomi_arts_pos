import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/db/database.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/ui_kit.dart';
import '../reports/reports_controller.dart';
import '../sales_list/sales_list_controller.dart';
import '../stock/stock_controller.dart';

/// BACKUP & RESTORE: two big buttons, plain wording. Copies the single SQLite
/// file out to a folder the owner picks, and loads one back.
class BackupView extends StatelessWidget {
  const BackupView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Backup',
              style: TextStyle(fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'Keep a copy of your shop data safe on a USB drive or a folder.',
            style: TextStyle(fontSize: Sizes.bodyText, color: AppColors.textSoft),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BigCard(
                  icon: Icons.backup,
                  title: 'Backup',
                  body: 'Save a copy of all your data to a place you choose.',
                  buttonText: 'Backup now',
                  onPressed: () => _backup(context),
                ),
              ),
              const SizedBox(width: Sizes.gap),
              Expanded(
                child: _BigCard(
                  icon: Icons.settings_backup_restore,
                  title: 'Restore',
                  body: 'Load a saved backup. This replaces your current data.',
                  buttonText: 'Restore from backup',
                  danger: true,
                  onPressed: () => _restore(context),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _backup(BuildContext context) async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to save the backup',
    );
    if (dir == null) return; // owner cancelled

    // Simple, readable timestamped file name.
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}-${two(now.minute)}';
    final fileName = 'roomi_arts_backup_$stamp.db';

    try {
      final path = await AppDatabase.instance.backupTo(dir, fileName: fileName);
      await _message(
        icon: Icons.check_circle,
        title: 'Backup saved',
        body: 'Your data was saved to:\n$path',
      );
    } catch (e) {
      await _message(
        icon: Icons.error_outline,
        title: 'Backup failed',
        body: 'Could not save the backup.\n$e',
        danger: true,
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await askYesNo(
      title: 'Restore from a backup?',
      message: 'This will REPLACE all current data with the backup you choose. '
          'This cannot be undone.',
      yesText: 'Yes, restore',
      danger: true,
    );
    if (!ok) return;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a backup file',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    final path = result?.files.single.path;
    if (path == null) return; // cancelled

    try {
      await AppDatabase.instance.restoreFrom(path);
      // Reload any screens that are already showing data.
      if (Get.isRegistered<StockController>()) {
        await Get.find<StockController>().load();
      }
      if (Get.isRegistered<ReportsController>()) {
        await Get.find<ReportsController>().load();
      }
      if (Get.isRegistered<SalesListController>()) {
        await Get.find<SalesListController>().load();
      }
      await _message(
        icon: Icons.check_circle,
        title: 'Restore complete',
        body: 'Your data was loaded from the backup.',
      );
    } catch (e) {
      await _message(
        icon: Icons.error_outline,
        title: 'Restore failed',
        body: 'Could not load the backup.\n$e',
        danger: true,
      );
    }
  }

  Future<void> _message({
    required IconData icon,
    required String title,
    required String body,
    bool danger = false,
  }) async {
    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sizes.radius)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: danger ? AppColors.danger : AppColors.violet),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(fontSize: Sizes.titleText, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: Sizes.bodyText, color: AppColors.textSoft)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: Sizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String buttonText;
  final VoidCallback onPressed;
  final bool danger;

  const _BigCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonText,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient icon tile: cloud-up = violet, restore = red.
          Align(
            alignment: Alignment.centerLeft,
            child: GradientTile(
              icon: icon,
              gradient: danger ? AppGradients.danger : AppGradients.violet,
              size: 56,
            ),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: const TextStyle(
                  fontFamily: AppTheme.display,
                  fontSize: Sizes.titleText,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(fontSize: Sizes.bodyText, color: AppColors.muted)),
          const SizedBox(height: 24),
          GradientButton(
            expand: true,
            icon: danger ? Icons.settings_backup_restore : Icons.backup,
            label: buttonText,
            gradient: danger ? AppGradients.danger : AppGradients.primary,
            onTap: onPressed,
          ),
        ],
      ),
    );
  }
}
