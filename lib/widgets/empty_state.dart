import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';

/// A friendly, helpful empty state that tells the owner what to do next.
/// e.g. "No products yet. Press 'Add product' to begin."
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final Widget? action; // optional big button

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    // Centered when there is room, scrollable when the space is tight, so it
    // never overflows in a small panel (e.g. the cart column on a small window).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: AppColors.violet),
                const SizedBox(height: Sizes.gap),
                Text(title,
                    style: const TextStyle(
                        fontSize: Sizes.titleText, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: Sizes.bodyText, color: AppColors.textSoft)),
                if (action != null) ...[
                  const SizedBox(height: 24),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
