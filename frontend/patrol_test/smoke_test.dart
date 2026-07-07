import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'authenticated home loads on desktop viewport',
    ($) async {
      await pumpPatrolE2eApp($);
      await loginAs($, DemoAccount.tenantAdmin);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Organization overview'), findsOneWidget);
    },
    targetFile: 'patrol_test/smoke_test.dart',
  );

  patrolTestWithDiagnostics(
    'authenticated home loads on mobile viewport',
    ($) async {
      await pumpPatrolE2eApp($, viewport: patrolMobileViewport);
      await loginAs($, DemoAccount.tenantAdmin);
      final l10n = patrolL10n($);

      expect(find.byType(HomePage), findsOneWidget);
      await expectAnyVisible($, <String>[
        'Organization overview',
        l10n.navigationHomeLabel,
        l10n.appTitle,
      ]);
    },
    targetFile: 'patrol_test/smoke_test.dart',
  );
}
