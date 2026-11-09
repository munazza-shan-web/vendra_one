
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ------------------------------------------------------------
// CATEGORIES
// ------------------------------------------------------------

class Categories extends Table {
  TextColumn get id => text()();

  TextColumn get name => text().unique()();

  TextColumn get description => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// PRODUCTS
// ------------------------------------------------------------

class Products extends Table {
  TextColumn get id => text()();

  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();

  TextColumn get name => text()();

  TextColumn get sku => text().nullable().unique()();

  TextColumn get barcode => text().nullable().unique()();

  TextColumn get description => text().nullable()();

  // Example: Rs. 150.00 = 15000 minor units.
  IntColumn get costPriceMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get sellingPriceMinor => integer()();

  IntColumn get stockQuantity =>
      integer().withDefault(const Constant(0))();

  IntColumn get lowStockThreshold =>
      integer().withDefault(const Constant(5))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// CUSTOMERS
// ------------------------------------------------------------

class Customers extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get phone => text().nullable()();

  TextColumn get email => text().nullable()();

  TextColumn get address => text().nullable()();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// SALES
// ------------------------------------------------------------

class Sales extends Table {
  TextColumn get id => text()();

  TextColumn get saleNumber => text().unique()();

  TextColumn get customerId =>
      text().nullable().references(Customers, #id)();

  IntColumn get subtotalMinor => integer()();

  IntColumn get discountMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get taxRateBasisPoints =>
      integer().withDefault(const Constant(0))();

  IntColumn get taxMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get totalMinor => integer()();

  IntColumn get paidMinor =>
      integer().withDefault(const Constant(0))();

  // completed, cancelled, partially_refunded, refunded
  TextColumn get status =>
      text().withDefault(const Constant('completed'))();

  // unpaid, partially_paid, paid
  TextColumn get paymentStatus =>
      text().withDefault(const Constant('unpaid'))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// SALE ITEMS
// ------------------------------------------------------------

class SaleItems extends Table {
  TextColumn get id => text()();

  TextColumn get saleId => text().references(Sales, #id)();

  TextColumn get productId => text().references(Products, #id)();

  // Product information is saved as a snapshot so historical
  // receipts remain accurate if the product is renamed later.
  TextColumn get productName => text()();

  TextColumn get sku => text().nullable()();

  IntColumn get quantity => integer()();

  IntColumn get unitPriceMinor => integer()();

  IntColumn get unitCostMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get subtotalMinor => integer()();

  IntColumn get discountMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get taxMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get totalMinor => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// PAYMENTS
// ------------------------------------------------------------

class Payments extends Table {
  TextColumn get id => text()();

  TextColumn get saleId => text().references(Sales, #id)();

  IntColumn get amountMinor => integer()();

  // cash, card, bank_transfer, other
  TextColumn get method => text()();

  TextColumn get reference => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// REFUNDS
// ------------------------------------------------------------

class Refunds extends Table {
  TextColumn get id => text()();

  TextColumn get saleId => text().references(Sales, #id)();

  IntColumn get amountMinor => integer()();

  TextColumn get reason => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// REFUND ITEMS
// ------------------------------------------------------------

class RefundItems extends Table {
  TextColumn get id => text()();

  TextColumn get refundId => text().references(Refunds, #id)();

  TextColumn get saleItemId => text().references(SaleItems, #id)();

  IntColumn get quantity => integer()();

  IntColumn get amountMinor => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// REFUND PAYMENTS
// ------------------------------------------------------------

class RefundPayments extends Table {
  TextColumn get id => text()();

  TextColumn get refundId => text().references(Refunds, #id)();

  IntColumn get amountMinor => integer()();

  // cash, card, bank_transfer, other
  TextColumn get method => text()();

  TextColumn get reference => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ------------------------------------------------------------
// DATABASE
// ------------------------------------------------------------

@DriftDatabase(
  tables: [
    Categories,
    Products,
    Customers,
    Sales,
    SaleItems,
    Payments,
    Refunds,
    RefundItems,
    RefundPayments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for widget and repository tests.
  /// Avoids platform path-provider and background-isolate dependencies.
  AppDatabase.forTesting() : super(NativeDatabase.memory());

  /// Creates a consistent SQLite backup at [destinationPath].
  /// The backup is tagged so restore can reject unrelated SQLite files.
  Future<void> createBackup(String destinationPath) async {
    final escapedPath = destinationPath.replaceAll("'", "''");
    await customStatement('''
      CREATE TABLE IF NOT EXISTS vendra_backup_metadata (
        app_name TEXT NOT NULL,
        format_version INTEGER NOT NULL
      )
    ''');
    await customStatement('DELETE FROM vendra_backup_metadata');
    await customStatement(
      "INSERT INTO vendra_backup_metadata (app_name, format_version) VALUES ('VendraOne', 1)",
    );
    await customStatement("VACUUM INTO '$escapedPath'");
  }

  /// Restores a VendraOne backup transactionally into the open database.
  Future<void> restoreBackup(String sourcePath) async {
    final escapedPath = sourcePath.replaceAll("'", "''");
    await customStatement("ATTACH DATABASE '$escapedPath' AS vendra_restore");

    try {
      final metadata = await customSelect(
        'SELECT app_name, format_version FROM vendra_restore.vendra_backup_metadata',
      ).get();

      if (metadata.length != 1 ||
          metadata.first.read<String>('app_name') != 'VendraOne' ||
          metadata.first.read<int>('format_version') != 1) {
        throw const FormatException('This is not a valid VendraOne backup.');
      }

      const tables = [
        'categories',
        'products',
        'customers',
        'sales',
        'sale_items',
        'payments',
        'refunds',
        'refund_items',
        'refund_payments',
        'suppliers',
        'purchases',
        'purchase_items',
        'expenses',
      ];

      for (final table in tables) {
        final exists = await customSelect(
          "SELECT name FROM vendra_restore.sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable.withString(table)],
        ).get();
        if (exists.isEmpty) {
          throw FormatException('Backup is missing required data: $table');
        }
      }

      await customStatement('PRAGMA foreign_keys = OFF');
      try {
        await transaction(() async {
          for (final table in tables.reversed) {
            await customStatement('DELETE FROM main.$table');
          }
          for (final table in tables) {
            await customStatement(
              'INSERT INTO main.$table SELECT * FROM vendra_restore.$table',
            );
          }
          final violations = await customSelect(
            'PRAGMA foreign_key_check',
          ).get();
          if (violations.isNotEmpty) {
            throw const FormatException(
              'The backup contains inconsistent related records.',
            );
          }
        });
      } finally {
        await customStatement('PRAGMA foreign_keys = ON');
      }

    } finally {
      await customStatement('DETACH DATABASE vendra_restore');
    }
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(customers);
            await m.createTable(sales);
            await m.createTable(saleItems);
            await m.createTable(payments);
            await m.createTable(refunds);
            await m.createTable(refundItems);
            await m.createTable(refundPayments);
          }
          if (from < 3) {
            await customStatement('''
              CREATE TABLE suppliers (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT,
                email TEXT,
                address TEXT,
                notes TEXT,
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at INTEGER NOT NULL
              )
            ''');
            await customStatement('''
              CREATE TABLE purchases (
                id TEXT NOT NULL PRIMARY KEY,
                purchase_number TEXT NOT NULL UNIQUE,
                supplier_id TEXT NOT NULL REFERENCES suppliers(id),
                subtotal_minor INTEGER NOT NULL,
                discount_minor INTEGER NOT NULL DEFAULT 0,
                total_minor INTEGER NOT NULL,
                paid_minor INTEGER NOT NULL DEFAULT 0,
                status TEXT NOT NULL DEFAULT 'received',
                notes TEXT,
                created_at INTEGER NOT NULL
              )
            ''');
            await customStatement('''
              CREATE TABLE purchase_items (
                id TEXT NOT NULL PRIMARY KEY,
                purchase_id TEXT NOT NULL REFERENCES purchases(id),
                product_id TEXT NOT NULL REFERENCES products(id),
                product_name TEXT NOT NULL,
                quantity INTEGER NOT NULL,
                unit_cost_minor INTEGER NOT NULL,
                line_total_minor INTEGER NOT NULL
              )
            ''');
            await customStatement(
              'CREATE INDEX purchases_supplier_idx ON purchases(supplier_id)',
            );
            await customStatement(
              'CREATE INDEX purchase_items_purchase_idx ON purchase_items(purchase_id)',
            );
          }

          if (from < 4) {
            await customStatement('''
              CREATE TABLE expenses (
                id TEXT NOT NULL PRIMARY KEY,
                title TEXT NOT NULL,
                category TEXT NOT NULL,
                amount_minor INTEGER NOT NULL,
                payment_method TEXT NOT NULL DEFAULT 'cash',
                reference TEXT,
                notes TEXT,
                expense_date INTEGER NOT NULL,
                created_at INTEGER NOT NULL
              )
            ''');
            await customStatement(
              'CREATE INDEX expenses_date_idx ON expenses(expense_date)',
            );
            await customStatement(
              'CREATE INDEX expenses_category_idx ON expenses(category)',
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

// ------------------------------------------------------------
// DATABASE CONNECTION
// ------------------------------------------------------------

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      p.join(directory.path, 'vendra_one.sqlite'),
    );

    return NativeDatabase.createInBackground(file);
  });
}
