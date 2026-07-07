import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';

import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'authenticated home loads on desktop viewport',
    ($) async {
      await pumpPatrolAuthenticatedApp($, viewport: patrolDesktopViewport);
      final l10n = patrolL10n($);

      expect(find.byType(HomePage), findsOneWidget);
      await expectAnyVisible(
        $,
        <String>[
          'Organization overview',
          l10n.homeLoadingTitle,
          'Today at a glance',
        ],
      );
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
          l10n.homeLoadingTitle,
          'Today at a glance',
        ],
      );
    },
    targetFile: 'patrol_test/smoke_test.dart',
    platform: 'chrome',
  );
}
