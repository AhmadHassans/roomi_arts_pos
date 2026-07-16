import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/app_prefs.dart';

/// One-time "How to use" screen (shown on first launch) and reopenable from the
/// small "Help" button in the corner. 4-5 short plain sentences.
class HelpView extends StatelessWidget {
  const HelpView({super.key});

  /// Show as a centered dialog. Marks help as shown when closed.
  static Future<void> open() async {
    await Get.dialog(const HelpView(), barrierDismissible: true);
    await AppPrefs.markHelpShown();
  }

  static const _steps = [
    ['Make a sale',
        'Open "New Sale". Search or tap a product to add it. Press "Complete sale & print".'],
    ['Add a product',
        'Go to "Stock" and press "Add product". Type the name and prices, then save.'],
    ['Do a return',
        'Go to "Return", type the invoice number, tick the items, and confirm.'],
    ['See reports',
        'Go to "Reports" to see today\'s sales, profit, and best sellers.'],
    ['Back up your data',
        'Go to "Backup" and press "Backup" to save a copy onto a USB drive.'],
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.radius),
      ),
      child: ConstrainedBox(
        // Cap height to the window (leave a margin) so it never grows past it.
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height - 80,
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed header (never scrolls away).
              const Text('How to use Roomi Arts',
                  style: TextStyle(
                      fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Here are the main things you can do:',
                  style: TextStyle(
                      fontSize: Sizes.bodyText, color: AppColors.textSoft)),
              const SizedBox(height: 20),
              // Scrollable cards — all sections always reachable.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in _steps) ...[
                        _HelpRow(title: s[0], body: s[1]),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Fixed close button (always visible).
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String title;
  final String body;
  const _HelpRow({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tealTint,
        borderRadius: BorderRadius.circular(Sizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: Sizes.bodyText,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: Sizes.bodyText)),
        ],
      ),
    );
  }
}
