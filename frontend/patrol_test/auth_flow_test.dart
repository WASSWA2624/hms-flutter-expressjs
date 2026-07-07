import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'unauthenticated users are redirected to login',
    ($) async {
      await pumpPatrolShellApp(
        $,
        overrides: testReadyAppOverrides(
          initialLocation: AppRoutes.patients.path,
        ),
      );

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
    },
    targetFile: 'patrol_test/auth_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'login shell renders without production services',
    ($) async {
      await pumpPatrolShellApp(
        $,
        overrides: testReadyAppOverrides(initialLocation: AppRoutes.login.path),
      );

      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        find.text('Use your facility account to open the HMS workspace.'),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsWidgets);
    },
    targetFile: 'patrol_test/auth_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'real login and logout returns to login screen',
    ($) async {
      await pumpPatrolE2eApp($);
      await loginAs($, DemoAccount.reception);
      await logoutPatrol($);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
    },
    targetFile: 'patrol_test/auth_flow_test.dart',
  );
}
