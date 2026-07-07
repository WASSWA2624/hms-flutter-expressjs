import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'emergency dispatch shell loads',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.ambulance, AppRoutes.emergency.path);

      await expectAnyVisible($, <String>[
        'Emergency board',
        'Loading emergency board',
      ]);
    },
    targetFile: 'patrol_test/ambulance_flow_test.dart',
  );
}
