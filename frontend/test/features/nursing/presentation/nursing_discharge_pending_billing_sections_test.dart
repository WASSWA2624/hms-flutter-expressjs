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
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/nursing/data/repositories/nursing_repository_impl.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_discharge_pending_billing_inventory.dart';
import 'package:hosspi_hms/features/nursing/presentation/pages/nursing_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/section_layout_assertions.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _dischargePending = NursingPatientSummary(
  id: 'adm-disc-bill',
  admissionId: 'adm-disc-bill',
  displayId: 'ADM-DISC-BILL',
  patientId: 'patient-disc-bill-1',
  patientDisplayId: 'PT-DISC-BILL',
  patientDisplayName: 'Discharge Billing Patient',
  stage: 'DISCHARGE_PLANNED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward D',
  bedDisplayLabel: 'Bed 4',
  hasActiveBed: true,
  dischargeStatus: 'PLANNED',
);

const NursingPatientDetail _dischargeDetail = NursingPatientDetail(
  summary: _dischargePending,
  latestDischarge: NursingDischargeSummary(
    id: 'ds-bill-1',
    status: 'PLANNED',
    summary: 'Awaiting billing clearance.',
    billingCleared: false,
    nursingCleared: false,
  ),
);

const List<AppModuleEntitlement> _nursingModules = <AppModuleEntitlement>[
  AppModuleEntitlement(
    code: nursingInpatientBedModule,
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = _nursingModules,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        id: 'nurse-1',
        roles: <String>['NURSE'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _clinicalReadPolicy() {
  return _policy(permissions: <AppPermission>{AppPermissions.clinicalRead});
}

AppAccessPolicy _billingReadPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      ..._nursingModules,
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

AppAccessPolicy _writeWithBillingPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      ..._nursingModules,
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

void _stubRepository(_MockNursingRepository repository) {
  when(() => repository.listWardPatients(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingWorklistQuery query =
        invocation.positionalArguments.single as NursingWorklistQuery;
    final List<NursingPatientSummary> filtered =
        <NursingPatientSummary>[_dischargePending]
            .where(
              (NursingPatientSummary item) => item.matchesScope(query.scope),
            )
            .toList(growable: false);
    return Result<AppPage<NursingPatientSummary>>.success(
      AppPage<NursingPatientSummary>(
        items: filtered,
        request: query.pageRequest,
        totalItemCount: filtered.length,
      ),
    );
  });
  when(() => repository.listPendingHandovers()).thenAnswer(
    (_) async =>
        const Result<List<NursingHandover>>.success(<NursingHandover>[]),
  );
  when(() => repository.listCurrentRosters()).thenAnswer(
    (_) async => const Result<List<NursingRosterAssignment>>.success(
      <NursingRosterAssignment>[],
    ),
  );
  when(() => repository.loadPatientDetail(any())).thenAnswer(
    (_) async => const Result<NursingPatientDetail>.success(_dischargeDetail),
  );
  when(() => repository.addNursingNote(any(), any())).thenAnswer(
    (_) async => const Result<NursingPatientDetail>.success(_dischargeDetail),
  );
  when(() => repository.updateDischargeClearance(any(), any())).thenAnswer(
    (_) async => Result<NursingPatientDetail>.success(
      NursingPatientDetail(
        summary: _dischargePending,
        latestDischarge: const NursingDischargeSummary(
          id: 'ds-bill-1',
          status: 'PLANNED',
          summary: 'Awaiting billing clearance.',
          billingCleared: false,
          nursingCleared: true,
        ),
      ),
    ),
  );
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpDischargePendingTab(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/nursing?scope=discharge-pending',
    routes: <RouteBase>[
      GoRoute(
        path: '/nursing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: NursingWorkspacePage(
              initialQuery: NursingWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          final String? patientId = state.uri.queryParameters['patient_id'];
          return Scaffold(
            body: Text(
              patientId == null || patientId.isEmpty
                  ? 'Billing workspace'
                  : 'Billing workspace patient=$patientId',
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nursingRepositoryProvider.overrideWithValue(repository),
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
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await _pumpAfterAction(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockNursingRepository repository;

  setUpAll(() {
    registerFallbackValue(const NursingWorklistQuery());
    registerFallbackValue(_dischargePending);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  group('Nursing Discharge pending billing inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(NursingDischargePendingBillingInventory.all, isNotEmpty);
      for (final NursingDischargePendingFinancialAtom atom
          in NursingDischargePendingBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass ==
                NursingDischargePendingFinancialClass.createCharge ||
            atom.financialClass ==
                NursingDischargePendingFinancialClass.settle ||
            atom.financialClass ==
                NursingDischargePendingFinancialClass.adjust ||
            atom.financialClass ==
                NursingDischargePendingFinancialClass.reverse ||
            atom.financialClass ==
                NursingDischargePendingFinancialClass.defer;
        if (billable && atom.mounted) {
          expect(
            atom.billingPath,
            isNotNull,
            reason: '${atom.id} must declare billingPath',
          );
        }
        if (!billable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} must declare NOT_* audit code',
          );
        }
      }
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      expect(
        NursingDischargePendingBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final NursingDischargePendingFinancialAtom atom
          in NursingDischargePendingBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(<Matcher>[
            contains('billing'),
            contains('persist'),
            contains('lab'),
            contains('radiology'),
            contains('pharmacy'),
            contains('discharge'),
            contains('nursing'),
            contains('consumable'),
            contains('clinical'),
          ]),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(
        NursingDischargePendingBillingInventory.collectPayment.mounted,
        isFalse,
      );
      expect(
        NursingDischargePendingBillingInventory.adjustRefund.mounted,
        isFalse,
      );
      expect(
        NursingDischargePendingBillingInventory.forbidsInlineCashier(
          NursingDischargePendingFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('Open billing / billing panel require billing:read', () {
      expect(
        identical(
          NursingDischargePendingAtomPermissions.openBilling,
          nursingBillingClearanceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingDischargePendingAtomPermissions.billingPanel,
          billingReadRequirement,
        ),
        isTrue,
      );
    });

    test('scope note documents Billing ownership', () {
      expect(
        nursingDischargePendingBillingScopeNote.toLowerCase(),
        contains('billing'),
      );
      expect(
        NursingDischargePendingBillingInventory.summary().toLowerCase(),
        contains('cashier'),
      );
    });
  });

  group('Nursing Discharge pending billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized reader has no collect/adjust; Open billing needs billing:read',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _clinicalReadPolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        expect(find.text('Discharge Billing Patient'), findsOneWidget);
        expect(find.text(l10n.dischargeOpenBillingAction), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('Open billing navigates to Billing with patient_id', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _billingReadPolicy(),
      );
      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );

      await tester.tap(find.text('Discharge Billing Patient'));
      await _pumpAfterAction(tester);

      expect(find.text(l10n.dischargeBillingSectionTitle), findsOneWidget);
      expect(find.text(l10n.billingClearanceCleared), findsNothing);
      expect(find.text(l10n.patientsOutstandingBalanceFilterLabel), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text(l10n.dischargeOpenBillingAction),
        ),
      );
      await _pumpAfterAction(tester);

      expect(
        find.text('Billing workspace patient=patient-disc-bill-1'),
        findsOneWidget,
      );
    });

    testWidgets(
      'unauthorized cannot see Open billing or billing panel',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _clinicalReadPolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        await tester.tap(find.text('Discharge Billing Patient'));
        await _pumpAfterAction(tester);

        expect(find.text(l10n.dischargeBillingSectionTitle), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text(l10n.dischargeOpenBillingAction),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'authorized writer sees discharge clearance next-action (ledger-aware path)',
      (WidgetTester tester) async {
        await _pumpDischargePendingTab(
          tester,
          repository: repository,
          accessPolicy: _writeWithBillingPolicy(),
        );
        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );

        expect(
          find.byTooltip(l10n.nursingActionDischargeClearance),
          findsWidgets,
        );
        expect(
          NursingDischargePendingBillingInventory.dischargeClearance.billingPath,
          contains('updateDischargeClearance'),
        );
      },
    );
  });

  group('Nursing Discharge pending flat sections (AC5)', () {
    testWidgets('desktop Discharge pending: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _billingReadPolicy(),
      );
      expectFlatSections(tester);

      await tester.tap(find.text('Discharge Billing Patient'));
      await _pumpAfterAction(tester);
      expectFlatSections(tester);
    });

    testWidgets('mobile Discharge pending: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _billingReadPolicy(),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _writeWithBillingPolicy(),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Discharge Billing Patient'));
      await _pumpAfterAction(tester);
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDischargePendingTab(
        tester,
        repository: repository,
        accessPolicy: _writeWithBillingPolicy(),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('Discharge Billing Patient'));
      await _pumpAfterAction(tester);
      expectFlatSections(tester);
    });
  });
}
