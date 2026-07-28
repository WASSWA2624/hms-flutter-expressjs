import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

void main() {
  Future<GoRouter> pumpAuthRequired(
    WidgetTester tester, {
    String initialLocation = '/auth-required',
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
          path: '/auth-required',
          builder: (_, _) => const AuthRequiredPage(),
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
      MaterialApp.router(
        routerConfig: router,
        theme: theme ?? AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'shows one Sign in entry and no Go to dashboard duplicate',
    (WidgetTester tester) async {
      await pumpAuthRequired(tester);

      final l10n = tester.element(find.byType(AuthRequiredPage)).l10n;

      expect(find.text(l10n.routeAuthRequiredTitle), findsOneWidget);
      expect(find.text(l10n.routeAuthRequiredBody), findsOneWidget);
      expect(find.text(l10n.authLoginActionLabel), findsOneWidget);
      expect(find.text(l10n.commonGoHomeActionLabel), findsNothing);
    },
  );

  testWidgets('Sign in opens login and preserves from', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpAuthRequired(
      tester,
      initialLocation: '/auth-required?from=%2Fpatients',
    );

    final l10n = tester.element(find.byType(AuthRequiredPage)).l10n;

    expect(find.text('/patients'), findsOneWidget);

    await tester.tap(find.text(l10n.authLoginActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('login:/patients'), findsOneWidget);
    expect(find.byType(AuthRequiredPage), findsNothing);
    expect(router.state.uri.path, '/login');
    expect(router.state.uri.queryParameters['from'], '/patients');
  });

  testWidgets('Sign in without from opens login only', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpAuthRequired(tester);
    final l10n = tester.element(find.byType(AuthRequiredPage)).l10n;

    await tester.tap(find.text(l10n.authLoginActionLabel));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(router.state.uri.path, '/login');
    expect(router.state.uri.queryParameters.containsKey('from'), isFalse);
  });

  testWidgets('renders on narrow viewport and dark theme', (
    WidgetTester tester,
  ) async {
    await pumpAuthRequired(
      tester,
      theme: AppTheme.dark,
      size: const Size(320, 640),
    );

    final l10n = tester.element(find.byType(AuthRequiredPage)).l10n;

    expect(find.text(l10n.routeAuthRequiredTitle), findsOneWidget);
    expect(find.text(l10n.authLoginActionLabel), findsOneWidget);
    expect(find.text(l10n.commonGoHomeActionLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
