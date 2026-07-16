import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants.dart';
import '../../core/printing/receipt_service.dart';
import '../../data/sale_repository.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../models/product.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_kit.dart';
import 'sale_controller.dart';

/// SALE SCREEN (home). Left: search + categories + product list.
/// Right: the cart, discount, total, payment, and the big complete button.
class SaleView extends StatelessWidget {
  const SaleView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SaleController());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: choose products.
          Expanded(flex: 3, child: _ProductPicker(c: c)),
          const SizedBox(width: Sizes.gap),
          // Right: the cart.
          SizedBox(width: 420, child: _CartPanel(c: c)),
        ],
      ),
    );
  }
}

// ------------------------- LEFT: product picker -------------------------

class _ProductPicker extends StatelessWidget {
  final SaleController c;
  const _ProductPicker({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('New sale',
            style: TextStyle(fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
        const SizedBox(height: Sizes.gap),
        // Search box also acts as the barcode input: type = filter, Enter = scan.
        TextField(
          autofocus: true,
          controller: c.searchController,
          style: const TextStyle(fontSize: Sizes.bodyText),
          textInputAction: TextInputAction.search,
          onChanged: c.onSearchChanged,
          onSubmitted: (v) {
            // Barcode scanner types the code then presses Enter.
            c.onBarcodeSubmitted(v);
            c.searchController.clear(); // clear for the next scan/search
            c.onSearchChanged('');
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 26),
            hintText: 'Search a product, or scan a barcode',
          ),
        ),
        const SizedBox(height: Sizes.gap),
        // Big category buttons to add common items fast.
        _CategoryButtons(c: c),
        const SizedBox(height: Sizes.gap),
        Expanded(child: _ResultsList(c: c)),
      ],
    );
  }
}

class _CategoryButtons extends StatelessWidget {
  final SaleController c;
  const _CategoryButtons({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(
          children: [
            for (final cat in Categories.all) ...[
              Expanded(
                child: _CategoryChip(
                  label: cat,
                  selected: c.activeCategory.value == cat,
                  tint: Color(Categories.colors[cat]!),
                  onTap: () => c.selectCategory(cat),
                ),
              ),
              if (cat != Categories.all.last) const SizedBox(width: 10),
            ],
          ],
        ));
  }
}

/// Category quick-pick chip. Selected = violet gradient; otherwise its soft
/// category tint. Hover/press states via InkWell.
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.tint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Ink(
          height: Sizes.buttonHeight,
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.primary : null,
            color: selected ? null : tint,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: selected ? AppShadows.glow(AppColors.violet) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                      fontFamily: AppTheme.body,
                      fontSize: Sizes.bodyText,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final SaleController c;
  const _ResultsList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.results.isEmpty) {
        return EmptyState(
          icon: Icons.inventory_2_outlined,
          title: c.search.value.trim().isEmpty ? 'No products yet' : 'No matches',
          hint: c.search.value.trim().isEmpty
              ? "Add products in the Stock screen first."
              : 'Try a different word.',
        );
      }
      return Card(
        child: ListView.separated(
          itemCount: c.results.length,
          separatorBuilder: (_, i) => const Divider(height: 1),
          itemBuilder: (_, i) => _ResultRow(c: c, product: c.results[i]),
        ),
      );
    });
  }
}

class _ResultRow extends StatelessWidget {
  final SaleController c;
  final Product product;
  const _ResultRow({required this.c, required this.product});

