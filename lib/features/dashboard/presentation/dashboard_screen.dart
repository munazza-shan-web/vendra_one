import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/sales_repository.dart';

String _money(int minor) => 'Rs ' + (minor / 100).toStringAsFixed(2);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesRepository = ref.watch(salesRepositoryProvider);
    final productRepository = ref.watch(productRepositoryProvider);
    final currencyDate = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('VendraOne'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                DateFormat('EEE, d MMM').format(currencyDate),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Sale>>(
        stream: salesRepository.watchSales(),
        builder: (context, salesSnapshot) {
          if (salesSnapshot.hasError) {
            return const Center(child: Text('Unable to load dashboard data.'));
          }
          if (!salesSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allSales = salesSnapshot.data!;
          final now = DateTime.now();
          final todaySales = allSales.where((sale) {
            return sale.status != 'cancelled' &&
                sale.createdAt.year == now.year &&
                sale.createdAt.month == now.month &&
                sale.createdAt.day == now.day;
          }).toList();
          final todayTotal = todaySales.fold<int>(
            0,
            (total, sale) => total + sale.totalMinor,
          );
          final recentSales = allSales
              .where((sale) => sale.status != 'cancelled')
              .take(5)
              .toList();

          return StreamBuilder<List<Product>>(
            stream: productRepository.watchProducts(),
            builder: (context, productSnapshot) {
              if (productSnapshot.hasError) {
                return const Center(child: Text('Unable to load inventory data.'));
              }
              if (!productSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = productSnapshot.data!;
              final lowStock = products
                  .where((product) =>
                      product.stockQuantity <= product.lowStockThreshold)
                  .toList();

              return RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    salesRepository.getAllSales(),
                    productRepository.getAllProducts(),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Text(
                      'Business overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here is how your store is doing today.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 18),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.55,
                      children: [
                        _MetricCard(
                          title: "Today's sales",
                          value: _money(todayTotal),
                          subtitle: todaySales.length.toString() + ' transactions',
                          icon: Icons.payments_outlined,
                          color: Colors.green,
                        ),
                        _MetricCard(
                          title: 'Sales today',
                          value: todaySales.length.toString(),
                          subtitle: 'Completed transactions',
                          icon: Icons.receipt_long_outlined,
                          color: Colors.blue,
                        ),
                        _MetricCard(
                          title: 'Products',
                          value: products.length.toString(),
                          subtitle: 'Active products',
                          icon: Icons.inventory_2_outlined,
                          color: Colors.deepPurple,
                        ),
                        _MetricCard(
                          title: 'Low stock',
                          value: lowStock.length.toString(),
                          subtitle: 'At or below reorder level',
                          icon: Icons.warning_amber_outlined,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Low stock alerts',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Text(
                          lowStock.length.toString(),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (lowStock.isEmpty)
                      const _InfoPanel(
                        icon: Icons.check_circle_outline,
                        message: 'All products are above their low-stock levels.',
                      )
                    else
                      ...lowStock.take(4).map(
                            (product) => Card(
                              child: ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.orange,
                                ),
                                title: Text(product.name),
                                subtitle: Text(
                                  'Stock: ' + product.stockQuantity.toString() +
                                      '  •  Alert at: ' +
                                      product.lowStockThreshold.toString(),
                                ),
                                trailing: const Icon(Icons.warning_amber_rounded),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Text(
                      'Recent sales',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (recentSales.isEmpty)
                      const _InfoPanel(
                        icon: Icons.receipt_long_outlined,
                        message: 'Your sales will appear here after the first checkout.',
                      )
                    else
                      ...recentSales.map(
                        (sale) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.receipt_outlined),
                            ),
                            title: Text(sale.saleNumber),
                            subtitle: Text(
                              DateFormat('d MMM, h:mm a').format(sale.createdAt) +
                                  '  •  ' +
                                  sale.paymentStatus.replaceAll('_', ' '),
                            ),
                            trailing: Text(
                              _money(sale.totalMinor),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
