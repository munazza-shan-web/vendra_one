import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendra_one/data/local/database/app_database.dart';
import 'package:vendra_one/data/local/database/database_provider.dart';
import 'package:vendra_one/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('VendraOne dashboard displays its main content', (tester) async {
    final database = AppDatabase.forTesting();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    // Allow the in-memory database streams to emit their initial values.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('VendraOne'), findsOneWidget);
    expect(find.text('Business overview'), findsOneWidget);

    // Unmount the dashboard and let stream subscriptions cancel.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
