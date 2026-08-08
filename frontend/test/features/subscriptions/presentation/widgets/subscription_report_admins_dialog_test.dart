import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/widgets/subscription_report_admins_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';

void main() {
  testWidgets(
    'report admins dialog shows package, upgrade guidance, and contacts',
    (WidgetTester tester) async {
      final List<String> copiedValues = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final Map<Object?, Object?> arguments = Map<Object?, Object?>.from(
              methodCall.arguments as Map,
            );
            copiedValues.add(arguments['text']! as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

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
                        summary: TenantSubscriptionSummary(
                          subscriptionId: 'sub-1',
                          planLabel: 'Pro',
                          tierCode: 'PRO',
                          nextPlanLabel: 'Custom',
                          daysUntilExpiry: 5,
                          endDate: DateTime.utc(2026, 8, 20),
                          headerState:
                              TenantSubscriptionHeaderState.expiringSoon,
                        ),
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
                            email: 'platform.admin@hosspi.com',
                            phone: '+256700000012',
                            roleName: 'PLATFORM_ADMIN',
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
      expect(find.text('Current package'), findsOneWidget);
      expect(find.text('Pro'), findsWidgets);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Expiring soon'), findsOneWidget);
      expect(find.text('Subscription ends soon'), findsOneWidget);
      expect(find.textContaining('expires in 5 days'), findsOneWidget);
      expect(find.textContaining('upgrade you to Custom'), findsOneWidget);
      expect(find.text('Facility Admin'), findsOneWidget);
      expect(find.text('Tenant Admin'), findsOneWidget);
      expect(find.text('Platform Demo'), findsOneWidget);
      expect(find.text('Hosspi platform support'), findsOneWidget);
      expect(find.byType(AppCopyableIdentifier), findsWidgets);

      await tester.tap(find.text('facility.admin@hosspi.com'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(copiedValues, <String>['facility.admin@hosspi.com']);
      expect(find.text('Email copied.'), findsOneWidget);

      await tester.tap(find.text('+256700000010'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(copiedValues, <String>[
        'facility.admin@hosspi.com',
        '+256700000010',
      ]);
    },
  );
}
