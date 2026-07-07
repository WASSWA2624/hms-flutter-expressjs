import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:patrol/patrol.dart';

import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'OPD queue shell loads',
    ($) async {
      await pumpPatrolAuthenticatedApp(
        $,
        initialLocation: AppRoutes.opd.path,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible($, <String>[l10n.opdTitle, l10n.opdLoadingTitle]);
    },
    targetFile: 'patrol_test/opd_flow_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'OPD workspace supports mobile shell layout',
    ($) async {
      await pumpPatrolAuthenticatedApp(
        $,
        initialLocation: AppRoutes.opd.path,
        viewport: patrolMobileViewport,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible($, <String>[l10n.opdTitle, l10n.opdLoadingTitle]);
    },
    targetFile: 'patrol_test/opd_flow_test.dart',
    platform: 'chrome',
  );
}
