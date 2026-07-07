import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:patrol/patrol.dart';

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

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Organization overview'), findsOneWidget);
    },
    targetFile: 'patrol_test/smoke_test.dart',
    platform: 'chrome',
  );
}
