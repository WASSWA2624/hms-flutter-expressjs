import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final authenticatedSessionState = SessionState.authenticated(
    session: AuthSession(
      tokens: SessionTokens(accessToken: 'test-access-token'),
      subject: 'admin@example.com',
      user: const AuthUserProfile(
        id: 'user-123',
        displayId: 'USR-123',
        email: 'admin@example.com',
        firstName: 'Wilson',
        lastName: 'Admin',
        tenantName: 'IHK Hospital',
        facilityName: 'IHK Hospital',
        facilityType: 'hospital',
        positionTitle: 'tenant_admin',
        staffNumber: 'STF-001',
        staffPosition: 'administrator',
        roles: <String>['tenant_admin'],
      ),
    ),
  );

  testWidgets('starts on home and navigates to not found without services', (
    WidgetTester tester,
  ) async {
    await pumpHosspiHmsApp(
      tester,
      overrides: testReadyAppOverrides(sessionState: authenticatedSessionState),
    );
    await tester.pumpAndSettle();

    final homeContext = tester.element(find.byType(HomePage));

    expect(find.text('Organization overview'), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);

    GoRouter.of(homeContext).go('/missing-route');
    await tester.pumpAndSettle();

    final notFoundContext = tester.element(find.byType(NotFoundPage));
    final notFoundL10n = notFoundContext.l10n;

    expect(find.text(notFoundL10n.routeNotFoundTitle), findsOneWidget);
    expect(find.text('/missing-route'), findsOneWidget);
  });
}
