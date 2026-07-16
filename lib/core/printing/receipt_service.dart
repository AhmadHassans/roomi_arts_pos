import 'dart:ffi';
import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../models/sale.dart';
import '../../models/sale_item.dart';
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

  /// Network printer address. When [networkIp] is set, the receipt is sent as
  /// raw ESC/POS bytes over TCP to [networkIp]:[networkPort] on any platform.
  /// Loaded at startup from [PrinterPrefs] and updated from the Settings screen.
  String? networkIp;
  int networkPort = PrinterPrefs.defaultPort;

  bool get hasNetworkPrinter =>
      networkIp != null && networkIp!.trim().isNotEmpty;

  /// True on the platform that has a directly-attached thermal printer (the
  /// Windows shop PC via USB). Network printing is handled separately.
  bool get isThermalPlatform => Platform.isWindows;

  /// Load saved network-printer settings into memory (call once at startup).
  Future<void> loadSettings() async {
    networkIp = await PrinterPrefs.getIp();
    networkPort = await PrinterPrefs.getPort();
  }

  /// Print a receipt, or show the on-screen preview. Order:
  ///  1. If a network printer is configured, send ESC/POS over TCP.
  ///  2. Else on Windows, send raw to the USB spooler.
  ///  3. Else (or if the network printer is unreachable), show the preview.
  ///
  /// Returns null on success, or a short plain-words message on failure — never
  /// throws, so a printer problem can never lose an already-saved sale.
  Future<String?> deliver({
    required Sale sale,
    required List<SaleItem> items,
    required Map<int, String> names,
  }) async {
    final data = ReceiptData.from(sale: sale, items: items, names: names);

    if (hasNetworkPrinter) {
      final List<int> bytes;
      try {
        bytes = await _buildBytes(data);
      } catch (e) {
        await ReceiptPreview.show(data);
        return 'Could not build the receipt: $e';
      }
      final err = await _sendOverTcp(bytes, networkIp!.trim(), networkPort);
      if (err == null) return null; // printed on the network printer
      // Unreachable: fall back to the preview so nothing is lost, and tell them.
      await ReceiptPreview.show(data);
      return err;
    }

    if (isThermalPlatform) {
      try {
        final bytes = await _buildBytes(data);
        return _sendRaw(bytes);
      } catch (e) {
        return 'Could not print receipt: $e';
      }
    }
    // No printer configured: show the same layout on screen.
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

  /// Send a small test receipt to [ip]:[port]. Returns null on success or a
  /// plain-words message. Used by the "Test print" button.
  Future<String?> testPrint(String ip, int port) async {
    final data = ReceiptData(
      shopName: 'Roomi Arts',
      subtitle: 'Stationery Shop',
      invoiceNo: 'TEST',
      dateText: ReceiptData.fmtDate(DateTime.now()),
      paymentText: 'Cash',
      isReturn: false,
      items: const [
        ReceiptItemLine('Test item', 1, 100),
      ],
      discount: 0,
      total: 100,
      footer: 'Printer test OK - you are ready to sell.',
    );
    final List<int> bytes;
    try {
      bytes = await _buildBytes(data);
    } catch (e) {
      return 'Could not build the test receipt: $e';
    }
    return _sendOverTcp(bytes, ip.trim(), port);
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

    // Header: shop name (bold, centered, big).
    out.addAll(g.text(
      ascii(data.shopName),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    out.addAll(g.text(ascii(data.subtitle),
        styles: const PosStyles(align: PosAlign.center)));
    if (data.isReturn) {
      out.addAll(g.text('** RETURN / REFUND **',
          styles: const PosStyles(align: PosAlign.center, bold: true)));
    }
    out.addAll(g.hr());

    // Date/time + invoice number.
    out.addAll(g.text('Invoice: ${ascii(data.invoiceNo)}'));
    out.addAll(g.text('Date: ${ascii(data.dateText)}'));
    out.addAll(g.text('Payment: ${ascii(data.paymentText)}'));
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
        PosColumn(text: ascii(it.name), width: 6),
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
