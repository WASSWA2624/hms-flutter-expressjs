import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/shared/layout/responsive_shell_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpShellAtSize(
    WidgetTester tester,
    Size size, {
    ValueChanged<int>? onDestinationSelected,
    List<ResponsiveShellDestination> destinations =
        const <ResponsiveShellDestination>[
          ResponsiveShellDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
          ),
          ResponsiveShellDestination(
            label: 'Settings',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
          ),
        ],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: ResponsiveAppShell(
          title: 'Template',
          compactTitle: 'App',
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          child: const Text('Body'),
        ),
      ),
    );
  }

  group('ResponsiveShellScaffold', () {
    testWidgets('uses a drawer for mobile widths', (WidgetTester tester) async {
      await pumpShellAtSize(tester, const Size(320, 640));

      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      expect(scaffold.drawer, isNotNull);
      expect(find.byType(AppMenuBar), findsOneWidget);
      expect(find.byType(SideNavigation), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Online'), findsNothing);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the compact title on medium mobile widths', (
      WidgetTester tester,
    ) async {
      await pumpShellAtSize(tester, const Size(390, 844));

      expect(find.text('App'), findsOneWidget);
      expect(find.text('Template'), findsNothing);
      expect(find.text('Online'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('omits the mobile drawer for a single destination', (
      WidgetTester tester,
    ) async {
      await pumpShellAtSize(
        tester,
        const Size(320, 640),
        destinations: const <ResponsiveShellDestination>[
          ResponsiveShellDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
          ),
        ],
      );

      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      expect(scaffold.drawer, isNull);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Body'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses a compact sidebar for tablet widths', (
      WidgetTester tester,
    ) async {
      await pumpShellAtSize(tester, const Size(600, 800));

      expect(find.byType(AppMenuBar), findsOneWidget);
      expect(find.byType(SideNavigation), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses a sidebar for desktop widths', (
      WidgetTester tester,
    ) async {
      await pumpShellAtSize(tester, const Size(1200, 900));

      expect(find.byType(AppMenuBar), findsOneWidget);
      expect(find.byType(SideNavigation), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Template'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('collapses desktop sidebar labels from the header toggle', (
      WidgetTester tester,
    ) async {
      await pumpShellAtSize(tester, const Size(1200, 900));

      await tester.tap(find.byTooltip('Toggle sidebar'));
      await tester.pumpAndSettle();

      final sideNavigation = tester.widget<SideNavigation>(
        find.byType(SideNavigation),
      );

      expect(sideNavigation.collapsed, isTrue);
      expect(sideNavigation.width, 72);
      expect(find.text('Settings'), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens and closes the mobile drawer from header controls', (
      WidgetTester tester,
    ) async {
      await pumpShellAtSize(tester, const Size(320, 640));

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.byTooltip('Close navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selects desktop side navigation from the keyboard', (
      WidgetTester tester,
    ) async {
      int? selectedIndex;
      await pumpShellAtSize(
        tester,
        const Size(1200, 900),
        onDestinationSelected: (int index) {
          selectedIndex = index;
        },
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selectedIndex, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
