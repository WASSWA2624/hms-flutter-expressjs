import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: pharmacyDispensingModule,
      licenseStatus: 'ACTIVE',
    ),
    AppModuleEntitlement(
      code: billingPaymentsModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  List<String> roles = const <String>['PHARMACIST'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBootstrap(_MockPharmacyRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer(
    (_) async => const Result<PharmacyWorkbench>.success(
      PharmacyWorkbench(
        summary: PharmacyWorkbenchSummary(),
        orders: AppPage<PharmacyOrder>(
          items: <PharmacyOrder>[],
          request: AppPageRequest(),
        ),
      ),
    ),
  );
  when(() => repository.searchDrugs(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyDrug>>.success(
      AppPage<PharmacyDrug>(items: <PharmacyDrug>[], request: AppPageRequest()),
    ),
  );
  when(() => repository.getInventoryStock(any())).thenAnswer(
    (_) async => const Result<PharmacyInventoryWorkbench>.success(
      PharmacyInventoryWorkbench(
        summary: PharmacyInventoryStockSummary(),
        stocks: AppPage<PharmacyInventoryStock>(
          items: <PharmacyInventoryStock>[],
          request: AppPageRequest(),
        ),
      ),
    ),
  );
  when(
    () => repository.loadStorageLayout(
      includeInactive: any(named: 'includeInactive'),
      includeDeleted: any(named: 'includeDeleted'),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<PharmacyStorageLayout>.success(PharmacyStorageLayout()),
  );
  when(() => repository.listFormularyItems(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyFormularyItem>>.success(
      AppPage<PharmacyFormularyItem>(
        items: <PharmacyFormularyItem>[],
        request: AppPageRequest(),
      ),
    ),
  );
}

Future<void> _pumpEditDialog(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  required _MockPharmacyRepository repository,
}) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pharmacyRepositoryProvider.overrideWithValue(repository),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: PharmacyDrugEditDialog(
            drug: PharmacyDrug(
              id: 'drug-1',
              name: 'Paracetamol',
              genericName: 'Paracetamol',
              pharmacyUnitPrice: 500,
              facilityUnitPrice: 450,
              isOfferedAtFacility: true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MockPharmacyRepository repository;

  setUpAll(() {
    registerFallbackValue(const PharmacyWorkbenchQuery());
    registerFallbackValue(const PharmacyDrugQuery());
    registerFallbackValue(const PharmacyFormularyQuery());
    registerFallbackValue(const PharmacyInventoryStockQuery());
  });

  setUp(() {
    repository = _MockPharmacyRepository();
    _stubBootstrap(repository);
  });

  testWidgets('shows pharmacy price only when pricing:pharmacy_write granted', (
    WidgetTester tester,
  ) async {
    await _pumpEditDialog(
      tester,
      repository: repository,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.pharmacyWrite,
          AppPermissions.pricingPharmacyWrite,
        },
      ),
    );

    expect(find.text('Pricing'), findsOneWidget);
    expect(find.textContaining('Pharmacy buy'), findsOneWidget);
    expect(find.textContaining('Pharmacy sell'), findsOneWidget);
    expect(find.textContaining('Transfer price'), findsOneWidget);
    expect(find.textContaining('Facility patient price'), findsNothing);
  });

  testWidgets('shows facility price only when pricing:facility_write granted', (
    WidgetTester tester,
  ) async {
    await _pumpEditDialog(
      tester,
      repository: repository,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingWrite,
          AppPermissions.pricingFacilityWrite,
        },
        roles: const <String>['BILLING'],
      ),
    );

    expect(find.text('Pricing'), findsOneWidget);
    expect(find.textContaining('Facility patient price'), findsOneWidget);
    expect(find.textContaining('Pharmacy sell'), findsNothing);
    expect(find.textContaining('Pharmacy buy'), findsNothing);
    expect(find.textContaining('Transfer price'), findsNothing);
  });

  testWidgets('shows both price fields for admin with both pricing writes', (
    WidgetTester tester,
  ) async {
    await _pumpEditDialog(
      tester,
      repository: repository,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.pricingPharmacyWrite,
          AppPermissions.pricingFacilityWrite,
        },
        roles: const <String>['FACILITY_ADMIN'],
      ),
    );

    expect(find.text('Pricing'), findsOneWidget);
    expect(find.textContaining('Pharmacy buy'), findsOneWidget);
    expect(find.textContaining('Pharmacy sell'), findsOneWidget);
    expect(find.textContaining('Transfer price'), findsOneWidget);
    expect(find.textContaining('Facility patient price'), findsOneWidget);
  });

  testWidgets('hides pricing section when neither pricing write is granted', (
    WidgetTester tester,
  ) async {
    await _pumpEditDialog(
      tester,
      repository: repository,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
      ),
    );

    expect(find.text('Pricing'), findsNothing);
    expect(find.textContaining('Pharmacy sell'), findsNothing);
    expect(find.textContaining('Facility patient price'), findsNothing);
  });
}
