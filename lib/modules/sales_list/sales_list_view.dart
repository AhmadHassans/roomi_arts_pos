import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../models/sale.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_kit.dart';
import 'sales_list_controller.dart';

/// SALES RECORDS SCREEN: every past sale and return, searchable by invoice
/// number and filterable by type/date. Tap a row to see the items and reprint
/// the receipt.
class SalesListView extends StatelessWidget {
  const SalesListView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SalesListController());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Sales records',
                  style: TextStyle(fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
              const Spacer(),
              SizedBox(
                height: Sizes.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: c.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh', style: TextStyle(fontSize: Sizes.bodyText)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.gap),
          _Filters(c: c),
          const SizedBox(height: Sizes.gap),
          Expanded(child: _List(c: c)),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final SalesListController c;
  const _Filters({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search by invoice number.
        TextField(
          style: const TextStyle(fontSize: Sizes.bodyText),
          onChanged: c.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 26),
            hintText: 'Search invoice number, e.g. INV-000012',
          ),
        ),
        const SizedBox(height: 12),
        // Type chips + date dropdown.
        Row(
          children: [
            Obx(() => _ChipBar(
                  value: c.typeFilter.value,
                  onChanged: c.setType,
                  options: const [
                    ('all', 'All'),
                    ('sale', 'Sales'),
                    ('return', 'Returns'),
                  ],
                )),
            const Spacer(),
            Obx(() => _DateDropdown(value: c.dateFilter.value, onChanged: c.setDate)),
          ],
        ),
      ],
    );
  }
}

class _ChipBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, String)> options;
  const _ChipBar({required this.value, required this.onChanged, required this.options});

  @override
  Widget build(BuildContext context) {
    return SegToggle(options: options, selected: value, onChanged: onChanged);
  }
}

class _DateDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DateDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5DDDA)),
        borderRadius: BorderRadius.circular(Sizes.radius),
        color: AppColors.surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.calendar_month, color: AppColors.violet),
          style: const TextStyle(fontSize: 15, color: AppColors.text),
          onChanged: (v) => onChanged(v ?? 'all'),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All dates')),
            DropdownMenuItem(value: 'today', child: Text('Today')),
            DropdownMenuItem(value: 'month', child: Text('This month')),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final SalesListController c;
  const _List({required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (c.sales.isEmpty) {
        return const EmptyState(
          icon: Icons.receipt_long,
          title: 'No sales found',
          hint: 'Completed sales and returns show up here. '
              'Try clearing the search or filters.',
        );
      }
      return Card(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: c.sales.length,
          separatorBuilder: (_, i) => const Divider(height: 1, color: AppColors.panelBorder),
          itemBuilder: (_, i) => _SaleRow(c: c, sale: c.sales[i]),
        ),
      );
    });
  }
}

class _SaleRow extends StatelessWidget {
  final SalesListController c;
  final Sale sale;
  const _SaleRow({required this.c, required this.sale});

  @override
  Widget build(BuildContext context) {
    final isReturn = sale.type == 'return';
    return InkWell(
      onTap: () => _openDetail(context, c, sale),
      hoverColor: AppColors.violetTint.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _TypeBadge(isReturn: isReturn),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sale.invoiceNo,
                      style: const TextStyle(
                          fontSize: Sizes.bodyText, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDateTime(sale.date)}  ·  '
                    '${sale.paymentType == 'cash' ? 'Cash' : 'Card'}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSoft),
                  ),
                ],
              ),
            ),
            Text(
              '${isReturn ? '-' : ''}Rs ${sale.totalAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontFamily: AppTheme.display,
                fontSize: Sizes.titleText,
                fontWeight: FontWeight.w800,
                // Positive sales green, returns/negative red.
                color: isReturn ? const Color(0xFFE2456A) : const Color(0xFF1EAE74),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSoft),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final bool isReturn;
  const _TypeBadge({required this.isReturn});

  @override
  Widget build(BuildContext context) {
    // Sales = violet gradient tile, returns = amber gradient tile.
    return GradientTile(
      icon: isReturn ? Icons.assignment_return : Icons.point_of_sale,
      gradient: isReturn ? AppGradients.amber : AppGradients.violet,
      size: 44,
    );
  }
}

// ------------------------------- Detail dialog -------------------------------

Future<void> _openDetail(
    BuildContext context, SalesListController c, Sale sale) async {
  final detail = await c.detail(sale);
  await Get.dialog(_DetailDialog(c: c, detail: detail));
}

class _DetailDialog extends StatelessWidget {
  final SalesListController c;
  final SaleDetail detail;
  const _DetailDialog({required this.c, required this.detail});

  @override
  Widget build(BuildContext context) {
    final sale = detail.sale;
    final isReturn = sale.type == 'return';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sizes.radius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _TypeBadge(isReturn: isReturn),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sale.invoiceNo,
                            style: const TextStyle(
                                fontSize: Sizes.titleText, fontWeight: FontWeight.w800)),
                        Text(
                          '${isReturn ? 'Return' : 'Sale'}  ·  '
                          '${fmtDateTime(sale.date)}  ·  '
                          '${sale.paymentType == 'cash' ? 'Cash' : 'Card'}',
                          style: const TextStyle(fontSize: 14, color: AppColors.textSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              // Item lines.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final it in detail.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(detail.names[it.productId] ?? 'Item',
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                '${it.qty} × ${it.priceAtSale.toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.textSoft),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(it.lineTotal.toStringAsFixed(0),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              if (sale.discountAmount > 0)
                _totalRow('Discount', '-${sale.discountAmount.toStringAsFixed(0)}'),
              _totalRow(
                isReturn ? 'Refund total' : 'Total',
                sale.totalAmount.toStringAsFixed(0),
                big: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                      label: const Text('Close', style: TextStyle(fontSize: Sizes.bodyText)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, Sizes.buttonHeight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reprint(c, sale),
                      icon: const Icon(Icons.print),
                      label: const Text('Reprint receipt',
                          style: TextStyle(fontSize: Sizes.bodyText)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: big ? Sizes.bodyText : 15,
                    fontWeight: big ? FontWeight.w800 : FontWeight.w500)),
            Text(value,
                style: TextStyle(
                    fontSize: big ? Sizes.titleText : 15,
                    fontWeight: big ? FontWeight.w800 : FontWeight.w600,
                    color: big ? AppColors.violet : AppColors.text)),
          ],
        ),
      );

  Future<void> _reprint(SalesListController c, Sale sale) async {
    final error = await c.reprint(sale);
    if (error == null) {
      Get.snackbar('Sent to printer', 'Receipt ${sale.invoiceNo} reprinted.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.violetTint,
          colorText: AppColors.text);
    } else {
      Get.snackbar('Could not print', error,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warnBg,
          colorText: AppColors.warn,
          duration: const Duration(seconds: 5));
    }
  }
}

/// Format an ISO8601 date string as "13/07/2026  02:35 PM".
String fmtDateTime(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(h12)}:${two(d.minute)} $ampm';
}
