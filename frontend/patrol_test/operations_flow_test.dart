import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'operations workspace shell loads',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.operations,
        AppRoutes.operations.path,
      );

      await expectAnyVisible($, <String>['Operations', 'Loading operations']);
    },
    targetFile: 'patrol_test/operations_flow_test.dart',
  );
}
