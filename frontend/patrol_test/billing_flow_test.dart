import 'package:hosspi_hms/app/router/app_routes.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'billing workspace shell loads',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.billing, AppRoutes.billing.path);
      final l10n = patrolL10n($);

      await expectAnyVisible($, <String>[
        l10n.billingWorkspaceTitle,
        l10n.billingLoadingTitle,
      ]);
    },
    targetFile: 'patrol_test/billing_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'billing workspace supports mobile shell layout',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.billing,
        AppRoutes.billing.path,
        viewport: patrolMobileViewport,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible($, <String>[
        l10n.billingWorkspaceTitle,
        l10n.billingLoadingTitle,
      ]);
    },
    targetFile: 'patrol_test/billing_flow_test.dart',
  );
}
