import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final AppRouteData route in AppRoutes.shellRoutes) {
    testWidgets('deep-link loads shell for ${route.name}', (
      WidgetTester tester,
    ) async {
      await pumpHosspiHmsApp(
        tester,
        overrides: testReadyAppOverrides(
          sessionState: integrationAuthenticatedSessionState(),
          initialLocation: route.path,
        ),
        size: const Size(1280, 800),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ForbiddenPage), findsNothing);
      expect(find.byType(Scaffold), findsWidgets);
    });
  }
}
