import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics('HR workspace shell loads', ($) async {
    await loginAndOpenRoute($, DemoAccount.hr, AppRoutes.hr.path);

    await expectAnyVisible($, <String>[
      'Human resources',
      'Loading HR workspace',
    ]);
  }, targetFile: 'patrol_test/hr_flow_test.dart');

  patrolTestWithDiagnostics(
    'HR workspace opens first staff row when available',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.hr, AppRoutes.hr.path);
      await openFirstDataRow($);
      await $.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    },
    targetFile: 'patrol_test/hr_flow_test.dart',
  );
}
