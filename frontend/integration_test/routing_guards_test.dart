import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final AppRouteData route in AppRoutes.shellRoutes) {
    if (!route.requiresAuthenticatedSession || route.isAuthEntryRoute) {
      continue;
    }

    testWidgets('protected route ${route.path} redirects to login', (
      WidgetTester tester,
    ) async {
      await pumpHosspiHmsApp(
        tester,
        overrides: testReadyAppOverrides(initialLocation: route.path),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });
  }
}
