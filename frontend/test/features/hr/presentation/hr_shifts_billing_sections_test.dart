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
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_shifts_billing_inventory.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

// ignore_for_file: avoid_redundant_argument_values

class _MockHrRepository extends Mock implements HrRepository {}

const String _tenantUuid = '550e8400-e29b-41d4-a716-446655440000';

const HrOption _template = HrOption(
  value: 'SHI0000001',
  label: 'Day pattern',
  displayId: 'SHI0000001',
  extra: <String, Object?>{
    'shift_type': 'DAY',
    'facility_id': 'fac-1',
    'is_active': true,
    'weekly_schedule_json': <Map<String, Object?>>[
      <String, Object?>{
        'day_of_week': 1,
        'time_slots': <Map<String, String>>[
          <String, String>{'start_time': '08:00', 'end_time': '17:00'},
        ],
      },
    ],
  },
);

const HrWorkItem _rosterDraft = HrWorkItem(
  id: 'roster-1',
  displayId: 'RST-1',
  queue: HrQueue.rosterDrafts,
  status: 'DRAFT',
  periodLabel: 'Week 12',
  rosterId: 'roster-1',
);

const HrWorkItem _unassignedShift = HrWorkItem(
  id: 'shift-1',
  displayId: 'SHF-1',
  queue: HrQueue.unassignedShifts,
  status: 'OPEN',
  shiftType: 'DAY',
  shiftId: 'shift-1',
  staffName: 'Unassigned',
);

const HrWorkItem _swapRequest = HrWorkItem(
  id: 'swap-1',
  displayId: 'SWP-1',
  queue: HrQueue.swapRequests,
  status: 'REQUESTED',
  shiftType: 'NIGHT',
  shiftId: 'shift-2',
  staffName: 'Ada Swap',
);

Finder _searchAction(String label) => find.byTooltip(label);

