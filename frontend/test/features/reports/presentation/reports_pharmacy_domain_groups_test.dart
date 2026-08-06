import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

AppAccessPolicy _pharmacyPolicy({bool canWrite = false}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['PHARMACIST'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.pharmacyRead,
        AppPermissions.reportsRead,
        if (canWrite) AppPermissions.reportsWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'pharmacy'),
        AppModuleEntitlement(code: 'pharmacy-dispensing'),
        AppModuleEntitlement(code: 'reporting-analytics'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

Future<void> _pumpGroups(
  WidgetTester tester, {
  required AppAccessPolicy policy,
  required List<String> openedDatasets,
  required List<ReportsWorkspacePanel> openedPanels,
  List<ReportsLookupOption> datasetShortcuts = const <ReportsLookupOption>[
    ReportsLookupOption(
      id: 'pharmacy_drug_consumption',
      label: 'Pharmacy drug consumption',
    ),
    ReportsLookupOption(
      id: 'pharmacy_dispense_throughput',
      label: 'Pharmacy dispense throughput',
    ),
    ReportsLookupOption(
      id: 'inventory_stock_risk',
      label: 'Inventory stock risk',
    ),
  ],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return SingleChildScrollView(
              child: ReportsPharmacyDomainGroups(
                l10n: AppLocalizations.of(context)!,
                policy: policy,
                allowedPanels: const <ReportsWorkspacePanel>[
                  ReportsWorkspacePanel.overview,
                  ReportsWorkspacePanel.catalog,
                  ReportsWorkspacePanel.delivery,
                ],
                datasetShortcuts: datasetShortcuts,
                onOpenDataset: openedDatasets.add,
                onOpenPanel: openedPanels.add,
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('pharmacist overview shows Analytics and Reporting tabs only', (
    tester,
  ) async {
    final List<String> openedDatasets = <String>[];
    final List<ReportsWorkspacePanel> openedPanels = <ReportsWorkspacePanel>[];

    await _pumpGroups(
      tester,
      policy: _pharmacyPolicy(canWrite: true),
      openedDatasets: openedDatasets,
      openedPanels: openedPanels,
    );

    expect(find.text('Analysis'), findsNothing);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Reporting'), findsOneWidget);
    expect(find.text('Top consumed drugs'), findsOneWidget);
    expect(find.text('Suggested stocking focus'), findsOneWidget);
    expect(find.text('Pharmacy drug consumption'), findsOneWidget);
    expect(find.text('Create or run report'), findsNothing);

    await tester.ensureVisible(find.text('Top consumed drugs'));
    await tester.tap(find.text('Top consumed drugs'));
    await tester.pump();
    expect(openedDatasets, contains('pharmacy_drug_consumption'));

    await tester.tap(find.text('Reporting'));
    await tester.pumpAndSettle();
    expect(find.text('Create or run report'), findsOneWidget);
    expect(find.text('Browse catalog'), findsOneWidget);
    expect(find.text('Top consumed drugs'), findsNothing);

    await tester.ensureVisible(find.text('Create or run report'));
    await tester.tap(find.text('Create or run report'));
    await tester.pump();
    expect(openedPanels, contains(ReportsWorkspacePanel.catalog));
  });

  testWidgets('read-only pharmacist hides create report chip', (tester) async {
    final List<String> openedDatasets = <String>[];
    final List<ReportsWorkspacePanel> openedPanels = <ReportsWorkspacePanel>[];

    await _pumpGroups(
      tester,
      policy: _pharmacyPolicy(),
      openedDatasets: openedDatasets,
      openedPanels: openedPanels,
      datasetShortcuts: const <ReportsLookupOption>[
        ReportsLookupOption(
          id: 'pharmacy_drug_consumption',
          label: 'Pharmacy drug consumption',
        ),
      ],
    );

    await tester.tap(find.text('Reporting'));
    await tester.pumpAndSettle();

    expect(find.text('Create or run report'), findsNothing);
    expect(find.text('Browse catalog'), findsOneWidget);
  });

  test('shouldShow is true for pharmacy pack and false without pharmacy read', () {
    expect(ReportsPharmacyDomainGroups.shouldShow(_pharmacyPolicy()), isTrue);
    final AppAccessPolicy receptionOnly = AppAccessPolicy.fromSession(
      AuthSession(
        tokens: SessionTokens(accessToken: 'token'),
        user: const AuthUserProfile(
          roles: <String>['RECEPTIONIST'],
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
        ),
        permissions: <AppPermission>{
          AppPermissions.receptionRead,
          AppPermissions.reportsRead,
        },
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'reporting-analytics'),
        ],
        isAuthorizationHydrated: true,
      ),
    );
    expect(ReportsPharmacyDomainGroups.shouldShow(receptionOnly), isFalse);
  });
}
