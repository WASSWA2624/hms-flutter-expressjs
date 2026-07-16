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

  testWidgets('shows full button labels and flat primary action', (
    WidgetTester tester,
  ) async {
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
}
