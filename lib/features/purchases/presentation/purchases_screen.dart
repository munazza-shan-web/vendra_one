import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/supplier_purchase_repository.dart';

String _money(int minor) => 'Rs ' + (minor / 100).toStringAsFixed(2);

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  Future<void> _addSupplier(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final address = TextEditingController();
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add supplier'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Supplier name *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Supplier name is required'
                        : null,
                  ),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
                  TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref.read(supplierPurchaseRepositoryProvider).addSupplier(
                  name: name.text,
                  phone: phone.text,
                  email: email.text,
                  address: address.text,
                  notes: notes.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Supplier added')),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not add supplier: $error')),
                  );
                }
              }
            },
            child: const Text('Save supplier'),
          ),
        ],
      ),
    );

    name.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    notes.dispose();
  }

  Future<void> _newPurchase(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(supplierPurchaseRepositoryProvider);
    final productRepo = ref.read(productRepositoryProvider);
    final suppliers = await repo.watchSuppliers().first;
    final products = await productRepo.getAllProducts();
    if (!context.mounted) return;

    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a supplier before recording a purchase.')),
      );
      return;
    }
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add products before recording a purchase.')),
      );
      return;
    }

    final quantityController = TextEditingController(text: '1');
    final costController = TextEditingController();
    final discountController = TextEditingController(text: '0');
    final paidController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    final lines = <PurchaseLineInput>[];
    String? supplierId = suppliers.first.id;
    String? productId = products.first.id;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedProduct = products.firstWhere((p) => p.id == productId);
          final subtotal = lines.fold<int>(
            0,
            (sum, line) => sum + line.quantity * line.unitCostMinor,
          );
          final discount = ((double.tryParse(discountController.text) ?? 0) * 100).round();
          final total = subtotal - discount;

          return AlertDialog(
            title: const Text('Record purchase'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: supplierId,
                      decoration: const InputDecoration(labelText: 'Supplier'),
                      items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (value) => setDialogState(() => supplierId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: productId,
                      decoration: const InputDecoration(labelText: 'Product'),
                      items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (value) => setDialogState(() {
                        productId = value;
                        final p = products.firstWhere((item) => item.id == value);
                        costController.text = (p.costPriceMinor / 100).toStringAsFixed(2);
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quantity'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Unit cost (Rs)'),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          final quantity = int.tryParse(quantityController.text.trim());
                          final cost = double.tryParse(costController.text.trim());
                          if (quantity == null || quantity <= 0 || cost == null || !cost.isFinite || cost < 0 || productId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid quantity and unit cost.')),
                            );
                            return;
                          }
                          if (lines.any((line) => line.productId == productId)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('This product is already in the purchase.')),
                            );
                            return;
                          }
                          setDialogState(() {
                            lines.add(PurchaseLineInput(
                              productId: productId!,
                              quantity: quantity,
                              unitCostMinor: (cost * 100).round(),
                            ));
                            quantityController.text = '1';
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                    ),
                    if (lines.isNotEmpty) ...[
                      const Divider(),
                      ...lines.map((line) {
                        final p = products.firstWhere((item) => item.id == line.productId);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name),
                          subtitle: Text('${line.quantity} × ${_money(line.unitCostMinor)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_money(line.quantity * line.unitCostMinor)),
                              IconButton(
                                tooltip: 'Remove item',
                                onPressed: () => setDialogState(() => lines.remove(line)),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const Divider(),
                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Discount (Rs)'),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    TextField(
                      controller: paidController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount paid now (Rs)'),
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text(_money(subtotal)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Purchase total'),
                        Text(_money(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (lines.isEmpty || supplierId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select a supplier and add at least one item.')),
                    );
                    return;
                  }
                  final discountValue = double.tryParse(discountController.text.trim()) ?? 0;
                  final paidValue = double.tryParse(paidController.text.trim()) ?? 0;
                  if (!discountValue.isFinite || !paidValue.isFinite || discountValue < 0 || paidValue < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Discount and payment must be valid non-negative amounts.')),
                    );
                    return;
                  }
                  try {
                    await repo.createPurchase(
                      supplierId: supplierId!,
                      items: List<PurchaseLineInput>.from(lines),
                      discountMinor: (discountValue * 100).round(),
                      paidMinor: (paidValue * 100).round(),
                      notes: notesController.text,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Purchase saved and stock updated.')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not save purchase: $error')),
                      );
                    }
                  }
                },
                child: const Text('Save purchase'),
              ),
            ],
          );
        },
      ),
    );

    quantityController.dispose();
    costController.dispose();
    discountController.dispose();
    paidController.dispose();
    notesController.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(supplierPurchaseRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          IconButton(
            tooltip: 'Add supplier',
            onPressed: () => _addSupplier(context, ref),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newPurchase(context, ref),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New purchase'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: StreamBuilder<List<SupplierRecord>>(
              stream: repository.watchSuppliers(),
              builder: (context, snapshot) {
                final suppliers = snapshot.data ?? [];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
                    title: const Text('Suppliers'),
                    subtitle: Text('${suppliers.length} active suppliers'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showSuppliers(context, suppliers, repository),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, Object?>>>(
              stream: repository.watchPurchases(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load purchases.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final purchases = snapshot.data!;
                if (purchases.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 60),
                          SizedBox(height: 12),
                          Text('No purchases recorded yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text('Record stock purchases from your suppliers. Received items will increase product inventory.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: purchases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final purchase = purchases[index];
                    final createdAt = DateTime.fromMillisecondsSinceEpoch(purchase['created_at'] as int);
                    final total = purchase['total_minor'] as int;
                    final paid = purchase['paid_minor'] as int;
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
                        title: Text(purchase['purchase_number'] as String),
                        subtitle: Text(
                          '${purchase['supplier_name']} • ${DateFormat('d MMM yyyy, h:mm a').format(createdAt)}\n'
                          '${(purchase['status'] as String).replaceAll('_', ' ')} • Paid ${_money(paid)}',
                        ),
                        isThreeLine: true,
                        trailing: Text(_money(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

  void _showSuppliers(
    BuildContext context,
    List<SupplierRecord> suppliers,
    SupplierPurchaseRepository repository,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Suppliers', style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: suppliers.isEmpty
                    ? const Center(child: Text('No suppliers added yet.'))
                    : ListView.builder(
                        itemCount: suppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = suppliers[index];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.store_outlined)),
                            title: Text(supplier.name),
                            subtitle: Text([
                              if (supplier.phone?.isNotEmpty == true) supplier.phone!,
                              if (supplier.email?.isNotEmpty == true) supplier.email!,
                            ].join(' • ')),
                            trailing: FutureBuilder<int>(
                              future: repository.getSupplierOutstanding(supplier.id),
                              builder: (context, snapshot) => Text(
                                _money(snapshot.data ?? 0),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
