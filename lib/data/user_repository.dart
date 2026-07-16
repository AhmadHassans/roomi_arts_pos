import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/auth/password_hash.dart';
import '../core/db/database.dart';
import '../models/app_user.dart';

/// All staff-account database access. Passwords are hashed here on the way in
/// and only ever compared through [PasswordHash.verify] — plain text never
/// touches the database.
class UserRepository {
  Database get _db => AppDatabase.instance.db;

  Future<int> count() async {
    final r = await _db.rawQuery('SELECT COUNT(*) AS n FROM users');
    return (r.first['n'] as num).toInt();
  }

  Future<bool> anyUsers() async => await count() > 0;

  Future<AppUser?> findByUsername(String username) async {
    final rows = await _db.query(
      'users',
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> getAll() async {
    final rows = await _db.query(
      'users',
      orderBy: "role = 'owner' DESC, username COLLATE NOCASE ASC",
    );
    return rows.map(AppUser.fromMap).toList();
  }

  /// Create a staff account. Throws if the username is already taken (the
  /// UNIQUE index enforces it). Returns the new id.
  Future<int> create({
    required String username,
    required String password,
    required UserRole role,
  }) async {
    final user = AppUser(
      username: username.trim(),
      role: role,
      passwordHash: PasswordHash.hash(password),
    );
    return _db.insert('users', user.toMap());
  }

  Future<void> changePassword(int id, String newPassword) async {
    await _db.update(
      'users',
      {'password_hash': PasswordHash.hash(newPassword)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  /// How many owners exist (used so the last owner can never be removed).
  Future<int> ownerCount() async {
    final r =
        await _db.rawQuery("SELECT COUNT(*) AS n FROM users WHERE role = 'owner'");
    return (r.first['n'] as num).toInt();
  }

  /// Returns the matching user when the credentials are correct, else null.
  Future<AppUser?> verify(String username, String password) async {
    final u = await findByUsername(username);
    if (u == null) return null;
    if (!PasswordHash.verify(password, u.passwordHash)) return null;
    return u;
  }
}