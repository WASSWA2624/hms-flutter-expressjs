import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/layout/shell_navigation_loading.dart';

void main() {
  group('ShellRouteChildRetention', () {
    testWidgets('keeps the previous route visible while loading', (
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
              child: Text('Patients'),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Patients'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: _RetentionHarness(
              routeKey: '/patients',
              isLoading: false,
              child: Text('Patients'),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsNothing);
      expect(find.text('Patients'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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
