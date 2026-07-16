import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../models/product.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_kit.dart';
import 'stock_controller.dart';
import 'widgets/add_stock_dialog.dart';
import 'widgets/product_form.dart';

/// STOCK SCREEN (inventory): searchable table, add/edit/delete, add-stock,
/// low-stock highlight.
class StockView extends StatelessWidget {
  const StockView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(StockController());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Title + big Add product button (top row, fixed position) ----
          Row(
            children: [
              const Text('Stock',
                  style: TextStyle(
                      fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
              const Spacer(),
              GradientButton(
                icon: Icons.add,
                label: 'Add product',
                onTap: () => _addProduct(c),
              ),
            ],
          ),
          const SizedBox(height: Sizes.gap),
          // ---- Search box ----
          TextField(
            style: const TextStyle(fontSize: Sizes.bodyText),
            onChanged: c.onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 26),
              hintText: 'Search products by name',
            ),
          ),
          const SizedBox(height: Sizes.gap),
          // ---- Table ----
          Expanded(
            child: Obx(() {
              if (c.loading.value && c.products.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.products.isEmpty) {
                // Helpful empty state.
                final searching = c.search.value.trim().isNotEmpty;
                return EmptyState(
                  icon: searching ? Icons.search_off : Icons.inventory_2_outlined,
                  title: searching ? 'No matching products' : 'No products yet',
                  hint: searching
                      ? 'Try a different word.'
                      : "Press 'Add product' to begin.",
                  action: searching
                      ? null
                      : SizedBox(
                          height: Sizes.buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: () => _addProduct(c),
                            icon: const Icon(Icons.add),
                            label: const Text('Add product'),
                          ),
                        ),
                );
              }
              return _ProductTable(controller: c);
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct(StockController c) async {
    final p = await ProductForm.open();
    if (p != null) {
      await c.addProduct(p);
      Get.snackbar('Saved', 'Product added',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

class _ProductTable extends StatelessWidget {
  final StockController controller;
  const _ProductTable({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const _HeaderRow(),
          const Divider(height: 1),
          Expanded(
            child: Obx(() => ListView.separated(
                  itemCount: controller.products.length,
                  separatorBuilder: (_, i) => const Divider(height: 1, color: AppColors.panelBorder),
                  itemBuilder: (_, i) => _ProductRow(
                      product: controller.products[i], controller: controller, index: i),
                )),
          ),
        ],
      ),
    );
  }
}

// Column widths kept identical in header and rows so everything lines up.
const _flexName = 3;
const _flexCat = 2;
const _flexNum = 2;
const _flexUnit = 2;
const _flexBarcode = 3;
const _flexActions = 4;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: Sizes.bodyText, fontWeight: FontWeight.w700);
    return Container(
      color: AppColors.violetTint,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: const Row(
        children: [
          Expanded(flex: _flexName, child: Text('Name', style: style)),
          Expanded(flex: _flexCat, child: Text('Category', style: style)),
          Expanded(flex: _flexNum, child: Text('Cost', style: style)),
          Expanded(flex: _flexNum, child: Text('Selling', style: style)),
          Expanded(flex: _flexNum, child: Text('Stock', style: style)),
          Expanded(flex: _flexUnit, child: Text('Unit', style: style)),
          Expanded(flex: _flexBarcode, child: Text('Barcode', style: style)),
          Expanded(flex: _flexActions, child: Text('Actions', style: style)),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final StockController controller;
  final int index;
  const _ProductRow({required this.product, required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final low = product.isLowStock(kLowStockThreshold);
    const cell = TextStyle(fontSize: Sizes.bodyText);

    return Container(
      // Low-stock rows keep the peach tint; others get subtle zebra striping.
      color: low
          ? AppColors.warnBg
          : (index.isOdd ? AppColors.bgLav : AppColors.panel),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: _flexName,
            child: Text(product.name,
                style: cell.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(flex: _flexCat, child: Text(product.category, style: cell)),
          Expanded(
              flex: _flexNum,
              child: Text(product.costPrice.toStringAsFixed(0), style: cell)),
          Expanded(
              flex: _flexNum,
              child: Text(product.sellingPrice.toStringAsFixed(0), style: cell)),
          Expanded(
            flex: _flexNum,
            child: Align(
              alignment: Alignment.centerLeft,
              child: low
                  ? StatusBadge(text: '${product.stockQty} Low', kind: BadgeKind.lowStock)
                  : StatusBadge(text: '${product.stockQty}', kind: BadgeKind.paid),
            ),
          ),
          Expanded(flex: _flexUnit, child: Text(product.unit, style: cell)),
          Expanded(
              flex: _flexBarcode,
              child: Text(product.barcode ?? '—', style: cell)),
          // Actions: always labelled buttons, never icon-only.
          Expanded(
            flex: _flexActions,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Add stock — soft violet fill.
                _actionButton(
                  icon: Icons.add_box,
                  label: 'Add stock',
                  fg: AppColors.violet,
                  bg: AppColors.violetTint,
                  onTap: () => _addStock(context),
                ),
                // Edit — outline.
                _actionButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  fg: AppColors.ink,
                  border: AppColors.panelBorder,
                  onTap: () => _edit(context),
                ),
                // Delete — soft red fill. Owner-only (cashiers can't delete).
                if (AuthService.to.isOwner)
                  _actionButton(
                    icon: Icons.delete,
                    label: 'Delete',
                    fg: AppColors.danger,
                    bg: const Color(0xFFFFE6EC),
                    onTap: () => _delete(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color fg,
    Color? bg,
    Color? border,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(color: border ?? Colors.transparent),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _addStock(BuildContext context) async {
    final amount = await AddStockDialog.open(product);
    if (amount != null) {
      await controller.addStock(product.id!, amount);
      Get.snackbar('Stock added', '+$amount to ${product.name}',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await ProductForm.open(existing: product);
    if (updated != null) {
      await controller.editProduct(updated);
      Get.snackbar('Saved', 'Product updated',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await askYesNo(
      title: 'Delete this product?',
      message: 'This will remove "${product.name}" from your stock list.',
      yesText: 'Yes, delete',
      danger: true,
    );
    if (ok) {
      await controller.deleteProduct(product.id!);
      Get.snackbar('Deleted', '${product.name} removed',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
