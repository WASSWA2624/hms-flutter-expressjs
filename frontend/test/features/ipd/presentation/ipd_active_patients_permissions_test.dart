import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_board_next_action.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdAdmissionSummary _needsNursing = IpdAdmissionSummary(
  id: 'adm-active-1',
  displayId: 'ADM-A1',
  patientId: 'pat-active-1',
  patientDisplayName: 'Ada Active',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED',
  hasActiveBed: true,
  nextStep: 'RECORD_NURSING_NOTE',
  wardDisplayName: 'Ward A',
  bedDisplayLabel: 'Bed 1',
);

const IpdAdmissionSummary _continueCare = IpdAdmissionSummary(
  id: 'adm-active-2',
  displayId: 'ADM-A2',
  patientId: 'pat-active-2',
  patientDisplayName: 'Omar Observed',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED',
  hasActiveBed: true,
  wardDisplayName: 'Ward A',
  bedDisplayLabel: 'Bed 2',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
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
  final List<AppModuleEntitlement> resolvedModules =
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
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBoard(
  _MockIpdRepository repository, {
  List<IpdAdmissionSummary> board = const <IpdAdmissionSummary>[
    _needsNursing,
    _continueCare,
  ],
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  IpdAdmissionDetail? detailOverride,
}) {
  when(() => repository.listAdmissions(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    List<IpdAdmissionSummary> items = board;
    if (query.scope == IpdQueueScope.activePatients ||
        query.section == IpdWorkspaceSection.activePatients) {
      items = board;
    }
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((IpdAdmissionSummary item) => item.matchesSearch(search))
          .toList(growable: false);
    }
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
  when(() => repository.getAdmission(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detailOverride != null) {
      return Result<IpdAdmissionDetail>.success(detailOverride);
    }
    final String id = invocation.positionalArguments.single as String;
    final IpdAdmissionSummary summary = board.firstWhere(
      (IpdAdmissionSummary item) => item.id == id || item.displayId == id,
      orElse: () => board.first,
    );
    return Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(summary: summary),
    );
  });
  when(
    () => repository.addNursingNote(any(), any()),
  ).thenAnswer((Invocation invocation) async {
    final String id = invocation.positionalArguments.first as String;
    final IpdAdmissionSummary summary = board.firstWhere(
      (IpdAdmissionSummary item) => item.id == id || item.displayId == id,
      orElse: () => _needsNursing,
    );
    return Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(
        summary: summary.copyWith(nextStep: 'CONTINUE_CARE'),
        nursingNotes: const <IpdClinicalRecord>[
          IpdClinicalRecord(
            id: 'note-1',
            kind: 'NURSING_NOTE',
            title: 'Shift note',
          ),
        ],
      ),
    );
  });
}

