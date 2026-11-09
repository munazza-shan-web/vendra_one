import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('VendraOne test environment renders a Material app',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('VendraOne')),
          body: const Center(
            child: Text('App test environment is ready'),
          ),
        ),
      ),
    );

    expect(find.text('VendraOne'), findsOneWidget);
    expect(find.text('App test environment is ready'), findsOneWidget);
  });
}
