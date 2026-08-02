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
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/operations/data/repositories/operations_repository_impl.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/domain/repositories/operations_repository.dart';
import 'package:hosspi_hms/features/operations/presentation/operations_access.dart';
import 'package:hosspi_hms/features/operations/presentation/pages/operations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOperationsRepository extends Mock implements OperationsRepository {}

/// In-progress request without asset → Update status next-action.
const OperationsWorkItem _inProgressNoAsset = OperationsWorkItem(
  id: 'MR-IP-1',
  displayId: 'MR-IP-1',
  status: 'IN_PROGRESS',
  metadata: OperationsRequestMetadata(
    issue: 'Boiler pressure alarm',
    priority: 'HIGH',
    category: 'HVAC',
    assignee: 'Tech A',
  ),
);

/// In-progress request with asset → Record service work next-action.
const OperationsWorkItem _inProgressWithAsset = OperationsWorkItem(
  id: 'MR-IP-2',
  displayId: 'MR-IP-2',
  status: 'IN_PROGRESS',
  assetId: 'AS-001',
  assetLabel: 'Boiler-1',
  metadata: OperationsRequestMetadata(
    issue: 'Boiler valve leak',
    priority: 'NORMAL',
    category: 'HVAC',
    assignee: 'Tech B',
  ),
);

