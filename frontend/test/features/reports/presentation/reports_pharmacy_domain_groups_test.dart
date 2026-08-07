import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_catalog.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/pharmacy_reporting_filters_dialog.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_search_bar.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';

import '../../../helpers/test_harness.dart';

AppAccessPolicy _pharmacyPolicy({
  bool canWrite = false,
  bool canExport = false,
}) {
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
        if (canExport) AppPermissions.evidenceExport,
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
  AppAccessPolicy? policy,
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
  setTestViewport(tester, const Size(1100, 1400));

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
                    policy: policy ?? _pharmacyPolicy(),
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
  test('pharmacy reporting catalog covers every documented category', () {
    final List<PharmacyReportingCategory> catalog = pharmacyReportingCatalog();
    expect(catalog, hasLength(17));
    expect(
      catalog.map((PharmacyReportingCategory c) => c.id).toSet(),
      containsAll(<String>[
        PharmacyReportingCategoryIds.salesRevenue,
        PharmacyReportingCategoryIds.inventoryStock,
        PharmacyReportingCategoryIds.managementExecutive,
      ]),
    );
    expect(
      catalog.every(
        (PharmacyReportingCategory category) => category.reports.isNotEmpty,
      ),
      isTrue,
    );
  });

  testWidgets('pharmacist overview defaults to Reporting with catalog and no Analytics body copy', (
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
      tester.getTopLeft(find.text('Reporting')).dx,
      lessThan(tester.getTopLeft(find.text('Analytics')).dx),
    );
    expect(
      find.textContaining('Explore consumption'),
      findsNothing,
    );
    expect(find.byType(AppSearchBar), findsOneWidget);
    expect(find.byTooltip('Expand all'), findsOneWidget);
    expect(find.text('Sales & revenue'), findsOneWidget);
    expect(find.text('Total sales'), findsNothing);
    expect(find.text('Top consumed drugs'), findsNothing);

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Collapse all'), findsOneWidget);
    expect(find.text('Total sales'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse all'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand all'), findsOneWidget);
    expect(find.text('Total sales'), findsNothing);

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pumpAndSettle();
    expect(find.text('Total sales'), findsOneWidget);

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Top consumed drugs'), findsOneWidget);
    expect(find.byType(AppSearchBar), findsNothing);

    await tester.ensureVisible(find.text('Top consumed drugs'));
    await tester.tap(find.text('Top consumed drugs'));
    await tester.pump();
    expect(openedDatasets, contains('pharmacy_drug_consumption'));
  });

  testWidgets('reporting search filters subcategory buttons', (tester) async {
    final List<String> openedDatasets = <String>[];

    await _pumpGroups(tester, openedDatasets: openedDatasets);

    await tester.enterText(
      find.byType(TextField).first,
      'Total sales',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.widgetWithText(ActionChip, 'Total sales'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Stock value'), findsNothing);
  });

  testWidgets('reporting subcategory opens in-place dialog without export when unauthorized', (
    tester,
  ) async {
    final List<String> openedDatasets = <String>[];

    await _pumpGroups(tester, openedDatasets: openedDatasets);

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Total sales'));
    await tester.tap(find.text('Total sales'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('TOTAL SALES'), findsOneWidget);
    expect(find.text('Last month'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(AppSelectField<ModuleReportingPeriodPreset>), findsOneWidget);
    expect(find.text('Print'), findsNothing);
    expect(find.text('Export'), findsNothing);
    expect(find.text('Export Excel'), findsNothing);
    expect(find.text('Export PDF'), findsNothing);

    await tester.tap(find.byType(AppSelectField<ModuleReportingPeriodPreset>));
    await tester.pumpAndSettle();
    final Finder customOption = find.text('Custom').last;
    await tester.ensureVisible(customOption);
    await tester.pumpAndSettle();
    await tester.tap(customOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('CUSTOM DATE RANGE'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
  });

  testWidgets('reporting dialog shows print and export when entitled', (
    tester,
  ) async {
    final List<String> openedDatasets = <String>[];

    await _pumpGroups(
      tester,
      openedDatasets: openedDatasets,
      policy: _pharmacyPolicy(canExport: true),
    );

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Total sales'));
    await tester.tap(find.text('Total sales'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('EXPORT REPORT'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('reporting filters button opens advanced filters dialog', (
    tester,
  ) async {
    final List<String> openedDatasets = <String>[];

    await _pumpGroups(
      tester,
      openedDatasets: openedDatasets,
    );

    final Finder filtersButton = find.descendant(
      of: find.byType(AppSearchBar),
      matching: find.byTooltip('Filters'),
    );
    expect(filtersButton, findsOneWidget);
    await tester.ensureVisible(filtersButton);
    await tester.tap(filtersButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ADVANCED FILTERS'), findsOneWidget);
    expect(find.text('Date range'), findsOneWidget);
    expect(find.text('Report type'), findsOneWidget);
    expect(find.text('Report category'), findsOneWidget);
    expect(find.text('Report'), findsWidgets);
    expect(find.text('All'), findsWidgets);
    expect(
      find.textContaining('Leave From and To empty'),
      findsOneWidget,
    );

    final Finder dialog = find.byType(ModuleReportingFiltersDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Sales & revenue')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Total sales')),
      findsOneWidget,
    );
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
