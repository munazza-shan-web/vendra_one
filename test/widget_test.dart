import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendra_one/app/app.dart';

void main() {
  testWidgets('VendraOne app opens on the Home dashboard', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VendraOneApp(),
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
  });
}
