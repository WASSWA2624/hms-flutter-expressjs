import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/app/startup/app_startup_initializer.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/storage/secure/app_secure_storage.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_harness.dart';

/// Cold-start session restore, end to end through the real startup path.
///
/// The unit suite proves [AppStartupInitializer] reads the stored tokens; this
/// proves the app that boots on top of that result never shows the login page
/// to a user who is still signed in.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String futureExpiry() {
    return DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .toIso8601String();
  }

  void seedStoredSession() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      SecureStorageKeys.accessToken: 'stored-access-token',
      SecureStorageKeys.refreshToken: 'stored-refresh-token',
      SecureStorageKeys.accessTokenExpiresAt: futureExpiry(),
    });
  }

  testWidgets('reopening the app restores the session without a login prompt', (
    WidgetTester tester,
  ) async {
    seedStoredSession();

    // Two cold starts in a row: closing the app must not consume the session.
    for (var launch = 0; launch < 2; launch++) {
      final result = await const AppStartupInitializer().initialize(
        config: testAppConfig(),
      );

      expect(
        result.state.sessionReadiness.status,
        SessionStatus.authenticated,
        reason: 'launch $launch did not restore the stored session',
      );

      await pumpHosspiHmsApp(
        tester,
        overrides: result.providerOverrides(
          initialLocation: AppRoutes.home.path,
        ),
      );
      await tester.pump();

      // The session is decided before the first frame, so neither the
      // unauthenticated login page nor the "checking session" shell may appear.
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(SessionRestoringPage), findsNothing);
    }
  });

  testWidgets('a cold start with no stored session lands on login', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});

    final result = await const AppStartupInitializer().initialize(
      config: testAppConfig(),
    );

    expect(
      result.state.sessionReadiness.status,
      SessionStatus.unauthenticated,
    );

    await pumpHosspiHmsApp(
      tester,
      overrides: result.providerOverrides(
        initialLocation: AppRoutes.patients.path,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
