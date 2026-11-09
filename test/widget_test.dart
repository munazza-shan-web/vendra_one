import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendra_one/data/local/database/app_database.dart';
import 'package:vendra_one/data/repositories/product_repository.dart';
import 'package:vendra_one/data/repositories/sales_repository.dart';
import 'package:vendra_one/features/dashboard/presentation/dashboard_screen.dart';

class _FakeSalesRepository implements SalesRepository {
  @override
  Stream<List<Sale>> watchSales() => Stream.value([]);

  @override
  Future<List<Sale>> getAllSales() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProductRepository implements ProductRepository {
  @override
  Stream<List<Product>> watchProducts() => Stream.value([]);

  @override
  Future<List<Product>> getAllProducts() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('VendraOne dashboard displays its main content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesRepositoryProvider.overrideWithValue(_FakeSalesRepository()),
          productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('VendraOne'), findsOneWidget);
    expect(find.text('Business overview'), findsOneWidget);
    expect(find.text('All products are above their low-stock levels.'),
        findsOneWidget);
  });
}
