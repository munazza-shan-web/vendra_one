import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendra_one/app/app.dart';
import 'package:vendra_one/data/local/database/app_database.dart';
import 'package:vendra_one/data/local/database/database_provider.dart';

void main() {
  testWidgets('VendraOne app opens on the Home dashboard', (tester) async {
    final database = AppDatabase.forTesting();

    await tester.pumpWidget(
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

    // Database-backed dashboard streams may show loading indicators.
    // Advance a bounded amount of time instead of waiting for animations
    // to settle indefinitely.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('VendraOne'), findsOneWidget);
    // The dashboard tab is labelled "Home" in the bottom navigation.
    expect(find.text('Home'), findsOneWidget);

    // Dispose the widget tree so database streams are cancelled before the
    // in-memory database is closed by the provider.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
