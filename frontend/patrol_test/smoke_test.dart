import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';

import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'authenticated home loads on desktop viewport',
    ($) async {
      await pumpPatrolAuthenticatedApp($, viewport: patrolDesktopViewport);

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Organization overview'), findsOneWidget);
    },
    targetFile: 'patrol_test/smoke_test.dart',
    platform: 'chrome',
  );

  patrolTestWithDiagnostics(
    'authenticated home loads on mobile viewport',
    ($) async {
      await pumpPatrolAuthenticatedApp($, viewport: patrolMobileViewport);
      final l10n = patrolL10n($);

      expect(find.byType(HomePage), findsOneWidget);
      await expectAnyVisible(
        $,
        <String>[
          'Organization overview',
          l10n.navigationHomeLabel,
          l10n.appTitle,
        ],
      );
    },
    targetFile: 'patrol_test/smoke_test.dart',
    platform: 'chrome',
  );
}
