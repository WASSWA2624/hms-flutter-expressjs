import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/shared/layout/shell_navigation_loading.dart';

void main() {
  group('AppShellLoadingBar', () {
    testWidgets('is hidden when not visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AppShellLoadingBar(visible: false),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows an indeterminate bar when visible', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AppShellLoadingBar(visible: true),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final LinearProgressIndicator indicator = tester.widget(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.minHeight, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses a static bar when animations are disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AppShellLoadingBar(visible: true),
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      final ColoredBox bar = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(AppShellLoadingBar),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(bar.color, AppTheme.light.colorScheme.primary);
      expect(tester.takeException(), isNull);
    });
  });
}
