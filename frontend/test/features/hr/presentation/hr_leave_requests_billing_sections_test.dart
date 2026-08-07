import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_leave_requests_billing_inventory.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockHrRepository extends Mock implements HrRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

const HrWorkItem _leaveItem = HrWorkItem(
  id: 'leave-1',
  displayId: 'LV-1',
  queue: HrQueue.leaveRequests,
  status: 'REQUESTED',
  staffName: 'Ada Leave',
  staffNumber: 'EMP-1',
  leaveType: 'ANNUAL',
);

const HrWorkItem _unpaidLeaveItem = HrWorkItem(
  id: 'leave-unpaid',
  displayId: 'LV-2',
  queue: HrQueue.leaveRequests,
  status: 'REQUESTED',
  staffName: 'Ben Unpaid',
  staffNumber: 'EMP-2',
  leaveType: 'UNPAID',
);

Finder _searchAction(String label) => find.byTooltip(label);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['HR'],
  String? facilityId = 'facility-1',
  String? tenantId = _tenantUuid,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockHrRepository repository, {
  List<HrWorkItem> workItems = const <HrWorkItem>[_leaveItem],
  Result<HrWorkspaceOverview>? overviewOverride,
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async =>
        overviewOverride ??
        const Result<HrWorkspaceOverview>.success(
          HrWorkspaceOverview(
            summary: HrWorkspaceSummary(leaveRequests: 1),
          ),
        ),
  );
  when(() => repository.listStaffProfiles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrStaffProfile>>.success(
      AppPage<HrStaffProfile>(
        items: <HrStaffProfile>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(
    () => repository.loadReferenceData(
      facilityId: any(named: 'facilityId'),
      departmentId: any(named: 'departmentId'),
    ),
  ).thenAnswer(
    (_) async => const Result<HrReferenceData>.success(HrReferenceData()),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final HrWorkItemsQuery query =
        invocation.positionalArguments.single as HrWorkItemsQuery;
    final List<HrWorkItem> items = workItems
        .where((HrWorkItem item) => item.queue == query.queue)
        .toList(growable: false);
    return Result<AppPage<HrWorkItem>>.success(
      AppPage<HrWorkItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listAccessUsers(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessUser>>.success(
      AppPage<HrAccessUser>(
        items: <HrAccessUser>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(() => repository.listAccessRoles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessRole>>.success(
      AppPage<HrAccessRole>(
        items: <HrAccessRole>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(() => repository.listAccessPermissions(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessPermission>>.success(
      AppPage<HrAccessPermission>(
        items: <HrAccessPermission>[],
        request: AppPageRequest(),
      ),
    ),
  );
}

Future<void> _pumpLeaveTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HrWorkItem> workItems = const <HrWorkItem>[_leaveItem],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, workItems: workItems);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/hr?section=leave-requests',
    routes: <RouteBase>[
      GoRoute(
        path: '/hr',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: HrWorkspacePage(
              initialQuery: HrWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hrRepositoryProvider.overrideWithValue(repository),
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
  late _MockHrRepository repository;

  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(const HrWorkItemsQuery());
    registerFallbackValue(const HrAccessQuery());
    registerFallbackValue(const HrStaffProfile(id: 'fallback'));
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHrRepository();
  });

  group('HR Leave requests financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        HrLeaveRequestsBillingInventory.leaveRequestsTabHasNoBillableActions,
        isTrue,
      );
      expect(
        HrLeaveRequestsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(HrLeaveRequestsBillingInventory.atoms, isNotEmpty);
      expect(
        HrLeaveRequestsBillingInventory.billableClasses.every(
          (HrLeaveRequestsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(hrLeaveRequestsBillingScopeNote, contains('NOT_BILLED'));
      expect(hrLeaveRequestsBillingScopeNote, contains('payroll'));

      for (final HrLeaveRequestsFinancialAtom atom
          in HrLeaveRequestsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<HrLeaveRequestsFinancialClass>[
            HrLeaveRequestsFinancialClass.notRequired,
            HrLeaveRequestsFinancialClass.notBilled,
            HrLeaveRequestsFinancialClass.noCharge,
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

    test('request / approve / reject stay NOT_BILLED staff ops', () {
      for (final String id in <String>[
        'request_leave',
        'next_action_approve_leave',
        'detail_approve_leave',
        'detail_reject_leave',
      ]) {
        final HrLeaveRequestsFinancialAtom atom =
            HrLeaveRequestsBillingInventory.atoms.singleWhere(
              (HrLeaveRequestsFinancialAtom a) => a.id == id,
            );
        expect(
          atom.financialClass,
          HrLeaveRequestsFinancialClass.notBilled,
          reason: id,
        );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
        expect(atom.mounted, isTrue, reason: id);
      }
    });

    test('UNPAID leave type is NOT_BILLED payroll metadata, not patient charge', () {
      final HrLeaveRequestsFinancialAtom unpaid =
          HrLeaveRequestsBillingInventory.atoms.singleWhere(
            (HrLeaveRequestsFinancialAtom atom) =>
                atom.id == 'unpaid_leave_type_metadata',
          );
      expect(unpaid.financialClass, HrLeaveRequestsFinancialClass.notBilled);
      expect(unpaid.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing / payroll SoR', () {
      expect(
        HrLeaveRequestsBillingInventory.atoms
            .singleWhere(
              (HrLeaveRequestsFinancialAtom atom) =>
                  atom.id == 'payroll_process_off_tab',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrLeaveRequestsBillingInventory.atoms
            .singleWhere(
              (HrLeaveRequestsFinancialAtom atom) =>
                  atom.id == 'patient_clinical_charge_via_leave',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrLeaveRequestsBillingInventory.atoms
            .singleWhere(
              (HrLeaveRequestsFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrLeaveRequestsBillingInventory.atoms
            .singleWhere(
              (HrLeaveRequestsFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
    });
  });

  group('HR Leave requests billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('UNPAID leave row shows type without Billing chrome', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        workItems: const <HrWorkItem>[_unpaidLeaveItem],
      );

      expect(find.textContaining('Unpaid leave'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog has no financial controls', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      await tester.tap(find.text('Ada Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Approve leave'), findsWidgets);
      expect(find.text('Reject leave'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Billing'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('approve mutation syncs queue without billing gate', (
      WidgetTester tester,
    ) async {
      when(
        () => repository.approveLeave(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async => const Result<Object?>.success(null));

      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      await tester.tap(find.text('Approve leave'));
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .descendant(
              of: find.byType(AppDialog),
              matching: find.text('Approve leave'),
            )
            .last,
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.approveLeave(any(), reason: any(named: 'reason')),
      ).called(1);
      verify(() => repository.listWorkItems(any())).called(greaterThan(1));
      expect(find.text('HR changes saved.'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('approve replay stays single mutation (idempotent UI path)', (
      WidgetTester tester,
    ) async {
      when(
        () => repository.approveLeave(any(), reason: any(named: 'reason')),
      ).thenAnswer((_) async => const Result<Object?>.success(null));

      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      await tester.tap(find.text('Approve leave'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AppDialog),
              matching: find.text('Approve leave'),
            )
            .last,
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.approveLeave(any(), reason: any(named: 'reason')),
      ).called(1);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('unauthorized reader cannot collect or approve', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
        ),
      );

      expect(_searchAction('Request leave'), findsNothing);
      expect(find.text('Approve leave'), findsNothing);
      expect(find.text('Reject leave'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('request leave dialog has no billing affordances', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      await tester.tap(_searchAction('Request leave'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Leave type'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Invoice'), findsNothing);
      expect(find.textContaining('Amount'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('HR Leave requests section layout (AC5)', () {
    testWidgets('desktop leave list: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);
    });

    testWidgets('mobile leave list: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        physicalSize: const Size(390, 844),
      );

      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
      );

      expectFlatSections(tester);

      await tester.tap(find.text('Ada Leave'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpLeaveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );

      expectFlatSections(tester);

      await tester.tap(_searchAction('Request leave'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });
}
