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
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_active_patients_billing_inventory.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdAdmissionSummary _activePatient = IpdAdmissionSummary(
  id: 'adm-active-bill-1',
  displayId: 'ADM-AB1',
  patientId: 'pat-active-bill-1',
  patientDisplayName: 'Ada Active Billing',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED',
  hasActiveBed: true,
  wardDisplayName: 'Ward A',
  bedDisplayLabel: 'Bed 1',
);

const IpdAdmissionDetail _activeDetail = IpdAdmissionDetail(
  summary: _activePatient,
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
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
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

void _stubRepository(
  _MockIpdRepository repository, {
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[_activePatient],
  IpdAdmissionDetail detail = _activeDetail,
}) {
  when(() => repository.listAdmissions(any())).thenAnswer((invocation) {
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    return Future<Result<AppPage<IpdAdmissionSummary>>>.value(
      Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
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
    (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[]),
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
  when(() => repository.getAdmission(any())).thenAnswer(
    (_) async => Result<IpdAdmissionDetail>.success(detail),
  );
}

Future<void> _pumpActiveTab(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[_activePatient],
  IpdAdmissionDetail detail = _activeDetail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/ipd?section=active',
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
        ipdRepositoryProvider.overrideWithValue(repository),
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
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IPD Active Patients billing inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(IpdActivePatientsBillingInventory.all, isNotEmpty);
      for (final IpdActivePatientsFinancialAtom atom
          in IpdActivePatientsBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass ==
                IpdActivePatientsFinancialClass.createCharge ||
            atom.financialClass == IpdActivePatientsFinancialClass.settle ||
            atom.financialClass == IpdActivePatientsFinancialClass.adjust ||
            atom.financialClass == IpdActivePatientsFinancialClass.reverse ||
            atom.financialClass == IpdActivePatientsFinancialClass.defer;
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
      for (final IpdActivePatientsFinancialAtom atom
          in IpdActivePatientsBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(<Matcher>[
            contains('billing'),
            contains('persist'),
            contains('lab'),
            contains('radiology'),
            contains('pharmacy'),
            contains('ward-round'),
            contains('nursing'),
            contains('admission'),
            contains('icu'),
            contains('discharge'),
            contains('transfer'),
            contains('approutes'),
          ]),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(IpdActivePatientsBillingInventory.collectPayment.mounted, isFalse);
      expect(IpdActivePatientsBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        IpdActivePatientsBillingInventory.forbidsInlineCashier(
          IpdActivePatientsFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('Open billing gate requires billing:read', () {
      expect(
        identical(
          IpdActivePatientsAtomPermissions.openBilling,
          ipdBillingReadRequirement,
        ),
        isTrue,
      );
    });

    test('scope note documents Active Patients financial focus', () {
      expect(
        ipdActivePatientsBillingScopeNote.toLowerCase(),
        contains('deposit'),
      );
      expect(
        ipdActivePatientsBillingScopeNote.toLowerCase(),
        contains('bed/day'),
      );
      expect(
        IpdActivePatientsBillingInventory.summary().toLowerCase(),
        contains('open billing'),
      );
    });
  });

  group('IPD Active Patients billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized reader has no collect/adjust; Open billing requires billing:read',
      (WidgetTester tester) async {
        await _pumpActiveTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
        );

        expect(find.text('Ada Active Billing'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Ada Active Billing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing:read shows Open billing (patient-scoped) without cashier',
      (WidgetTester tester) async {
        await _pumpActiveTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Ada Active Billing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();
        expect(
          find.text('Billing workspace patient=pat-active-bill-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('IPD Active Patients section layout (AC5)', () {
    testWidgets('desktop Active: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
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

      await tester.tap(find.text('Ada Active Billing'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Active + dark: flat sections', (WidgetTester tester) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );
      expectFlatSections(tester);

      await tester.tap(find.text('Ada Active Billing'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });
}
