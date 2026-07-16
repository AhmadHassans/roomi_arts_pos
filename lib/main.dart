import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app.dart';
import 'core/auth/auth_service.dart';
import 'core/db/database.dart';
import 'core/printing/receipt_service.dart';
import 'data/product_repository.dart';

Future<void> main() async {
  // Needed before any async work in main.
  WidgetsFlutterBinding.ensureInitialized();

  // Open the single local SQLite database (offline, desktop FFI).
  await AppDatabase.instance.init();

  // First launch only: fill in sample stationery products.
  await ProductRepository().seedIfEmpty();

  // Load saved network-printer settings (IP/port) into the receipt service.
  await ReceiptService.instance.loadSettings();

  // Login/roles: register the auth service and check whether any account
  // exists yet (decides between first-run setup and the login screen).
  final auth = Get.put(AuthService());
  await auth.bootstrap();

  runApp(const RoomiArtsApp());
}
