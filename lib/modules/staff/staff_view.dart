import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../data/user_repository.dart';
import '../../models/app_user.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/ui_kit.dart';

/// STAFF (owner-only): see all accounts, add a cashier or owner, change a
/// password, or remove an account. The last owner can never be removed.
class StaffView extends StatefulWidget {
  const StaffView({super.key});

  @override
  State<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<StaffView> {
  final _users = UserRepository();
  List<AppUser> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _users.getAll();
    if (!mounted) return; // the screen may have been left mid-load
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _addUser() async {
    final created = await _UserDialog.open();
    if (created == true) await _load();
  }

  Future<void> _changePassword(AppUser u) async {
    final changed = await _UserDialog.open(existing: u);
    if (changed == true) await _load();
  }

  Future<void> _delete(AppUser u) async {
    // Never allow deleting yourself or the last remaining owner.
    final me = AuthService.to.current.value;
    if (me?.id == u.id) {
      Get.snackbar('Not allowed', 'You cannot delete the account you are using.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (u.isOwner && await _users.ownerCount() <= 1) {
      Get.snackbar('Not allowed', 'There must always be at least one owner.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final ok = await askYesNo(
      title: 'Remove ${u.username}?',
      message: 'This account will no longer be able to log in.',
      yesText: 'Yes, remove',
      danger: true,
    );
    if (!ok) return;
    await _users.delete(u.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Staff',
                    style: TextStyle(
                        fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
              ),
              GradientButton(
                icon: Icons.person_add,
                label: 'Add staff',
                onTap: _addUser,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Owners have full access. Cashiers can bill and do returns only.',
            style: TextStyle(fontSize: Sizes.bodyText, color: AppColors.textSoft),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final u = _list[i];
                      return AppCard(
                        child: Row(
                          children: [
                            GradientTile(
                              icon: u.isOwner
                                  ? Icons.admin_panel_settings
                                  : Icons.point_of_sale,
                              gradient: u.isOwner
                                  ? AppGradients.primary
                                  : AppGradients.violet,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.username,
                                      style: const TextStyle(
                                          fontSize: Sizes.bodyText,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  StatusBadge(
                                    text: u.roleLabel,
                                    kind: u.isOwner
                                        ? BadgeKind.paid
                                        : BadgeKind.neutral,
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _changePassword(u),
                              icon: const Icon(Icons.key, size: 18),
                              label: const Text('Password'),
                            ),
                            IconButton(
                              onPressed: () => _delete(u),
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.danger),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Add a new account, or (when [existing] is set) change that account's
/// password. Returns true if something was saved.
class _UserDialog extends StatefulWidget {
  final AppUser? existing;
  const _UserDialog({this.existing});

  static Future<bool?> open({AppUser? existing}) => Get.dialog<bool>(
        _UserDialog(existing: existing),
        barrierDismissible: false,
      );

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _users = UserRepository();
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  UserRole _role = UserRole.cashier;
  String? _error;
  bool _busy = false;

  bool get _isPasswordOnly => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.username;
      _role = e.role;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final pass = _pass.text;
    if (!_isPasswordOnly && name.isEmpty) {
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
      if (_isPasswordOnly) {
        await _users.changePassword(widget.existing!.id!, pass);
      } else {
        await _users.create(username: name, password: pass, role: _role);
      }
      Get.back(result: true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'That username is already taken.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sizes.radius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isPasswordOnly ? 'Change password' : 'Add staff',
                  style: const TextStyle(
                      fontSize: Sizes.titleText, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                enabled: !_isPasswordOnly,
                style: const TextStyle(fontSize: Sizes.bodyText),
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              if (!_isPasswordOnly) ...[
                const SizedBox(height: Sizes.gap),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                        value: UserRole.cashier, child: Text('Cashier')),
                    DropdownMenuItem(
                        value: UserRole.owner, child: Text('Owner')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? UserRole.cashier),
                ),
              ],
              const SizedBox(height: Sizes.gap),
              TextField(
                controller: _pass,
                obscureText: true,
                style: const TextStyle(fontSize: Sizes.bodyText),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: Sizes.gap),
              TextField(
                controller: _confirm,
                obscureText: true,
                style: const TextStyle(fontSize: Sizes.bodyText),
                decoration:
                    const InputDecoration(labelText: 'Type password again'),
                onSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: Sizes.gap),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
