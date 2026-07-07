import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'lab workspace shell loads',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.lab, AppRoutes.lab.path);

      await expectAnyVisible($, <String>['Laboratory', 'Loading laboratory']);
    },
    targetFile: 'patrol_test/lab_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'lab workspace supports mobile shell layout',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.lab,
        AppRoutes.lab.path,
        viewport: patrolMobileViewport,
      );

      await expectAnyVisible($, <String>['Laboratory', 'Loading laboratory']);
    },
    targetFile: 'patrol_test/lab_flow_test.dart',
  );
}
