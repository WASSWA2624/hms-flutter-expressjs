import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';

import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'dashboard loads for authenticated tenant admin',
    ($) async {
      await pumpPatrolAuthenticatedApp($);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Organization overview'), findsOneWidget);
      expect(find.text('Today at a glance'), findsOneWidget);
    },
    targetFile: 'patrol_test/home_navigation_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'sidebar navigation opens patient registry',
    ($) async {
      await pumpPatrolAuthenticatedApp($);
      final l10n = patrolL10n($);

      await $.tester.tap(find.text(l10n.navigationPatientsLabel));
      await $.pumpAndSettle();

      expect(find.text(l10n.patientsTitle), findsWidgets);
    },
    targetFile: 'patrol_test/home_navigation_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'sidebar navigation opens billing workspace',
    ($) async {
      await pumpPatrolAuthenticatedApp($);
      final l10n = patrolL10n($);

      await $.tester.tap(find.text(l10n.navigationBillingLabel));
      await $.pumpAndSettle();

      await expectAnyVisible(
        $,
        <String>[l10n.billingWorkspaceTitle, l10n.billingLoadingTitle],
      );
    },
    targetFile: 'patrol_test/home_navigation_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'direct route navigation reaches OPD workspace shell',
    ($) async {
      await pumpPatrolAuthenticatedApp(
        $,
        initialLocation: AppRoutes.opd.path,
      );
      final l10n = patrolL10n($);

      await expectAnyVisible($, <String>[l10n.opdTitle, l10n.opdLoadingTitle]);
    },
    targetFile: 'patrol_test/home_navigation_test.dart',
    platform: 'chrome',
  );
}
