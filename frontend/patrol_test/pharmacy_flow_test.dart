import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'pharmacy workspace shell loads',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.pharmacy, AppRoutes.pharmacy.path);

      await expectAnyVisible($, <String>[
        'Pharmacy',
        'Loading pharmacy workspace',
      ]);
    },
    targetFile: 'patrol_test/pharmacy_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'pharmacy workspace supports mobile shell layout',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.pharmacy,
        AppRoutes.pharmacy.path,
        viewport: patrolMobileViewport,
      );

      await expectAnyVisible($, <String>[
        'Pharmacy',
        'Loading pharmacy workspace',
      ]);
    },
    targetFile: 'patrol_test/pharmacy_flow_test.dart',
  );
}
