import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
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
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(
      code: hrBillingPaymentsModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: const <String>['HR'],
        tenantId: _tenantUuid,
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

  group('HrPayrollDraftsAtomPermissions mapping', () {
    test('reuses feature helpers (no second vocabulary)', () {
      expect(
        identical(
          HrPayrollDraftsAtomPermissions.tab,
          hrReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrPayrollDraftsAtomPermissions.preview,
          hrPayrollPreviewRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrPayrollDraftsAtomPermissions.process,
          hrPayrollRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrPayrollDraftsAtomPermissions.nextAction,
          hrPayrollRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HrPayrollDraftsAtomPermissions.routeEntry,
          hrWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });

    test('intersection denial: missing financial:approve', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
      );
      expect(HrPayrollDraftsAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(HrPayrollDraftsAtomPermissions.preview.isAllowed(writer), isTrue);
      expect(HrPayrollDraftsAtomPermissions.process.isAllowed(writer), isFalse);
      expect(
        HrPayrollDraftsAtomPermissions.nextAction.isAllowed(writer),
        isFalse,
      );
    });

    test('intersection denial: financial:approve without hr:write', () {
      final AppAccessPolicy approveOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.financialApprove,
        },
      );
      expect(
        HrPayrollDraftsAtomPermissions.process.isAllowed(approveOnly),
        isFalse,
      );
      // Matrix nested ∪ still allows either key alone.
      expect(
        HrPayrollDraftsAtomPermissions.nestedWriteMatrix.isAllowed(approveOnly),
        isTrue,
      );
    });

    test('union allowance: nestedWriteMatrix ∪ hr:write | financial:approve', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.hrWrite},
      );
      final AppAccessPolicy financialOnly = _policy(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );
      expect(
        HrPayrollDraftsAtomPermissions.nestedWriteMatrix.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        HrPayrollDraftsAtomPermissions.nestedWriteMatrix.isAllowed(
          financialOnly,
        ),
        isTrue,
      );
      // Source process ∩ remains stricter than matrix ∪.
      expect(
        HrPayrollDraftsAtomPermissions.process.isAllowed(writeOnly),
        isFalse,
      );
    });

    test('full process ∩ present; route entry uses catalog ∩ hr:read', () {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
      );
      final AppAccessPolicy writeOnlyEntry = _policy(
        permissions: <AppPermission>{AppPermissions.hrWrite},
      );
      final AppAccessPolicy readOnlyEntry = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );
      expect(HrPayrollDraftsAtomPermissions.process.isAllowed(full), isTrue);
      expect(HrPayrollDraftsAtomPermissions.routeEntry.isAllowed(full), isTrue);
      expect(
        HrPayrollDraftsAtomPermissions.routeEntry.isAllowed(readOnlyEntry),
        isTrue,
      );
      // Catalog entry is ∩ hr:read (prompt ∪ noted separately via AppRoutes).
      expect(
        HrPayrollDraftsAtomPermissions.routeEntry.isAllowed(writeOnlyEntry),
        isFalse,
      );
      expect(
        HrPayrollDraftsAtomPermissions.tab.isAllowed(writeOnlyEntry),
        isFalse,
      );
      // AppRoutes ∪ still allows write-only into the module shell.
      final AccessRequirement routeUnion = AccessRequirement(
        anyPermissions: <AppPermission>[
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        ],
        activeModules: <String>[hrRostersModule],
        requiresTenantContext: true,
      );
      expect(routeUnion.isAllowed(writeOnlyEntry), isTrue);
    });

    test('subscription strips payroll when hr-rosters missing', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: hrBillingPaymentsModule,
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(HrPayrollDraftsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        HrPayrollDraftsAtomPermissions.process.isAllowed(noModule),
        isFalse,
      );
      expect(canViewHrSection(noModule, HrDeskSection.payroll), isFalse);
      expect(
        hrAllowedSections(noModule).contains(HrDeskSection.payroll),
        isFalse,
      );
    });

    test(
      'subscription strips process when billing-payments missing '
      '(financial:approve plan gate)',
      () {
        final AppAccessPolicy noBilling = _policy(
          permissions: <AppPermission>{
            AppPermissions.hrRead,
            AppPermissions.hrWrite,
            AppPermissions.financialApprove,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: hrRostersModule, licenseStatus: 'ACTIVE'),
          ],
        );
        expect(HrPayrollDraftsAtomPermissions.tab.isAllowed(noBilling), isTrue);
        expect(
          HrPayrollDraftsAtomPermissions.preview.isAllowed(noBilling),
          isTrue,
        );
        expect(
          HrPayrollDraftsAtomPermissions.process.isAllowed(noBilling),
          isFalse,
        );
      },
    );

    test('ABAC facility strip: missing facility fails route entry', () {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
        facilityId: null,
      );
      expect(HrPayrollDraftsAtomPermissions.tab.isAllowed(noFacility), isTrue);
      expect(
        HrPayrollDraftsAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(canEnterHrWorkspace(noFacility), isFalse);
    });

    test('authorized chrome states map to read ∩ / process ∩', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );
      final AppAccessPolicy processor = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
      );
      expect(HrPayrollDraftsAtomPermissions.loading.isAllowed(reader), isTrue);
      expect(HrPayrollDraftsAtomPermissions.empty.isAllowed(reader), isTrue);
      expect(HrPayrollDraftsAtomPermissions.retry.isAllowed(reader), isTrue);
      expect(
        HrPayrollDraftsAtomPermissions.success.isAllowed(reader),
        isFalse,
      );
      expect(
        HrPayrollDraftsAtomPermissions.validation.isAllowed(processor),
        isTrue,
      );
    });
  });

  testWidgets(
    'read-only: list + Preview present; Process / next-action absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );

      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Pay & Compensation'), findsWidgets);
      expect(find.text('run-1'), findsWidgets);
      expect(find.byType(AppTabToolbarPrimary), findsNothing);
      expect(find.text('Process payroll'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();

      expect(find.text('Preview payroll'), findsOneWidget);
      expect(find.text('Process payroll'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'hr:write without financial:approve: Preview present, Process absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
      );

      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Process payroll'), findsNothing);

      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();

      expect(find.text('Preview payroll'), findsOneWidget);
      expect(find.text('Process payroll'), findsNothing);
    },
  );

  testWidgets(
    'full ∩: Process next-action opens dialog without Quick actions shell',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
      );

      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      expect(find.text('Process payroll'), findsOneWidget);
      await tester.tap(find.text('Process payroll'));
      await tester.pumpAndSettle();

      expect(find.text('Process payroll'), findsWidgets);
      expect(find.text('Quick actions'), findsNothing);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();

      expect(find.text('Preview payroll'), findsOneWidget);
      expect(find.text('Process payroll'), findsWidgets);
    },
  );

  testWidgets(
    'authorized process syncs queue after mutation success',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
      );

      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      await tester.tap(find.text('Process payroll'));
      await tester.pumpAndSettle();

      final Finder submit = find.text('Process payroll');
      expect(submit, findsWidgets);
      await tester.tap(submit.last);
      await tester.pumpAndSettle();

      expect(find.text('HR changes saved.'), findsOneWidget);
      verify(
        () => repository.processPayrollRun(
          any(),
          replaceExistingItems: any(named: 'replaceExistingItems'),
          notes: any(named: 'notes'),
        ),
      ).called(1);
      verify(() => repository.listWorkItems(any())).called(greaterThan(1));
    },
  );

  testWidgets('empty payroll queue remains observable for readers', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.hrRead},
    );

    await _pumpPayrollTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      workItems: const <HrWorkItem>[],
    );

    expect(find.text('No queue items'), findsOneWidget);
    expect(find.text('Process payroll'), findsNothing);
  });

  testWidgets('mobile + dark: read chrome present, process gated', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.hrRead},
    );

    await _pumpPayrollTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );

    expect(find.textContaining('run-1'), findsWidgets);
    expect(find.textContaining('2026-07'), findsWidgets);
    expect(find.text('Process payroll'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop + light: full ∩ process control mounts', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy full = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.financialApprove,
      },
    );

    await _pumpPayrollTab(
      tester,
      repository: repository,
      accessPolicy: full,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Process payroll'), findsOneWidget);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
  });

  testWidgets(
    '∪ nestedWriteMatrix alone does not mount Process (source ∩ stricter)',
    (WidgetTester tester) async {
      // Matrix ∪ allows financial:approve alone; UI process stays source ∩.
      final AppAccessPolicy financialOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.financialApprove,
        },
      );
      expect(
        HrPayrollDraftsAtomPermissions.nestedWriteMatrix.isAllowed(
          financialOnly,
        ),
        isTrue,
      );

      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: financialOnly,
      );

      expect(_tab('Pay & Compensation'), findsOneWidget);
      expect(find.text('Process payroll'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();

      expect(find.text('Preview payroll'), findsOneWidget);
      expect(find.text('Process payroll'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: missing hr-rosters denies Payroll chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: hrBillingPaymentsModule,
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Process payroll'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write-only ∩ denial: catalog entry fails; Payroll chrome omitted',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
      );
      expect(
        HrPayrollDraftsAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
      expect(HrPayrollDraftsAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Process payroll'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Preview opens nested dialog; Process dialog shows fields',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
          AppPermissions.financialApprove,
        },
      );

      await _pumpPayrollTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      await tester.tap(find.text('run-1').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preview payroll'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Casey Payroll'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Process payroll').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Notes'), findsWidgets);
      expect(find.textContaining('Replace'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Payroll',
    (WidgetTester tester) async {
      when(() => repository.loadOverview()).thenAnswer(
        (_) async => const Result<HrWorkspaceOverview>.failure(
          AppFailure.network(),
        ),
      );
      when(() => repository.listStaffProfiles(any())).thenAnswer(
        (_) async => const Result<AppPage<HrStaffProfile>>.failure(
          AppFailure.network(),
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
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
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{
                  AppPermissions.hrRead,
                  AppPermissions.hrWrite,
                  AppPermissions.financialApprove,
                },
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('mobile + light: Payroll chrome + process ∩ present', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy full = _policy(
      permissions: <AppPermission>{
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.financialApprove,
      },
    );

    await _pumpPayrollTab(
      tester,
      repository: repository,
      accessPolicy: full,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.light,
    );

    expect(_tab('Pay & Compensation'), findsOneWidget);
    expect(find.textContaining('run-1'), findsWidgets);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);

    // Narrow layouts may collapse the next-action column; detail still gates.
    await tester.tap(find.textContaining('run-1').first);
    await tester.pumpAndSettle();

    expect(find.text('Preview payroll'), findsOneWidget);
    expect(find.text('Process payroll'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop + dark: read-only Process absent', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.hrRead},
    );

    await _pumpPayrollTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.dark,
    );

    expect(find.textContaining('run-1'), findsWidgets);
    expect(find.text('Process payroll'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });
}
