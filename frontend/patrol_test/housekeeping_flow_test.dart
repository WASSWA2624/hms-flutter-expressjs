import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'housekeeping task queue shell loads',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.housekeeping,
        AppRoutes.housekeeping.path,
      );

      await expectAnyVisible($, <String>[
        'Housekeeping',
        'Loading housekeeping',
      ]);
    },
    targetFile: 'patrol_test/housekeeping_flow_test.dart',
  );
}
