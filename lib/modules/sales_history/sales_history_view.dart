import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../data/sales_history_repository.dart';
import '../../widgets/ui_kit.dart';
import 'sales_history_controller.dart';

/// SALES HISTORY (owner-only): pick a day or a From–To range and see exactly
/// what was sold — summary totals, a day-wise invoice breakdown, and a
/// product-wise summary — with CSV export.
///
/// UI only. Every number comes from [SalesHistoryController] / the read-only
/// [SalesHistoryRepository]; sales are never modified here.
class SalesHistoryView extends StatelessWidget {
  const SalesHistoryView({super.key});

  static String _money(double v) => 'Rs ${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SalesHistoryController());
    return Container(
      color: AppColors.bgLav,
      child: Obx(() {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(c: c),
              const SizedBox(height: 18),
              _Controls(c: c),
              const SizedBox(height: 20),
              if (c.loading.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _SummaryRow(c: c),
                const SizedBox(height: 20),
                _ProductSummary(c: c),
                const SizedBox(height: 20),
                _Breakdown(c: c),
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// Title + selected-range label + Export button.
class _Header extends StatelessWidget {
  final SalesHistoryController c;
  const _Header({required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales history',
                  style: TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              Text('Showing: ${c.rangeLabel}',
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.muted)),
            ],
          ),
        ),
        SizedBox(
          width: 170,
          child: GradientButton(
            expand: true,
            icon: Icons.download,
            label: 'Export CSV',
            onTap: () => _export(context),
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final path = await c.exportCsv();
      Get.snackbar('Exported', 'Saved to:\n$path',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
          backgroundColor: AppColors.violetTint,
          colorText: AppColors.text);
    } catch (e) {
      Get.snackbar('Export failed', 'Could not save the file: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFFFE6EC),
          colorText: AppColors.danger);
    }
  }
}

/// Quick-range pills + single-day / date-range pickers.
class _Controls extends StatelessWidget {
  final SalesHistoryController c;
  const _Controls({required this.c});

  String _quickValue(HistoryRange r) => switch (r) {
        HistoryRange.today => 'today',
        HistoryRange.yesterday => 'yesterday',
        HistoryRange.week => 'week',
        HistoryRange.month => 'month',
        HistoryRange.custom => '', // no pill highlighted
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegToggle(
            height: 46,
            options: const [
              ('today', 'Today'),
              ('yesterday', 'Yesterday'),
              ('week', 'This week'),
              ('month', 'This month'),
            ],
            selected: _quickValue(c.activeRange.value),
            onChanged: (v) {
              switch (v) {
                case 'today':
                  c.today();
                case 'yesterday':
                  c.yesterday();
                case 'week':
                  c.thisWeek();
                case 'month':
                  c.thisMonth();
              }
            },
          ),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _pickDay(context),
              icon: const Icon(Icons.event, size: 18),
              label: const Text('Pick a day'),
            ),
          ),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _pickRange(context),
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text('Pick a range'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: c.from.value,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Pick a day',
    );
    if (picked != null) c.setSingleDay(picked);
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final lastDay = c.to.value.subtract(const Duration(days: 1));
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: c.from.value,
        end: lastDay.isBefore(c.from.value) ? c.from.value : lastDay,
      ),
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Pick a From – To range',
    );
    if (picked != null) c.setRange(picked.start, picked.end);
  }
}

/// Summary stat tiles: sales, profit, invoices + a payment-split card.
class _SummaryRow extends StatelessWidget {
  final SalesHistoryController c;
  const _SummaryRow({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.summary.value;
    if (s == null) return const SizedBox.shrink();
    final invoiceTag = s.returnCount > 0
        ? '${s.returnCount} return${s.returnCount == 1 ? '' : 's'}'
        : 'No returns';
    return LayoutBuilder(builder: (context, box) {
      // Four equal columns when wide; wrap to two-up when narrow.
      final wide = box.maxWidth > 720;
      final tileW = wide ? (box.maxWidth - 3 * 16) / 4 : (box.maxWidth - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: tileW,
            child: StatCard(
              title: 'Total sales',
              value: SalesHistoryView._money(s.salesTotal),
              tag: c.rangeLabel,
              icon: Icons.trending_up,
              gradient: AppGradients.violet,
            ),
          ),
          SizedBox(
            width: tileW,
            child: StatCard(
              title: 'Total profit',
              value: SalesHistoryView._money(s.profit),
              tag: 'After cost',
              icon: Icons.savings,
              gradient: AppGradients.coral,
            ),
          ),
          SizedBox(
            width: tileW,
            child: StatCard(
              title: 'Invoices',
              value: '${s.invoiceCount}',
              tag: invoiceTag,
              icon: Icons.receipt_long,
              gradient: AppGradients.teal,
            ),
          ),
          SizedBox(
            width: tileW,
            child: _PaymentSplitCard(split: s.split),
          ),
        ],
      );
    });
  }
}

