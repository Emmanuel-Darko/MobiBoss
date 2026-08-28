// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:momo_pos_reconcile/main.dart';
import 'package:momo_pos_reconcile/providers/momo_provider.dart';

void main() {
  testWidgets('MoMoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MoMoProvider()..init()),
        ],
        child: const MoMoApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
