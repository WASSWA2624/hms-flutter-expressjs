import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_priority_panel.dart';

void main() {
  testWidgets('shows empty section title with management actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardPriorityPanel(
                data: DashboardPriorityPanelData(
                  emptySectionTitle: 'Platform management',
                  emptyMessage: '',
                  showAlerts: false,
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform management'), findsOneWidget);
    expect(
      find.text('Manage tenants, facilities, roles, and users.'),
      findsNothing,
    );
    expect(find.text('Manage tenants'), findsOneWidget);
    expect(find.byIcon(Icons.corporate_fare_outlined), findsOneWidget);
  });
}
