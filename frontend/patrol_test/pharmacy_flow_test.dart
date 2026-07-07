import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'helpers/demo_credentials.dart';
import 'helpers/failure_reporter.dart';
import 'helpers/patrol_harness.dart';

void main() {
  patrolTestWithDiagnostics(
    'pharmacy workspace shell loads',
    ($) async {
      await loginAndOpenRoute($, DemoAccount.pharmacy, AppRoutes.pharmacy.path);

      await expectAnyVisible($, <String>[
        'Pharmacy',
        'Loading pharmacy workspace',
      ]);
    },
    targetFile: 'patrol_test/pharmacy_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'pharmacy workspace supports mobile shell layout',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.pharmacy,
        AppRoutes.pharmacy.path,
        viewport: patrolMobileViewport,
      );

      await expectAnyVisible($, <String>[
        'Pharmacy',
        'Loading pharmacy workspace',
      ]);
    },
    targetFile: 'patrol_test/pharmacy_flow_test.dart',
  );

  patrolTestWithDiagnostics(
    'pharmacy catalog and stock dialog opens and closes on web',
    ($) async {
      await loginAndOpenRoute(
        $,
        DemoAccount.pharmacy,
        AppRoutes.pharmacy.path,
        viewport: patrolDesktopViewport,
      );

      await expectAnyVisible($, <String>['Pharmacy']);
      await $.pumpAndSettle();

      final Finder catalogAction = find.text('Catalog and stock');
      if (catalogAction.evaluate().isEmpty) {
        final Finder overflow = find.byTooltip('More actions');
        if (overflow.evaluate().isNotEmpty) {
          await $.tester.tap(overflow);
          await $.pumpAndSettle();
        }
      }

      await expectAnyVisible($, <String>['Catalog and stock']);
      await $.tester.tap(find.text('Catalog and stock'));
      await $.pumpAndSettle();

      await expectAnyVisible($, <String>['CATALOG AND STOCK']);
      expect(find.byType(AppDialog), findsOneWidget);

      await $.tester.tap(find.byTooltip('Close'));
      await $.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(find.text('Pharmacy'), findsWidgets);
    },
    targetFile: 'patrol_test/pharmacy_flow_test.dart',
  );
}