Future<void> _pumpActiveTab(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdAdmissionSummary> board = const <IpdAdmissionSummary>[
    _needsNursing,
    _continueCare,
  ],
  Result<AppPage<IpdAdmissionSummary>>? listOverride,
  String initialLocation = '/ipd?section=active',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(repository, board: board, listOverride: listOverride);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
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
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  if (initialLocation.contains('id=')) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IpdActivePatientsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          IpdActivePatientsAtomPermissions.tab,
          ipdWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.listChrome,
          ipdWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.clinicalWrite,
          ipdClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.operationalWrite,
          ipdOperationalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.startAdmission,
          ipdOperationalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.nextActionNursingNote,
          ipdClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.billingRead,
          ipdBillingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.billingPanel,
          ipdBillingPanelReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.manageBeds,
          ipdBedManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.routeEntry,
          RouteAccessCatalog.ipdEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.catalogEntry,
          RouteAccessCatalog.ipdEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          ipdBoardTabRequirement(IpdWorkspaceSection.activePatients),
          IpdActivePatientsAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.nestedWrite,
          ipdClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IpdActivePatientsAtomPermissions.planOrManageDischarge,
          ipdClinicalWriteRequirement,
        ),
        isTrue,
      );
      expect(ipdRouteEntryMatchesAppRoutes(), isTrue);
      expect(
        AppRoutes.ipd.requiredAnyPermissions.toSet(),
        IpdActivePatientsAtomPermissions.routeEntry.anyPermissions.toSet(),
      );
    });

    test('∩ denial: clinical:read alone does not grant write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IpdActivePatientsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        IpdActivePatientsAtomPermissions.clinicalWrite.isAllowed(reader),
        isFalse,
      );
      expect(
        IpdActivePatientsAtomPermissions.nextActionNursingNote.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(
        IpdActivePatientsAtomPermissions.startAdmission.isAllowed(reader),
        isFalse,
      );
      expect(canWriteIpdClinical(reader), isFalse);
      expect(canViewIpdActivePatients(reader), isTrue);
    });

    test(
      'source keep: operational write ∪ (matrix ∩ clinical:write alone)',
      () {
        final AppAccessPolicy clinicalWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(
          IpdActivePatientsAtomPermissions.clinicalWrite.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          IpdActivePatientsAtomPermissions.operationalWrite.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(canWriteIpdClinical(clinicalWriter), isTrue);
        expect(canOperateIpd(clinicalWriter), isTrue);

        final AppAccessPolicy opsWriter = _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        );
        // Source keep ∪ operations:write for operational atoms.
        expect(
          IpdActivePatientsAtomPermissions.operationalWrite.isAllowed(
            opsWriter,
          ),
          isTrue,
        );
        expect(
          IpdActivePatientsAtomPermissions.clinicalWrite.isAllowed(opsWriter),
          isFalse,
        );
        expect(
          IpdActivePatientsAtomPermissions.nextActionNursingNote.isAllowed(
            opsWriter,
          ),
          isFalse,
        );
      },
    );

    test('∪ allowance: operations:read satisfies Active Patients tab', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        IpdActivePatientsAtomPermissions.tab.isAllowed(opsReader),
        isTrue,
      );
      expect(canViewIpdActivePatients(opsReader), isTrue);
      expect(canReadIpd(opsReader), isTrue);
      expect(
        IpdActivePatientsAtomPermissions.clinicalWrite.isAllowed(opsReader),
        isFalse,
      );
    });

    test('∪ allowance: billing:read satisfies route entry, not tab read', () {
      final AppAccessPolicy billingReader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(
        IpdActivePatientsAtomPermissions.routeEntry.isAllowed(billingReader),
        isTrue,
      );
      expect(canEnterIpdWorkspace(billingReader), isTrue);
      expect(canViewIpdActivePatients(billingReader), isFalse);
      expect(canReadIpd(billingReader), isFalse);
      expect(ipdAllowedSections(billingReader), isEmpty);
    });

    test('subscription strip: inpatient-bed-management required', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(IpdActivePatientsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        IpdActivePatientsAtomPermissions.clinicalWrite.isAllowed(noModule),
        isFalse,
      );
      expect(ipdAllowedSections(noModule), isEmpty);
    });

    test(
      'ABAC: missing facility still allows Active chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          IpdActivePatientsAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          IpdActivePatientsAtomPermissions.clinicalWrite.isAllowed(noFacility),
          isTrue,
        );
        expect(
          IpdActivePatientsAtomPermissions.routeEntry.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test('nested billing read ∩ absent without billing:read', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IpdActivePatientsAtomPermissions.billingRead.isAllowed(clinicalOnly),
        isFalse,
      );
      expect(
        IpdActivePatientsAtomPermissions.billingPanel.isAllowed(clinicalOnly),
        isFalse,
      );
      expect(canReadIpdBilling(clinicalOnly), isFalse);

      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.billingRead,
        },
      );
      expect(
        IpdActivePatientsAtomPermissions.billingRead.isAllowed(withBilling),
        isTrue,
      );
      expect(
        IpdActivePatientsAtomPermissions.billingPanel.isAllowed(withBilling),
        isTrue,
      );
    });

    test('manage beds keeps source (no unit:manage alone)', () {
      final AppAccessPolicy unitOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.unitManage,
        },
        roles: const <String>['UNIT_MANAGER'],
      );
      expect(
        IpdActivePatientsAtomPermissions.manageBeds.isAllowed(unitOnly),
        isFalse,
      );

      final AppAccessPolicy facilityAdmin = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(
        IpdActivePatientsAtomPermissions.manageBeds.isAllowed(facilityAdmin),
        isTrue,
      );
    });

    test('next-action / panel deep-link requirements map correctly', () {
      expect(
        ipdBoardNextActionRequirement(IpdBoardNextActionKind.recordNursingNote),
        same(ipdClinicalWriteRequirement),
      );
      expect(
        ipdBoardNextActionRequirement(IpdBoardNextActionKind.requestTransfer),
        same(ipdOperationalWriteRequirement),
      );
      expect(
        ipdBoardNextActionRequirement(IpdBoardNextActionKind.continueCare),
        isNull,
      );
      expect(
        ipdFocusedMutationRequirement(panel: IpdDetailPanel.nursing),
        same(ipdClinicalWriteRequirement),
      );
      expect(
        ipdFocusedMutationRequirement(panel: IpdDetailPanel.beds),
        same(ipdOperationalWriteRequirement),
      );
      expect(
        ipdBoardNextActionKind(_needsNursing),
        IpdBoardNextActionKind.recordNursingNote,
      );
      expect(
        ipdBoardNextActionKind(_continueCare),
        IpdBoardNextActionKind.continueCare,
      );
    });
  });

  testWidgets(
    'read-only ∩ denial: Active list visible; nursing note / Start admission absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.textContaining('Active Patients'), findsWidgets);
      expect(find.text('Ada Active'), findsOneWidget);
      expect(find.text('Omar Observed'), findsOneWidget);
      expect(find.text('Add nursing note'), findsNothing);
      expect(find.byTooltip('Start admission'), findsNothing);
      expect(find.text('Continue care'), findsOneWidget);
      expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
    },
  );

  testWidgets(
    'authorized clinical writer: nursing note next-action present',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Add nursing note'), findsWidgets);
      expect(find.byTooltip('Start admission'), findsOneWidget);
      expect(find.text('Ada Active'), findsOneWidget);
    },
  );

  testWidgets(
    '∪ operations:read shows Active tab without clinical write next-actions',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      expect(find.textContaining('Active Patients'), findsWidgets);
      expect(find.text('Ada Active'), findsOneWidget);
      expect(find.text('Add nursing note'), findsNothing);
      expect(find.byTooltip('Start admission'), findsNothing);
    },
  );

  testWidgets(
    'source ∪ operations:write mounts Start admission without nursing note',
    (WidgetTester tester) async {
      final AppAccessPolicy opsWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        roles: const <String>['OPERATIONS'],
      );
      expect(
        IpdActivePatientsAtomPermissions.startAdmission.isAllowed(opsWriter),
        isTrue,
      );
      expect(
        IpdActivePatientsAtomPermissions.nextActionNursingNote.isAllowed(
          opsWriter,
        ),
        isFalse,
      );

      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: opsWriter,
      );

      expect(find.textContaining('Active Patients'), findsWidgets);
      expect(find.byTooltip('Start admission'), findsOneWidget);
      expect(find.text('Add nursing note'), findsNothing);
      expect(find.text('Continue care'), findsOneWidget);
      expect(find.byTooltip('Manage beds'), findsNothing);
    },
  );

  testWidgets(
    'Manage beds not mounted on Active even for facility admin',
    (WidgetTester tester) async {
      final AppAccessPolicy facilityAdmin = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.facilityAdmin,
        },
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(
        IpdActivePatientsAtomPermissions.manageBeds.isAllowed(facilityAdmin),
        isTrue,
      );

      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: facilityAdmin,
      );

      expect(find.byTooltip('Manage beds'), findsNothing);
      expect(find.byTooltip('Start admission'), findsOneWidget);
    },
  );

  testWidgets(
    'billing:read alone collapses strip (no board read)',
    (WidgetTester tester) async {
      final AppAccessPolicy billingReader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: billingReader,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byType(AppListTable<IpdAdmissionSummary>), findsNothing);
    },
  );

  testWidgets(
    'post-mutation sync: nursing note patches selected admission via clinical write',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IpdActivePatientsAtomPermissions.nextActionNursingNote.isAllowed(
          writer,
        ),
        isTrue,
      );

      _stubBoard(repository);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
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
            appAccessPolicyProvider.overrideWithValue(writer),
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
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final Element element = tester.element(find.byType(IpdWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final IpdWorkspaceController controller = container.read(
        ipdWorkspaceControllerProvider.notifier,
      );
      final AppFailure? selectFailure = await controller.selectAdmission(
        _needsNursing,
      );
      expect(selectFailure, isNull);

      final AppFailure? mutateFailure = await controller.addNursingNote(
        _needsNursing,
        'Night shift stable',
      );
      expect(mutateFailure, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verify(() => repository.addNursingNote(any(), any())).called(1);

      final IpdWorkspaceState? state = container
          .read(ipdWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (IpdWorkspaceState value) => value,
            failure: (_) => null,
          );
      expect(state?.selectedAdmission?.nursingNotes, isNotEmpty);
      expect(
        state?.admissions.items.any(
          (IpdAdmissionSummary item) => item.id == _needsNursing.id,
        ),
        isTrue,
      );
    },
  );

  testWidgets('authorized empty state remains observable for readers', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );
    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      listOverride: Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: const <IpdAdmissionSummary>[],
          request: const AppPageRequest(pageIndex: 0, pageSize: 25),
          totalItemCount: 0,
        ),
      ),
    );
    expect(find.textContaining('No admissions'), findsOneWidget);
    expect(find.text('Add nursing note'), findsNothing);
  });

  testWidgets('authorized error/retry surface remains observable on Active', (
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
      listOverride: const Result<AppPage<IpdAdmissionSummary>>.failure(
        AppFailure.network(),
      ),
    );

    expect(find.byType(AsyncStateScaffold<IpdWorkspaceState>), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'panel=nursing deep link does not open without clinical write',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(
        ipdFocusedMutationRequirement(panel: IpdDetailPanel.nursing)!.isAllowed(
          reader,
        ),
        isFalse,
      );

      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        initialLocation: '/ipd?section=active&id=adm-active-1&panel=nursing',
      );

      expect(find.text('Add nursing note'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('mobile + dark: read-only chrome hides write atoms', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );
    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );
    expect(find.textContaining('Active Patients'), findsWidgets);
    expect(find.text('Add nursing note'), findsNothing);
    expect(find.byTooltip('Start admission'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop + light: clinical write mounts nursing note', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );
    await _pumpActiveTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );
    expect(find.text('Add nursing note'), findsWidgets);
    expect(find.byTooltip('Start admission'), findsOneWidget);
  });

  testWidgets(
    'detail without billing:read omits insurance authorization panel',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Ada Active'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Insurance authorization'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'detail with billing:read mounts insurance authorization panel',
    (WidgetTester tester) async {
      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.billingRead,
        },
      );
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: withBilling,
      );

      await tester.tap(find.text('Ada Active'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Insurance authorization'), findsOneWidget);
    },
  );
}
