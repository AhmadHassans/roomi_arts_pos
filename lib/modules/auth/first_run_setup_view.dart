import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/user_repository.dart';
import '../../models/app_user.dart';
import '../../widgets/ui_kit.dart';
import 'auth_scaffold.dart';

/// First launch only: create the OWNER account. Shown when no accounts exist.
/// After this, the owner can add cashier accounts from the Staff screen.
class FirstRunSetupView extends StatefulWidget {
  const FirstRunSetupView({super.key});

  @override
  State<FirstRunSetupView> createState() => _FirstRunSetupViewState();
}

class _FirstRunSetupViewState extends State<FirstRunSetupView> {
  final _users = UserRepository();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final pass = _pass.text;
    if (name.isEmpty) {
      setState(() => _error = 'Please type a username.');
      return;
    }
    if (pass.length < 4) {
      setState(() => _error = 'Password must be at least 4 characters.');
      return;
    }
    if (pass != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await _users.create(username: name, password: pass, role: UserRole.owner);
      final auth = AuthService.to;
      auth.markUsersExist();
      await auth.login(name, pass); // sign straight in
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not create the account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.admin_panel_settings,
      title: 'Set up the owner account',
      subtitle:
          'This is the main account with full access. Keep the password safe.',
      children: [
        _AuthField(controller: _name, label: 'Owner username', icon: Icons.person),
        const SizedBox(height: Sizes.gap),
        _AuthField(
            controller: _pass,
            label: 'Password',
            icon: Icons.lock,
            obscure: true),
        const SizedBox(height: Sizes.gap),
        _AuthField(
            controller: _confirm,
            label: 'Type password again',
            icon: Icons.lock_outline,
            obscure: true,
            onSubmitted: (_) => _create()),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!,
              style: const TextStyle(
                  color: AppColors.danger, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 22),
        GradientButton(
          expand: true,
          icon: Icons.check_circle,
          label: _busy ? 'Creating…' : 'Create account & start',
          onTap: _busy ? null : _create,
        ),
      ],
    );
  }
}

/// A tall, clearly-labelled auth text field. Shared look for all three screens.
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus,
      style: const TextStyle(fontSize: Sizes.bodyText),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted),
      ),
    );
  }
}

/// Exposed so the login and lock screens reuse the same field style.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => _AuthField(
        controller: controller,
        label: label,
        icon: icon,
        obscure: obscure,
        autofocus: autofocus,
        onSubmitted: onSubmitted,
      );
}
