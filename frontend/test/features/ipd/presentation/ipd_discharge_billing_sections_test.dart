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
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_discharge_billing_inventory.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

class _MockDischargeRepository extends Mock implements DischargeRepository {}

const IpdAdmissionSummary _dischargePlanned = IpdAdmissionSummary(
  id: 'adm-discharge-bill',
  displayId: 'ADM-DISC-B',
  patientId: 'patient-uuid-disc',
  patientDisplayName: 'Dana Discharge Billing',
  stage: 'DISCHARGE_PLANNED',
  admissionStatus: 'ADMITTED',
  nextStep: 'FINALIZE_DISCHARGE',
  hasActiveBed: true,
  encounterId: 'enc-disc-b',
  wardDisplayName: 'Medical Ward',
  dischargeStatus: 'PLANNED',
  clearancePhase: 'BILLING_PENDING',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
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
            if (needsOperations)
              const AppModuleEntitlement(
                code: 'facilities-maintenance',
                licenseStatus: 'ACTIVE',
              ),
            if (needsBilling)
              const AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubIpd(
  _MockIpdRepository repository, {
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[
    _dischargePlanned,
  ],
}) {
  when(() => repository.listAdmissions(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    return Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[
      IpdWardOption(id: 'ward-1', name: 'Medical Ward'),
    ]),
  );
  when(
    () => repository.listBeds(
      search: any(named: 'search'),
      status: any(named: 'status'),
      wardId: any(named: 'wardId'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[
      IpdBedOption(id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE'),
    ]),
  );
  when(
    () => repository.listBedBoard(
      wardId: any(named: 'wardId'),
      status: any(named: 'status'),
      statusAny: any(named: 'statusAny'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<List<IpdBedBoardEntry>>.success(<IpdBedBoardEntry>[]),
  );
  when(() => repository.getAdmission(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.single as String;
    final IpdAdmissionSummary summary = items.firstWhere(
      (IpdAdmissionSummary item) => item.id == id || item.displayId == id,
      orElse: () => items.first,
    );
    return Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(
        summary: summary,
        latestDischargeSummary: const IpdDischargeSummary(
          id: 'ds-1',
          status: 'PLANNED',
          summary: 'Ready; billing clearance pending.',
          clearancePhase: 'BILLING_PENDING',
        ),
      ),
    );
  });
}

void _stubDischarge(_MockDischargeRepository repository) {
  when(() => repository.getAdmissionDetail(any())).thenAnswer(
    (_) async => const Result<DischargeAdmissionDetail>.success(
      DischargeAdmissionDetail(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        patientId: 'patient-uuid-disc',
        encounterId: 'enc-disc-b',
        ipd: IpdAdmissionDetail(
          summary: _dischargePlanned,
          latestDischargeSummary: IpdDischargeSummary(
            id: 'ds-1',
            status: 'PLANNED',
            summary: 'Ready; billing clearance pending.',
            clearancePhase: 'BILLING_PENDING',
          ),
        ),
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
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<DischargeReferenceData>.success(DischargeReferenceData()),
  );
}

Future<void> _pumpDischargeTab(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockDischargeRepository discharge = _MockDischargeRepository();
  _stubIpd(repository);
  _stubDischarge(discharge);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/ipd?section=discharge',
    routes: <RouteBase>[
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IpdWorkspacePage(
              initialQuery: IpdAdmissionQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Text(
              'Billing workspace patient=${state.uri.queryParameters['patient_id'] ?? ''}',
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ipdRepositoryProvider.overrideWithValue(repository),
        dischargeRepositoryProvider.overrideWithValue(discharge),
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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(_dischargePlanned);
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IPD Discharge billing inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(IpdDischargeBillingInventory.atoms, isNotEmpty);
      expect(
        IpdDischargeBillingInventory.atoms.map(
          (IpdDischargeFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'start_admission',
          'next_action_manage_discharge',
          'plan_discharge',
          'manage_discharge',
          'finalize_override',
          'open_billing',
          'order_lab',
          'ward_round',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      for (final IpdDischargeFinancialAtom atom
          in IpdDischargeBillingInventory.atoms) {
        final bool notBillable =
            atom.financialClass == IpdDischargeFinancialClass.notBilled ||
            atom.financialClass == IpdDischargeFinancialClass.notRequired ||
            atom.financialClass == IpdDischargeFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(
        IpdDischargeBillingInventory.planDischarge.financialClass,
        IpdDischargeFinancialClass.notBilled,
      );
      expect(
        IpdDischargeBillingInventory.manageDischarge.financialClass,
        IpdDischargeFinancialClass.defer,
      );
      expect(
        IpdDischargeBillingInventory.summary(),
        contains('clinical-request-billing'),
      );
      expect(ipdDischargeBillingScopeNote, contains('assertBillingSettled'));
    });

    test('billable mounted atoms wire through shared Billing (no bypass)', () {
      expect(
        IpdDischargeBillingInventory.allMountedBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final IpdDischargeFinancialAtom atom
          in IpdDischargeBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull, reason: atom.id);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('clinical-request'),
            contains('finalize'),
            contains('approutes.billing'),
            contains('assert'),
            contains('override'),
          ),
          reason: atom.id,
        );
      }
      expect(
        IpdDischargeBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
      expect(
        IpdDischargeBillingInventory.startAdmission.billingPath,
        contains('persistAdmissionBilling'),
      );
    });

    test('cashier settle/adjust atoms are unmounted on Discharge', () {
      expect(IpdDischargeBillingInventory.collectPayment.mounted, isFalse);
      expect(IpdDischargeBillingInventory.adjustRefund.mounted, isFalse);
      expect(IpdDischargeBillingInventory.issueInvoiceLocal.mounted, isFalse);
      expect(
        IpdDischargeBillingInventory.isInlineCollectionForbidden(
          IpdDischargeFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        IpdDischargeAtomPermissions.openBilling,
        same(ipdBillingPanelReadRequirement),
      );
      expect(
        IpdDischargeAtomPermissions.openBilling.allPermissions,
        billingReadRequirement.allPermissions,
      );
    });
  });

  group('IPD Discharge billing wiring (AC2–AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.ipd,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'Open billing navigates with patient_id; no inline cashier',
      (WidgetTester tester) async {
        await _pumpDischargeTab(
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

        expect(find.text('Dana Discharge Billing'), findsOneWidget);
        await tester.tap(find.text('Dana Discharge Billing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Billing workspace patient=patient-uuid-disc',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unauthorized cannot Open billing or collect — clinical-only reader',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        );
        expect(
          IpdDischargeAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );
        expect(billingWorkspaceWriteRequirement.isAllowed(reader), isFalse);

        await _pumpDischargeTab(
          tester,
          repository: repository,
          accessPolicy: reader,
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Dana Discharge Billing'));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'Manage discharge opens planning dialog; no local invoice create',
      (WidgetTester tester) async {
        await _pumpDischargeTab(
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

        expect(find.text('Manage discharge'), findsWidgets);
        await tester.tap(find.text('Manage discharge').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
      },
    );
  });

  group('IPD Discharge flat sections (AC5)', () {
    testWidgets('desktop light: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpDischargeTab(
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

      expectFlatSections(tester);

      await tester.tap(find.text('Dana Discharge Billing'));
      await tester.pumpAndSettle();

      expect(find.byType(AppCollapsibleSection), findsWidgets);
      expect(find.byType(AppQuickActions), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('mobile dark: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDischargeTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      await tester.tap(find.text('Dana Discharge Billing'));
      await tester.pumpAndSettle();

      expectFlatSections(tester);
    });
  });
}
