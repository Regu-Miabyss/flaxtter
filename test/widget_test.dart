import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flaxtter material app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Flaxtter'))));
    expect(find.text('Flaxtter'), findsOneWidget);
  });
}
