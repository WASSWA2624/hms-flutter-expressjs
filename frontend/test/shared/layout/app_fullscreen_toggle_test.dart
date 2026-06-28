import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/layout/app_fullscreen_toggle.dart';

import '../components/component_test_app.dart';

void main() {
  testWidgets('AppFullscreenToggle is hidden when fullscreen is unsupported', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppFullscreenToggle(
        enterLabel: 'Enter full screen',
        exitLabel: 'Exit full screen',
      ),
      size: const Size(1200, 800),
    );

    expect(find.byType(AppFullscreenToggle), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.text('Enter full screen'), findsNothing);
  });
}
