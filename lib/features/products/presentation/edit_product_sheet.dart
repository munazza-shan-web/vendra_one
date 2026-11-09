
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';

class EditProductSheet extends ConsumerStatefulWidget {
  const EditProductSheet({
    super.key,
    required this.product,
  });

  final Product product;

  @override
  ConsumerState<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends ConsumerState<EditProductSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _descriptionController;

  String? _categoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(text: product.name);
    _sellingPriceController = TextEditingController(
      text: (product.sellingPriceMinor / 100).toStringAsFixed(2),
    );
    _costPriceController = TextEditingController(
      text: (product.costPriceMinor / 100).toStringAsFixed(2),
    );
    _stockController = TextEditingController(
      text: product.stockQuantity.toString(),
    );
    _lowStockController = TextEditingController(
      text: product.lowStockThreshold.toString(),
    );
    _skuController = TextEditingController(text: product.sku ?? '');
    _barcodeController = TextEditingController(text: product.barcode ?? '');
    _descriptionController = TextEditingController(
      text: product.description ?? '',
    );

    _categoryId = product.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int? _toMinorUnits(String value) {
    final amount = double.tryParse(value.trim());

    if (amount == null || !amount.isFinite || amount < 0) {
      return null;
    }

    return (amount * 100).round();
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    return null;
  }

  String? _validateMoney(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter an amount';
    }

    final amount = double.tryParse(value.trim());

    if (amount == null || !amount.isFinite || amount < 0) {
      return 'Enter a valid non-negative amount';
    }

    return null;
  }

  String? _validateInteger(String? value) {
    final number = int.tryParse(value ?? '');

    if (number == null || number < 0) {
      return 'Enter a valid whole number';
    }

    return null;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final sellingPrice = _toMinorUnits(_sellingPriceController.text);
    final costPrice = _costPriceController.text.trim().isEmpty
        ? 0
        : _toMinorUnits(_costPriceController.text);

    if (sellingPrice == null || costPrice == null) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(productRepositoryProvider).updateProduct(
            id: widget.product.id,
            name: _nameController.text.trim(),
            sellingPriceMinor: sellingPrice,
            costPriceMinor: costPrice,
            stockQuantity: int.parse(_stockController.text),
            lowStockThreshold: int.parse(_lowStockController.text),
            categoryId: _categoryId,
            sku: _skuController.text.trim().isEmpty
                ? null
                : _skuController.text.trim(),
            barcode: _barcodeController.text.trim().isEmpty
                ? null
                : _barcodeController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update product: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryRepository = ref.watch(categoryRepositoryProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Product',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              _field(
                controller: _nameController,
                label: 'Product name',
                validator: _requiredText,
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Category>>(
                stream: categoryRepository.watchAllCategories(),
                builder: (context, snapshot) {
                  final allCategories = snapshot.data ?? [];

                  // Include active categories and this product's existing
                  // category if it has been deactivated.
                  final availableCategories = allCategories.where((category) {
                    return category.isActive ||
                        category.id == widget.product.categoryId;
                  }).toList();

                  final selectedValue = availableCategories.any(
                    (category) => category.id == _categoryId,
                  )
                      ? _categoryId
                      : null;

                  return DropdownButtonFormField<String>(
                    initialValue: selectedValue,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                    items: availableCategories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category.id,
                        enabled: category.isActive,
                        child: Row(
                          children: [
                            Expanded(child: Text(category.name)),
                            if (!category.isActive)
                              const Text(
                                'Inactive',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _categoryId = value);
                    },
                  );
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _sellingPriceController,
                label: 'Selling price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validateMoney,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _costPriceController,
                label: 'Cost price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? null
                        : _validateMoney(value),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _stockController,
                label: 'Stock quantity',
                keyboardType: TextInputType.number,
                validator: _validateInteger,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _lowStockController,
                label: 'Low stock alert quantity',
                keyboardType: TextInputType.number,
                validator: _validateInteger,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _skuController,
                label: 'SKU',
              ),
              const SizedBox(height: 14),
              _field(
                controller: _barcodeController,
                label: 'Barcode',
              ),
              const SizedBox(height: 14),
              _field(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}
