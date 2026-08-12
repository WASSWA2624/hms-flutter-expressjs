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
import 'package:hosspi_hms/features/nursing/presentation/nursing_all_billing_inventory.dart';
import 'package:hosspi_hms/features/nursing/presentation/pages/nursing_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _allPatient = NursingPatientSummary(
  id: 'adm-all-bill-1',
  admissionId: 'adm-all-bill-1',
  displayId: 'ADM-ALL-B1',
  patientId: 'pat-all-bill-1',
  patientDisplayId: 'PT-ALL-B1',
  patientDisplayName: 'All Billing Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED',
  wardDisplayName: 'Ward A',
  bedDisplayLabel: 'Bed 1',
  hasActiveBed: true,
  dischargeStatus: 'DISCHARGE_PLANNED',
);

const NursingPatientDetail _allDetail = NursingPatientDetail(
  summary: _allPatient,
  latestDischarge: NursingDischargeSummary(
    id: 'ds-all-1',
    status: 'PLANNED',
    summary: 'Awaiting clearance',
    billingCleared: false,
    nursingCleared: false,
  ),
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
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['NURSE'],
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
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockNursingRepository repository, {
  List<NursingPatientSummary> items = const <NursingPatientSummary>[
    _allPatient,
  ],
  NursingPatientDetail detail = _allDetail,
}) {
  when(() => repository.listWardPatients(any())).thenAnswer((invocation) {
    final NursingWorklistQuery query =
        invocation.positionalArguments.single as NursingWorklistQuery;
    return Future<Result<AppPage<NursingPatientSummary>>>.value(
      Result<AppPage<NursingPatientSummary>>.success(
        AppPage<NursingPatientSummary>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
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
    (_) async => Result<NursingPatientDetail>.success(detail),
  );
  when(() => repository.addNursingNote(any(), any())).thenAnswer(
    (_) async => Result<NursingPatientDetail>.success(detail),
  );
  when(() => repository.updateDischargeClearance(any(), any())).thenAnswer(
    (_) async => Result<NursingPatientDetail>.success(
      NursingPatientDetail(
        summary: _allPatient,
        latestDischarge: const NursingDischargeSummary(
          id: 'ds-all-1',
          status: 'PLANNED',
          summary: 'Awaiting clearance',
          billingCleared: false,
          nursingCleared: true,
        ),
      ),
    ),
  );
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  NursingPatientDetail detail = _allDetail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/nursing',
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockNursingRepository repository;

  setUpAll(() {
    registerFallbackValue(const NursingWorklistQuery());
    registerFallbackValue(_allPatient);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  group('Nursing All billing inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(NursingAllBillingInventory.all, isNotEmpty);
      for (final NursingAllFinancialAtom atom
          in NursingAllBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass ==
                NursingAllFinancialClass.createCharge ||
            atom.financialClass == NursingAllFinancialClass.settle ||
            atom.financialClass == NursingAllFinancialClass.adjust ||
            atom.financialClass == NursingAllFinancialClass.reverse ||
            atom.financialClass == NursingAllFinancialClass.defer;
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
      for (final NursingAllFinancialAtom atom
          in NursingAllBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(<Matcher>[
            contains('billing'),
            contains('persist'),
            contains('lab'),
            contains('radiology'),
            contains('pharmacy'),
            contains('nursing'),
            contains('discharge'),
            contains('approutes'),
            contains('clinical'),
            contains('ipdflows'),
            contains('ledger'),
          ]),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(NursingAllBillingInventory.collectPayment.mounted, isFalse);
      expect(NursingAllBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        NursingAllBillingInventory.forbidsInlineCashier(
          NursingAllFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('Open billing gate requires billing:read ∩ billing-payments', () {
      expect(
        identical(
          NursingAllAtomPermissions.openBilling,
          nursingBillingClearanceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          NursingAllAtomPermissions.openBilling,
          billingReadRequirement,
        ),
        isTrue,
      );
    });

    test('scope note documents All tab financial focus', () {
      expect(
        nursingAllBillingScopeNote.toLowerCase(),
        contains('clinical-request-billing'),
      );
      expect(
        NursingAllBillingInventory.summary().toLowerCase(),
        contains('persistnursingservicebilling'),
      );
      expect(
        NursingAllBillingInventory.summary().toLowerCase(),
        contains('open billing'),
      );
      expect(
        NursingAllBillingInventory.administerMedication.auditCode,
        'NOT_BILLED',
      );
    });
  });

  group('Nursing All billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized reader has no collect/adjust; Open billing needs billing:read',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.nursingRead, AppPermissions.clinicalRead},
          ),
        );

        expect(find.text('All Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('All Billing Patient'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing:read shows Open billing + ledger status without cashier',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.nursingRead,
              AppPermissions.clinicalRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('All Billing Patient'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsWidgets);
        expect(find.text('Outstanding balance'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();
        expect(
          find.text('Billing workspace patient=pat-all-bill-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.nursingRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'billing panel shows ledger outstanding parity (not nurse-local paid)',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.nursingRead,
              AppPermissions.clinicalRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('All Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Billing clearance'), findsOneWidget);
        expect(find.text('Outstanding balance'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(
          NursingAllBillingInventory.dischargeClearance.billingPath,
          contains('isBillingSettledForPatient'),
        );
      },
    );
  });

  group('Nursing All section layout (AC5)', () {
    testWidgets('desktop All: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.nursingRead,
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
          },
        ),
      );
      expectFlatSections(tester);

      await tester.tap(find.text('All Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile All + dark: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.nursingRead,
            AppPermissions.clinicalRead,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );
      expectFlatSections(tester);

      await tester.tap(find.text('All Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });
}
