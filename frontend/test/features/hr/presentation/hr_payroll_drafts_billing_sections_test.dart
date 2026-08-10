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
import 'package:hosspi_hms/features/hr/presentation/hr_payroll_drafts_billing_inventory.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

// ignore_for_file: avoid_redundant_argument_values

class _MockHrRepository extends Mock implements HrRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

const HrWorkItem _payrollItem = HrWorkItem(
  id: 'pay-1',
  displayId: 'PR-1',
  queue: HrQueue.payrollDrafts,
  status: 'DRAFT',
  staffName: 'Casey Payroll',
  staffNumber: 'EMP-P1',
  payrollRunId: 'run-1',
  periodLabel: '2026-07',
);

const HrPayrollPreview _preview = HrPayrollPreview(
  status: 'DRAFT',
  totalAmount: 1200,
  currency: 'USD',
  staffCount: 1,
  items: <HrPayrollPreviewItem>[
    HrPayrollPreviewItem(
      staffName: 'Casey Payroll',
      staffProfileId: 'staff-p1',
      amount: 1200,
      currency: 'USD',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(
      code: hrBillingPaymentsModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['HR'],
        tenantId: _tenantUuid,
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockHrRepository repository, {
  List<HrWorkItem> workItems = const <HrWorkItem>[_payrollItem],
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(
      HrWorkspaceOverview(
        summary: HrWorkspaceSummary(payrollDraftRuns: 1),
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
  when(() => repository.previewPayrollRun(any())).thenAnswer(
    (_) async => const Result<HrPayrollPreview>.success(_preview),
  );
  when(
    () => repository.processPayrollRun(
      any(),
      replaceExistingItems: any(named: 'replaceExistingItems'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer((_) async => const Result<Object?>.success(null));
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

Future<void> _pumpPayrollTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<HrWorkItem> workItems = const <HrWorkItem>[_payrollItem],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, workItems: workItems);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/hr?section=payroll',
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
    registerFallbackValue('');
  });

  setUp(() {
    repository = _MockHrRepository();
  });

  group('HR Pay & Compensation financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(hrPayrollDraftsTabHasNoBillableActions(), isTrue);
      expect(
        HrPayrollDraftsBillingInventory.payrollDraftsTabHasNoBillableActions,
        isTrue,
      );
      expect(
        HrPayrollDraftsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(HrPayrollDraftsBillingInventory.atoms, isNotEmpty);
      expect(
        HrPayrollDraftsBillingInventory.billableClasses.every(
          (HrPayrollDraftsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(hrPayrollDraftsBillingScopeNote, contains('NOT_BILLED'));
      expect(hrPayrollDraftsBillingScopeNote, contains('Billing'));

      for (final HrPayrollDraftsFinancialAtom atom
          in HrPayrollDraftsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<HrPayrollDraftsFinancialClass>[
            HrPayrollDraftsFinancialClass.notRequired,
            HrPayrollDraftsFinancialClass.notBilled,
            HrPayrollDraftsFinancialClass.noCharge,
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

    test('process / preview stay NOT_BILLED staff compensation', () {
      for (final String id in <String>[
        'next_action_process',
        'detail_preview',
        'detail_process',
        'nested_preview_dialog',
        'nested_process_dialog',
        'payroll_draft_status_display',
      ]) {
        final HrPayrollDraftsFinancialAtom atom =
            HrPayrollDraftsBillingInventory.atoms.singleWhere(
              (HrPayrollDraftsFinancialAtom a) => a.id == id,
            );
        expect(
          atom.financialClass,
          HrPayrollDraftsFinancialClass.notBilled,
          reason: id,
        );
        expect(atom.auditCode, 'NOT_BILLED', reason: id);
        expect(atom.mounted, isTrue, reason: id);
      }
    });

    test('unmounted patient billable atoms document Billing SoR', () {
      expect(
        HrPayrollDraftsBillingInventory.atoms
            .singleWhere(
              (HrPayrollDraftsFinancialAtom atom) =>
                  atom.id == 'patient_create_charge',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrPayrollDraftsBillingInventory.atoms
            .singleWhere(
              (HrPayrollDraftsFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrPayrollDraftsBillingInventory.atoms
            .singleWhere(
              (HrPayrollDraftsFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrPayrollDraftsBillingInventory.atoms
            .singleWhere(
              (HrPayrollDraftsFinancialAtom atom) =>
                  atom.id == 'run_payroll_wizard',
            )
            .mounted,
        isFalse,
      );
    });
  });

  group('HR Pay & Compensation billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no patient payment/issue affordances', (
      WidgetTester tester,
    ) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
        ),
      );

      expect(find.text('Pay & Compensation'), findsWidgets);
      expect(find.text('run-1'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Collect payment'), findsNothing);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'detail: Approve/Print present; no patient Billing controls; flat',
      (WidgetTester tester) async {
        await _pumpPayrollTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.hrRead,
              AppPermissions.hrWrite,
              AppPermissions.financialApprove,
            },
          ),
        );

        await tester.tap(find.text('run-1').first);
        await tester.pumpAndSettle();

        expect(find.text('PAYROLL DETAILS'), findsOneWidget);
        expect(find.text('Approve & notify Finance'), findsWidgets);
        expect(find.text('Print'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('unauthorized reader cannot process or collect', (
      WidgetTester tester,
    ) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
        ),
      );

      expect(find.text('Approve & notify Finance'), findsNothing);

      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();

      expect(find.text('PAYROLL DETAILS'), findsOneWidget);
      expect(find.text('Print'), findsOneWidget);
      expect(find.text('Approve & notify Finance'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'process mutation posts payroll run only (no patient Billing path)',
      (WidgetTester tester) async {
        await _pumpPayrollTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.hrRead,
              AppPermissions.hrWrite,
              AppPermissions.financialApprove,
            },
          ),
        );

        // Next-action opens approve dialog without the detail Quick actions shell.
        expect(find.text('Review & approve'), findsOneWidget);
        await tester.tap(find.text('Review & approve'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Approve & notify Finance').last);
        await tester.pumpAndSettle();

        verify(
          () => repository.processPayrollRun(
            any(),
            replaceExistingItems: any(named: 'replaceExistingItems'),
            notes: any(named: 'notes'),
          ),
        ).called(1);
        expect(find.text('HR changes saved.'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
      },
    );

    testWidgets('preview shows compensation amounts, not patient balance', (
      WidgetTester tester,
    ) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
        ),
      );

      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();

      expect(find.text('Compensation breakdown'), findsOneWidget);
      expect(find.textContaining('1,200'), findsWidgets);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      verify(() => repository.previewPayrollRun(any())).called(greaterThanOrEqualTo(1));
      expectFlatSections(tester);
    });

    testWidgets('process replay stays on payroll repository (idempotent path)', (
      WidgetTester tester,
    ) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
        ),
      );

      for (int i = 0; i < 2; i++) {
        expect(find.text('Review & approve'), findsOneWidget);
        await tester.tap(find.text('Review & approve'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Approve & notify Finance').last);
        await tester.pumpAndSettle();
      }

      verify(
        () => repository.processPayrollRun(
          any(),
          replaceExistingItems: any(named: 'replaceExistingItems'),
          notes: any(named: 'notes'),
        ),
      ).called(2);
      expect(find.textContaining('Receive payment'), findsNothing);
    });
  });

  group('HR Pay & Compensation section layout (AC5)', () {
    testWidgets('desktop: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);
      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile: flat sections', (WidgetTester tester) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.hrRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('process dialog: flat sections', (WidgetTester tester) async {
      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
        ),
      );

      await tester.tap(find.text('Review & approve'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });
}
