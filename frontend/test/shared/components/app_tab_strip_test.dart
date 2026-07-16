import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_tab_strip.dart';

void main() {
  test('appTabToolbarLabel truncates to 10 characters', () {
    expect(appTabToolbarLabel('Refresh'), 'Refresh');
    expect(appTabToolbarLabel('New test'), 'New test');
    expect(appTabToolbarLabel('Start walk-in'), 'Start walk');
    expect(appTabToolbarLabel('  Assign  '), 'Assign');
  });

  testWidgets('renders conspicuous selected tab and dense toolbar', (
    WidgetTester tester,
  ) async {
    String selected = 'pending';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppTabStrip(
                tabs: const <AppTabItem>[
                  AppTabItem(id: 'pending', label: 'Pending', count: 12),
                  AppTabItem(id: 'results', label: 'Results', count: 3),
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
    expect(find.text('New test o'), findsOneWidget);

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);
  });
}
