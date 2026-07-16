import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../data/sale_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_kit.dart';
import '../sale/sale_controller.dart' show CartLine;
import 'return_controller.dart';

/// RETURN SCREEN: look up a past sale by invoice, tick items to return
/// (refund uses the actual price charged), optionally add replacement items
/// for an exchange, then confirm.
class ReturnView extends StatelessWidget {
  const ReturnView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ReturnController());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Return',
              style: TextStyle(fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
          const SizedBox(height: Sizes.gap),
          _InvoiceBar(c: c),
          const SizedBox(height: Sizes.gap),
          Expanded(child: _Body(c: c)),
        ],
      ),
    );
  }
}

class _InvoiceBar extends StatelessWidget {
  final ReturnController c;
  const _InvoiceBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            style: const TextStyle(fontSize: Sizes.bodyText),
            textInputAction: TextInputAction.search,
            onChanged: (v) => c.invoiceInput.value = v,
            onSubmitted: (_) => c.lookup(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.receipt_long, size: 26),
              hintText: 'Type the invoice number, e.g. INV-000001',
            ),
          ),
        ),
        const SizedBox(width: Sizes.gap),
        SizedBox(
          height: Sizes.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: c.lookup,
            icon: const Icon(Icons.search),
            label: const Text('Find sale', style: TextStyle(fontSize: Sizes.bodyText)),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final ReturnController c;
  const _Body({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (c.notFound.value) {
        return const EmptyState(
          icon: Icons.search_off,
          title: 'No sale found',
          hint: 'Check the invoice number and try again.',
        );
      }
      if (c.sale.value == null) {
        return const EmptyState(
          icon: Icons.assignment_return_outlined,
          title: 'Find a sale to return',
          hint: 'Type the invoice number above and press "Find sale".',
        );
      }
      // Loaded: left = items to return, right = exchange + summary.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _ReturnItems(c: c)),
          const SizedBox(width: Sizes.gap),
          SizedBox(width: 420, child: _SidePanel(c: c)),
        ],
      );
    });
  }
}

class _ReturnItems extends StatelessWidget {
  final ReturnController c;
  const _ReturnItems({required this.c});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() => Text('Sale ${c.sale.value?.invoiceNo ?? ''}',
                style: const TextStyle(
                    fontSize: Sizes.titleText, fontWeight: FontWeight.w800))),
            const SizedBox(height: 4),
            const Text('Choose the items and how many to return.',
                style: TextStyle(fontSize: 15, color: AppColors.textSoft)),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: Obx(() => ListView.separated(
                    itemCount: c.lines.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ReturnRow(c: c, line: c.lines[i]),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnRow extends StatelessWidget {
  final ReturnController c;
  final ReturnLine line;
  const _ReturnRow({required this.c, required this.line});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name,
                    style: const TextStyle(
                        fontSize: Sizes.bodyText, fontWeight: FontWeight.w600)),
                Text(
                  'Sold ${line.maxQty} · '
                  '${line.refundEach.toStringAsFixed(0)} each (price charged)',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSoft),
                ),
              ],
            ),
          ),
          const Text('Return',
              style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
          const SizedBox(width: 8),
          _RoundBtn(icon: Icons.remove, onTap: () => c.decReturn(line)),
          SizedBox(
            width: 40,
            child: Text('${line.returnQty}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: Sizes.bodyText, fontWeight: FontWeight.w700)),
          ),
          _RoundBtn(icon: Icons.add, onTap: () => c.incReturn(line)),
          SizedBox(
            width: 70,
            child: Text(line.refundTotal.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: Sizes.bodyText, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// Right panel: optional exchange items + money summary + confirm.
class _SidePanel extends StatelessWidget {
  final ReturnController c;
  const _SidePanel({required this.c});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Exchange (optional)',
                style: TextStyle(fontSize: Sizes.titleText, fontWeight: FontWeight.w800)),
            const Text('Add items the customer takes instead.',
                style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
            const SizedBox(height: 10),
            _ReplacementSearch(c: c),
            const SizedBox(height: 8),
            Expanded(child: _ReplacementList(c: c)),
            const Divider(height: 20),
            _Summary(c: c),
            const SizedBox(height: 12),
            _Confirm(c: c),
          ],
        ),
      ),
    );
  }
}