  @override
  Widget build(BuildContext context) {
    final out = product.stockQty <= 0;
    final low = !out && product.isLowStock(kLowStockThreshold);
    return InkWell(
      onTap: out ? null : () => c.addToCart(product),
      hoverColor: AppColors.violetTint.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          fontSize: Sizes.bodyText, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (out)
                    const StatusBadge(text: 'Out of stock', kind: BadgeKind.refund)
                  else if (low)
                    StatusBadge(text: '${product.stockQty} Low', kind: BadgeKind.lowStock)
                  else
                    Text('In stock: ${product.stockQty}',
                        style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                ],
              ),
            ),
            // Price, right-aligned to a fixed column so rows line up.
            SizedBox(
              width: 72,
              child: Text('Rs ${product.sellingPrice.toStringAsFixed(0)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: Sizes.bodyText,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            // Labelled add button, never icon-only.
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: out ? null : () => c.addToCart(product),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------- RIGHT: cart panel -------------------------

class _CartPanel extends StatelessWidget {
  final SaleController c;
  const _CartPanel({required this.c});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Cart',
                style:
                    TextStyle(fontSize: Sizes.titleText, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(() {
                if (c.cart.isEmpty) {
                  return const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Cart is empty',
                    hint: 'Tap a product on the left to add it.',
                  );
                }
                return ListView.separated(
                  itemCount: c.cart.length,
                  separatorBuilder: (_, i) => const Divider(height: 1),
                  itemBuilder: (_, i) => _CartRow(c: c, index: i),
                );
              }),
            ),
            const Divider(height: 16),
            _DiscountControl(c: c),
            const SizedBox(height: 8),
            _PaymentToggle(c: c),
            const SizedBox(height: 8),
            _Totals(c: c),
            const SizedBox(height: 8),
            _ActionButtons(c: c),
          ],
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final SaleController c;
  final int index;
  const _CartRow({required this.c, required this.index});

  @override
  Widget build(BuildContext context) {
    final line = c.cart[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.product.name,
                    style: const TextStyle(
                        fontSize: Sizes.bodyText, fontWeight: FontWeight.w600)),
                Text('${line.unitPrice.toStringAsFixed(0)} each',
                    style:
                        const TextStyle(fontSize: 14, color: AppColors.textSoft)),
              ],
            ),
          ),
          // Big minus / qty / plus.
          _RoundBtn(icon: Icons.remove, onTap: () => c.decrease(line)),
          SizedBox(
            width: 36,
            child: Text('${line.qty}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: Sizes.bodyText, fontWeight: FontWeight.w700)),
          ),
          _RoundBtn(icon: Icons.add, onTap: () => c.increase(line)),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(line.lineTotal.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: Sizes.bodyText, fontWeight: FontWeight.w700)),
          ),
          // One-tap remove (trash), labelled by tooltip + red colour.
          IconButton(
            onPressed: () => c.removeLine(line),
            icon: const Icon(Icons.delete, color: AppColors.danger),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.violet),
          foregroundColor: AppColors.violet,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Icon(icon, size: 22),
      ),
    );
  }
}

