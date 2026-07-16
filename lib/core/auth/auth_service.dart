import 'dart:async';
import 'package:get/get.dart';
import '../../data/user_repository.dart';
import '../../models/app_user.dart';
import '../constants.dart';

/// Holds who is currently logged in and enforces the auto-lock. One instance,
/// put at app start. The UI watches [current], [locked] and [hasUsers] to decide
/// which screen to show (first-run setup / login / lock / the app).
class AuthService extends GetxService {
  static AuthService get to => Get.find();

  final UserRepository _users = UserRepository();

  /// The signed-in user, or null when nobody is logged in.
  final Rxn<AppUser> current = Rxn<AppUser>();

  /// True when the screen is locked and a password is needed to get back in.
  final locked = false.obs;

  /// null = still checking; false = no accounts yet (show first-run setup);
  /// true = at least one account exists (show login).
  final Rxn<bool> hasUsers = Rxn<bool>();

  bool get isLoggedIn => current.value != null;
  bool get isOwner => current.value?.isOwner ?? false;

  /// Lock the screen automatically after this much inactivity.
  static const Duration idleTimeout = Duration(minutes: kAutoLockMinutes);
  Timer? _idleTimer;

  /// Check once at startup whether any accounts exist.
  Future<void> bootstrap() async {
    hasUsers.value = await _users.anyUsers();
  }

  Future<AppUser?> login(String username, String password) async {
    final u = await _users.verify(username, password);
    if (u != null) {
      current.value = u;
      locked.value = false;
      _restartIdle();
    }
    return u;
  }

  void logout() {
    current.value = null;
    locked.value = false;
    _idleTimer?.cancel();
  }

  /// Lock (does nothing if nobody is logged in).
  void lock() {
    if (!isLoggedIn) return;
    locked.value = true;
    _idleTimer?.cancel();
  }

  /// Re-enter the current user's password to unlock.
  Future<bool> unlock(String password) async {
    final u = current.value;
    if (u == null) return false;
    final ok = await _users.verify(u.username, password);
    if (ok != null) {
      locked.value = false;
      _restartIdle();
      return true;
    }
    return false;
  }

  /// Any user interaction calls this to push back the auto-lock.
  void registerActivity() {
    if (isLoggedIn && !locked.value) _restartIdle();
  }

  /// Called after the first-run owner account is created.
  void markUsersExist() => hasUsers.value = true;

  void _restartIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, lock);
  }

  @override
  void onClose() {
    _idleTimer?.cancel();
    super.onClose();
  }
}