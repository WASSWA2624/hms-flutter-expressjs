import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/layout/shell_navigation_loading.dart';

void main() {
  group('ShellRouteChildRetention', () {
    testWidgets('swaps to the destination on the same frame as the route change', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _RetentionHarness(
              routeKey: '/home',
              isLoading: false,
              child: Text('Home'),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _RetentionHarness(
              routeKey: '/patients',
              isLoading: true,
              child: Text('Patients loading'),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsNothing);
      expect(find.text('Patients loading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'does not keep a previous route when destination shows loading chrome',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: _RetentionHarness(
                routeKey: '/home',
                isLoading: false,
                child: Text('Home'),
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: _RetentionHarness(
                routeKey: '/radiology',
                isLoading: true,
                child: Text('Radiology loading'),
              ),
            ),
          ),
        );

        expect(find.text('Home'), findsNothing);
        expect(find.text('Radiology loading'), findsOneWidget);
      },
    );

    testWidgets('keys the child by route so identity updates with navigation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _RetentionHarness(
              routeKey: '/home',
              isLoading: false,
              child: Text('Home'),
            ),
          ),
        ),
      );

      final Key homeKey = tester
          .widget<KeyedSubtree>(find.byType(KeyedSubtree))
          .key!;
      expect(homeKey, const ValueKey<String>('/home'));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _RetentionHarness(
              routeKey: '/settings',
              isLoading: false,
              child: Text('Settings'),
            ),
          ),
        ),
      );

      final Key settingsKey = tester
          .widget<KeyedSubtree>(find.byType(KeyedSubtree))
          .key!;
      expect(settingsKey, const ValueKey<String>('/settings'));
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('ShellLoadingReporter', () {
    testWidgets('marks shell loading after the destination mounts', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ShellLoadingReporter(
              isLoading: true,
              child: Text('Loading child'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(container.read(shellNavigationLoadingProvider), isTrue);
      expect(find.text('Loading child'), findsOneWidget);
    });

    testWidgets('clears shell loading after dispose settles', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ShellLoadingReporter(
              isLoading: true,
              child: Text('Loading child'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(container.read(shellNavigationLoadingProvider), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Text('Gone')),
        ),
      );
      await tester.pump();

      expect(container.read(shellNavigationLoadingProvider), isFalse);
    });
  });

  group('AsyncStateScaffold deferred shell loading', () {
    testWidgets(
      'paints loading chrome instead of an empty content area',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ShellNavigationScope(
                deferLoadingToShell: true,
                child: AsyncStateScaffold<String>(
                  value: const AsyncValue<Result<String>>.loading(),
                  loadingTitle: 'Loading patients',
                  loadingBody: 'Fetching the registry.',
                  dataBuilder: (_, String data) => Text(data),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Loading patients'), findsOneWidget);
        expect(find.text('Fetching the registry.'), findsOneWidget);
        expect(find.byType(AppStateScaffold), findsOneWidget);
      },
    );
  });
}

class _RetentionHarness extends StatelessWidget {
  const _RetentionHarness({
    required this.routeKey,
    required this.isLoading,
    required this.child,
  });

  final String routeKey;
  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShellRouteChildRetention(
      routeKey: routeKey,
      isLoading: isLoading,
      child: child,
    );
  }
}
