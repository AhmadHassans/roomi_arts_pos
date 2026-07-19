import 'package:get/get.dart';

/// Which main screen is shown. The sidebar stays fixed; only the body swaps,
/// so button positions never move (muscle memory).
class ShellController extends GetxController {
  // 0 Sale, 1 Stock, 2 Return, 3 Records, 4 Reports, 5 History, 6 Backup,
  // 7 Staff, 8 Settings
  final current = 0.obs;

  void go(int index) => current.value = index;
}
