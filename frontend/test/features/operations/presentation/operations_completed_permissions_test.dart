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

const OperationsWorkItem _completedRequest = OperationsWorkItem(
  id: 'MR-DONE',
  displayId: 'MR-DONE',
  status: 'COMPLETED',
  assetLabel: 'HVAC Unit',
  metadata: OperationsRequestMetadata(
    issue: 'Filter replaced',
    priority: 'LOW',
    category: 'HVAC',
  ),
);

const OperationsWorkItem _cancelledRequest = OperationsWorkItem(
  id: 'MR-CXL',
  displayId: 'MR-CXL',
  status: 'CANCELLED',
  assetLabel: 'Pump',
  metadata: OperationsRequestMetadata(
    issue: 'Cancelled leak check',
    priority: 'NORMAL',
    category: 'PLUMBING',
  ),
);

const OperationsAsset _generatorAsset = OperationsAsset(
  id: 'AS-001',
  name: 'Backup Generator',
  assetTag: 'GEN-01',
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
    _completedRequest,
  ],
  List<OperationsAsset> assets = const <OperationsAsset>[_generatorAsset],
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

Future<void> _pumpCompletedTab(
  WidgetTester tester, {
  required _MockOperationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[
    _completedRequest,
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
    initialLocation: '/operations?section=completed',
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
    registerFallbackValue(_completedRequest);
    registerFallbackValue(
      const OperationsRequestDraft(
        category: 'OTHER',
        priority: 'NORMAL',
        issue: 'Test',
      ),
    );
    registerFallbackValue(
      const OperationsRequestNoteDraft(kind: 'CLOSEOUT', note: 'Done'),
    );
    registerFallbackValue(
      const OperationsStatusUpdateDraft(status: 'COMPLETED'),
    );
  });

  setUp(() {
    repository = _MockOperationsRepository();
  });

  test('reuses feature *Requirement helpers (no second vocabulary)', () {
    expect(
      identical(
        OperationsCompletedAtomPermissions.tab,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsCompletedAtomPermissions.write,
        operationsWorkspaceWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsCompletedAtomPermissions.createRequest,
        operationsWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsCompletedAtomPermissions.mutate,
        operationsMutationRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsCompletedAtomPermissions.closeout,
        operationsWorkspaceWriteRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsCompletedAtomPermissions.report,
        operationsWorkspaceReportRequirement,
      ),
      isTrue,
    );
    expect(
      identical(
        OperationsCompletedAtomPermissions.routeEntry,
        RouteAccessCatalog.operationsEntry,
      ),
      isTrue,
    );
    // Report source inventory "Always" narrowed to matrix read ∩.
    expect(
      identical(
        operationsWorkspaceReportRequirement,
        operationsWorkspaceReadRequirement,
      ),
      isTrue,
    );
    expect(
      OperationsCompletedAtomPermissions.create.allPermissions,
      contains(AppPermissions.operationsWrite),
    );
    expect(
      OperationsCompletedAtomPermissions.tab.allPermissions,
      contains(AppPermissions.operationsRead),
    );
    // Route entry ∪ read|write (matrix union allowance).
    expect(
      OperationsCompletedAtomPermissions.routeEntry.anyPermissions,
      containsAll(<AppPermission>[
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
      ]),
    );
  });

  test('atom map covers inventory verbs (AC1)', () {
    expect(OperationsCompletedAtomPermissions.tab, isNotNull);
    expect(OperationsCompletedAtomPermissions.listChrome, isNotNull);
    expect(OperationsCompletedAtomPermissions.search, isNotNull);
    expect(OperationsCompletedAtomPermissions.filters, isNotNull);
    expect(OperationsCompletedAtomPermissions.settings, isNotNull);
    expect(OperationsCompletedAtomPermissions.empty, isNotNull);
    expect(OperationsCompletedAtomPermissions.loading, isNotNull);
    expect(OperationsCompletedAtomPermissions.retry, isNotNull);
    expect(OperationsCompletedAtomPermissions.success, isNotNull);
    expect(OperationsCompletedAtomPermissions.validation, isNotNull);
    expect(OperationsCompletedAtomPermissions.rowSelect, isNotNull);
    expect(OperationsCompletedAtomPermissions.detail, isNotNull);
    expect(OperationsCompletedAtomPermissions.nextAction, isNotNull);
    expect(OperationsCompletedAtomPermissions.create, isNotNull);
    expect(OperationsCompletedAtomPermissions.update, isNotNull);
    expect(OperationsCompletedAtomPermissions.delete, isNotNull);
    expect(OperationsCompletedAtomPermissions.closeout, isNotNull);
    expect(OperationsCompletedAtomPermissions.assign, isNotNull);
    expect(OperationsCompletedAtomPermissions.updateStatus, isNotNull);
    expect(OperationsCompletedAtomPermissions.serviceLog, isNotNull);
    expect(OperationsCompletedAtomPermissions.note, isNotNull);
    expect(OperationsCompletedAtomPermissions.report, isNotNull);
    expect(OperationsCompletedAtomPermissions.nestedWrite, isNotNull);
    expect(OperationsCompletedAtomPermissions.nestedRead, isNotNull);
    expect(OperationsCompletedAtomPermissions.routeEntry, isNotNull);
  });

  testWidgets(
    'read ∩ denial of write: list/Report visible; Create / Closeout / detail writes absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsCompletedAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        OperationsCompletedAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        OperationsCompletedAtomPermissions.closeout.isAllowed(reader),
        isFalse,
      );
      expect(
        OperationsCompletedAtomPermissions.report.isAllowed(reader),
        isTrue,
      );

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Filter replaced'), findsOneWidget);
      expect(_tabLabel('Completed'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Add closeout note if needed'), findsNothing);
      expect(find.text('Review request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Filter replaced'));
      await tester.pumpAndSettle();

      expect(find.text('REQUEST DETAIL'), findsOneWidget);
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
          matching: find.text('Closeout note'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Create, Closeout next-action, complementary detail writes mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        roles: const <String>['OPERATIONS'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        OperationsCompletedAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        OperationsCompletedAtomPermissions.closeout.isAllowed(writer),
        isTrue,
      );

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Filter replaced'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.byTooltip('Add closeout note if needed'), findsOneWidget);

      await tester.tap(find.text('Filter replaced'));
      await tester.pumpAndSettle();

      // Closeout is the row next-action — omitted from complementary detail.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Closeout note'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:write alone without operations:read omits Completed chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      expect(
        OperationsCompletedAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        OperationsCompletedAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        OperationsCompletedAtomPermissions.report.isAllowed(writeOnly),
        isFalse,
      );
      // Matrix create ∩ write alone — create helper allows write; chrome collapses
      // because tab read ∩ fails (same pattern as housekeeping).
      expect(
        OperationsCompletedAtomPermissions.create.isAllowed(writeOnly),
        isTrue,
      );
      expect(canEnterOperationsWorkspace(writeOnly), isTrue);
      expect(canReadOperations(writeOnly), isFalse);

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Filter replaced'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:read alone satisfies entry and Completed chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy readOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsCompletedAtomPermissions.routeEntry.isAllowed(readOnly),
        isTrue,
      );
      expect(
        OperationsCompletedAtomPermissions.tab.isAllowed(readOnly),
        isTrue,
      );

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: readOnly,
      );

      expect(find.text('Filter replaced'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
      expect(find.byTooltip('Add closeout note if needed'), findsNothing);
    },
  );

  testWidgets(
    'report ∩: operations:read mounts Report (source Always narrowed); write alone does not',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsCompletedAtomPermissions.report.isAllowed(opsReader),
        isTrue,
      );

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.textContaining('All requests'), findsWidgets);
      expect(find.text('Preview'), findsNothing);

      await _pumpCompletedTab(
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
    'subscription strip: facilities-maintenance missing omits Completed chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        OperationsCompletedAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        OperationsCompletedAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Filter replaced'), findsNothing);
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
        OperationsCompletedAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        OperationsCompletedAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(canEnterOperationsWorkspace(noFacility), isFalse);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: no extra nested module chrome on Completed',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
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

      await tester.tap(find.text('Filter replaced'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Billing'), findsNothing);
      expect(find.textContaining('Clinical'), findsNothing);
      expect(find.text('Service logs'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'authorized Create opens dialog; validation keeps it open',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
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

      await tester.tap(find.text('Create request').last);
      await tester.pumpAndSettle();

      // Required issue empty — dialog stays; no mutation.
      verifyNever(() => repository.createRequest(any()));
    },
  );

  testWidgets(
    'authorized Closeout next-action opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      when(() => repository.appendRequestNote(any(), any())).thenAnswer(
        (_) async =>
            const Result<OperationsWorkItem>.success(_completedRequest),
      );

      await _pumpCompletedTab(
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

      await tester.tap(find.byTooltip('Add closeout note if needed'));
      await tester.pumpAndSettle();

      expect(find.text('Save note'), findsOneWidget);
      expect(find.text('REQUEST DETAIL'), findsNothing);

      final Finder noteField = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(noteField.first, 'Closed out');
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Save note'),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.appendRequestNote(
          any(
            that: predicate<OperationsWorkItem>(
              (OperationsWorkItem item) => item.id == 'MR-DONE',
            ),
          ),
          any(
            that: predicate<OperationsRequestNoteDraft>(
              (OperationsRequestNoteDraft draft) =>
                  draft.kind == 'CLOSEOUT' && draft.note == 'Closed out',
            ),
          ),
        ),
      ).called(1);
      expect(find.text('Operations changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelled row shows non-button copy; no write next-action',
    (WidgetTester tester) async {
      // Completed section chrome still hosts cancelled next-action copy when
      // a cancelled row is present (status filter normally excludes them).
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          roles: const <String>['OPERATIONS'],
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        requests: const <OperationsWorkItem>[_cancelledRequest],
        listOverride: Result<AppPage<OperationsWorkItem>>.success(
          AppPage<OperationsWorkItem>(
            items: const <OperationsWorkItem>[_cancelledRequest],
            request: const AppPageRequest(),
            totalItemCount: 1,
          ),
        ),
      );

      expect(find.text('Cancelled leak check'), findsOneWidget);
      expect(find.text('Request cancelled'), findsWidgets);
      expect(find.byTooltip('Add closeout note if needed'), findsNothing);
      expect(find.text('Review request'), findsNothing);
    },
  );

  testWidgets(
    'empty write-authorized Completed queue still shows Create when allowed',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
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
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('No maintenance requests'), findsOneWidget);
    },
  );

  testWidgets(
    'empty authorized Completed still shows chrome; Create omitted for reader',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
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
    'error/retry surface remains for authorized Completed users',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
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

  testWidgets('authorized loading then success on Completed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.listRequests(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<AppPage<OperationsWorkItem>>.success(
        AppPage<OperationsWorkItem>(
          items: const <OperationsWorkItem>[_completedRequest],
          request: const AppPageRequest(),
          totalItemCount: 1,
        ),
      );
    });
    when(() => repository.listAssets(any())).thenAnswer(
      (_) async => Result<AppPage<OperationsAsset>>.success(
        AppPage<OperationsAsset>(
          items: const <OperationsAsset>[_generatorAsset],
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
      initialLocation: '/operations?section=completed',
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
    expect(find.text('Filter replaced'), findsOneWidget);
  });

  testWidgets(
    'mobile viewport: authorized Closeout trailing; read-only omits write',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        roles: const <String>['OPERATIONS'],
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        physicalSize: const Size(390, 844),
      );

      expect(find.byType(AppListTableGrid), findsNothing);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(find.byTooltip('Add closeout note if needed'), findsOneWidget);
      expect(_tabLabel('Completed'), findsOneWidget);

      await _pumpCompletedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expect(find.byTooltip('Add closeout note if needed'), findsNothing);
      expect(find.text('Review request'), findsNothing);
    },
  );

  testWidgets(
    'desktop viewport: Completed status filter absent for authorized reader',
    (WidgetTester tester) async {
      await _pumpCompletedTab(
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

  testWidgets('light + dark themes mount authorized Completed chrome', (
    WidgetTester tester,
  ) async {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      await _pumpCompletedTab(
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

      expect(find.text('Filter replaced'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    }
  });

  test(
    'section tab gate: Completed uses Completed atom tab requirement',
    () {
      expect(
        identical(
          operationsSectionTabRequirement(OperationsDeskSection.completed),
          OperationsCompletedAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        canViewOperationsSection(
          _policy(permissions: <AppPermission>{AppPermissions.operationsRead}),
          OperationsDeskSection.completed,
        ),
        isTrue,
      );
    },
  );
}
