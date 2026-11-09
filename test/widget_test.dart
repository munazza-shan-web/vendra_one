
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendra_one/app/app.dart';

void main() {
  testWidgets('VendraOne dashboard loads', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VendraOneApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('VendraOne'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
