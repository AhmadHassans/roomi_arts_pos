// The thermal printer only understands single-byte ASCII/CP437. These check
// that receipt text is sanitized so a stray em-dash / smart quote can't break
// (or garble) a printed receipt.
import 'package:flutter_test/flutter_test.dart';
import 'package:roomi_arts_pos/core/printing/receipt_service.dart';

void main() {
  test('dashes and smart punctuation map to safe ASCII', () {
    expect(ReceiptService.ascii('Printer test OK — you are ready'),
        'Printer test OK - you are ready');
    expect(ReceiptService.ascii('en–dash and minus−sign'),
        'en-dash and minus-sign');
    expect(ReceiptService.ascii('can’t won’t'), "can't won't");
    expect(ReceiptService.ascii('“quoted”'), '"quoted"');
    expect(ReceiptService.ascii('loading…'), 'loading...');
    expect(ReceiptService.ascii('₨ 250'), 'Rs 250');
  });

  test('plain ASCII is unchanged', () {
    const s = 'Blue ball pen x2 = 30  INV-000123';
    expect(ReceiptService.ascii(s), s);
  });

  test('other non-ASCII becomes ? (never breaks the line)', () {
    expect(ReceiptService.ascii('日本'), '??');
    // Tabs and newlines are preserved.
    expect(ReceiptService.ascii('a\tb\nc'), 'a\tb\nc');
  });
}
