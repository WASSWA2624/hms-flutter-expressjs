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

    testWidgets('icon-only mode requires and exposes a semantic label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();

      await pumpComponent(
        tester,
        AppButton(
          iconOnly: true,
          leadingIcon: Icons.refresh,
          label: 'Refresh data',
          semanticLabel: 'Refresh data',
          onPressed: () {},
        ),
      );

      expect(find.bySemanticsLabel('Refresh data'), findsWidgets);

      semantics.dispose();
    });

    testWidgets('uses soft fill and thin border for primary variant', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppButton.primary(
          label: 'Try again',
          leadingIcon: Icons.refresh,
          onPressed: () {},
        ),
      );

      final TextButton button = tester.widget<TextButton>(
        find.byType(TextButton),
      );
      final ButtonStyle style = button.style!;
      final Color? background = style.backgroundColor?.resolve(<WidgetState>{});
      final BorderSide? side = style.side?.resolve(<WidgetState>{});
      expect(background, isNotNull);
      expect(background!.a, closeTo(0.12, 0.001));
      expect(style.overlayColor?.resolve(<WidgetState>{}), isNull);
      expect(side?.width, 0.5);
    });

    testWidgets('applies a thin border on all variants', (
      WidgetTester tester,
    ) async {
      for (final AppButtonVariant variant in AppButtonVariant.values) {
        await pumpComponent(
          tester,
          AppButton(
            label: variant.name,
            variant: variant,
            onPressed: () {},
          ),
        );

        final TextButton button = tester.widget<TextButton>(
          find.byType(TextButton),
        );
        final BorderSide? side = button.style!.side?.resolve(<WidgetState>{});
        expect(side, isNotNull);
        expect(side!.width, 0.5);
        expect(side.style, BorderStyle.solid);
      }
    });

    testWidgets('section header scope drops fill and border', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        AppActionLabelScope(
          showLabels: true,
          forceIconOnly: false,
          plainChrome: true,
          child: AppButton.secondary(
            label: 'Edit vitals',
            dense: true,
            onPressed: () {},
          ),
        ),
      );

      final TextButton button = tester.widget<TextButton>(
        find.byType(TextButton),
      );
      final ButtonStyle style = button.style!;
      expect(
        style.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(style.side?.resolve(<WidgetState>{}), BorderSide.none);
    });
  });
}
