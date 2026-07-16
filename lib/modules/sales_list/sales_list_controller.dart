import 'package:get/get.dart';

import '../../core/printing/receipt_service.dart';
import '../../data/sale_repository.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';

/// A sale plus its lines and product names — everything needed to show the
/// detail dialog and reprint the receipt.
class SaleDetail {
  final Sale sale;
  final List<SaleItem> items;
  final Map<int, String> names;
  const SaleDetail({required this.sale, required this.items, required this.names});
}

/// Drives the Sales-records screen: the searchable/filterable list of every
/// past sale and return, the detail view, and receipt reprint.
class SalesListController extends GetxController {
  final SaleRepository _repo = SaleRepository();

  final loading = true.obs;
  final sales = <Sale>[].obs;

  // Filters. Changing any of them re-runs the query.
  final query = ''.obs;
  final typeFilter = 'all'.obs; // all | sale | return
  final dateFilter = 'all'.obs; // all | today | month

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;

    DateTime? from;
    DateTime? to;
    final now = DateTime.now();
    if (dateFilter.value == 'today') {
      from = DateTime(now.year, now.month, now.day);
      to = from.add(const Duration(days: 1));
    } else if (dateFilter.value == 'month') {
      from = DateTime(now.year, now.month, 1);
      to = DateTime(now.year, now.month + 1, 1);
    }

    sales.value = await _repo.listSales(
      query: query.value,
      type: typeFilter.value,
      from: from,
      to: to,
    );
    loading.value = false;
  }

  void search(String q) {
    query.value = q;
    load();
  }

  void setType(String t) {
    typeFilter.value = t;
    load();
  }

  void setDate(String d) {
    dateFilter.value = d;
    load();
  }

  /// Load a sale's lines + product names for the detail dialog / reprint.
  Future<SaleDetail> detail(Sale sale) async {
    final items = await _repo.itemsForSale(sale.id!);
    final names =
        await _repo.namesForProductIds(items.map((e) => e.productId).toList());
    return SaleDetail(sale: sale, items: items, names: names);
  }

  /// Reprint the 80mm receipt for a past sale. Returns null on success or a
  /// short message on failure (same contract as the printer service).
  Future<String?> reprint(Sale sale) async {
    final d = await detail(sale);
    return ReceiptService.instance
        .deliver(sale: d.sale, items: d.items, names: d.names);
  }
}
