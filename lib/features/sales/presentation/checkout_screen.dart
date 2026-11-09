
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../scanner/presentation/barcode_scanner_screen.dart';

String _money(int minor) => 'Rs ${(minor / 100).toStringAsFixed(2)}';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _taxController = TextEditingController(text: '0');
  final _paymentController = TextEditingController();

  final Map<String, int> _cart = {};

  late Future<List<Product>> _productsFuture;

  String _search = '';
  String? _customerId;
  String _paymentMethod = 'cash';
  bool _saving = false;
  bool _paymentManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _productsFuture = ref.read(productRepositoryProvider).getAllProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  int _parseMinor(String value) {
    final amount = double.tryParse(value.trim()) ?? 0;
    return (amount * 100).round();
  }

  int _parseBasisPoints(String value) {
    final percentage = double.tryParse(value.trim()) ?? 0;
    return (percentage * 100).round();
  }

  int _calculateTotal(int subtotal) {
    final discount = _parseMinor(_discountController.text).clamp(0, subtotal);
    final taxRate = _parseBasisPoints(_taxController.text).clamp(0, 10000);
    final taxable = subtotal - discount;
    final tax = (taxable * taxRate + 5000) ~/ 10000;
    return taxable + tax;
  }

  void _updateDefaultPayment(int subtotal) {
    if (_paymentManuallyEdited) return;

    final total = _calculateTotal(subtotal);
    _paymentController.text = (total / 100).toStringAsFixed(2);
  }

  Future<void> _addCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer name *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final id = await ref.read(customerRepositoryProvider).addCustomer(
              name: nameController.text,
              phone: phoneController.text,
            );

        if (mounted) {
          setState(() => _customerId = id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer added.')),
          );
        }
      } catch (error) {
        if (mounted) _showError(error);
      }
    }

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.isEmpty) return;

    final products = await ref.read(productRepositoryProvider).getAllProducts();
    if (!mounted) return;

    Product? match;
    for (final product in products) {
      if (product.barcode?.trim() == barcode) {
        match = product;
        break;
      }
    }

    _searchController.text = barcode;
    if (match == null) {
      setState(() => _search = barcode);
      _showMessage('No product is registered with barcode $barcode.');
      return;
    }

    if (match.stockQuantity <= 0) {
      _showMessage('${match.name} is out of stock.');
      return;
    }

    setState(() {
      _search = '';
      _searchController.clear();
      final currentQuantity = _cart[match!.id] ?? 0;
      if (currentQuantity < match.stockQuantity) {
        _cart[match.id] = currentQuantity + 1;
      }
    });
    _showMessage('${match.name} added to cart.');
  }

  Future<void> _checkout(List<Product> products) async {
    if (_cart.isEmpty) {
      _showMessage('Add at least one product.');
      return;
    }

    final discount = _parseMinor(_discountController.text);
    final taxRate = _parseBasisPoints(_taxController.text);

    if (discount < 0 || taxRate < 0) {
      _showMessage('Discount and tax cannot be negative.');
      return;
    }

    final productMap = {
      for (final product in products) product.id: product,
    };

    var subtotal = 0;

    for (final entry in _cart.entries) {
      final product = productMap[entry.key];

      if (product == null) {
        _showMessage('A product is no longer available.');
        return;
      }

      subtotal += product.sellingPriceMinor * entry.value;
    }

    if (discount > subtotal) {
      _showMessage('Discount cannot exceed the subtotal.');
      return;
    }

    final taxable = subtotal - discount;
    final tax = (taxable * taxRate + 5000) ~/ 10000;
    final total = taxable + tax;

    final paymentText = _paymentController.text.trim();
    final paymentMinor = paymentText.isEmpty ? 0 : _parseMinor(paymentText);

    if (paymentMinor < 0 || paymentMinor > total) {
      _showMessage('Enter a valid payment amount.');
      return;
    }

    if (paymentMinor < total && _customerId == null) {
      _showMessage('Select a customer for credit or partial payment.');
      return;
    }

    setState(() => _saving = true);

    try {
      final saleItems = _cart.entries
          .map(
            (entry) => SaleCartItem(
              productId: entry.key,
              quantity: entry.value,
            ),
          )
          .toList();

      final payments = paymentMinor > 0
          ? [
              SalePaymentInput(
                amountMinor: paymentMinor,
                method: _paymentMethod,
              ),
            ]
          : <SalePaymentInput>[];

      final saleId = await ref.read(salesRepositoryProvider).createSale(
            items: saleItems,
            payments: payments,
            customerId: _customerId,
            discountMinor: discount,
            taxRateBasisPoints: taxRate,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale created successfully: $saleId')),
      );

      Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(Object error) {
    _showMessage(error.toString().replaceFirst('Exception: ', ''));
  }

  @override
  Widget build(BuildContext context) {
    final customerRepository = ref.watch(customerRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New sale'),
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load products.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;

          final visibleProducts = products.where((product) {
            final query = _search.toLowerCase();
            return product.name.toLowerCase().contains(query) ||
                (product.sku?.toLowerCase().contains(query) ?? false) ||
                (product.barcode?.toLowerCase().contains(query) ?? false);
          }).toList();

          final productMap = {
            for (final product in products) product.id: product,
          };

          var subtotal = 0;

          for (final entry in _cart.entries) {
            final product = productMap[entry.key];
            if (product != null) {
              subtotal += product.sellingPriceMinor * entry.value;
            }
          }

          final discount = _parseMinor(_discountController.text);
          final safeDiscount = discount.clamp(0, subtotal);
          final taxable = subtotal - safeDiscount;
          final taxRate = _parseBasisPoints(_taxController.text).clamp(0, 10000);
          final tax = (taxable * taxRate + 5000) ~/ 10000;
          final total = taxable + tax;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    hintText: 'Search products by name, SKU or barcode',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Scan barcode',
                          onPressed: _scanBarcode,
                          icon: const Icon(Icons.qr_code_scanner),
                        ),
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: visibleProducts.isEmpty
                    ? const Center(child: Text('No products found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: visibleProducts.length,
                        itemBuilder: (context, index) {
                          final product = visibleProducts[index];
                          final quantity = _cart[product.id] ?? 0;
                          final outOfStock = product.stockQuantity <= 0;

                          return Card(
                            child: ListTile(
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${_money(product.sellingPriceMinor)}'
                                '  •  Stock: ${product.stockQuantity}',
                              ),
                              trailing: quantity > 0
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              if (quantity <= 1) {
                                                _cart.remove(product.id);
                                              } else {
                                                _cart[product.id] = quantity - 1;
                                              }
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: quantity >=
                                                  product.stockQuantity
                                              ? null
                                              : () => setState(
                                                    () => _cart[product.id] =
                                                        quantity + 1,
                                                  ),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    )
                                  : IconButton(
                                      onPressed: outOfStock
                                          ? null
                                          : () => setState(
                                                () => _cart[product.id] = 1,
                                              ),
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: Colors.blue,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Items in cart')),
                          Text(
                            '${_cart.values.fold<int>(0, (a, b) => a + b)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Expanded(child: Text('Subtotal')),
                          Text(_money(subtotal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Expanded(child: Text('Total')),
                          Text(
                            _money(total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _cart.isEmpty || _saving
                            ? null
                            : () => _showCheckoutOptions(
                                  customerRepository,
                                  subtotal,
                                ),
                        icon: const Icon(Icons.payment),
                        label: Text(
                          _saving
                              ? 'Processing...'
                              : 'Checkout • ${_money(total)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCheckoutOptions(
    CustomerRepository customerRepository,
    int subtotal,
  ) async {
    _paymentManuallyEdited = false;
    _updateDefaultPayment(subtotal);

    final customers = await customerRepository.getAllCustomers();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final discount = _parseMinor(_discountController.text);
            final taxRate = _parseBasisPoints(_taxController.text);
            final safeDiscount = discount.clamp(0, subtotal);
            final taxable = subtotal - safeDiscount;
            final safeTaxRate = taxRate.clamp(0, 10000);
            final tax = (taxable * safeTaxRate + 5000) ~/ 10000;
            final currentTotal = taxable + tax;

            void updatePricing() {
              if (!_paymentManuallyEdited) {
                _updateDefaultPayment(subtotal);
              }
              setSheetState(() {});
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Payment details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Subtotal: ${_money(subtotal)}'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Discount (Rs)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => updatePricing(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _taxController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tax rate (%)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => updatePricing(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Tax')),
                              Text(_money(tax)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Final total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _money(currentTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _customerId,
                      decoration: const InputDecoration(
                        labelText: 'Customer (required for credit)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Walk-in customer'),
                        ),
                        ...customers.map(
                          (customer) => DropdownMenuItem<String>(
                            value: customer.id,
                            child: Text(customer.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _customerId = value);
                        setSheetState(() {});
                      },
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _addCustomer();
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add customer'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _paymentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount received (Rs)',
                        helperText: 'Enter 0 for a fully unpaid credit sale.',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        _paymentManuallyEdited = true;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('Cash'),
                        ),
                        DropdownMenuItem(
                          value: 'card',
                          child: Text('Card'),
                        ),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Bank transfer'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _paymentMethod = value);
                          setSheetState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              _checkoutFromCurrentProducts();
                            },
                      child: const Text('Complete sale'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkoutFromCurrentProducts() async {
    final products =
        await ref.read(productRepositoryProvider).getAllProducts();
    if (!mounted) return;
    await _checkout(products);
  }
}
