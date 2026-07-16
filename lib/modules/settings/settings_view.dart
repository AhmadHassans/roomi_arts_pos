import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/printing/printer_prefs.dart';
import '../../core/printing/receipt_service.dart';
import '../../core/theme.dart';
import '../../core/tokens.dart';
import '../../widgets/ui_kit.dart';

/// SETTINGS (owner-only): configure the network receipt printer (IP + port),
/// test the connection, and send a test print.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

enum _Status { unknown, checking, connected, unreachable }

class _SettingsViewState extends State<SettingsView> {
  final _ip = TextEditingController();
  final _port = TextEditingController();
  _Status _status = _Status.unknown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final ip = await PrinterPrefs.getIp();
    final port = await PrinterPrefs.getPort();
    if (!mounted) return;
    setState(() {
      // Prefill with the shop printer's address on first setup.
      _ip.text = ip.isEmpty ? '192.168.1.100' : ip;
      _port.text = port.toString();
    });
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  ({String ip, int port})? _read() {
    final ip = _ip.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (ip.isEmpty) {
      _toast('Please type the printer IP address.');
      return null;
    }
    if (port == null || port <= 0 || port > 65535) {
      _toast('Please type a valid port (e.g. 9100).');
      return null;
    }
    return (ip: ip, port: port);
  }

  Future<void> _save() async {
    final v = _read();
    if (v == null) return;
    await PrinterPrefs.save(ip: v.ip, port: v.port);
    // Apply immediately so the next sale prints to it.
    ReceiptService.instance.networkIp = v.ip;
    ReceiptService.instance.networkPort = v.port;
    _toast('Printer settings saved.');
    await _check();
  }

  Future<void> _check() async {
    final v = _read();
    if (v == null) return;
    setState(() => _status = _Status.checking);
    final ok = await ReceiptService.instance.pingPrinter(v.ip, v.port);
    if (!mounted) return;
    setState(() => _status = ok ? _Status.connected : _Status.unreachable);
  }

  Future<void> _testPrint() async {
    final v = _read();
    if (v == null) return;
    // Make sure the latest values are saved/applied before testing.
    await PrinterPrefs.save(ip: v.ip, port: v.port);
    ReceiptService.instance.networkIp = v.ip;
    ReceiptService.instance.networkPort = v.port;

    setState(() => _busy = true);
    final err = await ReceiptService.instance.testPrint(v.ip, v.port);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = err == null ? _Status.connected : _Status.unreachable;
    });
    _toast(err ?? 'Test receipt sent — check the printer.');
  }

  void _toast(String msg) => Get.snackbar('Printer', msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.violetTint,
      colorText: AppColors.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Settings',
                style:
                    TextStyle(fontSize: Sizes.bigText, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Set up your network receipt printer (connected to the WiFi router).',
              style: TextStyle(fontSize: Sizes.bodyText, color: AppColors.textSoft),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const GradientTile(
                            icon: Icons.print, gradient: AppGradients.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Network receipt printer',
                              style: TextStyle(
                                  fontSize: Sizes.titleText,
                                  fontWeight: FontWeight.w800)),
                        ),
                        _StatusChip(status: _status),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _ip,
                      style: const TextStyle(fontSize: Sizes.bodyText),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Printer IP address',
                        hintText: 'e.g. 192.168.1.100',
                        prefixIcon: Icon(Icons.lan, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: Sizes.gap),
                    TextField(
                      controller: _port,
                      style: const TextStyle(fontSize: Sizes.bodyText),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '9100',
                        prefixIcon: Icon(Icons.settings_ethernet,
                            color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: GradientButton(
                            expand: true,
                            icon: Icons.save,
                            label: 'Save',
                            onTap: _busy ? null : _save,
                          ),
                        ),
                        const SizedBox(width: Sizes.gap),
                        Expanded(
                          child: SizedBox(
                            height: Sizes.buttonHeight,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _check,
                              icon: const Icon(Icons.wifi_find),
                              label: const Text('Check connection'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sizes.gap),
                    SizedBox(
                      height: Sizes.buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _testPrint,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.receipt_long),
                        label: Text(_busy ? 'Sending…' : 'Test print'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tip: most ESC/POS network printers use port 9100. If a '
                      'sale can’t reach the printer, the receipt is shown on '
                      'screen instead so nothing is lost.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _Status status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg, icon) = switch (status) {
      _Status.connected => (
          'Connected',
          const Color(0xFF1EAE74),
          const Color(0xFFE3F7EE),
          Icons.check_circle
        ),
      _Status.unreachable => (
          'Not reachable',
          AppColors.danger,
          const Color(0xFFFFE6EC),
          Icons.error
        ),
      _Status.checking => (
          'Checking…',
          AppColors.violet,
          AppColors.violetTint,
          Icons.sync
        ),
      _Status.unknown => (
          'Not checked',
          AppColors.muted,
          const Color(0xFFEFECF8),
          Icons.help_outline
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
