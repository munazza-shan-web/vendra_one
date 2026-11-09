import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';
import '../local/database/database_provider.dart';

class SupplierRecord {
  const SupplierRecord({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;

  factory SupplierRecord.fromRow(Map<String, Object?> row) {
    return SupplierRecord(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String?,
      email: row['email'] as String?,
      address: row['address'] as String?,
      notes: row['notes'] as String?,
      isActive: (row['is_active'] as int) == 1,
    );
  }
}

class PurchaseLineInput {
  const PurchaseLineInput({
    required this.productId,
    required this.quantity,
    required this.unitCostMinor,
  });

  final String productId;
  final int quantity;
  final int unitCostMinor;
}

class SupplierPurchaseRepository {
  SupplierPurchaseRepository(this._db);

  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  Stream<List<SupplierRecord>> watchSuppliers() {
    return _db.customSelect(
      'SELECT * FROM suppliers WHERE is_active = 1 ORDER BY name COLLATE NOCASE',
    ).watch().map(
      (rows) => rows.map((row) => SupplierRecord.fromRow(row.data)).toList(),
    );
  }

  Stream<List<Map<String, Object?>>> watchPurchases() {
    return _db.customSelect('''
      SELECT p.id, p.purchase_number, p.supplier_id, s.name AS supplier_name,
             p.total_minor, p.paid_minor, p.status, p.created_at
      FROM purchases p
      INNER JOIN suppliers s ON s.id = p.supplier_id
      ORDER BY p.created_at DESC
    ''').watch().map((rows) => rows.map((row) => row.data).toList());
  }

  Future<void> addSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Supplier name is required.');
    }
    await _db.customStatement(
      'INSERT INTO suppliers (id, name, phone, email, address, notes, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        Variable.withString(_uuid.v4()),
        Variable.withString(name.trim()),
        Variable.withString(_clean(phone) ?? ''),
        Variable.withString(_clean(email) ?? ''),
        Variable.withString(_clean(address) ?? ''),
        Variable.withString(_clean(notes) ?? ''),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }

  Future<String> createPurchase({
    required String supplierId,
    required List<PurchaseLineInput> items,
    int discountMinor = 0,
    int paidMinor = 0,
    String? notes,
  }) async {
    if (items.isEmpty) throw ArgumentError('Add at least one purchase item.');
    if (discountMinor < 0 || paidMinor < 0) {
      throw ArgumentError('Discount and payment cannot be negative.');
    }
    if (items.any((item) => item.quantity <= 0 || item.unitCostMinor < 0)) {
      throw ArgumentError('Quantities must be positive and costs cannot be negative.');
    }

    return _db.transaction(() async {
      final supplier = await _db.customSelect(
        'SELECT id FROM suppliers WHERE id = ? AND is_active = 1',
        variables: [Variable.withString(supplierId)],
      ).getSingleOrNull();
      if (supplier == null) throw StateError('Supplier not found.');

      var subtotal = 0;
      final productRows = <Map<String, Object?>>[];
      for (final item in items) {
        final product = await _db.customSelect(
          'SELECT id, name FROM products WHERE id = ? AND is_active = 1',
          variables: [Variable.withString(item.productId)],
        ).getSingleOrNull();
        if (product == null) throw StateError('A selected product is unavailable.');
        productRows.add(product.data);
        subtotal += item.quantity * item.unitCostMinor;
      }

      if (discountMinor > subtotal) {
        throw ArgumentError('Discount cannot exceed purchase subtotal.');
      }
      final total = subtotal - discountMinor;
      if (paidMinor > total) {
        throw ArgumentError('Payment cannot exceed purchase total.');
      }

      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final purchaseNumber = 'PUR-' + DateTime.now().microsecondsSinceEpoch.toString();

      await _db.customStatement(
        'INSERT INTO purchases '
        '(id, purchase_number, supplier_id, subtotal_minor, discount_minor, total_minor, paid_minor, status, notes, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          Variable.withString(id),
          Variable.withString(purchaseNumber),
          Variable.withString(supplierId),
          Variable.withInt(subtotal),
          Variable.withInt(discountMinor),
          Variable.withInt(total),
          Variable.withInt(paidMinor),
          Variable.withString(paidMinor == total ? 'paid' : paidMinor > 0 ? 'partially_paid' : 'unpaid'),
          Variable.withString(_clean(notes) ?? ''),
          Variable.withInt(now),
        ],
      );

      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final product = productRows[index];
        final lineTotal = item.quantity * item.unitCostMinor;
        await _db.customStatement(
          'INSERT INTO purchase_items '
          '(id, purchase_id, product_id, product_name, quantity, unit_cost_minor, line_total_minor) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            Variable.withString(_uuid.v4()),
            Variable.withString(id),
            Variable.withString(item.productId),
            Variable.withString(product['name'] as String),
            Variable.withInt(item.quantity),
            Variable.withInt(item.unitCostMinor),
            Variable.withInt(lineTotal),
          ],
        );
        await _db.customStatement(
          'UPDATE products SET stock_quantity = stock_quantity + ?, '
          'cost_price_minor = ?, updated_at = ? WHERE id = ?',
          [
            Variable.withInt(item.quantity),
            Variable.withInt(item.unitCostMinor),
            Variable.withInt(now),
            Variable.withString(item.productId),
          ],
        );
      }
      return id;
    });
  }

  Future<int> getSupplierOutstanding(String supplierId) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(SUM(total_minor - paid_minor), 0) AS outstanding '
      'FROM purchases WHERE supplier_id = ?',
      variables: [Variable.withString(supplierId)],
    ).getSingle();
    return row.read<int>('outstanding');
  }

  String? _clean(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }
}

final supplierPurchaseRepositoryProvider =
    Provider<SupplierPurchaseRepository>((ref) {
  return SupplierPurchaseRepository(ref.watch(appDatabaseProvider));
});
