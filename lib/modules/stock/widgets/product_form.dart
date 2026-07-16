import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/product.dart';

/// Simple add/edit product form shown as a dialog.
/// Returns the built Product (id preserved when editing), or null if cancelled.
class ProductForm extends StatefulWidget {
  final Product? existing; // null = add new
  const ProductForm({super.key, this.existing});

  static Future<Product?> open({Product? existing}) {
    return Get.dialog<Product>(
      ProductForm(existing: existing),
      barrierDismissible: false,
    );
  }

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _sell;
  late final TextEditingController _stock;
  late final TextEditingController _barcode;
  late String _category;
  late String _unit;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _cost = TextEditingController(text: e?.costPrice.toString() ?? '');
    _sell = TextEditingController(text: e?.sellingPrice.toString() ?? '');
    _stock = TextEditingController(text: e?.stockQty.toString() ?? '');
    _barcode = TextEditingController(text: e?.barcode ?? '');
    _category = e?.category ?? Categories.all.first;
    _unit = e?.unit ?? Units.all.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _sell.dispose();
    _stock.dispose();
    _barcode.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final p = Product(
      id: widget.existing?.id,
      name: _name.text.trim(),
      category: _category,
      costPrice: double.parse(_cost.text.trim()),
      sellingPrice: double.parse(_sell.text.trim()),
      stockQty: int.parse(_stock.text.trim()),
      unit: _unit,
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
    );
    Get.back(result: p);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.radius)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit product' : 'Add product',
                    style: const TextStyle(
                        fontSize: Sizes.titleText, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _field(_name, 'Name', required: true),
                const SizedBox(height: Sizes.gap),
                _dropdown(
                  label: 'Category',
                  value: _category,
                  items: Categories.all,
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: Sizes.gap),
                Row(
                  children: [
                    Expanded(child: _numField(_cost, 'Cost price')),
                    const SizedBox(width: Sizes.gap),
                    Expanded(child: _numField(_sell, 'Selling price')),
                  ],
                ),
                const SizedBox(height: Sizes.gap),
                Row(
                  children: [
                    Expanded(child: _numField(_stock, 'Stock (pieces)', integer: true)),
                    const SizedBox(width: Sizes.gap),
                    Expanded(
                      child: _dropdown(
                        label: 'Unit',
                        value: _unit,
                        items: Units.all,
                        onChanged: (v) => setState(() => _unit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sizes.gap),
                _field(_barcode, 'Barcode (optional)'),
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
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool required = false}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(fontSize: Sizes.bodyText),
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Please type a name' : null
          : null,
    );
  }

  Widget _numField(TextEditingController c, String label, {bool integer = false}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(fontSize: Sizes.bodyText),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        integer
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        final n = integer ? int.tryParse(v.trim()) : double.tryParse(v.trim());
        if (n == null) return 'Enter a number';
        if (n < 0) return 'Cannot be less than 0';
        return null;
      },
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      style: const TextStyle(fontSize: Sizes.bodyText, color: AppColors.text),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
