import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'category_seeder.dart';
import 'database_provider.dart';

final categorySeederProvider = Provider<CategorySeeder>((ref) {
  final database = ref.watch(appDatabaseProvider);

  return CategorySeeder(database);
});