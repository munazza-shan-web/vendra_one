import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';
import '../local/database/database_provider.dart';

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.amountMinor,
    required this.paymentMethod,
    this.reference,
    this.notes,
    required this.expenseDate,
  });

  final String id;
  final String title;
  final String category;
  final int amountMinor;
  final String paymentMethod;
  final String? reference;
  final String? notes;
  final DateTime expenseDate;

  factory ExpenseRecord.fromRow(Map<String, Object?> row) {
    return ExpenseRecord(
      id: row['id'] as String,
      title: row['title'] as String,
      category: row['category'] as String,
      amountMinor: row['amount_minor'] as int,
      paymentMethod: row['payment_method'] as String,
      reference: row['reference'] as String?,
      notes: row['notes'] as String?,
      expenseDate: DateTime.fromMillisecondsSinceEpoch(row['expense_date'] as int),
    );
  }
}

class ExpenseRepository {
  ExpenseRepository(this._db);

  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  static const categories = [
    'Rent',
    'Utilities',
    'Salaries',
    'Transport',
    'Packaging',
    'Maintenance',
    'Marketing',
    'Supplies',
    'Other',
  ];

  static const paymentMethods = [
    'cash',
    'card',
    'bank_transfer',
    'other',
  ];

  Stream<List<ExpenseRecord>> watchExpenses() {
    return _db.customSelect(
      'SELECT * FROM expenses ORDER BY expense_date DESC, created_at DESC',
    ).watch().map(
      (rows) => rows.map((row) => ExpenseRecord.fromRow(row.data)).toList(),
    );
  }

  Future<void> addExpense({
    required String title,
    required String category,
    required int amountMinor,
    required String paymentMethod,
    required DateTime expenseDate,
    String? reference,
    String? notes,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Expense title is required.');
    if (amountMinor <= 0) throw ArgumentError('Expense amount must be greater than zero.');
    if (!categories.contains(category)) throw ArgumentError('Select a valid expense category.');
    if (!paymentMethods.contains(paymentMethod)) throw ArgumentError('Select a valid payment method.');

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT INTO expenses '
      '(id, title, category, amount_minor, payment_method, reference, notes, expense_date, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(_uuid.v4()),
        Variable.withString(title.trim()),
        Variable.withString(category),
        Variable.withInt(amountMinor),
        Variable.withString(paymentMethod),
        Variable.withString(_clean(reference) ?? ''),
        Variable.withString(_clean(notes) ?? ''),
        Variable.withInt(expenseDate.millisecondsSinceEpoch),
        Variable.withInt(now),
      ],
    );
  }

  Future<void> deleteExpense(String id) async {
    await _db.customStatement(
      'DELETE FROM expenses WHERE id = ?',
      [Variable.withString(id)],
    );
  }

  Future<int> getTotalForPeriod(DateTime start, DateTime end) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM expenses '
      'WHERE expense_date >= ? AND expense_date < ?',
      variables: [
        Variable.withInt(start.millisecondsSinceEpoch),
        Variable.withInt(end.millisecondsSinceEpoch),
      ],
    ).getSingle();
    return row.read<int>('total');
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(appDatabaseProvider));
});
