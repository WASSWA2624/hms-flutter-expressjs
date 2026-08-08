import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_report_admins_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';

void main() {
  testWidgets('report admins dialog opens maximized with hierarchy contacts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showSubscriptionReportAdminsDialog(
                      context,
                      headerState: TenantSubscriptionHeaderState.active,
                      facilityAdmins: const <OrgAdminContact>[
                        OrgAdminContact(
                          id: 'f1',
                          fullName: 'Facility Admin',
                          email: 'facility.admin@hosspi.com',
                          phone: '+256700000010',
                          roleName: 'FACILITY_ADMIN',
                        ),
                      ],
                      tenantAdmins: const <OrgAdminContact>[
                        OrgAdminContact(
                          id: 't1',
                          fullName: 'Tenant Admin',
                          email: 'tenant.admin@hosspi.com',
                          phone: '+256700000011',
                          roleName: 'TENANT_ADMIN',
                        ),
                      ],
                      platformAdmins: const <OrgAdminContact>[
                        OrgAdminContact(
                          id: 'p1',
                          fullName: 'Platform Demo',
                          email: 'super.admin@hosspi.com',
                          phone: '+256700000012',
                          roleName: 'SUPER_ADMIN',
                        ),
                        OrgAdminContact(
                          email: 'support@hosspi.com',
                          phone: '+256700000013',
                          roleName: 'PLATFORM_SUPPORT',
                          isSupportChannel: true,
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.initialMaximized, isTrue);
    expect(find.text('Facility Admin'), findsOneWidget);
    expect(find.text('Tenant Admin'), findsOneWidget);
    expect(find.text('Platform Demo'), findsOneWidget);
    expect(find.text('Hosspi platform support'), findsOneWidget);
    expect(find.text('facility.admin@hosspi.com'), findsOneWidget);
    expect(find.text('super.admin@hosspi.com'), findsOneWidget);
  });
}
