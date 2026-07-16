import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/auth/auth_service.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'modules/auth/first_run_setup_view.dart';
import 'modules/auth/lock_view.dart';
import 'modules/auth/login_view.dart';
import 'modules/help/help_view.dart';
import 'modules/shell/shell_view.dart';
import 'widgets/app_prefs.dart';

class RoomiArtsApp extends StatelessWidget {
  const RoomiArtsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppText.shopName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _Root(),
    );
  }
}

/// Decides which screen to show based on the login state:
///   still checking -> spinner
///   no accounts    -> first-run owner setup
///   logged out     -> login
///   locked         -> lock screen
///   otherwise      -> the app (shell)
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.to;
    return Obx(() {
      final ready = auth.hasUsers.value;
      if (ready == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (ready == false) return const FirstRunSetupView();
      if (!auth.isLoggedIn) return const LoginView();
      if (auth.locked.value) return const LockView();
      return const _ShellWithHelp();
    });
  }
}

/// The shell plus the one-time "How to use" help on first ever launch.
class _ShellWithHelp extends StatefulWidget {
  const _ShellWithHelp();

  @override
  State<_ShellWithHelp> createState() => _ShellWithHelpState();
}

class _ShellWithHelpState extends State<_ShellWithHelp> {
  @override
  void initState() {
    super.initState();
    _maybeShowFirstRunHelp();
  }

  Future<void> _maybeShowFirstRunHelp() async {
    if (await AppPrefs.helpAlreadyShown()) return;
    // Wait for the first frame so a dialog can be shown safely.
    WidgetsBinding.instance.addPostFrameCallback((_) => HelpView.open());
  }

  @override
  Widget build(BuildContext context) => const ShellView();
}
