import 'dart:ffi';
import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../constants.dart';
import 'printer_prefs.dart';
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

  /// Chosen printing mode. Defaults to the USB/system printer, which previews
  /// automatically on a machine without one (so Mac testing "just works").
  PrinterMode printerMode = PrinterMode.system;

  /// Network printer address (only used when [printerMode] is network).
  String? networkIp;
  int networkPort = PrinterPrefs.defaultPort;

  bool get hasNetworkPrinter =>
      networkIp != null && networkIp!.trim().isNotEmpty;

  /// True on the platform that has a directly-attached USB/system thermal
  /// printer (the Windows shop PC). Elsewhere, system mode previews instead.
  bool get isThermalPlatform => Platform.isWindows;

  /// Load saved printer settings into memory (call once at startup).
  Future<void> loadSettings() async {
    printerMode = await PrinterPrefs.getMode();
    networkIp = await PrinterPrefs.getIp();
    networkPort = await PrinterPrefs.getPort();
    final name = await PrinterPrefs.getName();
    printerName = name.isEmpty ? null : name;
  }

  /// Names of the printers installed on this Windows machine (local + network
  /// connections). Empty on non-Windows or if none are installed. Used by
  /// Settings so the owner can pick which USB/system printer to print to.
  List<String> listPrinters() {
    if (!Platform.isWindows) return const [];
    const flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
    const level = 4; // PRINTER_INFO_4: just the name + attributes (fast).
    final needed = calloc<Uint32>();
    final returned = calloc<Uint32>();
    try {
      // First call sizes the buffer (fails, fills `needed`).
      EnumPrinters(flags, nullptr, level, nullptr, 0, needed, returned);
      final size = needed.value;
      if (size == 0) return const [];

      final buffer = calloc<Uint8>(size);
      try {
        if (EnumPrinters(flags, nullptr, level, buffer, size, needed,
                returned) ==
            0) {
          return const [];
        }
        final count = returned.value;
        final names = <String>[];
        final info = buffer.cast<PRINTER_INFO_4>();
        for (var i = 0; i < count; i++) {
          final p = (info + i).ref.pPrinterName;
          if (p != nullptr) {
            final name = p.toDartString();
            if (name.isNotEmpty) names.add(name);
          }
        }
        return names;
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc.free(needed);
      calloc.free(returned);
    }
  }

  /// Print a receipt, or show the on-screen preview — depending on [printerMode]
  /// and the platform. Never throws and never blocks a sale:
  ///  - system mode on Windows -> USB/system spooler.
  ///  - system mode elsewhere (Mac testing) -> on-screen preview, no error.
  ///  - network mode with an IP -> ESC/POS over TCP; if unreachable, preview +
  ///    a short message.
  ///  - anything else -> preview.
  ///
  /// Returns null on success, or a short plain-words message on failure.
  Future<String?> deliver({
    required Sale sale,
    required List<SaleItem> items,
    required Map<int, String> names,
    String? cashierName,
    double? cashReceived,
  }) async {
    final data = ReceiptData.from(
      sale: sale,
      items: items,
      names: names,
      cashierName: cashierName,
      cashReceived: cashReceived,
    );
    return _route(data);
  }

  /// Route a built receipt to the printer or the preview per [printerMode].
  Future<String?> _route(ReceiptData data) async {
    // Network mode: send over TCP, fall back to preview if it can't be reached.
    if (printerMode == PrinterMode.network && hasNetworkPrinter) {
      final List<int> bytes;
      try {
        bytes = await _buildBytes(data);
      } catch (e) {
        await ReceiptPreview.show(data);
        return 'Could not build the receipt: $e';
      }
      final err = await _sendOverTcp(bytes, networkIp!.trim(), networkPort);
      if (err == null) return null; // printed
      await ReceiptPreview.show(data); // keep the sale, show it on screen
      return err;
    }

    // System/USB mode: real spooler on Windows, silent preview elsewhere.
    if (printerMode == PrinterMode.system && isThermalPlatform) {
      try {
        final bytes = await _buildBytes(data);
        return _sendRaw(bytes);
      } catch (e) {
        return 'Could not print receipt: $e';
      }
    }

    // Default / testing on Mac: show the same layout on screen, no error.
    await ReceiptPreview.show(data);
    return null;
  }

  // ------------------------- Network (TCP / ESC-POS) -------------------------

  /// Open a TCP connection to the printer and write the raw ESC/POS bytes.
  /// Returns null on success or a plain-words message. Never throws.
  Future<String?> _sendOverTcp(List<int> bytes, String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      // Give the printer a moment to drain before we close the socket.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await socket.close();
      return null;
    } catch (e) {
      return 'Printer at $ip:$port is not reachable — showing a preview '
          'instead. Check the printer power and network.';
    } finally {
      socket?.destroy();
    }
  }

  /// Quick reachability check for the Settings status indicator. True if the
  /// printer accepts a TCP connection on [ip]:[port].
  Future<bool> pingPrinter(String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip.trim(), port,
          timeout: const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  /// Print (or preview) a small test receipt using the CURRENT [printerMode] and
  /// settings. Save the settings first so they are applied. Returns null on
  /// success or a plain-words message. Used by the "Test print" button.
  Future<String?> testPrint() {
    final data = ReceiptData(
      shopName: AppText.shopName,
      subtitle: AppText.shopTagline,
      address: AppText.shopAddress,
      phone: AppText.shopPhone,
      invoiceNo: 'TEST',
      dateText: ReceiptData.fmtDate(DateTime.now()),
      cashier: 'Test',
      paymentText: 'Cash',
      isReturn: false,
      items: const [
        ReceiptItemLine('Test item', 1, 100, 100),
      ],
      subtotal: 100,
      discount: 0,
      total: 100,
      cashReceived: 200,
      footer: 'Printer test OK - you are ready to sell.',
    );
    return _route(data);
  }

  // ------------------------- Build the 80mm receipt -------------------------

  /// Thermal printers use a single-byte code page (CP437), so any non-ASCII
  /// character (em-dash, smart quotes, ellipsis, curly apostrophe, ₨, etc.)
  /// prints as garbage or breaks the line. Map the common ones to safe ASCII
  /// and replace anything else outside printable ASCII with '?'. Tabs/newlines
  /// are kept.
  static String ascii(String s) {
    const map = {
      '—': '-', '–': '-', '−': '-', '‑': '-', '―': '-',
      '“': '"', '”': '"', '„': '"', '«': '"', '»': '"',
      '‘': "'", '’': "'", '‚': "'", '`': "'",
      '…': '...', '•': '*', '·': '-', '×': 'x', '÷': '/',
      '₨': 'Rs', '﷼': 'Rs', '®': '(R)', '©': '(C)', '™': '(TM)',
      '°': ' deg', ' ': ' ',
    };
    final sb = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      final rep = map[ch];
      if (rep != null) {
        sb.write(rep);
      } else if (r == 9 || r == 10 || (r >= 32 && r < 127)) {
        sb.write(ch);
      } else {
        sb.write('?');
      }
    }
    return sb.toString();
  }

  Future<List<int>> _buildBytes(ReceiptData data) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm80, profile);
    final out = <int>[];

    const center = PosStyles(align: PosAlign.center);

    // Header: shop name (bold, centered, big) + tagline, address, phone.
    out.addAll(g.text(
      ascii(data.shopName),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    out.addAll(g.text(ascii(data.subtitle), styles: center));
    out.addAll(g.text(ascii(data.address), styles: center));
    out.addAll(g.text(ascii(data.phone), styles: center));
    if (data.isReturn) {
      out.addAll(g.text('** RETURN / REFUND **',
          styles: const PosStyles(align: PosAlign.center, bold: true)));
    }
    out.addAll(g.hr());

    // Invoice / date / cashier / payment (label left, value right).
    void kv(String label, String value) {
      out.addAll(g.row([
        PosColumn(text: ascii(label), width: 5),
        PosColumn(
            text: ascii(value),
            width: 7,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    kv('Invoice:', data.invoiceNo);
    kv('Date:', data.dateText);
    if (data.cashier != null && data.cashier!.isNotEmpty) {
      kv('Cashier:', data.cashier!);
    }
    kv('Payment:', data.paymentText);
    out.addAll(g.hr());

    // Column header: Item | Qty x Rate | Amt.
    out.addAll(g.row([
      PosColumn(text: 'Item', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(
          text: 'Qty x Rate',
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(
          text: 'Amt',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]));

    for (final it in data.items) {
      out.addAll(g.row([
        PosColumn(text: ascii(it.name), width: 5),
        PosColumn(
            text: '${it.qty} x ${ReceiptData.money(it.unitPrice)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
            text: ReceiptData.money(it.lineTotal),
            width: 3,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    out.addAll(g.hr());

    // Totals block.
    void totalRow(String label, String value, {bool big = false}) {
      final style = PosStyles(
        bold: big,
        align: PosAlign.right,
        height: big ? PosTextSize.size2 : PosTextSize.size1,
      );
      out.addAll(g.row([
        PosColumn(
            text: ascii(label),
            width: 6,
            styles: PosStyles(bold: big, height: style.height)),
        PosColumn(text: ascii(value), width: 6, styles: style),
      ]));
    }

    totalRow('Subtotal', ReceiptData.money(data.subtotal));
    totalRow('Discount', '-${ReceiptData.money(data.discount)}');
    totalRow('TOTAL', 'Rs ${ReceiptData.money(data.total)}', big: true);

    // Cash received / change (cash sales only).
    if (data.showsCash) {
      out.addAll(g.hr());
      totalRow('Cash received', ReceiptData.money(data.cashReceived!));
      if (data.balanceDue != null) {
        totalRow('BALANCE DUE', 'Rs ${ReceiptData.money(data.balanceDue!)}',
            big: true);
      } else {
        totalRow('CHANGE RETURN',
            'Rs ${ReceiptData.money(data.changeReturn ?? 0)}',
            big: true);
      }
    }

    out.addAll(g.hr());
    out.addAll(g.text('Items: ${data.itemsCount}', styles: center));
    out.addAll(g.text(ascii(data.footer),
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
