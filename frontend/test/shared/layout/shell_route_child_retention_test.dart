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
      expect(find.text('Patients', skipOffstage: false), findsOneWidget);
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

    testWidgets(
      'does not flash a blank deferred child before loading is reported',
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

        // Route swap with isLoading still false — previously committed blank.
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: _RetentionHarness(
                routeKey: '/radiology',
                isLoading: false,
                child: ColoredBox(
                  color: Color(0x00000000),
                  child: SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Home'), findsOneWidget);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: _RetentionHarness(
                routeKey: '/radiology',
                isLoading: true,
                child: ColoredBox(
                  color: Color(0x00000000),
                  child: SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
        // Flush/cancel any never-loaded settle timers from the prior frame.
        await tester.pump(Duration.zero);
        expect(find.text('Home'), findsOneWidget);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: _RetentionHarness(
                routeKey: '/radiology',
                isLoading: false,
                child: Text('Radiology'),
              ),
            ),
          ),
        );

        expect(find.text('Home'), findsNothing);
        expect(find.text('Radiology'), findsOneWidget);
      },
    );

    testWidgets(
      'commits destinations that never report shell loading after settle',
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
                routeKey: '/settings',
                isLoading: false,
                child: Text('Settings'),
              ),
            ),
          ),
        );

        expect(find.text('Home'), findsOneWidget);

        await tester.pump(Duration.zero);
        await tester.pump(Duration.zero);
        await tester.pump();

        expect(find.text('Home'), findsNothing);
        expect(find.text('Settings'), findsOneWidget);
      },
    );

    testWidgets(
      'preserves pending route State across offstage commit',
      (WidgetTester tester) async {
        final GlobalKey<_ProbeState> probeKey = GlobalKey<_ProbeState>();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: _RetentionHarness(
                routeKey: '/home',
                isLoading: false,
                child: const Text('Home'),
              ),
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: _RetentionHarness(
                routeKey: '/ipd',
                isLoading: true,
                child: _Probe(key: probeKey, label: 'IPD'),
              ),
            ),
          ),
        );

        final _ProbeState offstageState = probeKey.currentState!;
        expect(find.text('IPD', skipOffstage: false), findsOneWidget);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: _RetentionHarness(
                routeKey: '/ipd',
                isLoading: false,
                child: _Probe(key: probeKey, label: 'IPD'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('IPD'), findsOneWidget);
        expect(
          identical(offstageState, probeKey.currentState),
          isTrue,
          reason: 'Route Element/State must survive Offstage → visible commit',
        );
        expect(tester.takeException(), isNull);
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

class _Probe extends StatefulWidget {
  const _Probe({required this.label, super.key});

  final String label;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => Text(widget.label);
}
