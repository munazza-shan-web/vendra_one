
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/sales_repository.dart';
import 'checkout_screen.dart';
import 'sale_details_screen.dart';

String _money(int minor) => 'Rs ${(minor / 100).toStringAsFixed(2)}';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(salesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [
          IconButton(
            tooltip: 'New sale',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CheckoutScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_shopping_cart),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: repository.watchSales(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load sales.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sales = snapshot.data!;

          if (sales.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 56),
                  SizedBox(height: 12),
                  Text(
                    'No sales yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text('Create your first sale to get started.'),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sales history',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text('${sales.length} records'),
                ],
              ),
              const SizedBox(height: 12),
              for (final sale in sales)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.receipt_long),
                    ),
                    title: Text(
                      sale.saleNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.createdAt.toLocal().toString().substring(0, 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sale.status.replaceAll('_', ' ')} • '
                            '${sale.paymentStatus.replaceAll('_', ' ')}',
                            style: TextStyle(
                              color: sale.status == 'cancelled'
                                  ? Colors.red
                                  : sale.paymentStatus == 'paid'
                                      ? Colors.green
                                      : Colors.orange.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Text(
                      _money(sale.totalMinor),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SaleDetailsScreen(
                            saleId: sale.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CheckoutScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New sale'),
      ),
    );
  }
}
