import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  Future<void> pumpSessionRestoring(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = const Size(800, 600),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final GoRouter router = GoRouter(
      initialLocation: '/session-restoring',
      routes: <RouteBase>[
        GoRoute(
          path: '/session-restoring',
          builder: (_, _) => const SessionRestoringPage(),
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
    // Loading indicator animates; do not pumpAndSettle.
    await tester.pump();
  }

  testWidgets(
    'shows loading wait surface and no Go to dashboard or Sign in',
    (WidgetTester tester) async {
      await pumpSessionRestoring(tester);

      final l10n = tester.element(find.byType(SessionRestoringPage)).l10n;

      expect(find.text(l10n.routeSessionRestoringTitle), findsOneWidget);
      expect(find.text(l10n.routeSessionRestoringBody), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text(l10n.commonGoHomeActionLabel), findsNothing);
      expect(find.text(l10n.authLoginActionLabel), findsNothing);
      expect(find.byType(AppButton), findsNothing);
    },
  );

  testWidgets('renders on narrow viewport and dark theme', (
    WidgetTester tester,
  ) async {
    await pumpSessionRestoring(
      tester,
      theme: AppTheme.dark,
      size: const Size(320, 640),
    );

    final l10n = tester.element(find.byType(SessionRestoringPage)).l10n;

    expect(find.text(l10n.routeSessionRestoringTitle), findsOneWidget);
    expect(find.text(l10n.routeSessionRestoringBody), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(find.text(l10n.commonGoHomeActionLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
