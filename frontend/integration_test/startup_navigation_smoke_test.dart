import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts on home and navigates to not found without services', (
    WidgetTester tester,
  ) async {
    await pumpHosspiHmsApp(tester, overrides: testReadyAppOverrides());
    await tester.pumpAndSettle();

    final homeContext = tester.element(find.byType(HomePage));
    final l10n = homeContext.l10n;

    expect(find.text(l10n.homeReadyTitle), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);

    GoRouter.of(homeContext).go('/missing-route');
    await tester.pumpAndSettle();

    final notFoundContext = tester.element(find.byType(NotFoundPage));
    final notFoundL10n = notFoundContext.l10n;

    expect(find.text(notFoundL10n.routeNotFoundTitle), findsOneWidget);
    expect(find.text('/missing-route'), findsOneWidget);
  });
}
