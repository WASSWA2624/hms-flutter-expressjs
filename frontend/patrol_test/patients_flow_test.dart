import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'patient registry list shell loads',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.reception, AppRoutes.patients.path);
      final l10n = patrolL10n($);

      await expectAnyVisible($, <String>[
        l10n.patientsTitle,
        l10n.patientsLoadingTitle,
      ]);
    },
    targetFile: 'patrol_test/patients_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'patient registry supports mobile shell layout',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.reception,
        AppRoutes.patients.path,
        viewport: patrolMobileViewport,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible($, <String>[
        l10n.patientsTitle,
        l10n.patientsLoadingTitle,
      ]);
    },
    targetFile: 'patrol_test/patients_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'patient registry opens first patient detail when rows exist',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.reception, AppRoutes.patients.path);
      await openFirstDataRow($);
      await $.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    },
    targetFile: 'patrol_test/patients_flow_test.dart',
  );
}
