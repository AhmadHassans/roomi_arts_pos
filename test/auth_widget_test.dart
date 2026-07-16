// Widget tests for the login gate: the login/setup screens render, a wrong
// password is rejected, and a logged-in owner sees the app shell.
//
// sqflite ffi runs on a real background isolate, so DB work happens in setUp
// (real async) or inside tester.runAsync — never directly in the FakeAsync test
// body, which would deadlock.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roomi_arts_pos/app.dart';
import 'package:roomi_arts_pos/core/auth/auth_service.dart';
import 'package:roomi_arts_pos/core/db/database.dart';
import 'package:roomi_arts_pos/data/user_repository.dart';
import 'package:roomi_arts_pos/models/app_user.dart';
import 'package:roomi_arts_pos/modules/auth/first_run_setup_view.dart';
import 'package:roomi_arts_pos/modules/auth/login_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _owner = AppUser(username: 'boss', role: UserRole.owner, passwordHash: 'x');

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'help_shown': true});
    await AppDatabase.instance.initInMemory();
    // Real async DB work belongs here, not in the FakeAsync test body.
    await UserRepository()
        .create(username: 'boss', password: 'pass1234', role: UserRole.owner);
    Get.reset();
    Get.put(AuthService()..hasUsers.value = true);
  });

  tearDown(() {
    if (Get.isRegistered<AuthService>()) Get.find<AuthService>().logout();
  });

  testWidgets('first-run setup screen renders', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: FirstRunSetupView()));
    await tester.pump();
    expect(find.text('Set up the owner account'), findsOneWidget);
    expect(find.text('Create account & start'), findsOneWidget);
  });

  testWidgets('login screen renders', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
    await tester.pump();
    expect(find.text('Log in'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
  });

  testWidgets('a wrong password is rejected', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'boss');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'wrongpass');
    // The tap fires an async DB verify — drive it in real async.
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(InkWell, 'Log in'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('Wrong username or password.'), findsOneWidget);
  });

  testWidgets('a logged-in owner sees the app shell with owner-only areas',
      (tester) async {
    // The app targets a desktop window; use its minimum size so the shell lays
    // out without overflow (same as the overflow test).
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Set the signed-in user directly (no DB call in the FakeAsync body).
    Get.find<AuthService>().current.value = _owner;

    await tester.pumpWidget(const RoomiArtsApp());
    await _settle(tester);

    expect(find.byType(LoginView), findsNothing);
    expect(find.text('Log out'), findsOneWidget); // top bar
    expect(find.text('Staff'), findsOneWidget); // owner-only sidebar item
  });
}
