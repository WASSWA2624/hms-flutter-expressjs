import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

void main() {
  final SessionState authenticatedSession = SessionState.authenticated(
    session: AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        id: 'user-1',
        email: 'user@example.com',
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: <String>['nurse'],
      ),
    ),
  );

  Future<GoRouter> pumpForbidden(
    WidgetTester tester, {
    required SessionState sessionState,
    String initialLocation = '/forbidden',
    ThemeData? theme,
    Size size = const Size(800, 600),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final GoRouter router = GoRouter(
      initialLocation: initialLocation,
      routes: <RouteBase>[
        GoRoute(
          path: '/forbidden',
          builder: (_, _) => const ForbiddenPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (BuildContext context, GoRouterState state) {
            final String? from = state.uri.queryParameters['from'];
            return Scaffold(
              body: Text(from == null ? 'login' : 'login:$from'),
            );
          },
        ),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSessionStateProvider.overrideWithValue(sessionState),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: theme ?? AppTheme.light,
          darkTheme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'authenticated denial shows one Go to dashboard and no Sign in',
    (WidgetTester tester) async {
      await pumpForbidden(
        tester,
        sessionState: authenticatedSession,
        initialLocation: '/forbidden?from=%2Fpatients',
      );

      final l10n = tester.element(find.byType(ForbiddenPage)).l10n;

      expect(find.text(l10n.routeForbiddenTitle), findsOneWidget);
      expect(find.text('/patients'), findsOneWidget);
      expect(find.text(l10n.commonGoHomeActionLabel), findsOneWidget);
      expect(find.text(l10n.authLoginActionLabel), findsNothing);
    },
  );

  testWidgets('authenticated Go to dashboard opens home', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpForbidden(
      tester,
      sessionState: authenticatedSession,
      initialLocation: '/forbidden?from=%2Fpatients',
    );

    final l10n = tester.element(find.byType(ForbiddenPage)).l10n;

    await tester.tap(find.text(l10n.commonGoHomeActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(ForbiddenPage), findsNothing);
    expect(router.state.uri.path, '/');
  });

  testWidgets(
    'session forbidden shows one Sign in and no Go to dashboard',
    (WidgetTester tester) async {
      await pumpForbidden(
        tester,
        sessionState: const SessionState.forbidden(),
        initialLocation: '/forbidden?from=%2Fpatients',
      );

      final l10n = tester.element(find.byType(ForbiddenPage)).l10n;

      expect(find.text(l10n.routeForbiddenTitle), findsOneWidget);
      expect(find.text(l10n.routeForbiddenBody), findsOneWidget);
      expect(find.text(l10n.authLoginActionLabel), findsOneWidget);
      expect(find.text(l10n.commonGoHomeActionLabel), findsNothing);
      expect(find.text(l10n.accessDeniedPermissionRequired), findsNothing);
      expect(find.text(l10n.accessDeniedRoleRequired), findsNothing);
    },
  );

  testWidgets('session forbidden Sign in opens login and preserves from', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpForbidden(
      tester,
      sessionState: const SessionState.forbidden(),
      initialLocation: '/forbidden?from=%2Fpatients',
    );

    final l10n = tester.element(find.byType(ForbiddenPage)).l10n;

    expect(find.text('/patients'), findsOneWidget);

    await tester.tap(find.text(l10n.authLoginActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('login:/patients'), findsOneWidget);
    expect(find.byType(ForbiddenPage), findsNothing);
    expect(router.state.uri.path, '/login');
    expect(router.state.uri.queryParameters['from'], '/patients');
  });

  testWidgets('session forbidden Sign in without from opens login only', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpForbidden(
      tester,
      sessionState: const SessionState.forbidden(),
    );
    final l10n = tester.element(find.byType(ForbiddenPage)).l10n;

    await tester.tap(find.text(l10n.authLoginActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(router.state.uri.path, '/login');
    expect(router.state.uri.queryParameters.containsKey('from'), isFalse);
  });

  testWidgets('renders on narrow viewport and dark theme', (
    WidgetTester tester,
  ) async {
    await pumpForbidden(
      tester,
      sessionState: authenticatedSession,
      theme: AppTheme.dark,
      size: const Size(320, 640),
    );

    final l10n = tester.element(find.byType(ForbiddenPage)).l10n;

    expect(find.text(l10n.routeForbiddenTitle), findsOneWidget);
    expect(find.text(l10n.commonGoHomeActionLabel), findsOneWidget);
    expect(find.text(l10n.authLoginActionLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
