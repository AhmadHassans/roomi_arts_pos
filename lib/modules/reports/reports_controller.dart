import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../data/reports_repository.dart';

/// Loads all the numbers shown on the Reports screen.
class ReportsController extends GetxController {
  final ReportsRepository _repo = ReportsRepository();

  final loading = true.obs;

  final todaySales = 0.0.obs;
  final todayProfit = 0.0.obs;
  final monthSales = 0.0.obs;
  final monthProfit = 0.0.obs;

  final daily = <DailySales>[].obs;
  final best = <BestSeller>[].obs;
  final low = <({String name, int stock})>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final endToday = startToday.add(const Duration(days: 1));
    final startMonth = DateTime(now.year, now.month, 1);
    final endMonth = DateTime(now.year, now.month + 1, 1);

    todaySales.value = await _repo.salesTotal(startToday, endToday);
    todayProfit.value = await _repo.profitTotal(startToday, endToday);
    monthSales.value = await _repo.salesTotal(startMonth, endMonth);
    monthProfit.value = await _repo.profitTotal(startMonth, endMonth);

    daily.value = await _repo.dailySales(startMonth, endMonth);
    best.value = await _repo.bestSellers();
    low.value = await _repo.lowStock(kLowStockThreshold);

    loading.value = false;
  }
}
