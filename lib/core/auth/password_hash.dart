import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Salted PBKDF2-HMAC-SHA256 password hashing. Passwords/PINs are NEVER stored
/// in plain text — only this one-way, salted, slow hash is kept.
///
/// Stored format (single string, easy to keep in one TEXT column):
///   `pbkdf2$iterations$saltBase64$hashBase64`
class PasswordHash {
  PasswordHash._();

  static const int _iterations = 100000; // deliberately slow (anti-brute-force)
  static const int _saltLen = 16; // 128-bit random salt
  static const int _keyLen = 32; // SHA-256 output size

  /// Hash a password for storage. A fresh random salt is generated every time,
  /// so the same password produces a different stored string each time.
  static String hash(String password) {
    final salt = _randomBytes(_saltLen);
    final dk = _pbkdf2(utf8.encode(password), salt, _iterations, _keyLen);
    return 'pbkdf2\$$_iterations\$${base64.encode(salt)}\$${base64.encode(dk)}';
  }

  /// True if [password] matches the [stored] hash. Uses a constant-time compare
  /// so a wrong guess can't be timed. Any malformed stored value returns false.
  static bool verify(String password, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    final List<int> salt;
    final List<int> expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } catch (_) {
      return false;
    }
    final dk = _pbkdf2(utf8.encode(password), salt, iterations, expected.length);
    return _constantTimeEquals(dk, expected);
  }

  /// PBKDF2 for a derived key of at most one SHA-256 block (<= 32 bytes), which
  /// is all we need. Single block => only i=1.
  static List<int> _pbkdf2(
      List<int> password, List<int> salt, int iterations, int keyLen) {
    final hmac = Hmac(sha256, password);
    // U1 = PRF(P, Salt || INT32_BE(1))
    final block = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(block).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result.sublist(0, keyLen);
  }

  static List<int> _randomBytes(int n) {
    final rnd = Random.secure();
    return List<int>.generate(n, (_) => rnd.nextInt(256));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}