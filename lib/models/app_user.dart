/// A staff account that can log in. Two roles only:
///  - owner: full access (Reports, Backup/Restore, delete product, big
///    discounts, manage staff).
///  - cashier: day-to-day billing/returns only; owner-only areas are blocked.
///
/// The password is never held here in plain text — only its salted hash.
enum UserRole { owner, cashier }

class AppUser {
  final int? id;
  final String username;
  final UserRole role;
  final String passwordHash;

  const AppUser({
    this.id,
    required this.username,
    required this.role,
    required this.passwordHash,
  });

  bool get isOwner => role == UserRole.owner;

  static UserRole roleFrom(String s) =>
      s == 'owner' ? UserRole.owner : UserRole.cashier;
  static String roleName(UserRole r) =>
      r == UserRole.owner ? 'owner' : 'cashier';

  String get roleLabel => isOwner ? 'Owner' : 'Cashier';

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'username': username,
        'role': roleName(role),
        'password_hash': passwordHash,
      };

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as int?,
        username: m['username'] as String,
        role: roleFrom(m['role'] as String),
        passwordHash: m['password_hash'] as String,
      );
}