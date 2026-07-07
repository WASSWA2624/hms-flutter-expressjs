import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'patient registry list shell loads',
    ($) async {
      await pumpPatrolAuthenticatedApp(
        $,
        initialLocation: AppRoutes.patients.path,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible(
        $,
        <String>[l10n.patientsTitle, l10n.patientsLoadingTitle],
      );
    },
    targetFile: 'patrol_test/patients_flow_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'patient registry supports mobile shell layout',
    ($) async {
      await pumpPatrolAuthenticatedApp(
        $,
        initialLocation: AppRoutes.patients.path,
        viewport: patrolMobileViewport,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible(
        $,
        <String>[l10n.patientsTitle, l10n.patientsLoadingTitle],
      );
    },
    targetFile: 'patrol_test/patients_flow_test.dart',
    platform: 'chrome',
  );
}
