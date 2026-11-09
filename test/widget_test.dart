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

    // The dashboard listens to live database streams and keeps an
    // indeterminate progress indicator active while the first query loads.
    // pumpAndSettle therefore cannot settle; advance frames without waiting
    // for every animation to stop.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('VendraOne'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
