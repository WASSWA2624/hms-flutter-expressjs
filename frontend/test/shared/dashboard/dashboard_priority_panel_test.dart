import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_priority_panel.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

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

  testWidgets(
    'spaces alerts above empty management queue',
    (WidgetTester tester) async {
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
                    emptySectionTitle: 'Facility management',
                    emptyMessage: '',
                    showAlerts: true,
                    alertsTitle: 'Facility alerts',
                    alertItems: <DashboardWorklistItemData>[
                      DashboardWorklistItemData(
                        title: 'Entitlement Denied Modules',
                        subtitle: '1 facility',
                        icon: Icons.warning_amber_rounded,
                      ),
                    ],
                    emptyActions: <DashboardQuickActionData>[
                      DashboardQuickActionData(
                        label: 'Add staff profile',
                        icon: Icons.badge_outlined,
                        semanticsLabel: 'Add staff profile',
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

      // Alerts render as one compact chip line - no section title, no card.
      expect(find.text('Facility alerts'), findsNothing);
      final Rect alertChip = tester.getRect(
        find.text(
          'Entitlement Denied Modules (1 facility)',
          findRichText: true,
        ),
      );
      final Rect managementTitle = tester.getRect(
        find.text('Facility management'),
      );
      expect(managementTitle.top, greaterThan(alertChip.bottom));
    },
  );

  testWidgets('renders alerts as minimal square-edged tags', (
    WidgetTester tester,
  ) async {
    int taps = 0;
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
                  showQueue: false,
                  showAlerts: true,
                  alertsTitle: 'Alerts',
                  alertItems: <DashboardWorklistItemData>[
                    DashboardWorklistItemData(
                      title: 'Tenants Without Subscription',
                      subtitle: '3',
                      icon: Icons.warning_amber_rounded,
                      status: const AppWorkspaceStatus(
                        label: 'Warning',
                        tone: AppWorkspaceStatusTone.warning,
                      ),
                      onTap: () => taps += 1,
                    ),
                    const DashboardWorklistItemData(
                      title: 'Integration Errors',
                      subtitle: '2',
                      icon: Icons.warning_amber_rounded,
                      status: AppWorkspaceStatus(
                        label: 'High',
                        tone: AppWorkspaceStatusTone.error,
                      ),
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

    // Count sits in brackets beside the label; no separate status badge.
    expect(
      find.text('Tenants Without Subscription (3)', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Integration Errors (2)', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Warning'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    // Square edges: alert tags never round their corners.
    for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(DashboardAlertsStrip),
        matching: find.byType(DecoratedBox),
      ),
    )) {
      expect((box.decoration as BoxDecoration).borderRadius, isNull);
    }

    await tester.tap(
      find.text('Tenants Without Subscription (3)', findRichText: true),
    );
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
