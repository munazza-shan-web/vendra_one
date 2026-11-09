
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/sales_repository.dart';

String _money(int minor) => 'Rs ${(minor / 100).toStringAsFixed(2)}';

class SaleDetailsScreen extends ConsumerStatefulWidget {
  const SaleDetailsScreen({
    required this.saleId,
    super.key,
  });

  final String saleId;

  @override
  ConsumerState<SaleDetailsScreen> createState() =>
      _SaleDetailsScreenState();
}

class _SaleDetailsScreenState extends ConsumerState<SaleDetailsScreen> {
  Future<SaleDetails?>? _detailsFuture;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    _detailsFuture =
        ref.read(salesRepositoryProvider).getSaleDetails(widget.saleId);
  }

  Future<void> _refresh() async {
    setState(_loadDetails);
    await _detailsFuture;
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _collectPayment(SaleDetails details) async {
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    var method = 'cash';

    final outstanding = await ref
        .read(salesRepositoryProvider)
        .getOutstandingForSale(details.sale);

    if (!mounted) {
      amountController.dispose();
      referenceController.dispose();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Collect payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Outstanding: ${_money(outstanding)}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount received (Rs)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: method,
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
                          setDialogState(() => method = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Reference (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save payment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final amount = double.tryParse(amountController.text.trim());

      if (amount == null || amount <= 0) {
        _message('Enter a valid payment amount.');
      } else {
        await _runAction(() async {
          await ref.read(salesRepositoryProvider).recordPayment(
                saleId: widget.saleId,
                amountMinor: (amount * 100).round(),
                method: method,
                reference: referenceController.text,
              );
        }, 'Payment recorded.');
      }
    }

    amountController.dispose();
    referenceController.dispose();
  }

  Future<void> _cancelSale() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel sale?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep sale'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cancel sale'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _runAction(() async {
        await ref.read(salesRepositoryProvider).cancelSale(
              saleId: widget.saleId,
              reason: reasonController.text,
            );
      }, 'Sale cancelled and stock restored.');
    }

    reasonController.dispose();
  }

  Future<void> _returnItem(SaleDetails details) async {
    final repository = ref.read(salesRepositoryProvider);

    final returnedQuantities =
        await repository.getReturnedQuantities(widget.saleId);

    if (!mounted) return;

    final returnableItems = details.items.where((item) {
      final alreadyReturned = returnedQuantities[item.id] ?? 0;
      return item.quantity - alreadyReturned > 0;
    }).toList();

    if (returnableItems.isEmpty) {
      _message('There are no remaining items available to return.');
      return;
    }

    final quantityController = TextEditingController(text: '1');
    final reasonController = TextEditingController();

    String? selectedItemId = returnableItems.first.id;
    var method = 'cash';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedItem = returnableItems.firstWhere(
              (item) => item.id == selectedItemId,
            );

            final alreadyReturned =
                returnedQuantities[selectedItem.id] ?? 0;

            final remainingQuantity =
                selectedItem.quantity - alreadyReturned;

            return AlertDialog(
              title: const Text('Return item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedItemId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sale item',
                        border: OutlineInputBorder(),
                      ),
                      items: returnableItems.map((item) {
                        final returned =
                            returnedQuantities[item.id] ?? 0;
                        final remaining = item.quantity - returned;

                        return DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.productName} ($remaining remaining)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedItemId = value;
                            quantityController.text = '1';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity to return',
                        helperText:
                            'Maximum returnable quantity: $remainingQuantity',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'Refund method',
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
                          setDialogState(() => method = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sold: ${selectedItem.quantity} | '
                      'Already returned: $alreadyReturned | '
                      'Remaining: $remainingQuantity',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Back'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Process return'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final quantity = int.tryParse(quantityController.text.trim());

      if (selectedItemId == null || quantity == null || quantity <= 0) {
        _message('Enter a valid return quantity.');
      } else {
        await _runAction(() async {
          await repository.refundSale(
            saleId: widget.saleId,
            items: [
              RefundLineInput(
                saleItemId: selectedItemId!,
                quantity: quantity,
              ),
            ],
            refundMethod: method,
            reason: reasonController.text,
          );
        }, 'Return processed and stock restored.');
      }
    }

    quantityController.dispose();
    reasonController.dispose();
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_processing) return;

    setState(() => _processing = true);

    try {
      await action();
      if (!mounted) return;

      _message(successMessage);
      await _refresh();
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale details'),
      ),
      body: FutureBuilder<SaleDetails?>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load sale details.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final details = snapshot.data;

          if (details == null) {
            return const Center(child: Text('Sale not found.'));
          }

          final sale = details.sale;

          return FutureBuilder<int>(
            future: ref
                .read(salesRepositoryProvider)
                .getOutstandingForSale(sale),
            builder: (context, balanceSnapshot) {
              final outstanding = balanceSnapshot.data ?? 0;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.saleNumber,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            sale.createdAt
                                .toLocal()
                                .toString()
                                .substring(0, 16),
                          ),
                          const SizedBox(height: 12),
                          _infoRow(
                            'Status',
                            sale.status.replaceAll('_', ' '),
                          ),
                          _infoRow(
                            'Payment status',
                            sale.paymentStatus.replaceAll('_', ' '),
                          ),
                          _infoRow(
                            'Subtotal',
                            _money(sale.subtotalMinor),
                          ),
                          _infoRow(
                            'Discount',
                            _money(sale.discountMinor),
                          ),
                          _infoRow('Tax', _money(sale.taxMinor)),
                          const Divider(),
                          _infoRow('Total', _money(sale.totalMinor)),
                          _infoRow('Received', _money(sale.paidMinor)),
                          _infoRow(
                            'Outstanding',
                            _money(outstanding),
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Items',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...details.items.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.productName),
                        subtitle: Text(
                          '${item.quantity} × ${_money(item.unitPriceMinor)}',
                        ),
                        trailing: Text(
                          _money(item.totalMinor),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Payments',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (details.payments.isEmpty)
                    const Text('No payments recorded.')
                  else
                    ...details.payments.map(
                      (payment) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: Text(_money(payment.amountMinor)),
                          subtitle: Text(
                            '${payment.method.replaceAll('_', ' ')} • '
                            '${payment.createdAt.toLocal().toString().substring(0, 16)}',
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_processing)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (sale.status != 'cancelled' && outstanding > 0)
                      FilledButton.icon(
                        onPressed: () => _collectPayment(details),
                        icon: const Icon(Icons.payments),
                        label: const Text('Collect payment'),
                      ),
                    if (sale.status != 'cancelled' &&
                        sale.status != 'refunded')
                      OutlinedButton.icon(
                        onPressed: () => _returnItem(details),
                        icon: const Icon(Icons.assignment_return),
                        label: const Text('Return item'),
                      ),
                    if (sale.status == 'completed' && sale.paidMinor == 0)
                      TextButton.icon(
                        onPressed: _cancelSale,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel unpaid sale'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
