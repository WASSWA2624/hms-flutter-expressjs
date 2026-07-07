import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'biomedical workspace shell loads',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.biomed, AppRoutes.biomedical.path);

      await expectAnyVisible($, <String>['Biomedical', 'Loading biomedical']);
    },
    targetFile: 'patrol_test/biomedical_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'biomedical workspace supports work order shell',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.biomed, AppRoutes.biomedical.path);
      await openFirstDataRow($);
      await $.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    },
    targetFile: 'patrol_test/biomedical_flow_test.dart',
  );
}
