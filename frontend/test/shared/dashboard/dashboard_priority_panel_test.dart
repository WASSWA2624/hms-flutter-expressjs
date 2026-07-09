import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_priority_panel.dart';

void main() {
  testWidgets('shows empty section title with management actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPriorityPanel(
            data: DashboardPriorityPanelData(
              emptySectionTitle: 'Platform management',
              emptyMessage: 'Manage tenants, facilities, roles, and users.',
              emptyActions: <DashboardQuickActionData>[
                DashboardQuickActionData(
                  label: 'Manage tenants',
                  icon: Icons.corporate_fare_outlined,
                  semanticsLabel: 'Manage tenants',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Platform management'), findsOneWidget);
    expect(
      find.text('Manage tenants, facilities, roles, and users.'),
      findsOneWidget,
    );
    expect(find.text('Manage tenants'), findsOneWidget);
    expect(find.byType(AppButton), findsWidgets);
  });
}
