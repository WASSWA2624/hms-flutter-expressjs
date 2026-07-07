import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics('radiology workspace shell loads', ($) async {
    await loginAndOpenRoute($, DemoAccount.radiology, AppRoutes.radiology.path);

    await expectAnyVisible($, <String>[
      'Radiology',
      'Loading radiology workspace',
    ]);
  }, targetFile: 'patrol_test/radiology_flow_test.dart');

  patrolTestWithDiagnostics(
    'radiology workspace supports mobile shell layout',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.radiology,
        AppRoutes.radiology.path,
        viewport: patrolMobileViewport,
      );

      await expectAnyVisible($, <String>[
        'Radiology',
        'Loading radiology workspace',
      ]);
    },
    targetFile: 'patrol_test/radiology_flow_test.dart',
  );
}
