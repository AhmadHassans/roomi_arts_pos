import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/ui_kit.dart';
import 'auth_scaffold.dart';
import 'first_run_setup_view.dart' show AuthField;

/// Shown after the auto-lock (or the manual Lock button). The same user types
/// their password to get back in, without losing their session. "Log out"
/// switches to a different user.
class LockView extends StatefulWidget {
  const LockView({super.key});

  @override
  State<LockView> createState() => _LockViewState();
}

class _LockViewState extends State<LockView> {
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_pass.text.isEmpty) {
      setState(() => _error = 'Please type your password.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final ok = await AuthService.to.unlock(_pass.text);
    if (!ok) {
      setState(() {
        _busy = false;
        _error = 'Wrong password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.to.current.value?.username ?? '';
    return AuthScaffold(
      icon: Icons.lock_clock,
      title: 'Screen locked',
      subtitle: 'Locked after $kAutoLockMinutes minutes idle. '
          'Logged in as $name.',
      children: [
        AuthField(
            controller: _pass,
            label: 'Password',
            icon: Icons.lock,
            obscure: true,
            autofocus: true,
            onSubmitted: (_) => _unlock()),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!,
              style: const TextStyle(
                  color: AppColors.danger, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 22),
        GradientButton(
          expand: true,
          icon: Icons.lock_open,
          label: _busy ? 'Please wait…' : 'Unlock',
          onTap: _busy ? null : _unlock,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: Sizes.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () => AuthService.to.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Log out (switch user)',
                style: TextStyle(fontSize: Sizes.bodyText)),
          ),
        ),
      ],
    );
  }
}