Finder _tableRowInkWell() => find.byWidgetPredicate(
  (Widget widget) => widget.runtimeType.toString() == 'AppListTableRowInkWell',
);

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
  List<HrWorkItem> workItems = const <HrWorkItem>[_rosterDraft],
  List<HrOption> templates = const <HrOption>[_template],
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => const Result<HrWorkspaceOverview>.success(
      HrWorkspaceOverview(
        summary: HrWorkspaceSummary(draftRosters: 1, unassignedShifts: 1),
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
    (_) async => Result<HrReferenceData>.success(
      HrReferenceData(
        shiftTemplates: templates,
        facilities: const <HrOption>[
          HrOption(value: 'fac-1', label: 'Main'),
        ],
        shiftTypes: const <HrOption>[HrOption(value: 'DAY', label: 'DAY')],
      ),
    ),
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
      AppPage<HrAccessUser>(items: <HrAccessUser>[], request: AppPageRequest()),
    ),
  );
  when(() => repository.listAccessRoles(any())).thenAnswer(
    (_) async => const Result<AppPage<HrAccessRole>>.success(
      AppPage<HrAccessRole>(items: <HrAccessRole>[], request: AppPageRequest()),
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
  when(
    () => repository.deleteShiftTemplate(any()),
  ).thenAnswer((_) async => const Result<Object?>.success(null));
  when(
    () => repository.createShiftTemplate(any()),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.updateShiftTemplate(any(), any()),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.publishRoster(
      any(),
      notifyStaff: any(named: 'notifyStaff'),
      allowPartialPublish: any(named: 'allowPartialPublish'),
      publishNote: any(named: 'publishNote'),
    ),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.overrideShift(
      any(),
      staffProfileId: any(named: 'staffProfileId'),
      reason: any(named: 'reason'),
    ),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
  when(
    () => repository.approveSwap(any(), reason: any(named: 'reason')),
  ).thenAnswer((_) async => const Result<Object?>.success(null));
  when(
    () => repository.rejectSwap(any(), reason: any(named: 'reason')),
  ).thenAnswer((_) async => const Result<Object?>.success(null));
  when(() => repository.generateRosterPreview(any())).thenAnswer(
    (_) async => const Result<HrRosterGenerateResult>.success(
      HrRosterGenerateResult(
        coveragePercent: 90,
        gapCount: 1,
        assignmentCount: 12,
      ),
    ),
  );
  when(
    () => repository.generateRoster(
      any(),
      replaceExistingAssignments: any(named: 'replaceExistingAssignments'),
      dryRun: any(named: 'dryRun'),
    ),
  ).thenAnswer((_) async => const Result<Object?>.success(<String, Object?>{}));
}

Future<void> _pumpShiftsTab(
  WidgetTester tester, {
  required _MockHrRepository repository,
  required AppAccessPolicy accessPolicy,
  List<HrWorkItem> workItems = const <HrWorkItem>[_rosterDraft],
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/hr?section=shifts',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, workItems: workItems);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
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

void _expectNoPatientBillingAffordances() {
  expect(find.textContaining('Receive payment'), findsNothing);
  expect(find.textContaining('Issue invoice'), findsNothing);
  expect(find.textContaining('Collect'), findsNothing);
  expect(find.textContaining('Balance due'), findsNothing);
  expect(find.textContaining('Refund'), findsNothing);
  expect(find.textContaining('Write off'), findsNothing);
  expect(find.textContaining('Credit note'), findsNothing);
}

void main() {
  late _MockHrRepository repository;

  setUpAll(() {
    registerFallbackValue(const HrStaffQuery());
    registerFallbackValue(
      const HrWorkItemsQuery(queue: HrQueue.rosterDrafts),
    );
    registerFallbackValue(const HrAccessQuery());
    registerFallbackValue(const AppPageRequest());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockHrRepository();
  });

  group('HR Shifts financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(HrShiftsBillingInventory.shiftsTabHasNoBillableActions, isTrue);
      expect(
        HrShiftsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(HrShiftsBillingInventory.atoms, isNotEmpty);
      expect(
        HrShiftsBillingInventory.billableClasses.every(
          (HrShiftsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(hrShiftsBillingScopeNote, contains('NOT_BILLED'));

      for (final HrShiftsFinancialAtom atom
          in HrShiftsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<HrShiftsFinancialClass>[
            HrShiftsFinancialClass.notRequired,
            HrShiftsFinancialClass.notBilled,
            HrShiftsFinancialClass.noCharge,
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

    test('roster mutations stay NOT_BILLED internal ops', () {
      for (final String id in <String>[
        'next_action_publish_roster',
        'next_action_override_shift',
        'next_action_approve_reject_swap',
        'template_create_edit',
        'template_delete',
      ]) {
        final HrShiftsFinancialAtom atom = HrShiftsBillingInventory.atoms
            .singleWhere((HrShiftsFinancialAtom item) => item.id == id);
        expect(atom.financialClass, HrShiftsFinancialClass.notBilled);
        expect(atom.auditCode, 'NOT_BILLED');
        expect(atom.mounted, isTrue);
      }
    });

    test('unmounted billable atoms document Billing SoR; payroll stays off-tab', () {
      expect(
        HrShiftsBillingInventory.atoms
            .singleWhere(
              (HrShiftsFinancialAtom atom) =>
                  atom.id == 'staff_payroll_compensation',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrShiftsBillingInventory.atoms
            .singleWhere(
              (HrShiftsFinancialAtom atom) =>
                  atom.id == 'patient_clinical_charge_via_shift',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrShiftsBillingInventory.atoms
            .singleWhere(
              (HrShiftsFinancialAtom atom) => atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        HrShiftsBillingInventory.atoms
            .singleWhere(
              (HrShiftsFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(hrShiftsBillingScopeNote, contains('Billing'));
      expect(hrShiftsBillingScopeNote, contains('Payroll'));
    });
  });

  group('HR Shifts billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.rosterWrite,
            AppPermissions.rosterPublish,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.text('Week 12'), findsWidgets);
      expect(_searchAction('Create roster template'), findsOneWidget);
      _expectNoPatientBillingAffordances();
      expectFlatSections(tester);
    });

    testWidgets(
      'roster detail: assigned staff section; no financial controls',
      (WidgetTester tester) async {
        when(() => repository.getRoster(any())).thenAnswer(
          (_) async => const Result<Map<String, Object?>>.success(
            <String, Object?>{
              'name': 'Week 12',
              'status': 'DRAFT',
              'is_recurring': false,
              'human_friendly_id': 'RST-1001',
              'staff': <Object?>[],
            },
          ),
        );

        await _pumpShiftsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.hrRead,
              AppPermissions.rosterWrite,
              AppPermissions.rosterPublish,
              AppPermissions.billingWrite,
            },
          ),
        );

        await tester.tap(find.text('Week 12').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.textContaining('Roster'), findsWidgets);
        expect(find.text('Assigned staff'), findsWidgets);
        _expectNoPatientBillingAffordances();
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Create roster template dialog: flat sections; no billing affordances',
      (WidgetTester tester) async {
        await _pumpShiftsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.hrRead,
              AppPermissions.hrWrite,
              AppPermissions.rosterWrite,
              AppPermissions.billingWrite,
            },
          ),
        );

        when(() => repository.createRoster(any())).thenAnswer(
          (_) async => const Result<Object?>.success(null),
        );

        await tester.tap(_searchAction('Create roster template'));
        await tester.pumpAndSettle();

        expect(find.text('Create roster template'), findsWidgets);
        expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
        expect(find.text('Template details'), findsWidgets);
        expect(find.text('Recurring'), findsWidgets);
        _expectNoPatientBillingAffordances();
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'unauthorized users cannot collect or adjust from Shifts',
      (WidgetTester tester) async {
        await _pumpShiftsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.hrRead},
          ),
        );

        expect(_searchAction('Create roster template'), findsNothing);
        expect(find.text('Publish roster'), findsNothing);
        _expectNoPatientBillingAffordances();
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'authorized Edit action stays roster ops (no Billing post path)',
      (WidgetTester tester) async {
        when(() => repository.getRoster(any())).thenAnswer(
          (_) async => const Result<Map<String, Object?>>.success(
            <String, Object?>{
              'name': 'Week 12',
              'status': 'DRAFT',
              'is_recurring': false,
              'human_friendly_id': 'RST-1001',
              'staff': <Object?>[],
            },
          ),
        );

        await _pumpShiftsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.hrRead,
              AppPermissions.rosterWrite,
            },
          ),
          workItems: const <HrWorkItem>[_rosterDraft],
        );

        await tester.tap(find.text('Edit').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('EDIT ROSTER TEMPLATE'), findsWidgets);
        expect(find.text('Template details'), findsWidgets);
        _expectNoPatientBillingAffordances();
        expectFlatSections(tester);
      },
    );

    testWidgets('Override shift dialog has no payment controls', (
      WidgetTester tester,
    ) async {
      await _pumpShiftsTab(
        tester,
        repository: repository,
        workItems: const <HrWorkItem>[_unassignedShift],
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterWrite,
            AppPermissions.billingWrite,
          },
        ),
        initialLocation: '/hr?section=shifts&queue=unassigned_shifts',
      );

      expect(find.text('Override shift'), findsWidgets);
      await tester.tap(find.text('Override shift').first);
      await tester.pumpAndSettle();

      _expectNoPatientBillingAffordances();
      expectFlatSections(tester);
    });

    testWidgets('Approve swap dialog has no payment controls', (
      WidgetTester tester,
    ) async {
      await _pumpShiftsTab(
        tester,
        repository: repository,
        workItems: const <HrWorkItem>[_swapRequest],
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterApprove,
            AppPermissions.billingWrite,
          },
        ),
        initialLocation: '/hr?section=swap-requests&queue=SWAP_REQUESTS',
      );

      expect(find.text('Approve swap'), findsWidgets);
      await tester.tap(find.text('Approve swap').first);
      await tester.pumpAndSettle();

      _expectNoPatientBillingAffordances();
      expectFlatSections(tester);
    });
  });

  group('HR Shifts flat sections / viewports / themes (AC5–AC6)', () {
    testWidgets('desktop worklist: flat sections', (WidgetTester tester) async {
      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterWrite,
          },
        ),
        physicalSize: const Size(1440, 900),
      );
      expectFlatSections(tester);
    });

    testWidgets('mobile worklist: flat sections', (WidgetTester tester) async {
      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterWrite,
          },
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterWrite,
            AppPermissions.rosterPublish,
          },
        ),
        themeMode: ThemeMode.light,
      );
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpShiftsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterWrite,
            AppPermissions.rosterPublish,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      expectFlatSections(tester);
    });

    testWidgets('authorized empty state remains observable without billing UI', (
      WidgetTester tester,
    ) async {
      await _pumpShiftsTab(
        tester,
        repository: repository,
        workItems: const <HrWorkItem>[],
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.rosterWrite,
          },
        ),
      );

      _expectNoPatientBillingAffordances();
      expectFlatSections(tester);
    });
  });
}
