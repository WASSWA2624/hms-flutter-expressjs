import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_planned_billing_inventory.dart';
import 'package:hosspi_hms/features/discharge/presentation/pages/discharge_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/section_layout_assertions.dart';

class _MockDischargeRepository extends Mock implements DischargeRepository {}

const IpdAdmissionSummary _planned = IpdAdmissionSummary(
  id: 'adm-planned-bill',
  displayId: 'ADM-PLAN-1',
  patientDisplayName: 'Planned Billing Patient',
  stage: 'DISCHARGE_PLANNED',
  dischargeStatus: 'PLANNED',
  wardDisplayName: 'Ward A',
  clearancePhase: 'BILLING_PENDING',
);

const DischargeAdmissionDetail _detail = DischargeAdmissionDetail(
  ipd: IpdAdmissionDetail(
    summary: _planned,
    latestDischargeSummary: IpdDischargeSummary(
      id: 'ds-1',
      status: 'PLANNED',
      summary: 'Plan ready; billing clearance pending.',
    ),
    dischargeSummaries: <IpdDischargeSummary>[
      IpdDischargeSummary(
        id: 'ds-1',
        status: 'PLANNED',
        summary: 'Plan ready; billing clearance pending.',
      ),
    ],
  ),
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  patientId: 'patient-planned-1',
  encounterId: 'encounter-planned-1',
  pharmacyOrders: <DischargeRelatedRecord>[
    DischargeRelatedRecord(
      id: 'rx-1',
      kind: 'pharmacy_order',
      title: 'Amoxicillin',
      status: 'ORDERED',
    ),
  ],
  invoices: <DischargeRelatedRecord>[
    DischargeRelatedRecord(
      id: 'inv-1',
      kind: 'invoice',
      title: 'Final bill',
      status: 'ISSUED',
      billingStatus: 'ISSUED',
      amount: 2500,
      currency: 'UGX',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  final bool needsPharmacy = permissions.contains(AppPermissions.pharmacyRead);
  final bool needsClinical = permissions.any(
    (AppPermission p) =>
        p == AppPermissions.clinicalRead || p == AppPermissions.clinicalWrite,
  );
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['DOCTOR'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements:
          modules ??
          <AppModuleEntitlement>[
            const AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            if (needsClinical)
              const AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            if (needsBilling)
              const AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
            if (needsPharmacy)
              const AppModuleEntitlement(
                code: 'pharmacy-dispensing',
                licenseStatus: 'ACTIVE',
              ),
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stub(_MockDischargeRepository repository) {
  when(() => repository.listQueue(any())).thenAnswer(
    (_) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[_planned],
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: 1,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<DischargeReferenceData>.success(DischargeReferenceData()),
  );
  when(() => repository.getAdmissionDetail(any())).thenAnswer(
    (_) async => const Result<DischargeAdmissionDetail>.success(_detail),
  );
  when(() => repository.createPharmacyOrder(any())).thenAnswer(
    (_) async => const Result<void>.success(null),
  );
}

Future<void> _pumpPlanned(
  WidgetTester tester, {
  required _MockDischargeRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stub(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/discharge?section=planned',
    routes: <RouteBase>[
      GoRoute(
        path: '/discharge',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: DischargeWorkspacePage(
              initialQuery: DischargeWorklistQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Text('Billing workspace ${state.uri.query}'),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        dischargeRepositoryProvider.overrideWithValue(repository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockDischargeRepository repository;

  setUpAll(() {
    registerFallbackValue(const DischargeWorklistQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockDischargeRepository();
  });

  group('Discharge Planned billing inventory (AC1)', () {
    test('every atom is classified billable or explicit not-billable', () {
      expect(DischargePlannedBillingInventory.atoms, isNotEmpty);
      expect(dischargePlannedBillingScopeNote, contains('Planned'));
      for (final DischargePlannedFinancialAtom atom
          in DischargePlannedBillingInventory.atoms) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        if (atom.financialClass == DischargePlannedFinancialClass.notBilled ||
            atom.financialClass ==
                DischargePlannedFinancialClass.notRequired ||
            atom.financialClass == DischargePlannedFinancialClass.noCharge) {
          expect(atom.auditCode, isNotNull);
        }
      }
    });

    test('mounted billable atoms wire through Billing (no bypass path)', () {
      expect(
        DischargePlannedBillingInventory.allMountedBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final DischargePlannedFinancialAtom atom
          in DischargePlannedBillingInventory.billableAtoms) {
        if (!atom.mounted) {
          continue;
        }
        if (DischargePlannedBillingInventory.isInlineCollectionForbidden(
          atom.financialClass,
        )) {
          expect(
            atom.billingPath,
            anyOf(contains('Billing'), contains('billing')),
          );
        }
      }
      expect(
        DischargePlannedAtomPermissions.requestBilling,
        same(billingReadRequirement),
      );
      expect(
        DischargePlannedAtomPermissions.openBilling,
        same(billingReadRequirement),
      );
    });

    test('pharmacy create-charge reuses clinical-request-billing path', () {
      expect(
        DischargePlannedBillingInventory.requestPharmacy.billingPath,
        contains('persistPharmacyOrderBilling'),
      );
      expect(
        DischargePlannedBillingInventory.requestPharmacy.financialClass,
        DischargePlannedFinancialClass.createCharge,
      );
    });

    test('finalize / continue defer through Billing ledger gate', () {
      expect(
        DischargePlannedBillingInventory.continueDischarge.billingPath,
        contains('assertBillingSettledForDischarge'),
      );
      expect(
        DischargePlannedBillingInventory.finalizeWithOverride.financialClass,
        DischargePlannedFinancialClass.defer,
      );
    });
  });

  group('Discharge Planned billing wiring (AC2-AC4)', () {
    test('discharge realtime group includes billing for status parity', () {
      expect(
        RealtimeEventGroups.discharge,
        containsAll(RealtimeEventGroups.billing),
      );
      expect(
        RealtimeEventGroups.discharge,
        containsAll(RealtimeEventGroups.pharmacy),
      );
    });

    testWidgets(
      'no bypass: unauthorized cannot collect/adjust; no local invoice dialog',
      (WidgetTester tester) async {
        await _pumpPlanned(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        expect(find.text('Planned Billing Patient'), findsOneWidget);
        await tester.tap(find.text('Planned Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.text('Request final billing'), findsNothing);
        expect(find.text('Create invoice request'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Open billing navigates to Billing workspace (reuse, no fork)',
      (WidgetTester tester) async {
        await _pumpPlanned(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
              AppPermissions.pharmacyRead,
            },
          ),
        );

        await tester.tap(find.text('Planned Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Final bill'), findsOneWidget);
        expect(find.text('Open billing'), findsWidgets);
        expect(find.text('Request final billing'), findsNothing);
        expect(find.text('Create invoice request'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing workspace'), findsOneWidget);
        expect(
          find.textContaining('patient_id=patient-planned-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'pharmacy request posts via repository (clinical-request-billing backend)',
      (WidgetTester tester) async {
        when(() => repository.loadReferenceData()).thenAnswer(
          (_) async => const Result<DischargeReferenceData>.success(
            DischargeReferenceData(
              drugs: <DischargeDrugOption>[
                DischargeDrugOption(id: 'drug-1', name: 'Amox'),
              ],
            ),
          ),
        );

        await _pumpPlanned(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
            },
          ),
        );

        await tester.tap(find.text('Planned Billing Patient'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Request medicines'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.byType(AppFormShell), findsOneWidget);
      },
    );

    testWidgets(
      'invoice status panel reflects Billing SoR (ISSUED parity)',
      (WidgetTester tester) async {
        await _pumpPlanned(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Planned Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Final bill'), findsOneWidget);
        expect(find.textContaining('Issued'), findsWidgets);
      },
    );

    testWidgets(
      'Manage clearance opens planning without inline cashier',
      (WidgetTester tester) async {
        await _pumpPlanned(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.byTooltip('Manage clearance').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsOneWidget);
        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.text('Create invoice request'), findsNothing);
        expectFlatSections(tester);
      },
    );
  });

  group('Discharge Planned flat sections (AC5)', () {
    testWidgets('desktop detail: no nested titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpPlanned(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
            AppPermissions.pharmacyRead,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.light,
      );
      expectFlatSections(tester);

      await tester.tap(find.text('Planned Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
      expect(countTitledSections(tester), greaterThan(0));
    });

    testWidgets('mobile + dark: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpPlanned(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );
      expectFlatSections(tester);
    });
  });
}
