import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  group('AppButton', () {
    testWidgets('runs the action when enabled', (WidgetTester tester) async {
      var taps = 0;

      await pumpComponent(
        tester,
        AppButton.primary(
          label: 'Save',
          onPressed: () {
            taps += 1;
          },
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('shows loading state and blocks duplicate actions', (
      WidgetTester tester,
    ) async {
      var taps = 0;

      await pumpComponent(
        tester,
        AppButton.primary(
          label: 'Save',
          isLoading: true,
          onPressed: () {
            taps += 1;
          },
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(taps, 0);
    });
  });

  group('AppIconButton', () {
    testWidgets('requires and exposes an icon semantic label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();

      await pumpComponent(
        tester,
        AppIconButton(
          icon: Icons.refresh,
          semanticLabel: 'Refresh data',
          onPressed: () {},
        ),
      );

      expect(find.bySemanticsLabel('Refresh data'), findsWidgets);

      semantics.dispose();
    });
  });
}
