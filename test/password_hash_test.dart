// Password hashing: verifies passwords are salted, one-way, and never match a
// wrong guess. No database needed — pure function tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/auth/password_hash.dart';

void main() {
  test('a correct password verifies', () {
    final stored = PasswordHash.hash('open-sesame');
    expect(PasswordHash.verify('open-sesame', stored), isTrue);
  });

  test('a wrong password does not verify', () {
    final stored = PasswordHash.hash('correct horse');
    expect(PasswordHash.verify('wrong horse', stored), isFalse);
    expect(PasswordHash.verify('', stored), isFalse);
  });

  test('the stored hash is never the plain text', () {
    const pw = 'my-secret-1234';
    final stored = PasswordHash.hash(pw);
    expect(stored.contains(pw), isFalse);
    expect(stored.startsWith('pbkdf2\$'), isTrue);
  });

  test('the same password hashes differently each time (random salt)', () {
    final a = PasswordHash.hash('same');
    final b = PasswordHash.hash('same');
    expect(a == b, isFalse);
    // ...yet both still verify.
    expect(PasswordHash.verify('same', a), isTrue);
    expect(PasswordHash.verify('same', b), isTrue);
  });

  test('a malformed stored value returns false, never throws', () {
    expect(PasswordHash.verify('x', 'not-a-hash'), isFalse);
    expect(PasswordHash.verify('x', ''), isFalse);
    expect(PasswordHash.verify('x', 'pbkdf2\$abc\$def'), isFalse);
  });
}