class _ReplacementSearch extends StatelessWidget {
  final ReturnController c;
  const _ReplacementSearch({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          style: const TextStyle(fontSize: 15),
          onChanged: c.searchProducts,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search a product to add',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        Obx(() {
          if (c.productSearch.value.trim().isEmpty || c.productResults.isEmpty) {
            return const SizedBox.shrink();
          }
          return Container(
            constraints: const BoxConstraints(maxHeight: 160),
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD5DDDA)),
              borderRadius: BorderRadius.circular(Sizes.radius),
            ),
            child: ListView(
              shrinkWrap: true,
              children: c.productResults
                  .map((p) => ListTile(
                        dense: true,
                        title: Text(p.name, style: const TextStyle(fontSize: 15)),
                        trailing: Text(p.sellingPrice.toStringAsFixed(0)),
                        onTap: () => c.addReplacement(p),
                      ))
                  .toList(),
            ),
          );
        }),
      ],
    );
  }
}

class _ReplacementList extends StatelessWidget {
  final ReturnController c;
  const _ReplacementList({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.replacements.isEmpty) {
        return const Center(
          child: Text('No exchange items.',
              style: TextStyle(fontSize: 15, color: AppColors.textSoft)),
        );
      }
      return ListView.separated(
        itemCount: c.replacements.length,
        separatorBuilder: (_, i) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final CartLine l = c.replacements[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.product.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                _RoundBtn(icon: Icons.remove, onTap: () => c.decReplacement(l)),
                SizedBox(
                  width: 34,
                  child: Text('${l.qty}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                _RoundBtn(icon: Icons.add, onTap: () => c.incReplacement(l)),
                SizedBox(
                  width: 56,
                  child: Text(l.lineTotal.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

class _Summary extends StatelessWidget {
  final ReturnController c;
  const _Summary({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      c.lines.length;
      c.replacements.length;
      final diff = c.difference;
      final customerPays = diff > 0;
      return Column(
        children: [
          _row('Refund (returned items)', c.refundTotal),
          if (c.hasReplacement) _row('New items', c.replacementTotal),
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
                Text(customerPays ? 'Customer pays' : 'Refund to customer',
                    style: const TextStyle(
                        fontFamily: AppTheme.display,
                        fontSize: Sizes.bodyText,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text('Rs ${diff.abs().toStringAsFixed(0)}',
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

  Widget _row(String label, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 15)),
          ],
        ),
      );
}

class _Confirm extends StatelessWidget {
  final ReturnController c;
  const _Confirm({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      c.lines.length;
      c.replacements.length;
      return GradientButton(
        expand: true,
        icon: Icons.check_circle,
        label: c.hasReplacement ? 'Confirm exchange' : 'Confirm return',
        onTap: c.canConfirm ? () => _confirm(context) : null,
      );
    });
  }

  Future<void> _confirm(BuildContext context) async {
    final isExchange = c.hasReplacement;
    final diff = c.difference;
    final msg = isExchange
        ? (diff >= 0
            ? 'Customer pays ${diff.toStringAsFixed(0)}.'
            : 'Refund ${diff.abs().toStringAsFixed(0)} to the customer.')
        : 'Refund ${c.refundTotal.toStringAsFixed(0)} to the customer.';

    final ok = await askYesNo(
      title: isExchange ? 'Confirm exchange?' : 'Confirm return?',
      message: '$msg\nStock will be updated.',
      yesText: 'Yes, confirm',
    );
    if (!ok) return;

    // Saved in one transaction. If it would return/oversell more than allowed
    // it rolls back and nothing changes — tell the cashier and stop.
    final ReturnResult res;
    try {
      res = await c.confirm();
    } on OverReturnException {
      await _warn('Return not saved',
          'That is more than was bought on this invoice (some may already be returned).');
      return;
    } on InsufficientStockException {
      await _warn('Exchange not saved',
          'A replacement item just went out of stock. Check quantities and try again.');
      return;
    }
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
              Text(isExchange ? 'Exchange done' : 'Return done',
                  style: const TextStyle(fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                res.difference >= 0
                    ? 'Customer pays ${res.difference.toStringAsFixed(0)}'
                    : 'Refund ${res.difference.abs().toStringAsFixed(0)} to customer',
                style: const TextStyle(fontSize: Sizes.bodyText, color: AppColors.textSoft),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: Sizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Done'),
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

// Shared round +/- button (same look as the Sale screen).
class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.violet),
          foregroundColor: AppColors.violet,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Icon(icon, size: 20),
      ),
    );
  }
}
