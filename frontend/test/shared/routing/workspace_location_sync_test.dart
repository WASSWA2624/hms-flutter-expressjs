import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/shared/routing/workspace_location_sync.dart';

void main() {
  testWidgets('syncWorkspaceLocation uses go and updates the reported uri', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/nursing?scope=assigned-ward',
      routes: <RouteBase>[
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return Scaffold(
              body: Column(
                children: <Widget>[
                  Text('path:${state.uri.path}'),
                  Text('query:${state.uri.query}'),
                  child,
                ],
              ),
            );
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/nursing',
              builder: (BuildContext context, GoRouterState state) {
                return TextButton(
                  onPressed: () => syncWorkspaceLocation(context, '/opd'),
                  child: const Text('to-opd'),
                );
              },
            ),
            GoRoute(
              path: '/opd',
              builder: (BuildContext context, GoRouterState state) {
                return const Text('opd-page');
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('path:/nursing'), findsOneWidget);
    expect(find.text('query:scope=assigned-ward'), findsOneWidget);

    await tester.tap(find.text('to-opd'));
    await tester.pumpAndSettle();

    expect(find.text('opd-page'), findsOneWidget);
    expect(find.text('path:/opd'), findsOneWidget);
    expect(router.state.uri.path, '/opd');
  });

  testWidgets('syncWorkspaceLocation is a no-op when already on location', (
    WidgetTester tester,
  ) async {
    var buildCount = 0;
    final GoRouter router = GoRouter(
      initialLocation: '/opd?section=queue',
      routes: <RouteBase>[
        GoRoute(
          path: '/opd',
          builder: (BuildContext context, GoRouterState state) {
            buildCount += 1;
            return TextButton(
              onPressed: () =>
                  syncWorkspaceLocation(context, '/opd?section=queue'),
              child: const Text('resync'),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final int afterFirst = buildCount;

    await tester.tap(find.text('resync'));
    await tester.pumpAndSettle();

    expect(buildCount, afterFirst);
    expect(router.state.uri.toString(), '/opd?section=queue');
  });
}
