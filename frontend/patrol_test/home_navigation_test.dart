import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'dashboard loads for authenticated tenant admin',
    ($) async {
      await pumpPatrolE2eApp($);
      await loginAs($, DemoAccount.tenantAdmin);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Organization overview'), findsOneWidget);
      expect(find.text('Today at a glance'), findsOneWidget);
    },
    targetFile: 'patrol_test/home_navigation_test.dart',
  );

  patrolTestWithDiagnostics(
    'sidebar navigation opens patient registry',
    ($) async {
      await pumpPatrolE2eApp($);
      await loginAs($, DemoAccount.tenantAdmin);
      final l10n = patrolL10n($);

      await $.tester.tap(find.text(l10n.navigationPatientsLabel));
      await $.pumpAndSettle();

      expect(find.text(l10n.patientsTitle), findsWidgets);
    },
    targetFile: 'patrol_test/home_navigation_test.dart',
  );

  patrolTestWithDiagnostics(
    'sidebar navigation opens billing workspace',
    ($) async {
      await pumpPatrolE2eApp($);
      await loginAs($, DemoAccount.billing);
      final l10n = patrolL10n($);

      await $.tester.tap(find.text(l10n.navigationBillingLabel));
      await $.pumpAndSettle();

      await expectAnyVisible($, <String>[
        l10n.billingWorkspaceTitle,
        l10n.billingLoadingTitle,
      ]);
    },
    targetFile: 'patrol_test/home_navigation_test.dart',
  );

  patrolTestWithDiagnostics(
    'direct route navigation reaches OPD workspace shell',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.doctor, AppRoutes.opd.path);
      final l10n = patrolL10n($);

      await expectAnyVisible($, <String>[l10n.opdTitle, l10n.opdLoadingTitle]);
    },
    targetFile: 'patrol_test/home_navigation_test.dart',
  );
}
