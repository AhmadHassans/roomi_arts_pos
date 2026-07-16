// Layout-overflow guard. Builds every screen AND the help dialog at (and below)
// the minimum window size and asserts Flutter records no overflow. An overflow
// (the yellow/black stripe) surfaces as a FlutterError from takeException().
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roomi_arts_pos/core/auth/auth_service.dart';
import 'package:roomi_arts_pos/core/db/database.dart';
import 'package:roomi_arts_pos/data/product_repository.dart';
import 'package:roomi_arts_pos/models/app_user.dart';
import 'package:roomi_arts_pos/modules/help/help_view.dart';
import 'package:roomi_arts_pos/modules/shell/shell_controller.dart';
import 'package:roomi_arts_pos/modules/shell/shell_view.dart';

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() async {
    await AppDatabase.instance.initInMemory();
    await ProductRepository().seedIfEmpty();
    Get.reset();
    // The shell needs a logged-in owner (top bar, role-gated sidebar).
    Get.put(AuthService()
      ..hasUsers.value = true
      ..current.value = const AppUser(
          username: 'owner', role: UserRole.owner, passwordHash: 'x'));
  });

  testWidgets('every screen fits at the minimum window size (1024x680)',
      (tester) async {
    await _setSize(tester, const Size(1024, 680));
    await tester.pumpWidget(const GetMaterialApp(home: ShellView()));

    // The DB runs on real async (sqflite ffi); runAsync lets those loads finish
    // so the loading spinners clear before we check the settled layout.
    Future<void> settle() async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
    }

    await settle();
    final shell = Get.find<ShellController>();
    // Sale, Stock, Return, Records, Reports, Backup, Staff (owner sees all).
    for (var i = 0; i < 7; i++) {
      shell.go(i);
      await settle();
      expect(tester.takeException(), isNull,
          reason: 'screen index $i overflowed at 1024x680');
    }
  });

  testWidgets('help dialog scrolls and never overflows on a short window',
      (tester) async {
    // Deliberately shorter than the app minimum to prove the scroll fix.
    await _setSize(tester, const Size(900, 480));
    await tester.pumpWidget(const GetMaterialApp(home: HelpView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'help dialog overflowed');

    // All five sections exist in the (scrollable) tree.
    expect(find.text('Make a sale'), findsOneWidget);
    expect(find.text('Back up your data'), findsOneWidget);
    // The close button stays present (not scrolled away).
    expect(find.text('Got it'), findsOneWidget);
  });
}