/// Cash / Card / Online amounts for the range, styled like a stat tile.
class _PaymentSplitCard extends StatelessWidget {
  final PaymentSplit split;
  const _PaymentSplitCard({required this.split});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.amber,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.glow(AppColors.amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 19),
          ),
          const SizedBox(height: 12),
          const Text('Payment split',
              style: TextStyle(
                  fontFamily: AppTheme.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 8),
          _row('Cash', split.cash),
          _row('Card', split.card),
          _row('Online', split.online),
        ],
      ),
    );
  }

  Widget _row(String label, double amount) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontFamily: AppTheme.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92))),
            Text('Rs ${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontFamily: AppTheme.display,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      );
}

/// Collapsible product-wise summary: "Pens: 12 sold, Rs X".
class _ProductSummary extends StatelessWidget {
  final SalesHistoryController c;
  const _ProductSummary({required this.c});

  @override
  Widget build(BuildContext context) {
    final products = c.products;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Product-wise summary',
            subtitle: 'What sold in this range',
            trailing: SizedBox(
              height: 40,
              child: TextButton.icon(
                onPressed: () => c.showProducts.toggle(),
                icon: Icon(
                    c.showProducts.value
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20),
                label: Text(c.showProducts.value ? 'Hide' : 'Show'),
              ),
            ),
          ),
          if (c.showProducts.value) ...[
            const SizedBox(height: 12),
            if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Nothing sold in this range.',
                    style: TextStyle(color: AppColors.muted)),
              )
            else
              ...products.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(p.name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.violetTint,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text('${p.qty} sold',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.violetDark)),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: Text('Rs ${p.amount.toStringAsFixed(0)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                      ],
                    ),
                  )),
          ],
        ],
      ),
    );
  }
}

/// Day-wise breakdown: one card per day, listing each invoice's items.
class _Breakdown extends StatelessWidget {
  final SalesHistoryController c;
  const _Breakdown({required this.c});

  @override
  Widget build(BuildContext context) {
    final days = c.days;
    if (days.isEmpty) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No sales in this range.',
                style: TextStyle(fontSize: 16, color: AppColors.muted)),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days) ...[
          _DayCard(day: day),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final HistoryDay day;
  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse('${day.day}T00:00:00');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day header: date + that day's net total.
          Row(
            children: [
              const GradientTile(
                  icon: Icons.calendar_today, gradient: AppGradients.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(SalesHistoryController.fmtDay(d),
                    style: const TextStyle(
                        fontFamily: AppTheme.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ),
              Text('Rs ${day.dayTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.violet)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.panelBorder, height: 20),
          for (final inv in day.invoices) _InvoiceBlock(inv: inv),
        ],
      ),
    );
  }
}

class _InvoiceBlock extends StatelessWidget {
  final HistoryInvoice inv;
  const _InvoiceBlock({required this.inv});

  @override
  Widget build(BuildContext context) {
    final amountColor = inv.isReturn ? AppColors.danger : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(inv.invoiceNo,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(width: 8),
              if (inv.isReturn)
                const StatusBadge(text: 'RETURN', kind: BadgeKind.refund),
              const SizedBox(width: 8),
              Text(SalesHistoryController.fmtTime(inv.dateTime),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const Spacer(),
              _payChip(inv.paymentType),
              const SizedBox(width: 10),
              Text('${inv.isReturn ? '-' : ''}Rs ${inv.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: amountColor)),
            ],
          ),
          const SizedBox(height: 6),
          // Items sold on this invoice.
          for (final it in inv.items)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
              child: Row(
                children: [
                  const Text('•  ',
                      style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  Expanded(
                    child: Text(it.name,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.text)),
                  ),
                  Text('x${it.qty}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: Text('Rs ${it.amount.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.text)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _payChip(String type) {
    final label = type.isEmpty
        ? '—'
        : '${type[0].toUpperCase()}${type.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.violetTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.violetDark)),
    );
  }
}
