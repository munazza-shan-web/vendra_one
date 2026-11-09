import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/reports_repository.dart';

String _money(int minor) => 'Rs ' + (minor / 100).toStringAsFixed(2);

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = 'This month';
  Future<ReportSummary>? _summaryFuture;

  DateTimeRange _dateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case 'Today':
        return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
      case '7 days':
        return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today.add(const Duration(days: 1)));
      case '30 days':
        return DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today.add(const Duration(days: 1)));
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        );
    }
  }

  Future<ReportSummary> _loadSummary() {
    final range = _dateRange();
    return ref.read(reportsRepositoryProvider).getSummary(
      start: range.start,
      end: range.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    _summaryFuture ??= _loadSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: () => setState(() => _summaryFuture = _loadSummary()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<ReportSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to calculate reports.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final report = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Today', label: Text('Today')),
                  ButtonSegment(value: '7 days', label: Text('7 days')),
                  ButtonSegment(value: '30 days', label: Text('30 days')),
                  ButtonSegment(value: 'This month', label: Text('Month')),
                ],
                selected: {_period},
                onSelectionChanged: (selection) {
                  setState(() {
                    _period = selection.first;
                    _summaryFuture = _loadSummary();
                  });
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Sales overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _ReportMetric(
                    title: 'Net sales',
                    value: _money(report.netSalesMinor),
                    icon: Icons.trending_up,
                  ),
                  _ReportMetric(
                    title: 'Transactions',
                    value: report.salesCount.toString(),
                    icon: Icons.receipt_long_outlined,
                  ),
                  _ReportMetric(
                    title: 'Collected',
                    value: _money(report.collectedMinor),
                    icon: Icons.payments_outlined,
                  ),
                  _ReportMetric(
                    title: 'Receivables',
                    value: _money(report.receivablesMinor),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Profit and costs',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ReportRow(label: 'Gross sales', value: _money(report.grossSalesMinor)),
                      _ReportRow(label: 'Returns', value: '- ' + _money(report.returnsMinor)),
                      const Divider(height: 22),
                      _ReportRow(label: 'Net sales', value: _money(report.netSalesMinor), bold: true),
                      _ReportRow(label: 'Cost of goods sold', value: '- ' + _money(report.costOfGoodsMinor)),
                      const Divider(height: 22),
                      _ReportRow(label: 'Gross profit', value: _money(report.grossProfitMinor), bold: true),
                      _ReportRow(label: 'Operating expenses', value: '- ' + _money(report.expensesMinor)),
                      const Divider(height: 22),
                      _ReportRow(
                        label: 'Estimated net profit',
                        value: _money(report.netProfitMinor),
                        bold: true,
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Other business activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ReportRow(label: 'Purchases recorded', value: _money(report.purchasesMinor)),
                      const SizedBox(height: 8),
                      const Text(
                        'Purchases are shown separately from cost of goods sold. Net profit uses the cost snapshots saved on completed sales.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Reports use records saved on this device. Estimated net profit excludes taxes and any costs not entered in VendraOne.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize
        ? (value.startsWith('-')
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
