import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_insurance_setup_billing_inventory.dart';
import 'package:hosspi_hms/features/claims/presentation/pages/claims_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockClaimsRepository extends Mock implements ClaimsRepository {}

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  authorizationPendingCount: 0,
  authorizationApprovedCount: 0,
  submittedClaimsCount: 0,
  approvedClaimsCount: 0,
  paidClosedCount: 0,
);

const InsuranceCompanyOption _company = InsuranceCompanyOption(
  id: 'co-1',
  displayId: 'INS-1',
  name: 'Acme Insurance',
  code: 'ACME',
);

const CoveragePlanOption _plan = CoveragePlanOption(
  id: 'plan-1',
  displayId: 'PLN-1',
  name: 'Gold Plan',
  insuranceCompanyId: 'co-1',
  coveragePercentage: 80,
);

const ClaimsReferenceData _referenceData = ClaimsReferenceData(
  insuranceCompanies: <InsuranceCompanyOption>[_company],
  coveragePlans: <CoveragePlanOption>[_plan],
);

AuthSession _sessionForPolicy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    user: const AuthUserProfile(
      roles: <String>['BILLING'],
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    ),
    permissions: permissions,
    moduleEntitlements: modules,
    isAuthorizationHydrated: true,
  );
}

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    _sessionForPolicy(permissions: permissions, modules: modules),
  );
}

void _stubClaimsRepository(_MockClaimsRepository repository) {
  when(() => repository.listQueue(any())).thenAnswer(
    (_) async => Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: const <ClaimsQueueItem>[],
        request: const AppPageRequest(),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<ClaimsReferenceData>.success(_referenceData),
  );
  when(() => repository.loadWorkspaceSummary()).thenAnswer(
    (_) async => const Result<ClaimsWorkspaceSummary>.success(_summary),
  );
}

Future<void> _pumpInsuranceSetupTab(
  WidgetTester tester, {
  required _MockClaimsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubClaimsRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/claims?section=insurance-setup',
    routes: <RouteBase>[
      GoRoute(
        path: '/claims',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ClaimsWorkspacePage(
              initialQuery: ClaimsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        claimsRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockClaimsRepository repository;

  setUpAll(() {
    registerFallbackValue(const ClaimsQueueQuery());
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  group('Claims Insurance Setup financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        ClaimsInsuranceSetupBillingInventory.insuranceSetupTabHasNoBillableActions,
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(ClaimsInsuranceSetupBillingInventory.atoms, isNotEmpty);
      expect(
        ClaimsInsuranceSetupBillingInventory.billableClasses.every(
          (ClaimsInsuranceSetupFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(claimsInsuranceSetupBillingScopeNote, contains('NOT_BILLED'));
      expect(claimsInsuranceSetupBillingScopeNote, contains('price-resolver'));

      for (final ClaimsInsuranceSetupFinancialAtom atom
          in ClaimsInsuranceSetupBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<ClaimsInsuranceSetupFinancialClass>[
            ClaimsInsuranceSetupFinancialClass.notRequired,
            ClaimsInsuranceSetupFinancialClass.notBilled,
            ClaimsInsuranceSetupFinancialClass.noCharge,
          ]),
          reason: atom.id,
        );
        expect(
          atom.auditCode,
          isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
          reason: atom.id,
        );
      }
    });

    test('catalog creates stay NOT_BILLED (prospective pricing config)', () {
      for (final String id in <String>[
        'add_company',
        'add_scheme',
        'add_offer',
        'enroll_patient',
        'add_price_book',
        'insurer_api',
      ]) {
        final ClaimsInsuranceSetupFinancialAtom atom =
            ClaimsInsuranceSetupBillingInventory.atoms.singleWhere(
              (ClaimsInsuranceSetupFinancialAtom a) => a.id == id,
            );
        expect(atom.mounted, isTrue, reason: id);
        expect(
          atom.financialClass,
          ClaimsInsuranceSetupFinancialClass.notBilled,
          reason: id,
        );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
      }
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        ClaimsInsuranceSetupBillingInventory.atoms
            .singleWhere(
              (ClaimsInsuranceSetupFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupBillingInventory.atoms
            .singleWhere(
              (ClaimsInsuranceSetupFinancialAtom atom) =>
                  atom.id == 'issue_invoice',
            )
            .mounted,
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupBillingInventory.atoms
            .singleWhere(
              (ClaimsInsuranceSetupFinancialAtom atom) =>
                  atom.id == 'silent_enrollment_auto_verify',
            )
            .mounted,
        isFalse,
      );
      expect(claimsInsuranceSetupBillingScopeNote, contains('Billing'));
    });
  });

  group('Claims Insurance Setup billing bypass (AC2–AC4)', () {
    testWidgets('panel has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.textContaining('Write off'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Add company'), findsOneWidget);
      expect(find.textContaining('Add price'), findsOneWidget);
      expect(find.byType(AppListTable<ClaimsQueueItem>), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'Add company dialog: catalog form only — no Billing collect chrome',
      (WidgetTester tester) async {
        await _pumpInsuranceSetupTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            },
          ),
        );

        await tester.tap(find.textContaining('Add company'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Payment method'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('unauthorized reader cannot collect or create catalog', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(reader),
        isFalse,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('Enroll patient'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('Claims Insurance Setup section layout (AC5)', () {
    testWidgets('desktop light: flat titled sections', (WidgetTester tester) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.light,
      );

      expect(find.textContaining('Insurance Setup'), findsWidgets);
      expectFlatSections(tester);
    });

    testWidgets('mobile dark: flat titled sections', (WidgetTester tester) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      expect(find.textContaining('Insurance Setup'), findsWidgets);
      expectFlatSections(tester);
    });

    testWidgets('catalog dialog keeps flat section layout', (
      WidgetTester tester,
    ) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.textContaining('Add scheme'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);

      await tester.tap(find.textContaining('Cancel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Add price'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Payment method'), findsNothing);
      expectFlatSections(tester);
    });
  });
}