const OperationsAsset _boilerAsset = OperationsAsset(
  id: 'AS-001',
  name: 'Boiler-1',
  assetTag: 'BLR-01',
  status: 'OPEN',
  facilityLabel: 'Main Campus',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['VIEWER'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: operationsFacilitiesMaintenanceModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
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

void _stubRepository(
  _MockOperationsRepository repository, {
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[
    _inProgressNoAsset,
  ],
  List<OperationsAsset> assets = const <OperationsAsset>[_boilerAsset],
  Result<AppPage<OperationsWorkItem>>? listOverride,
}) {
  when(() => repository.listRequests(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final OperationsWorkItemQuery query =
        invocation.positionalArguments.single as OperationsWorkItemQuery;
    List<OperationsWorkItem> items = requests;
    final String? status = query.status?.trim().toUpperCase();
    if (status != null && status.isNotEmpty) {
      items = requests
          .where((OperationsWorkItem item) => item.normalizedStatus == status)
          .toList(growable: false);
    }
    return Result<AppPage<OperationsWorkItem>>.success(
      AppPage<OperationsWorkItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listAssets(any())).thenAnswer(
    (_) async => Result<AppPage<OperationsAsset>>.success(
      AppPage<OperationsAsset>(
        items: assets,
        request: const AppPageRequest(),
        totalItemCount: assets.length,
      ),
    ),
  );
  when(() => repository.listServiceLogs(any())).thenAnswer(
    (_) async => const Result<AppPage<OperationsServiceLog>>.success(
      AppPage<OperationsServiceLog>(
        items: <OperationsServiceLog>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(() => repository.getRequest(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.first as String;
    final OperationsWorkItem item = requests.firstWhere(
      (OperationsWorkItem request) =>
          request.id == id || request.displayId == id,
      orElse: () => requests.first,
    );
    return Result<OperationsWorkItem>.success(item);
  });
}

Future<void> _pumpInProgressTab(
  WidgetTester tester, {
  required _MockOperationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[
    _inProgressNoAsset,
  ],
  Result<AppPage<OperationsWorkItem>>? listOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    requests: requests,
    listOverride: listOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/operations?section=in-progress',
    routes: <RouteBase>[
      GoRoute(
        path: '/operations',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: OperationsWorkspacePage(
              initialQuery: OperationsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        operationsRepositoryProvider.overrideWithValue(repository),
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

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.textContaining(label),
  );
}

void main() {
  late _MockOperationsRepository repository;

  setUpAll(() {
    registerFallbackValue(const OperationsWorkItemQuery());
    registerFallbackValue(const OperationsAssetQuery());
    registerFallbackValue(const OperationsServiceLogQuery());
    registerFallbackValue(_inProgressNoAsset);
    registerFallbackValue(
      const OperationsServiceLogDraft(assetId: 'AS-001', notes: 'Done'),
    );
    registerFallbackValue(
      const OperationsRequestDraft(
        category: 'OTHER',
        priority: 'NORMAL',
        issue: 'Test',
      ),
    );
    registerFallbackValue(
      const OperationsTriageDraft(assignedEngineer: 'Tech'),
    );
    registerFallbackValue(
      const OperationsStatusUpdateDraft(status: 'COMPLETED'),
    );
    registerFallbackValue(
      const OperationsRequestNoteDraft(kind: 'CLOSEOUT', note: 'Done'),
    );
  });

  setUp(() {
    repository = _MockOperationsRepository();
  });

  test('reuses feature *Requirement helpers (no second vocabulary)', () {
    expect(
      identical(
        OperationsInProgressAtomPermissions.tab,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsInProgressAtomPermissions.write,
        operationsWorkspaceWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsInProgressAtomPermissions.createRequest,
        operationsWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsInProgressAtomPermissions.mutate,
        operationsMutationRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsInProgressAtomPermissions.report,
        operationsWorkspaceReportRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsInProgressAtomPermissions.routeEntry,
        RouteAccessCatalog.operationsEntry,
      ),
      isTrue,
    );
    expect(
      identical(
        operationsWorkspaceReportRequirement,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      OperationsInProgressAtomPermissions.create.allPermissions,
      contains(AppPermissions.operationsWrite),
    );
    expect(
      OperationsInProgressAtomPermissions.tab.allPermissions,
      contains(AppPermissions.operationsRead),
    );
    expect(
      OperationsInProgressAtomPermissions.routeEntry.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
      ]),
    );
  });

  test('atom map covers inventory verbs (AC1)', () {
    expect(OperationsInProgressAtomPermissions.tab, isNotNull);
    expect(OperationsInProgressAtomPermissions.listChrome, isNotNull);
    expect(OperationsInProgressAtomPermissions.search, isNotNull);
    expect(OperationsInProgressAtomPermissions.filters, isNotNull);
    expect(OperationsInProgressAtomPermissions.settings, isNotNull);
    expect(OperationsInProgressAtomPermissions.empty, isNotNull);
    expect(OperationsInProgressAtomPermissions.loading, isNotNull);
    expect(OperationsInProgressAtomPermissions.retry, isNotNull);
    expect(OperationsInProgressAtomPermissions.success, isNotNull);
    expect(OperationsInProgressAtomPermissions.validation, isNotNull);
    expect(OperationsInProgressAtomPermissions.rowSelect, isNotNull);
    expect(OperationsInProgressAtomPermissions.detail, isNotNull);
    expect(OperationsInProgressAtomPermissions.nextAction, isNotNull);
    expect(OperationsInProgressAtomPermissions.create, isNotNull);
    expect(OperationsInProgressAtomPermissions.update, isNotNull);
    expect(OperationsInProgressAtomPermissions.delete, isNotNull);
    expect(OperationsInProgressAtomPermissions.updateStatus, isNotNull);
    expect(OperationsInProgressAtomPermissions.serviceLog, isNotNull);
    expect(OperationsInProgressAtomPermissions.assign, isNotNull);
    expect(OperationsInProgressAtomPermissions.note, isNotNull);
    expect(OperationsInProgressAtomPermissions.closeout, isNotNull);
    expect(OperationsInProgressAtomPermissions.report, isNotNull);
    expect(OperationsInProgressAtomPermissions.nestedWrite, isNotNull);
    expect(OperationsInProgressAtomPermissions.nestedRead, isNotNull);
    expect(OperationsInProgressAtomPermissions.routeEntry, isNotNull);
  });

  test(
    'section tab gate: In progress uses InProgress atom tab requirement',
    () {
      expect(
        identical(
          operationsSectionTabRequirement(OperationsDeskSection.inProgress),
          OperationsInProgressAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        canViewOperationsSection(
          _policy(permissions: <AppPermission>{AppPermissions.operationsRead}),
          OperationsDeskSection.inProgress,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    '∩ denial: read-only hides Create / write next-actions; Report + list remain',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(OperationsInProgressAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        OperationsInProgressAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        OperationsInProgressAtomPermissions.updateStatus.isAllowed(reader),
        isFalse,
      );
      expect(
        OperationsInProgressAtomPermissions.report.isAllowed(reader),
        isTrue,
      );
      expect(canMutateOperations(reader), isFalse);

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Boiler pressure alarm'), findsOneWidget);
      expect(_tabLabel('In progress'), findsOneWidget);
      expect(find.byType(AppListTable<OperationsWorkItem>), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Update repair status'), findsNothing);
      expect(find.text('Review request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Boiler pressure alarm'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Add service log'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Create, Update status next-action, complementary detail mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        roles: const <String>['OPERATIONS'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        OperationsInProgressAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        OperationsInProgressAtomPermissions.updateStatus.isAllowed(writer),
        isTrue,
      );
      expect(canMutateOperations(writer), isTrue);

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Boiler pressure alarm'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.byTooltip('Update repair status'), findsOneWidget);

      await tester.tap(find.text('Boiler pressure alarm'));
      await tester.pumpAndSettle();

      // Update status is the row next-action — omitted from complementary.
      // No assetId ⇒ Add service log also absent; Assign remains.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Update status'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Assign'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩ with asset: Record service work next-action mounts',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        roles: const <String>['OPERATIONS'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        OperationsInProgressAtomPermissions.serviceLog.isAllowed(writer),
        isTrue,
      );

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        requests: const <OperationsWorkItem>[_inProgressWithAsset],
      );

      expect(find.text('Boiler valve leak'), findsOneWidget);
      expect(find.byTooltip('Record service work'), findsOneWidget);
      expect(find.byTooltip('Update repair status'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:write alone satisfies entry; In progress chrome needs read ∩',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      expect(
        OperationsInProgressAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        OperationsInProgressAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        OperationsInProgressAtomPermissions.report.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        OperationsInProgressAtomPermissions.create.isAllowed(writeOnly),
        isTrue,
      );
      expect(canEnterOperationsWorkspace(writeOnly), isTrue);
      expect(canReadOperations(writeOnly), isFalse);

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Boiler pressure alarm'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:read alone satisfies entry and In progress chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy readOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsInProgressAtomPermissions.routeEntry.isAllowed(readOnly),
        isTrue,
      );
      expect(
        OperationsInProgressAtomPermissions.tab.isAllowed(readOnly),
        isTrue,
      );

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: readOnly,
      );

      expect(find.text('Boiler pressure alarm'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
    },
  );

  testWidgets(
    'report ∩: operations:read mounts Report (source Always narrowed); write alone does not',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsInProgressAtomPermissions.report.isAllowed(opsReader),
        isTrue,
      );

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.textContaining('All requests'), findsWidgets);
      expect(find.text('Preview'), findsNothing);

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsWrite},
        ),
      );
      expect(find.text('Report'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: facilities-maintenance missing omits In progress chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        OperationsInProgressAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        OperationsInProgressAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Boiler pressure alarm'), findsNothing);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC facility strip: missing facility context fails route entry ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        facilityId: null,
      );
      expect(
        OperationsInProgressAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        OperationsInProgressAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(canEnterOperationsWorkspace(noFacility), isFalse);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: no cross-module nested write atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        roles: const <String>['OPERATIONS'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        OperationsInProgressAtomPermissions.nestedWrite.isAllowed(writer),
        isTrue,
      );

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Boiler pressure alarm'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Billing'), findsNothing);
      expect(find.textContaining('Clinical'), findsNothing);
      expect(find.text('Service logs'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Create request opens dialog with validation chrome',
    (WidgetTester tester) async {
      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.textContaining('Create request'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Create request'), findsWidgets);
      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));

      await tester.tap(find.text('Create request').last);
      await tester.pumpAndSettle();

      // Required issue empty — dialog stays; no mutation.
      verifyNever(() => repository.createRequest(any()));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Update status next-action mutates, syncs list, and shows success',
    (WidgetTester tester) async {
      const OperationsWorkItem completed = OperationsWorkItem(
        id: 'MR-IP-1',
        displayId: 'MR-IP-1',
        status: 'COMPLETED',
        metadata: OperationsRequestMetadata(
          issue: 'Boiler pressure alarm',
          priority: 'HIGH',
          category: 'HVAC',
          assignee: 'Tech A',
        ),
      );
      when(() => repository.updateRequestStatus(any(), any())).thenAnswer(
        (_) async => const Result<OperationsWorkItem>.success(completed),
      );

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Update repair status'));
      await tester.pumpAndSettle();

      expect(find.text('Save status'), findsOneWidget);
      expect(find.text('REQUEST DETAIL'), findsNothing);

      await tester.tap(find.text('Save status'));
      await tester.pumpAndSettle();

      verify(() => repository.updateRequestStatus(any(), any())).called(1);
      expect(find.text('Operations changes saved.'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Record service work next-action mutates and syncs',
    (WidgetTester tester) async {
      when(() => repository.addServiceLog(any())).thenAnswer(
        (_) async => const Result<OperationsServiceLog>.success(
          OperationsServiceLog(
            id: 'SL-1',
            assetId: 'AS-001',
            notes: 'Replaced valve',
          ),
        ),
      );

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        requests: const <OperationsWorkItem>[_inProgressWithAsset],
      );

      await tester.tap(find.byTooltip('Record service work'));
      await tester.pumpAndSettle();

      expect(find.text('Save service log'), findsOneWidget);
      expect(find.text('REQUEST DETAIL'), findsNothing);

      await tester.enterText(find.byType(TextFormField).last, 'Replaced valve');
      await tester.tap(find.text('Save service log'));
      await tester.pumpAndSettle();

      verify(() => repository.addServiceLog(any())).called(1);
      expect(find.text('Operations changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'empty authorized In progress still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        requests: const <OperationsWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No maintenance requests'), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty write-authorized In progress keeps Create request primary',
    (WidgetTester tester) async {
      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        requests: const <OperationsWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No maintenance requests'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on In progress',
    (WidgetTester tester) async {
      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        listOverride: const Result<AppPage<OperationsWorkItem>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(AppFailureStateView), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on In progress', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.listRequests(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<AppPage<OperationsWorkItem>>.success(
        AppPage<OperationsWorkItem>(
          items: const <OperationsWorkItem>[_inProgressNoAsset],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      );
    });
    when(() => repository.listAssets(any())).thenAnswer(
      (_) async => Result<AppPage<OperationsAsset>>.success(
        AppPage<OperationsAsset>(
          items: const <OperationsAsset>[_boilerAsset],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    when(() => repository.listServiceLogs(any())).thenAnswer(
      (_) async => const Result<AppPage<OperationsServiceLog>>.success(
        AppPage<OperationsServiceLog>(
          items: <OperationsServiceLog>[],
          request: AppPageRequest(),
        ),
      ),
    );

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/operations?section=in-progress',
      routes: <RouteBase>[
        GoRoute(
          path: '/operations',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: OperationsWorkspacePage(
                initialQuery: OperationsWorkspaceQuery.fromUri(state.uri),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          operationsRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.operationsRead,
                AppPermissions.operationsWrite,
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
    expect(find.textContaining('Loading'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('Boiler pressure alarm'), findsOneWidget);
  });

  testWidgets(
    'mobile viewport: authorized next-action trailing; read-only omits write',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        roles: const <String>['OPERATIONS'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(AppListTableGrid), findsNothing);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(find.byTooltip('Update repair status'), findsOneWidget);
      expect(_tabLabel('In progress'), findsOneWidget);

      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expect(find.byTooltip('Update repair status'), findsNothing);
      expect(find.text('Review request'), findsNothing);
    },
  );

  testWidgets(
    'desktop viewport: In progress status filter absent for authorized reader',
    (WidgetTester tester) async {
      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        physicalSize: const Size(1440, 900),
      );

      final AppListTable<OperationsWorkItem> table = tester
          .widget<AppListTable<OperationsWorkItem>>(
            find.byType(AppListTable<OperationsWorkItem>),
          );
      expect(
        table.search!.filterGroups.any(
          (AppSearchBarFilterGroup group) => group.key == 'status',
        ),
        isFalse,
      );
    },
  );

  testWidgets('light + dark themes mount authorized In progress chrome', (
    WidgetTester tester,
  ) async {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      await _pumpInProgressTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        themeMode: mode,
      );

      expect(find.text('Boiler pressure alarm'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    }
  });
}
