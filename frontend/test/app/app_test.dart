import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/app.dart';
import 'package:hosspi_hms/app/router/app_router.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/app/startup/app_startup_state.dart';
import 'package:hosspi_hms/app/startup/startup_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_readiness.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  const Locale englishLocale = Locale('en');
  final authenticatedSessionState = SessionState.authenticated(
    session: AuthSession(
      tokens: SessionTokens(accessToken: 'test-access-token'),
      subject: 'admin@example.com',
    ),
  );

  List<Object?> authenticatedOverrides({String? initialLocation}) {
    return <Object?>[
      initialSessionStateProvider.overrideWithValue(authenticatedSessionState),
      appStartupStateProvider.overrideWithValue(
        AppStartupState(
          themeMode: ThemeMode.system,
          locale: englishLocale,
          storageReadiness: const StorageReadiness.ready(),
          sessionReadiness: authenticatedSessionState,
        ),
      ),
      if (initialLocation != null)
        appInitialLocationProvider.overrideWithValue(initialLocation),
    ];
  }

  testWidgets('renders the HOSSPI HMS shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedOverrides().cast(),
        child: const HosspiHmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = tester.element(find.byType(HomePage)).l10n;

    expect(find.text(l10n.appTitle), findsWidgets);
    expect(find.text(l10n.appStatusOnlineLabel), findsOneWidget);
    expect(find.text(l10n.homeReadyTitle), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);

    for (final String serviceArea in l10n.homeServiceAreas) {
      expect(find.text(serviceArea), findsOneWidget);
    }
  });

  testWidgets('renders the home screen at 320px width', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedOverrides().cast(),
        child: const HosspiHmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = tester.element(find.byType(HomePage)).l10n;
    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

    expect(find.text(l10n.homeReadyTitle), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(scaffold.drawer, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the home screen at medium mobile width', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedOverrides().cast(),
        child: const HosspiHmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = tester.element(find.byType(HomePage)).l10n;

    expect(find.text(l10n.homeReadyTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates to settings and shows HMS preferences', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedOverrides().cast(),
        child: const HosspiHmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final homeContext = tester.element(find.byType(HomePage));
    final l10n = homeContext.l10n;

    GoRouter.of(homeContext).go('/settings');
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsTitle), findsWidgets);
    expect(find.text(l10n.settingsBody), findsOneWidget);
    expect(find.text(l10n.settingsLanguageFieldLabel), findsWidgets);
    expect(find.text(l10n.settingsThemeModeFieldLabel), findsOneWidget);
    expect(find.text(l10n.settingsLanguageEnglish), findsWidgets);
    expect(find.byType(AppLogo), findsOneWidget);
  });

  testWidgets('uses startup theme and locale providers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupStateProvider.overrideWithValue(
            AppStartupState(
              themeMode: ThemeMode.dark,
              locale: englishLocale,
              storageReadiness: const StorageReadiness.ready(),
              sessionReadiness: authenticatedSessionState,
            ),
          ),
          initialSessionStateProvider.overrideWithValue(
            authenticatedSessionState,
          ),
        ],
        child: const HosspiHmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(materialApp.themeMode, ThemeMode.dark);
    expect(materialApp.locale, englishLocale);
  });

  testWidgets('shows localized not-found UI for unknown routes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedOverrides().cast(),
        child: const HosspiHmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(HomePage))).go('/missing-route');
    await tester.pumpAndSettle();

    final l10n = tester.element(find.byType(NotFoundPage)).l10n;

    expect(find.text(l10n.routeNotFoundTitle), findsOneWidget);
    expect(find.text(l10n.routeNotFoundBody), findsOneWidget);
    expect(find.text('/missing-route'), findsOneWidget);
  });

  testWidgets('restores unknown initial locations to not-found UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authenticatedOverrides(
          initialLocation: '/missing-route',
        ).cast(),
        child: const HosspiHmsApp(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = tester.element(find.byType(NotFoundPage)).l10n;

    expect(find.text(l10n.routeNotFoundTitle), findsOneWidget);
    expect(find.text('/missing-route'), findsOneWidget);
  });
}
