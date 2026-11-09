import 'package:drift/drift.dart';

import 'app_database.dart';
import 'default_categories.dart';

class CategorySeeder {
  CategorySeeder(this._database);

  final AppDatabase _database;

  Future<void> seedDefaultCategories() async {
    await _database.batch((batch) {
      for (final name in defaultCategories) {
        batch.insert(
          _database.categories,
          CategoriesCompanion.insert(
            id: 'default-${name.toLowerCase().replaceAll(' ', '-')}',
            name: name,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }
}