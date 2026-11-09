
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

  @override
  int get schemaVersion => 3;

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
