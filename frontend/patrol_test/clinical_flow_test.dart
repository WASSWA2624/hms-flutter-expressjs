import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'clinical workspace shell loads',
    ($) async {
      await pumpPatrolAuthenticatedApp(
        $,
        initialLocation: AppRoutes.clinical.path,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible(
        $,
        <String>[l10n.clinicalTitle, l10n.clinicalLoadingTitle],
      );
    },
    targetFile: 'patrol_test/clinical_flow_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'clinical workspace supports mobile shell layout',
    ($) async {
      await pumpPatrolAuthenticatedApp(
        $,
        initialLocation: AppRoutes.clinical.path,
        viewport: patrolMobileViewport,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible(
        $,
        <String>[l10n.clinicalTitle, l10n.clinicalLoadingTitle],
      );
    },
    targetFile: 'patrol_test/clinical_flow_test.dart',
    platform: 'chrome',
  );
}
