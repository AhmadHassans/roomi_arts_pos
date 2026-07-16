import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/constants.dart';
import '../core/theme.dart';

/// A plain, non-scary Yes / No confirmation.
///
/// Returns true if the owner presses Yes. Wording is kept simple and the
/// buttons are big. Used before completing a sale and before deleting anything.
Future<bool> askYesNo({
  required String title,
  required String message,
  String yesText = 'Yes',
  String noText = 'No',
  bool danger = false, // makes the Yes button red (e.g. deletes)
}) async {
  final result = await Get.dialog<bool>(
    Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: Sizes.titleText, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: Sizes.bodyText)),
            const SizedBox(height: 24),
            Row(
              children: [
                // No is on the left and calm (easy to back out).
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, Sizes.buttonHeight),
                      side: const BorderSide(color: Color(0xFFD5DDDA)),
                      foregroundColor: AppColors.text,
                    ),
                    onPressed: () => Get.back(result: false),
                    child: Text(noText,
                        style: const TextStyle(fontSize: Sizes.bodyText)),
                  ),
                ),
                const SizedBox(width: Sizes.gap),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, Sizes.buttonHeight),
                      backgroundColor:
                          danger ? AppColors.danger : AppColors.violet,
                    ),
                    onPressed: () => Get.back(result: true),
                    child: Text(yesText,
                        style: const TextStyle(fontSize: Sizes.bodyText)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: true,
  );
  return result ?? false;
}
