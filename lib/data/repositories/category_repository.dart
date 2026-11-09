
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';
import '../local/database/database_provider.dart';

class CategoryRepository {
  CategoryRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<String> addCategory({
    required String name,
    String? description,
  }) async {
    final cleanName = _validateName(name);

    await _ensureUniqueName(cleanName);

    final id = _uuid.v4();

    await _database.into(_database.categories).insert(
      CategoriesCompanion.insert(
        id: id,
        name: cleanName,
        description: Value(_cleanDescription(description)),
      ),
    );

    return id;
  }

  // Active categories for product forms and filters.
  Future<List<Category>> getAllCategories() {
    return (_database.select(_database.categories)
          ..where((category) => category.isActive.equals(true))
          ..orderBy([
            (category) => OrderingTerm.asc(category.name),
          ]))
        .get();
  }

  Stream<List<Category>> watchCategories() {
    return (_database.select(_database.categories)
          ..where((category) => category.isActive.equals(true))
          ..orderBy([
            (category) => OrderingTerm.asc(category.name),
          ]))
        .watch();
  }

  // All categories for category management.
  Future<List<Category>> getAllCategoriesIncludingInactive() {
    return (_database.select(_database.categories)
          ..orderBy([
            (category) => OrderingTerm.asc(category.name),
          ]))
        .get();
  }

  Stream<List<Category>> watchAllCategories() {
    return (_database.select(_database.categories)
          ..orderBy([
            (category) => OrderingTerm.asc(category.name),
          ]))
        .watch();
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String? description,
  }) async {
    final cleanName = _validateName(name);

    final existing = await (_database.select(_database.categories)
          ..where((category) => category.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      throw Exception('Category not found.');
    }

    await _ensureUniqueName(cleanName, excludingId: id);

    await (_database.update(_database.categories)
          ..where((category) => category.id.equals(id)))
        .write(
      CategoriesCompanion(
        name: Value(cleanName),
        description: Value(_cleanDescription(description)),
      ),
    );
  }

  Future<void> deactivateCategory(String id) async {
    final existing = await (_database.select(_database.categories)
          ..where((category) => category.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      throw Exception('Category not found.');
    }

    if (!existing.isActive) return;

    await (_database.update(_database.categories)
          ..where((category) => category.id.equals(id)))
        .write(
      const CategoriesCompanion(
        isActive: Value(false),
      ),
    );
  }

  Future<void> activateCategory(String id) async {
    final existing = await (_database.select(_database.categories)
          ..where((category) => category.id.equals(id)))
        .getSingleOrNull();

    if (existing == null) {
      throw Exception('Category not found.');
    }

    if (existing.isActive) return;

    await _ensureUniqueName(
      existing.name,
      excludingId: id,
    );

    await (_database.update(_database.categories)
          ..where((category) => category.id.equals(id)))
        .write(
      const CategoriesCompanion(
        isActive: Value(true),
      ),
    );
  }

  String _validateName(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw Exception('Category name cannot be empty.');
    }

    if (cleanName.length > 100) {
      throw Exception('Category name cannot exceed 100 characters.');
    }

    return cleanName;
  }

  Future<void> _ensureUniqueName(
    String name, {
    String? excludingId,
  }) async {
    final normalizedName = name.trim().toLowerCase();

    final categories = await _database.select(_database.categories).get();

    final duplicate = categories.any(
      (category) =>
          category.id != excludingId &&
          category.name.trim().toLowerCase() == normalizedName,
    );

    if (duplicate) {
      throw Exception('A category with this name already exists.');
    }
  }

  String? _cleanDescription(String? description) {
    final cleaned = description?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);

  return CategoryRepository(database);
});
