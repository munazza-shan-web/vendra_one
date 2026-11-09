import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/local/database/app_database.dart';
import 'data/local/database/category_seeder.dart';
import 'data/local/database/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create the local database.
  final database = AppDatabase();

  // Insert default categories.
  await CategorySeeder(database).seedDefaultCategories();

  // Start the application.
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
      child: const VendraOneApp(),
    ),
  );
}