
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';
import '../local/database/database_provider.dart';

class CustomerRepository {
  CustomerRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<String> addCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Customer name is required.');
    }

    final id = _uuid.v4();

    await _database.into(_database.customers).insert(
      CustomersCompanion.insert(
        id: id,
        name: cleanName,
        phone: Value(_clean(phone)),
        email: Value(_clean(email)),
        address: Value(_clean(address)),
        notes: Value(_clean(notes)),
      ),
    );

    return id;
  }

  Future<List<Customer>> getAllCustomers() {
    return (_database.select(_database.customers)
          ..where((row) => row.isActive.equals(true))
          ..orderBy([(row) => OrderingTerm.asc(row.name)]))
        .get();
  }

  Stream<List<Customer>> watchCustomers() {
    return (_database.select(_database.customers)
          ..where((row) => row.isActive.equals(true))
          ..orderBy([(row) => OrderingTerm.asc(row.name)]))
        .watch();
  }

  Future<List<Customer>> searchCustomers(String query) {
    final term = query.trim();

    if (term.isEmpty) return getAllCustomers();

    return (_database.select(_database.customers)
          ..where(
            (row) =>
                row.isActive.equals(true) &
                (row.name.contains(term) |
                    row.phone.contains(term) |
                    row.email.contains(term)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.name)]))
        .get();
  }

  Future<Customer?> getCustomerById(String id) {
    return (_database.select(_database.customers)
          ..where(
            (row) =>
                row.id.equals(id) & row.isActive.equals(true),
          ))
        .getSingleOrNull();
  }

  Future<void> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Customer name is required.');
    }

    final updated = await (_database.update(_database.customers)
          ..where(
            (row) =>
                row.id.equals(id) & row.isActive.equals(true),
          ))
        .write(
      CustomersCompanion(
        name: Value(cleanName),
        phone: Value(_clean(phone)),
        email: Value(_clean(email)),
        address: Value(_clean(address)),
        notes: Value(_clean(notes)),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (updated == 0) {
      throw StateError('Customer not found or inactive.');
    }
  }

  Future<void> deactivateCustomer(String id) async {
    await (_database.update(_database.customers)
          ..where((row) => row.id.equals(id)))
        .write(
      CustomersCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Outstanding = original total - received payments
  /// - value of returned goods + cash refunds already paid.
  ///
  /// Returning an unpaid item reduces the customer's debt.
  /// Refunding money already received does not create a new debt.
  Future<int> getOutstandingBalance(String customerId) async {
    final customerSales = await (_database.select(_database.sales)
          ..where((row) => row.customerId.equals(customerId)))
        .get();

    var balance = 0;

    for (final sale in customerSales) {
      if (sale.status == 'cancelled') continue;

      final refunds = await (_database.select(_database.refunds)
            ..where((row) => row.saleId.equals(sale.id)))
          .get();

      final refundIds = refunds.map((row) => row.id).toList();

      var returnedGoodsValue = 0;

      if (refundIds.isNotEmpty) {
        final refundItems = await (_database.select(_database.refundItems)
              ..where((row) => row.refundId.isIn(refundIds)))
            .get();

        returnedGoodsValue = refundItems.fold<int>(
          0,
          (total, item) => total + item.amountMinor,
        );
      }

      final cashRefunded = refunds.fold<int>(
        0,
        (total, refund) => total + refund.amountMinor,
      );

      final saleBalance = sale.totalMinor -
          sale.paidMinor -
          returnedGoodsValue +
          cashRefunded;

      balance += saleBalance > 0 ? saleBalance : 0;
    }

    return balance;
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(appDatabaseProvider));
});
