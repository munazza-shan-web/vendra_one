
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';
import '../local/database/database_provider.dart';

class ProductRepository {
  ProductRepository(this._database);

  final AppDatabase _database;

  final Uuid _uuid = const Uuid();

  // Add a new product.
  Future<String> addProduct({
    required String name,
    required int sellingPriceMinor,
    int costPriceMinor = 0,
    int stockQuantity = 0,
    int lowStockThreshold = 5,
    String? categoryId,
    String? sku,
    String? barcode,
    String? description,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Product name is required.');
    }

    if (sellingPriceMinor < 0 ||
        costPriceMinor < 0 ||
        stockQuantity < 0 ||
        lowStockThreshold < 0) {
      throw ArgumentError('Product values cannot be negative.');
    }

    final id = _uuid.v4();

    await _database.into(_database.products).insert(
      ProductsCompanion.insert(
        id: id,
        name: name.trim(),
        sellingPriceMinor: sellingPriceMinor,
        costPriceMinor: Value(costPriceMinor),
        stockQuantity: Value(stockQuantity),
        lowStockThreshold: Value(lowStockThreshold),
        categoryId: Value(categoryId),
        sku: Value(_clean(sku)),
        barcode: Value(_clean(barcode)),
        description: Value(_clean(description)),
      ),
    );

    return id;
  }

  // Get all active products.
  Future<List<Product>> getAllProducts() {
    return (_database.select(_database.products)
          ..where((product) => product.isActive.equals(true))
          ..orderBy([(product) => OrderingTerm.asc(product.name)]))
        .get();
  }

  // Watch active products.
  Stream<List<Product>> watchProducts() {
    return (_database.select(_database.products)
          ..where((product) => product.isActive.equals(true))
          ..orderBy([(product) => OrderingTerm.asc(product.name)]))
        .watch();
  }

  // Search products by name, SKU, or barcode.
  Future<List<Product>> searchProducts(String query) {
    final searchTerm = query.trim();

    if (searchTerm.isEmpty) {
      return getAllProducts();
    }

    return (_database.select(_database.products)
          ..where(
            (product) =>
                product.isActive.equals(true) &
                (product.name.contains(searchTerm) |
                    product.sku.contains(searchTerm) |
                    product.barcode.equals(searchTerm)),
          )
          ..orderBy([(product) => OrderingTerm.asc(product.name)]))
        .get();
  }

  // Find an active product by its ID.
  Future<Product?> getProductById(String id) {
    return (_database.select(_database.products)
          ..where(
            (product) =>
                product.id.equals(id) &
                product.isActive.equals(true),
          ))
        .getSingleOrNull();
  }

  // Find an active product by barcode.
  Future<Product?> getProductByBarcode(String barcode) {
    final value = barcode.trim();

    if (value.isEmpty) {
      return Future.value(null);
    }

    return (_database.select(_database.products)
          ..where(
            (product) =>
                product.barcode.equals(value) &
                product.isActive.equals(true),
          ))
        .getSingleOrNull();
  }

  // Update an existing product.
  Future<void> updateProduct({
    required String id,
    required String name,
    required int sellingPriceMinor,
    required int costPriceMinor,
    required int stockQuantity,
    required int lowStockThreshold,
    String? categoryId,
    String? sku,
    String? barcode,
    String? description,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Product name is required.');
    }

    if (sellingPriceMinor < 0 ||
        costPriceMinor < 0 ||
        stockQuantity < 0 ||
        lowStockThreshold < 0) {
      throw ArgumentError('Product values cannot be negative.');
    }

    await (_database.update(_database.products)
          ..where((product) => product.id.equals(id)))
        .write(
      ProductsCompanion(
        name: Value(name.trim()),
        sellingPriceMinor: Value(sellingPriceMinor),
        costPriceMinor: Value(costPriceMinor),
        stockQuantity: Value(stockQuantity),
        lowStockThreshold: Value(lowStockThreshold),
        categoryId: Value(categoryId),
        sku: Value(_clean(sku)),
        barcode: Value(_clean(barcode)),
        description: Value(_clean(description)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Deactivate a product without permanently deleting it.
  Future<void> deactivateProduct(String id) async {
    await (_database.update(_database.products)
          ..where((product) => product.id.equals(id)))
        .write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Get products that have reached their low-stock threshold.
  Future<List<Product>> getLowStockProducts() {
    return (_database.select(_database.products)
          ..where(
            (product) =>
                product.isActive.equals(true) &
                product.stockQuantity.isSmallerOrEqual(
                  product.lowStockThreshold,
                ),
          ))
        .get();
  }

  // Safely adjust stock.
  // The checkout repository will perform its own atomic stock
  // validation and deduction inside a database transaction.
  Future<void> adjustStock({
    required String productId,
    required int quantityChange,
  }) async {
    await _database.transaction(() async {
      final product = await (_database.select(_database.products)
            ..where(
              (item) =>
                  item.id.equals(productId) &
                  item.isActive.equals(true),
            ))
          .getSingleOrNull();

      if (product == null) {
        throw StateError('Product not found or inactive.');
      }

      final newQuantity = product.stockQuantity + quantityChange;

      if (newQuantity < 0) {
        throw StateError('Insufficient stock.');
      }

      await (_database.update(_database.products)
            ..where(
              (item) => item.id.equals(productId),
            ))
          .write(
        ProductsCompanion(
          stockQuantity: Value(newQuantity),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

// Riverpod provider.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);

  return ProductRepository(database);
});
