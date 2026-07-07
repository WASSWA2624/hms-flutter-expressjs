import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/shared/layout/responsive_shell_scaffold.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('responsive shell renders on desktop viewport', (
    WidgetTester tester,
  ) async {
    await pumpHosspiHmsApp(
      tester,
      overrides: testReadyAppOverrides(
        sessionState: integrationAuthenticatedSessionState(),
        mockHomeRepository: true,
      ),
      size: const Size(1440, 900),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ResponsiveShellScaffold), findsWidgets);
  });

  testWidgets('responsive shell renders on mobile viewport', (
    WidgetTester tester,
  ) async {
    await pumpHosspiHmsApp(
      tester,
      overrides: testReadyAppOverrides(
        sessionState: integrationAuthenticatedSessionState(),
        mockHomeRepository: true,
      ),
      size: const Size(390, 844),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
