// Staff accounts: create, verify, roles, unique usernames, owner counting.
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/db/database.dart';
import 'package:roomi_arts_pos/data/user_repository.dart';
import 'package:roomi_arts_pos/models/app_user.dart';

void main() {
  final users = UserRepository();

  setUp(() async {
    await AppDatabase.instance.initInMemory();
  });

  test('no users on a fresh database', () async {
    expect(await users.anyUsers(), isFalse);
    expect(await users.count(), 0);
  });

  test('create then verify with correct and wrong password', () async {
    await users.create(
        username: 'boss', password: 'pass1234', role: UserRole.owner);
    expect(await users.anyUsers(), isTrue);

    final ok = await users.verify('boss', 'pass1234');
    expect(ok, isNotNull);
    expect(ok!.isOwner, isTrue);

    expect(await users.verify('boss', 'nope'), isNull);
    expect(await users.verify('ghost', 'pass1234'), isNull);
  });

  test('usernames are case-insensitive and must be unique', () async {
    await users.create(
        username: 'Cashier1', password: 'pass1234', role: UserRole.cashier);
    // Same name, different case -> rejected by the UNIQUE index.
    expect(
      () => users.create(
          username: 'cashier1', password: 'other123', role: UserRole.cashier),
      throwsA(anything),
    );
    // Login still works regardless of the case typed.
    expect(await users.verify('CASHIER1', 'pass1234'), isNotNull);
  });

  test('a cashier is not an owner', () async {
    await users.create(
        username: 'sara', password: 'pass1234', role: UserRole.cashier);
    final u = await users.verify('sara', 'pass1234');
    expect(u!.isOwner, isFalse);
    expect(u.roleLabel, 'Cashier');
  });

  test('changePassword updates the stored hash', () async {
    final id = await users.create(
        username: 'joe', password: 'oldpass1', role: UserRole.cashier);
    await users.changePassword(id, 'newpass1');
    expect(await users.verify('joe', 'oldpass1'), isNull);
    expect(await users.verify('joe', 'newpass1'), isNotNull);
  });

  test('ownerCount tracks owners for the last-owner rule', () async {
    await users.create(
        username: 'o1', password: 'pass1234', role: UserRole.owner);
    await users.create(
        username: 'c1', password: 'pass1234', role: UserRole.cashier);
    expect(await users.ownerCount(), 1);
    await users.create(
        username: 'o2', password: 'pass1234', role: UserRole.owner);
    expect(await users.ownerCount(), 2);
  });
}
