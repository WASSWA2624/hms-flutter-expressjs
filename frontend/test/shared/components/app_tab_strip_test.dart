import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/shared/components/app_tab_strip.dart';

void main() {
  testWidgets('hides toolbar when there are no actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppTabStrip(
            tabs: const <AppTabItem>[
              AppTabItem(id: 'a', label: 'Pending', count: 2),
            ],
            selectedId: 'a',
            onTabTapped: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(AppTabToolbarAction), findsNothing);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
  });

  testWidgets('renders leading icons when provided on tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppTabStrip(
            tabs: const <AppTabItem>[
              AppTabItem(
                id: 'tenants',
                label: 'Tenants',
                icon: Icons.corporate_fare_outlined,
              ),
              AppTabItem(
                id: 'users',
                label: 'Users',
                icon: Icons.people_outline,
              ),
            ],
            selectedId: 'tenants',
            onTabTapped: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.corporate_fare_outlined), findsOneWidget);
    expect(find.byIcon(Icons.people_outline), findsOneWidget);
  });

  testWidgets('shows full button labels on large screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String selected = 'pending';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppTabStrip(
                tabs: const <AppTabItem>[
                  AppTabItem(
                    id: 'pending',
                    label: 'Pending',
                    count: 12,
                    countTone: AppTabCountTone.warning,
                  ),
                  AppTabItem(
                    id: 'results',
                    label: 'Results',
                    count: 3,
                    countTone: AppTabCountTone.info,
                  ),
                ],
                selectedId: selected,
                onTabTapped: (String id) => setState(() => selected = id),
                secondaryActions: <Widget>[
                  AppTabToolbarAction(
                    label: 'Refresh',
                    icon: Icons.refresh,
                    onPressed: () {},
                  ),
                ],
                primaryAction: AppTabToolbarPrimary(
                  label: 'New test order',
                  icon: Icons.add,
                  onPressed: () {},
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('New test order'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);
  });

  testWidgets('hides toolbar button labels on small screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppTabStrip(
            tabs: const <AppTabItem>[
              AppTabItem(id: 'pending', label: 'Pending'),
            ],
            selectedId: 'pending',
            onTabTapped: (_) {},
            secondaryActions: <Widget>[
              AppTabToolbarAction(
                label: 'Refresh',
                icon: Icons.refresh,
                onPressed: () {},
              ),
            ],
            primaryAction: AppTabToolbarPrimary(
              label: 'New test order',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Refresh'), findsNothing);
    expect(find.text('New test order'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shows overflow menu for tabs that do not fit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String selected = 'a';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppTabStrip(
                tabs: const <AppTabItem>[
                  AppTabItem(id: 'a', label: 'Appointments'),
                  AppTabItem(id: 'b', label: 'Desk queue'),
                  AppTabItem(id: 'c', label: 'High priority'),
                  AppTabItem(id: 'd', label: 'Active visits'),
                  AppTabItem(id: 'e', label: 'Follow-ups'),
                  AppTabItem(id: 'f', label: 'Payment gate'),
                ],
                selectedId: selected,
                onTabTapped: (String id) => setState(() => selected = id),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('tabOverflowMore')), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('Payment gate'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('tabOverflowMore')));
    await tester.pumpAndSettle();

    expect(find.text('Payment gate'), findsOneWidget);
    await tester.tap(find.text('Payment gate'));
    await tester.pumpAndSettle();

    expect(selected, 'f');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides overflow menu when all tabs fit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppTabStrip(
            tabs: const <AppTabItem>[
              AppTabItem(id: 'a', label: 'Pending'),
              AppTabItem(id: 'b', label: 'Results'),
            ],
            selectedId: 'a',
            onTabTapped: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('tabOverflowMore')), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('selected flared tab with icons does not overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(980, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppTabStrip(
            tabs: const <AppTabItem>[
              AppTabItem(
                id: 'tenants',
                label: 'Tenants',
                icon: Icons.corporate_fare_outlined,
              ),
              AppTabItem(
                id: 'facilities',
                label: 'Facilities',
                icon: Icons.apartment_outlined,
              ),
              AppTabItem(
                id: 'departments',
                label: 'Departments',
                icon: Icons.account_tree_outlined,
              ),
              AppTabItem(
                id: 'units',
                label: 'Units',
                icon: Icons.hub_outlined,
              ),
              AppTabItem(
                id: 'wards',
                label: 'Wards',
                icon: Icons.bed_outlined,
              ),
              AppTabItem(
                id: 'rooms',
                label: 'Rooms',
                icon: Icons.meeting_room_outlined,
              ),
              AppTabItem(
                id: 'beds',
                label: 'Beds',
                icon: Icons.hotel_outlined,
              ),
              AppTabItem(
                id: 'users',
                label: 'Users',
                icon: Icons.people_outline,
              ),
            ],
            selectedId: 'departments',
            onTabTapped: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Departments'), findsOneWidget);
  });
}
