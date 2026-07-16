import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/ui_kit.dart';
import 'auth_scaffold.dart';
import 'first_run_setup_view.dart' show AuthField;

/// The login screen. Username + password. Shown whenever nobody is signed in.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _name = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final name = _name.text.trim();
    final pass = _pass.text;
    if (name.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please type your username and password.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final user = await AuthService.to.login(name, pass);
    if (user == null) {
      setState(() {
        _busy = false;
        _error = 'Wrong username or password.';
      });
    }
    // On success the app root rebuilds automatically to the shell.
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      icon: Icons.lock,
      title: 'Log in',
      subtitle: 'Enter your username and password to continue.',
      children: [
        AuthField(
            controller: _name,
            label: 'Username',
            icon: Icons.person,
            autofocus: true),
        const SizedBox(height: Sizes.gap),
        AuthField(
            controller: _pass,
            label: 'Password',
            icon: Icons.lock,
            obscure: true,
            onSubmitted: (_) => _login()),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!,
              style: const TextStyle(
                  color: AppColors.danger, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 22),
        GradientButton(
          expand: true,
          icon: Icons.login,
          label: _busy ? 'Please wait…' : 'Log in',
          onTap: _busy ? null : _login,
        ),
      ],
    );
  }
}
