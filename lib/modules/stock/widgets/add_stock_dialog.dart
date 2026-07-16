import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/product.dart';

/// Quick "Add stock" when a new box arrives (e.g. +24).
/// Returns the amount to add, or null if cancelled.
class AddStockDialog extends StatefulWidget {
  final Product product;
  const AddStockDialog({super.key, required this.product});

  static Future<int?> open(Product product) {
    return Get.dialog<int>(
      AddStockDialog(product: product),
      barrierDismissible: false,
    );
  }

  @override
  State<AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<AddStockDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n <= 0) {
      setState(() => _error = 'Enter how many pieces to add');
      return;
    }
    Get.back(result: n);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.radius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add stock',
                  style: TextStyle(
                      fontSize: Sizes.titleText, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('${p.name}  ·  now ${p.stockQty} in stock',
                  style: const TextStyle(
                      fontSize: Sizes.bodyText, color: AppColors.textSoft)),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: Sizes.bodyText),
                onSubmitted: (_) => _confirm(),
                decoration: InputDecoration(
                  labelText: 'How many pieces to add',
                  hintText: 'e.g. 24 for a box of 24',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, Sizes.buttonHeight),
                        side: const BorderSide(color: Color(0xFFD5DDDA)),
                        foregroundColor: AppColors.text,
                      ),
                      onPressed: () => Get.back(),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: Sizes.bodyText)),
                    ),
                  ),
                  const SizedBox(width: Sizes.gap),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirm,
                      child: const Text('Add'),
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
}
