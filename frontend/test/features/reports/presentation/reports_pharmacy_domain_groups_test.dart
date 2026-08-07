import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_search_bar.dart';

import '../../../helpers/test_harness.dart';

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
  required List<String> openedDatasets,
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
  setTestViewport(tester, const Size(720, 900));

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Builder(
              builder: (BuildContext context) {
                return SingleChildScrollView(
                  child: ReportsPharmacyDomainGroups(
                    l10n: AppLocalizations.of(context)!,
                    datasetShortcuts: datasetShortcuts,
                    onOpenDataset: openedDatasets.add,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('pharmacist overview shows Analytics and Reporting tabs without body copy', (
    tester,
  ) async {
    final List<String> openedDatasets = <String>[];

    await _pumpGroups(
      tester,
      openedDatasets: openedDatasets,
    );

    expect(find.text('Analysis'), findsNothing);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Reporting'), findsOneWidget);
    expect(
      find.textContaining('Explore consumption'),
      findsNothing,
    );
    expect(
      find.textContaining('Create, run, schedule'),
      findsNothing,
    );
    expect(find.text('Top consumed drugs'), findsOneWidget);
    expect(find.text('Suggested stocking focus'), findsOneWidget);
    expect(find.text('Create or run report'), findsNothing);

    await tester.ensureVisible(find.text('Top consumed drugs'));
    await tester.tap(find.text('Top consumed drugs'));
    await tester.pump();
    expect(openedDatasets, contains('pharmacy_drug_consumption'));

    await tester.tap(find.text('Reporting'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSearchBar), findsOneWidget);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.text('Browse catalog'), findsNothing);
    expect(find.text('Create or run report'), findsNothing);
    expect(find.textContaining('Create, run, schedule'), findsNothing);
    expect(find.text('Top consumed drugs'), findsNothing);
  });

  testWidgets('reporting tab notifies parent when selected', (tester) async {
    final List<String> openedDatasets = <String>[];
    final List<String> selectedTabs = <String>[];

    setTestViewport(tester, const Size(720, 900));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Builder(
                builder: (BuildContext context) {
                  return ReportsPharmacyDomainGroups(
                    l10n: AppLocalizations.of(context)!,
                    datasetShortcuts: const <ReportsLookupOption>[
                      ReportsLookupOption(
                        id: 'pharmacy_drug_consumption',
                        label: 'Pharmacy drug consumption',
                      ),
                    ],
                    onOpenDataset: openedDatasets.add,
                    onTabChanged: selectedTabs.add,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reporting'));
    await tester.pumpAndSettle();

    expect(
      selectedTabs,
      contains(ReportsPharmacyDomainGroups.reportingTabId),
    );
  });

  testWidgets('reporting filters button opens advanced filters dialog', (
    tester,
  ) async {
    final List<String> openedDatasets = <String>[];

    await _pumpGroups(
      tester,
      openedDatasets: openedDatasets,
    );

    await tester.tap(find.text('Reporting'));
    await tester.pumpAndSettle();

    final Finder filtersButton = find.descendant(
      of: find.byType(AppSearchBar),
      matching: find.byTooltip('Filters'),
    );
    expect(filtersButton, findsOneWidget);
    await tester.ensureVisible(filtersButton);
    await tester.tap(filtersButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(AppDialog.shellKey), findsOneWidget);
    expect(find.text('ADVANCED FILTERS'), findsOneWidget);
    expect(find.text('Report category'), findsOneWidget);
    expect(find.text('Date range'), findsOneWidget);
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
