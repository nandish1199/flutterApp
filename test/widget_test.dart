// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('Home page smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ElateFitApp());
    await tester.pumpAndSettle();

    expect(find.text('Your wellness space'), findsOneWidget);
  });

  testWidgets('Balance card opens the Weight Tracker', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ElateFitApp());
    await tester.pumpAndSettle();
    final weightTracker = find.text('Weight tracker');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(weightTracker);
    await tester.pumpAndSettle();

    expect(find.text('Progress starts today'), findsOneWidget);
  });
}