class _DiscountControl extends StatelessWidget {
  final SaleController c;
  const _DiscountControl({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Discount',
            style: TextStyle(fontSize: Sizes.bodyText, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        // Percent / Amount toggle (shared pill style).
        Obx(() => SegToggle(
              height: 44,
              options: const [('percent', '%'), ('amount', 'Rs')],
              selected: c.discountKind.value == DiscountKind.percent ? 'percent' : 'amount',
              onChanged: (v) => c.discountKind.value =
                  v == 'percent' ? DiscountKind.percent : DiscountKind.amount,
            )),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: const TextStyle(fontSize: Sizes.bodyText),
              onChanged: (v) => c.discountValue.value = double.tryParse(v) ?? 0,
              decoration: const InputDecoration(
                hintText: '0',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentToggle extends StatelessWidget {
  final SaleController c;
  const _PaymentToggle({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Payment',
            style: TextStyle(fontSize: Sizes.bodyText, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Obx(() => SegToggle(
              height: 48,
              options: const [('cash', 'Cash'), ('card', 'Card')],
              selected: c.paymentCash.value ? 'cash' : 'card',
              onChanged: (v) => c.paymentCash.value = v == 'cash',
            )),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  final SaleController c;
  const _Totals({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Touch cart so this rebuilds when it changes.
      c.cart.length;
      c.discountValue.value;
      c.discountKind.value;
      return Column(
        children: [
          _line('Subtotal', c.subtotal),
          if (c.discountAmount > 0) _line('Discount', -c.discountAmount),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.glow(AppColors.violet),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontFamily: AppTheme.display,
                        fontSize: Sizes.titleText,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text('Rs ${c.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontFamily: AppTheme.display,
                        fontSize: Sizes.bigText,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _line(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: Sizes.bodyText)),
          Text(value.toStringAsFixed(0),
              style: const TextStyle(fontSize: Sizes.bodyText)),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final SaleController c;
  const _ActionButtons({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() => GradientButton(
              expand: true,
              height: Sizes.buttonHeight + 6,
              fontSize: 18,
              icon: Icons.check_circle,
              label: 'Complete sale & print',
              onTap: c.canComplete ? () => _complete(context) : null,
            )),
        const SizedBox(height: 8),
        SizedBox(
          height: Sizes.buttonHeight,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () => _cancel(context),
            icon: const Icon(Icons.close),
            label: const Text('Cancel', style: TextStyle(fontSize: Sizes.bodyText)),
          ),
        ),
      ],
    );
  }

  Future<void> _cancel(BuildContext context) async {
    if (c.cart.isEmpty) return;
    final ok = await askYesNo(
      title: 'Empty the cart?',
      message: 'This will remove all items from the current sale.',
      yesText: 'Yes, empty',
      danger: true,
    );
    if (ok) c.clearCart();
  }

  Future<void> _complete(BuildContext context) async {
    // Big discounts need an owner. A cashier is blocked with a clear message.
    if (c.isBigDiscount && !AuthService.to.isOwner) {
      await _warn(
        'Discount too large',
        'A discount over ${kCashierMaxDiscountPercent.toStringAsFixed(0)}% '
            'needs an owner. Please ask the owner to log in.',
      );
      return;
    }

    // Friendly pre-check for overselling (the database is the real guard).
    final over = c.overStockLine;
    if (over != null) {
      await _warn(
        'Not enough stock',
        'Only ${over.product.stockQty} of "${over.product.name}" left, '
            'but the cart has ${over.qty}. Lower the quantity.',
      );
      return;
    }

    final ok = await askYesNo(
      title: 'Complete this sale?',
      message: 'Total is ${c.total.toStringAsFixed(0)}. '
          'This will save the sale and print a receipt.',
      yesText: 'Yes, complete',
    );
    if (!ok) return;

    // The sale is saved in one transaction; if stock ran out meanwhile, it
    // rolls back and nothing is saved — tell the cashier and stop.
    final SaleCompletion saved;
    try {
      saved = await c.completeSale();
    } on InsufficientStockException {
      await _warn('Sale not saved',
          'One item just went out of stock. Check the quantities and try again.');
      return;
    }

    // Show / print the receipt. Failure never blocks the sale — it is already
    // saved; we just tell the cashier in plain words.
    final printError = await ReceiptService.instance.deliver(
      sale: saved.sale,
      items: saved.items,
      names: saved.names,
    );

    // Big clear "Sale complete" message, then back to a fresh empty sale.
    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sizes.radius)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.violet, size: 72),
              const SizedBox(height: 12),
              const Text('Sale complete',
                  style: TextStyle(fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Invoice ${saved.sale.invoiceNo}',
                  style: const TextStyle(fontSize: Sizes.bodyText, color: AppColors.textSoft)),
              if (printError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warnBg,
                    borderRadius: BorderRadius.circular(Sizes.radius),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.print_disabled, color: AppColors.warn),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(printError,
                            style: const TextStyle(fontSize: 15, color: AppColors.warn)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: Sizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Next customer'),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Simple blocking warning dialog (plain words, one OK button).
  Future<void> _warn(String title, String message) async {
    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sizes.radius)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warn, size: 64),
                const SizedBox(height: 12),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: Sizes.titleText,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: Sizes.bodyText, color: AppColors.textSoft)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: Sizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
