// Basic Flutter widget test for final_app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_app/main.dart';

void main() {
  testWidgets('App loads and displays main navigation tabs', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify bottom navigation items exist.
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
    expect(find.byIcon(Icons.report_problem_outlined), findsOneWidget);
  });
}
