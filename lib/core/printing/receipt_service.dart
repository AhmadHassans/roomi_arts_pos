import 'dart:ffi';
import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../models/sale.dart';
import '../../models/sale_item.dart';
import 'receipt_data.dart';
import 'receipt_preview.dart';

/// ALL receipt output lives in this one file so the printer package can be
/// swapped later without touching the rest of the app.
///
/// Two paths, ONE layout (both render from [ReceiptData]):
///  - Windows (the shop machine): build 80mm ESC/POS bytes and send them RAW to
///    the USB receipt printer through the Windows print spooler (win32).
///  - Mac / other desktop (testing without the printer): show the exact same
///    receipt on screen as a preview.
class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();

  /// Optional printer name. When null, the Windows default printer is used.
  String? printerName;

  /// True on the platform that has the real thermal printer (Windows). Elsewhere
  /// we show an on-screen preview instead.
  bool get isThermalPlatform => Platform.isWindows;

  /// Print (Windows) or preview (elsewhere) a receipt. Returns null on success,
  /// or a short plain-words message on failure — never throws, so a printer
  /// problem can never lose an already-saved sale.
  Future<String?> deliver({
    required Sale sale,
    required List<SaleItem> items,
    required Map<int, String> names,
  }) async {
    final data = ReceiptData.from(sale: sale, items: items, names: names);
    if (isThermalPlatform) {
      try {
        final bytes = await _buildBytes(data);
        return _sendRaw(bytes);
      } catch (e) {
        return 'Could not print receipt: $e';
      }
    }
    // Testing on Mac/other desktop: show the same layout on screen.
    await ReceiptPreview.show(data);
    return null;
  }

  // ------------------------- Build the 80mm receipt -------------------------

  Future<List<int>> _buildBytes(ReceiptData data) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm80, profile);
    final out = <int>[];

    // Header: shop name (bold, centered, big).
    out.addAll(g.text(
      data.shopName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    out.addAll(g.text(data.subtitle,
        styles: const PosStyles(align: PosAlign.center)));
    if (data.isReturn) {
      out.addAll(g.text('** RETURN / REFUND **',
          styles: const PosStyles(align: PosAlign.center, bold: true)));
    }
    out.addAll(g.hr());

    // Date/time + invoice number.
    out.addAll(g.text('Invoice: ${data.invoiceNo}'));
    out.addAll(g.text('Date: ${data.dateText}'));
    out.addAll(g.text('Payment: ${data.paymentText}'));
    out.addAll(g.hr());

    // Column header.
    out.addAll(g.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(
          text: 'Total',
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]));

    for (final it in data.items) {
      out.addAll(g.row([
        PosColumn(text: it.name, width: 6),
        PosColumn(
            text: '${it.qty}',
            width: 2,
            styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
            text: ReceiptData.money(it.lineTotal),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    out.addAll(g.hr());

    if (data.discount > 0) {
      out.addAll(g.row([
        PosColumn(text: 'Discount', width: 8),
        PosColumn(
            text: '-${ReceiptData.money(data.discount)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    out.addAll(g.row([
      PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
          text: ReceiptData.money(data.total),
          width: 6,
          styles: const PosStyles(
              bold: true, align: PosAlign.right, height: PosTextSize.size2)),
    ]));

    out.addAll(g.hr());
    out.addAll(g.text(data.footer,
        styles: const PosStyles(align: PosAlign.center, bold: true)));
    out.addAll(g.feed(2));
    out.addAll(g.cut());

    return out;
  }

  // ------------------------- Send RAW to Windows -------------------------

  /// Send raw bytes to the printer via the Windows spooler.
  /// Returns null on success or a plain error message.
  String? _sendRaw(List<int> bytes) {
    final name = printerName ?? _defaultPrinterName();
    if (name == null) {
      return 'No printer found. Please connect the receipt printer.';
    }

    final pName = name.toNativeUtf16();
    final phPrinter = calloc<HANDLE>();
    final docInfo = calloc<DOC_INFO_1>();
    final pDocName = 'Roomi Arts Receipt'.toNativeUtf16();
    final pDatatype = 'RAW'.toNativeUtf16();
    final pBytes = calloc<Uint8>(bytes.length);
    final written = calloc<Uint32>();

    try {
      if (OpenPrinter(pName, phPrinter, nullptr) == 0) {
        return 'Could not open the printer "$name".';
      }
      final hPrinter = phPrinter.value;

      docInfo.ref.pDocName = pDocName;
      docInfo.ref.pOutputFile = nullptr;
      docInfo.ref.pDatatype = pDatatype;

      if (StartDocPrinter(hPrinter, 1, docInfo) == 0) {
        ClosePrinter(hPrinter);
        return 'Printer did not accept the receipt.';
      }
      StartPagePrinter(hPrinter);

      // Copy bytes into native memory.
      final buf = pBytes.asTypedList(bytes.length);
      buf.setAll(0, bytes);

      WritePrinter(hPrinter, pBytes.cast(), bytes.length, written);

      EndPagePrinter(hPrinter);
      EndDocPrinter(hPrinter);
      ClosePrinter(hPrinter);
      return null; // success
    } finally {
      calloc.free(pName);
      calloc.free(phPrinter);
      calloc.free(docInfo);
      calloc.free(pDocName);
      calloc.free(pDatatype);
      calloc.free(pBytes);
      calloc.free(written);
    }
  }

  /// Name of the current Windows default printer, or null if none.
  String? _defaultPrinterName() {
    final needed = calloc<Uint32>();
    // First call: ask for the required buffer size (fails, sets `needed`).
    GetDefaultPrinter(nullptr, needed);
    final size = needed.value;
    if (size == 0) {
      calloc.free(needed);
      return null;
    }
    final buffer = calloc<Uint16>(size).cast<Utf16>();
    try {
      if (GetDefaultPrinter(buffer, needed) == 0) return null;
      return buffer.toDartString();
    } finally {
      calloc.free(needed);
      calloc.free(buffer);
    }
  }
}
