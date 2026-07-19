import 'package:get/get.dart';

import '../../data/sales_history_repository.dart';

/// Which quick range is active (drives the highlighted quick button). `custom`
/// means the owner picked a specific day or From–To range by hand.
enum HistoryRange { today, yesterday, week, month, custom }

/// Drives the date-wise Sales History screen: the selected day/range, the
/// summary totals, the day-wise breakdown, the product-wise summary, and CSV
/// export. Read-only over the existing sales data.
class SalesHistoryController extends GetxController {
  final SalesHistoryRepository _repo = SalesHistoryRepository();

  final loading = true.obs;

  /// Selected range, [from, to): from is a day start (inclusive), to is a day
  /// start (exclusive). A single day is from..from+1day.
  final Rx<DateTime> from = DateTime.now().obs;
  final Rx<DateTime> to = DateTime.now().obs;
  final Rx<HistoryRange> activeRange = HistoryRange.today.obs;

  final Rxn<HistorySummary> summary = Rxn<HistorySummary>();
  final days = <HistoryDay>[].obs;
  final products = <ProductSold>[].obs;

  /// Whether the product-wise summary panel is expanded.
  final showProducts = false.obs;

  @override
  void onInit() {
    super.onInit();
    today();
  }

  // ------------------------- Quick ranges -------------------------

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  void today() {
    final s = _dayStart(DateTime.now());
    _apply(s, s.add(const Duration(days: 1)), HistoryRange.today);
  }

  void yesterday() {
    final s = _dayStart(DateTime.now()).subtract(const Duration(days: 1));
    _apply(s, s.add(const Duration(days: 1)), HistoryRange.yesterday);
  }

  /// This week = Monday 00:00 through now's day end (exclusive next day).
  void thisWeek() {
    final today = _dayStart(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    _apply(monday, today.add(const Duration(days: 1)), HistoryRange.week);
  }

  void thisMonth() {
    final now = DateTime.now();
    _apply(DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1), HistoryRange.month);
  }

  // ------------------------- Manual pick -------------------------

  /// Pick a single calendar day.
  void setSingleDay(DateTime day) {
    final s = _dayStart(day);
    _apply(s, s.add(const Duration(days: 1)), HistoryRange.custom);
  }

  /// Pick a From–To range (inclusive of both days).
  void setRange(DateTime fromDay, DateTime toDay) {
    var s = _dayStart(fromDay);
    var e = _dayStart(toDay).add(const Duration(days: 1)); // end exclusive
    if (e.isBefore(s)) {
      final t = s;
      s = _dayStart(toDay);
      e = t.add(const Duration(days: 1));
    }
    _apply(s, e, HistoryRange.custom);
  }

  void _apply(DateTime s, DateTime e, HistoryRange range) {
    from.value = s;
    to.value = e;
    activeRange.value = range;
    load();
  }

  Future<void> load() async {
    loading.value = true;
    summary.value = await _repo.summary(from.value, to.value);
    days.value = await _repo.breakdown(from.value, to.value);
    products.value = await _repo.productSummary(from.value, to.value);
    loading.value = false;
  }

  // ------------------------- Labels -------------------------

  /// True when the range covers exactly one calendar day.
  bool get isSingleDay =>
      to.value.difference(from.value).inDays == 1;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String fmtDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// "14 Jul 2026" for a single day, or "10 Jul 2026  –  14 Jul 2026".
  String get rangeLabel {
    if (isSingleDay) return fmtDay(from.value);
    final lastDay = to.value.subtract(const Duration(days: 1));
    return '${fmtDay(from.value)}  –  ${fmtDay(lastDay)}';
  }

  static String fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  // ------------------------- CSV export -------------------------

  /// Build the CSV text for the current range: a summary block, one row per
  /// invoice item line, then a product-wise summary. Pure — the caller picks
  /// where to save it (native Save-As) so there are no sandbox writes.
  String buildCsv() {
    final s = summary.value;
    final buf = StringBuffer();

    buf.writeln('Roomi Arts - Sales History');
    buf.writeln('Range,${_csv(rangeLabel)}');
    if (s != null) {
      buf.writeln('Total sales,${s.salesTotal.toStringAsFixed(0)}');
      buf.writeln('Total profit,${s.profit.toStringAsFixed(0)}');
      buf.writeln('Invoices,${s.invoiceCount}');
      buf.writeln('Returns,${s.returnCount}');
      buf.writeln('Cash,${s.split.cash.toStringAsFixed(0)}');
      buf.writeln('Card,${s.split.card.toStringAsFixed(0)}');
      buf.writeln('Online,${s.split.online.toStringAsFixed(0)}');
    }
    buf.writeln();

    // One row per item. Invoice-level fields (Discount, Total, Payment,
    // Cashier) repeat on each of the invoice's rows so every row is
    // self-contained for filtering in Excel. Returns are shown negative.
    // Cashier is blank: it is not stored per sale (printed live only).
    buf.writeln(
        'Invoice,Date,Time,Item,Quantity,Rate,Amount,Discount,Total,Payment,Cashier');
    for (final day in days) {
      for (final inv in day.invoices) {
        final sign = inv.isReturn ? -1 : 1;
        final invTotal = (inv.amount * sign).toStringAsFixed(0);
        final invDisc = (inv.discount * sign).toStringAsFixed(0);
        final pay = _payLabel(inv.paymentType);
        final cashier = _csv(inv.cashier ?? '');
        if (inv.items.isEmpty) {
          buf.writeln('${_csv(inv.invoiceNo)},${day.day},'
              '${fmtTime(inv.dateTime)},,,,,'
              '$invDisc,$invTotal,$pay,$cashier');
        }
        for (final it in inv.items) {
          final rate = it.qty == 0 ? 0.0 : it.amount / it.qty;
          final amt = it.amount * sign;
          buf.writeln('${_csv(inv.invoiceNo)},${day.day},'
              '${fmtTime(inv.dateTime)},${_csv(it.name)},'
              '${it.qty * sign},${rate.toStringAsFixed(2)},'
              '${amt.toStringAsFixed(0)},$invDisc,$invTotal,$pay,$cashier');
        }
      }
    }

    // Product-wise summary at the end.
    buf.writeln();
    buf.writeln('Product,Qty sold,Amount');
    for (final p in products) {
      buf.writeln('${_csv(p.name)},${p.qty},${p.amount.toStringAsFixed(0)}');
    }

    return buf.toString();
  }

  /// True when the current range has any sales or returns to export.
  bool get hasSales => days.isNotEmpty;

  static String _payLabel(String type) => type.isEmpty
      ? ''
      : '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}';

  /// Suggested CSV file name for the current range, e.g.
  /// roomi_sales_2026-07-14.csv or roomi_sales_2026-07-10_to_2026-07-14.csv.
  String suggestedCsvName() {
    String k(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final stamp = isSingleDay
        ? k(from.value)
        : '${k(from.value)}_to_${k(to.value.subtract(const Duration(days: 1)))}';
    return 'roomi_sales_$stamp.csv';
  }

  /// Escape a CSV field: quote when it contains a comma, quote, or newline.
  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
