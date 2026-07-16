import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../widgets/ui_kit.dart';

/// Shared full-screen shell for the login / setup / lock screens: a soft
/// background with one centered white card. Keeps those three screens looking
/// like one system.
class AuthScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  const AuthScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLav,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AppCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: GradientTile(
                      icon: icon,
                      gradient: AppGradients.primary,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppText.shopName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppTheme.display,
                        fontSize: Sizes.bigText,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: Sizes.titleText,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: Sizes.bodyText, color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
