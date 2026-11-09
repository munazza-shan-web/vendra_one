import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database/app_database.dart';
import '../local/database/database_provider.dart';

class ReportSummary {
  const ReportSummary({
    required this.salesCount,
    required this.grossSalesMinor,
    required this.returnsMinor,
    required this.netSalesMinor,
    required this.collectedMinor,
    required this.receivablesMinor,
    required this.costOfGoodsMinor,
    required this.grossProfitMinor,
    required this.expensesMinor,
    required this.netProfitMinor,
    required this.purchasesMinor,
  });

  final int salesCount;
  final int grossSalesMinor;
  final int returnsMinor;
  final int netSalesMinor;
  final int collectedMinor;
  final int receivablesMinor;
  final int costOfGoodsMinor;
  final int grossProfitMinor;
  final int expensesMinor;
  final int netProfitMinor;
  final int purchasesMinor;
}

class ReportsRepository {
  ReportsRepository(this._db);

  final AppDatabase _db;

  Future<ReportSummary> getSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final startValue = Variable.withInt(start.millisecondsSinceEpoch);
    final endValue = Variable.withInt(end.millisecondsSinceEpoch);

    final sales = await _db.customSelect(
      'SELECT COUNT(*) AS sales_count, '
      'COALESCE(SUM(total_minor), 0) AS gross_sales, '
      'COALESCE(SUM(paid_minor), 0) AS collected, '
      'COALESCE(SUM(total_minor - paid_minor), 0) AS receivables '
      'FROM sales WHERE status != ? AND created_at >= ? AND created_at < ?',
      variables: [
        Variable.withString('cancelled'),
        startValue,
        endValue,
      ],
    ).getSingle();

    final returns = await _db.customSelect(
      'SELECT COALESCE(SUM(ri.amount_minor), 0) AS returned_value '
      'FROM refund_items ri '
      'INNER JOIN refunds r ON r.id = ri.refund_id '
      'INNER JOIN sales s ON s.id = r.sale_id '
      'WHERE s.created_at >= ? AND s.created_at < ?',
      variables: [startValue, endValue],
    ).getSingle();

    final soldCost = await _db.customSelect(
      'SELECT COALESCE(SUM(si.unit_cost_minor * si.quantity), 0) AS cost '
      'FROM sale_items si INNER JOIN sales s ON s.id = si.sale_id '
      'WHERE s.status != ? AND s.created_at >= ? AND s.created_at < ?',
      variables: [
        Variable.withString('cancelled'),
        startValue,
        endValue,
      ],
    ).getSingle();

    final returnedCost = await _db.customSelect(
      'SELECT COALESCE(SUM(ri.quantity * si.unit_cost_minor), 0) AS cost '
      'FROM refund_items ri '
      'INNER JOIN refunds r ON r.id = ri.refund_id '
      'INNER JOIN sale_items si ON si.id = ri.sale_item_id '
      'INNER JOIN sales s ON s.id = r.sale_id '
      'WHERE s.created_at >= ? AND s.created_at < ?',
      variables: [startValue, endValue],
    ).getSingle();

    final expenses = await _db.customSelect(
      'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses '
      'WHERE expense_date >= ? AND expense_date < ?',
      variables: [startValue, endValue],
    ).getSingle();

    final purchases = await _db.customSelect(
      'SELECT COALESCE(SUM(total_minor), 0) AS total FROM purchases '
      'WHERE created_at >= ? AND created_at < ?',
      variables: [startValue, endValue],
    ).getSingle();

    final grossSales = sales.read<int>('gross_sales');
    final returnedValue = returns.read<int>('returned_value');
    final netSales = grossSales - returnedValue;
    final cogs = soldCost.read<int>('cost') - returnedCost.read<int>('cost');
    final grossProfit = netSales - cogs;
    final expenseTotal = expenses.read<int>('total');

    return ReportSummary(
      salesCount: sales.read<int>('sales_count'),
      grossSalesMinor: grossSales,
      returnsMinor: returnedValue,
      netSalesMinor: netSales,
      collectedMinor: sales.read<int>('collected'),
      receivablesMinor: sales.read<int>('receivables'),
      costOfGoodsMinor: cogs,
      grossProfitMinor: grossProfit,
      expensesMinor: expenseTotal,
      netProfitMinor: grossProfit - expenseTotal,
      purchasesMinor: purchases.read<int>('total'),
    );
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(appDatabaseProvider));
});
