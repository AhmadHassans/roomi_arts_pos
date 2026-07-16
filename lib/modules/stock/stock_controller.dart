import 'package:get/get.dart';
import '../../data/product_repository.dart';
import '../../models/product.dart';

/// Drives the Stock screen: load, live search, add/edit/delete, add-stock.
class StockController extends GetxController {
  final ProductRepository _repo = ProductRepository();

  final products = <Product>[].obs;
  final search = ''.obs;
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    products.value = await _repo.getAll(search: search.value);
    loading.value = false;
  }

  /// Live filter as the owner types.
  void onSearchChanged(String value) {
    search.value = value;
    load();
  }

  Future<void> addProduct(Product p) async {
    await _repo.insert(p);
    await load();
  }

  Future<void> editProduct(Product p) async {
    await _repo.update(p);
    await load();
  }

  Future<void> deleteProduct(int id) async {
    await _repo.delete(id);
    await load();
  }

  /// e.g. a new box of 24 arrives -> add 24 to stock.
  Future<void> addStock(int id, int amount) async {
    await _repo.addStock(id, amount);
    await load();
  }
}
