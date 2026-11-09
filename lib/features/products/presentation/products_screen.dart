
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../categories/presentation/categories_screen.dart';
import 'edit_product_sheet.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productRepository = ref.watch(productRepositoryProvider);
    final categoryRepository = ref.watch(categoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CategoriesScreen(),
                ),
              );
            },
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
          ),
          IconButton(
            onPressed: () => _showAddProduct(context),
            icon: const Icon(Icons.add),
            tooltip: 'Add product',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 48,
            child: StreamBuilder<List<Category>>(
              stream: categoryRepository.watchCategories(),
              builder: (context, snapshot) {
                final categories = snapshot.data ?? [];

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _categoryChip('All', null),
                    ...categories.map(
                      (category) => _categoryChip(
                        category.name,
                        category.id,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: productRepository.watchProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load products.'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final products = snapshot.data ?? [];

                final filteredProducts = products.where((product) {
                  final query =
                      _searchController.text.trim().toLowerCase();

                  final matchesSearch = query.isEmpty ||
                      product.name.toLowerCase().contains(query) ||
                      (product.sku?.toLowerCase().contains(query) ?? false) ||
                      (product.barcode?.contains(query) ?? false);

                  final matchesCategory = _selectedCategoryId == null ||
                      product.categoryId == _selectedCategoryId;

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredProducts.isEmpty) {
                  return _emptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];

                    return _ProductCard(
                      product: product,
                      onTap: () => _showProductDetails(product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String? categoryId) {
    final selected = _selectedCategoryId == categoryId;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedCategoryId = categoryId;
          });
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Add a product or change your search.'),
          ],
        ),
      ),
    );
  }

  void _showAddProduct(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddProductSheet(),
    );
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Selling price: ${_formatPrice(product.sellingPriceMinor)}',
              ),
              Text(
                'Cost price: ${_formatPrice(product.costPriceMinor)}',
              ),
              Text('Stock: ${product.stockQuantity}'),
              Text('SKU: ${product.sku ?? 'Not set'}'),
              Text('Barcode: ${product.barcode ?? 'Not set'}'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();

                    await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => EditProductSheet(
                        product: product,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Product'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();

                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Deactivate Product?'),
                        content: Text(
                          'Are you sure you want to deactivate "${product.name}"? '
                          'It will no longer appear among active products.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: const Text('Deactivate'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true || !mounted) return;

                    try {
                      await ref
                          .read(productRepositoryProvider)
                          .deactivateProduct(product.id);

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product deactivated successfully.'),
                        ),
                      );
                    } catch (error) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Could not deactivate product: $error'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Deactivate Product'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLowStock =
        product.stockQuantity <= product.lowStockThreshold;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.inventory_2_outlined),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Stock: ${product.stockQuantity}  •  ${product.sku ?? 'No SKU'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatPrice(product.sellingPriceMinor),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isLowStock)
              const Text(
                'Low stock',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AddProductSheet extends ConsumerStatefulWidget {
  const AddProductSheet({super.key});

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _lowStockController = TextEditingController(text: '5');
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();

  String? _categoryId;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final sellingPrice =
        _toMinorUnits(_sellingPriceController.text);

    final costPrice = _costPriceController.text.trim().isEmpty
        ? 0
        : _toMinorUnits(_costPriceController.text);

    if (sellingPrice == null || costPrice == null) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(productRepositoryProvider).addProduct(
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
          );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product added successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save product: $error'),
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
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Product',
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
                stream: categoryRepository.watchCategories(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];

                  return DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        )
                        .toList(),
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
                label: 'Cost price (optional)',
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
                label: 'Opening stock',
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
                label: 'SKU (optional)',
              ),
              const SizedBox(height: 14),
              _field(
                controller: _barcodeController,
                label: 'Barcode (optional)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProduct,
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
                    _isSaving ? 'Saving...' : 'Save Product',
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}

String _formatPrice(int minorUnits) {
  return NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs ',
    decimalDigits: 2,
  ).format(minorUnits / 100);
}
