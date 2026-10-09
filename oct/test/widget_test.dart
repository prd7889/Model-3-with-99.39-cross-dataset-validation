import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oct_classifier/main.dart';

void main() {
  testWidgets('shows gallery entry point', (tester) async {
    await tester.pumpWidget(const OctClassifierApp());
    await tester.pump();
    expect(find.text('Image classifier'), findsOneWidget);
    expect(find.text('Open gallery'), findsOneWidget);
  });

  testWidgets('switches between light and dark themes', (tester) async {
    await tester.pumpWidget(const OctClassifierApp());
    await tester.pump();
    final before = Theme.of(tester.element(find.byType(ClassifierScreen)))
        .brightness;
    await tester.tap(find.byTooltip('Use dark theme'));
    await tester.pumpAndSettle();
    final after = Theme.of(tester.element(find.byType(ClassifierScreen)))
        .brightness;
    expect(before, Brightness.light);
    expect(after, Brightness.dark);
  });
}
