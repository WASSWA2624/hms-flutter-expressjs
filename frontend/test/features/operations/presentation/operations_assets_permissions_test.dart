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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOperationsRepository extends Mock implements OperationsRepository {}

const OperationsAsset _generatorAsset = OperationsAsset(
  id: 'AS-001',
  name: 'Backup Generator',
  assetTag: 'GEN-01',
  status: 'OPEN',
  facilityLabel: 'Main Campus',
);

const OperationsWorkItem _openRequest = OperationsWorkItem(
  id: 'MR-OPEN',
  displayId: 'MR-OPEN',
  status: 'OPEN',
  assetLabel: 'Generator',
  metadata: OperationsRequestMetadata(
    issue: 'Generator alarm',
    priority: 'HIGH',
    category: 'POWER_BACKUP',
  ),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['OPERATIONS'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: operationsFacilitiesModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
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
  List<OperationsAsset> assets = const <OperationsAsset>[_generatorAsset],
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[_openRequest],
  Result<AppPage<OperationsWorkItem>>? requestsOverride,
  Result<AppPage<OperationsAsset>>? assetsOverride,
}) {
  when(() => repository.listRequests(any())).thenAnswer((_) async {
    if (requestsOverride != null) {
      return requestsOverride;
    }
    return Result<AppPage<OperationsWorkItem>>.success(
      AppPage<OperationsWorkItem>(
        items: requests,
        request: const AppPageRequest(),
        totalItemCount: requests.length,
      ),
    );
  });
  when(() => repository.listAssets(any())).thenAnswer((_) async {
    if (assetsOverride != null) {
      return assetsOverride;
    }
    return Result<AppPage<OperationsAsset>>.success(
      AppPage<OperationsAsset>(
        items: assets,
        request: const AppPageRequest(),
        totalItemCount: assets.length,
      ),
    );
  });
  when(() => repository.listServiceLogs(any())).thenAnswer(
    (_) async => const Result<AppPage<OperationsServiceLog>>.success(
      AppPage<OperationsServiceLog>(
        items: <OperationsServiceLog>[],
        request: AppPageRequest(),
      ),
    ),
  );
  when(() => repository.getRequest(any())).thenAnswer(
    (_) async => const Result<OperationsWorkItem>.success(_openRequest),
  );
}

Finder _tabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.textContaining(label),
  );
}

Future<void> _pumpAssetsTab(
  WidgetTester tester, {
  required _MockOperationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<OperationsAsset> assets = const <OperationsAsset>[_generatorAsset],
  Result<AppPage<OperationsWorkItem>>? requestsOverride,
  Result<AppPage<OperationsAsset>>? assetsOverride,
  String initialLocation = '/operations?section=assets',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    assets: assets,
    requestsOverride: requestsOverride,
    assetsOverride: assetsOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
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

void main() {
  late _MockOperationsRepository repository;

  setUpAll(() {
    registerFallbackValue(const OperationsWorkItemQuery());
    registerFallbackValue(const OperationsAssetQuery());
    registerFallbackValue(const OperationsServiceLogQuery());
    registerFallbackValue(
      const OperationsRequestDraft(
        category: 'OTHER',
        priority: 'NORMAL',
        issue: 'Test',
      ),
    );
  });

  setUp(() {
    repository = _MockOperationsRepository();
  });

  group('OperationsAssetsAtomPermissions helpers (reuse / AC1)', () {
    test('atom map reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          OperationsAssetsAtomPermissions.tab,
          operationsReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OperationsAssetsAtomPermissions.createRequest,
          operationsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OperationsAssetsAtomPermissions.mutate,
          operationsMutationRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OperationsAssetsAtomPermissions.report,
          operationsReportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          OperationsAssetsAtomPermissions.routeEntry,
          RouteAccessCatalog.operationsEntry,
        ),
        isTrue,
      );
      // Report matrix read ∩ narrows inventory "Always" — same as read helper.
      expect(
        identical(
          operationsWorkspaceReportRequirement,
          operationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        OperationsAssetsAtomPermissions.create.allPermissions,
        contains(AppPermissions.operationsWrite),
      );
      expect(
        OperationsAssetsAtomPermissions.update.allPermissions,
        contains(AppPermissions.operationsWrite),
      );
      expect(
        OperationsAssetsAtomPermissions.delete.allPermissions,
        contains(AppPermissions.operationsWrite),
      );
      expect(
        OperationsAssetsAtomPermissions.createAsset.allPermissions,
        contains(AppPermissions.operationsWrite),
      );
      expect(
        OperationsAssetsAtomPermissions.updateAsset.allPermissions,
        contains(AppPermissions.operationsWrite),
      );
      expect(
        OperationsAssetsAtomPermissions.deleteAsset.allPermissions,
        contains(AppPermissions.operationsWrite),
      );
    });

    test('atom map covers inventory verbs (AC1)', () {
      expect(OperationsAssetsAtomPermissions.tab, isNotNull);
      expect(OperationsAssetsAtomPermissions.listChrome, isNotNull);
      expect(OperationsAssetsAtomPermissions.search, isNotNull);
      expect(OperationsAssetsAtomPermissions.filters, isNotNull);
      expect(OperationsAssetsAtomPermissions.settings, isNotNull);
      expect(OperationsAssetsAtomPermissions.empty, isNotNull);
      expect(OperationsAssetsAtomPermissions.loading, isNotNull);
      expect(OperationsAssetsAtomPermissions.retry, isNotNull);
      expect(OperationsAssetsAtomPermissions.success, isNotNull);
      expect(OperationsAssetsAtomPermissions.validation, isNotNull);
      expect(OperationsAssetsAtomPermissions.rowSelect, isNotNull);
      expect(OperationsAssetsAtomPermissions.detail, isNotNull);
      expect(OperationsAssetsAtomPermissions.create, isNotNull);
      expect(OperationsAssetsAtomPermissions.update, isNotNull);
      expect(OperationsAssetsAtomPermissions.delete, isNotNull);
      expect(OperationsAssetsAtomPermissions.write, isNotNull);
      expect(OperationsAssetsAtomPermissions.mutate, isNotNull);
      expect(OperationsAssetsAtomPermissions.createRequest, isNotNull);
      expect(OperationsAssetsAtomPermissions.createAsset, isNotNull);
      expect(OperationsAssetsAtomPermissions.updateAsset, isNotNull);
      expect(OperationsAssetsAtomPermissions.deleteAsset, isNotNull);
      expect(OperationsAssetsAtomPermissions.report, isNotNull);
      expect(OperationsAssetsAtomPermissions.nestedWrite, isNotNull);
      expect(OperationsAssetsAtomPermissions.nestedRead, isNotNull);
      expect(OperationsAssetsAtomPermissions.routeEntry, isNotNull);
      expect(
        OperationsAssetsAtomPermissions.tab.allPermissions,
        contains(AppPermissions.operationsRead),
      );
      expect(
        OperationsAssetsAtomPermissions.routeEntry.anyPermissions,
        containsAll(<AppPermission>[
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        ]),
      );
    });
  });

  testWidgets(
    'read-only ∩: Assets list visible; Create request absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(OperationsAssetsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        OperationsAssetsAtomPermissions.createRequest.isAllowed(reader),
        isFalse,
      );
      expect(OperationsAssetsAtomPermissions.write.isAllowed(reader), isFalse);
      expect(OperationsAssetsAtomPermissions.report.isAllowed(reader), isTrue);

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tabLabel('Assets'), findsOneWidget);
      expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
      expect(find.text('Tag'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Backup Generator (GEN-01)'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Main Campus'), findsAtLeastNWidgets(1));
      // Inventory: asset detail has no write actions.
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.textContaining('Edit'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.textContaining('Delete'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Create request, list chrome, and report mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        OperationsAssetsAtomPermissions.createRequest.isAllowed(writer),
        isTrue,
      );
      expect(OperationsAssetsAtomPermissions.report.isAllowed(writer), isTrue);
      expect(
        OperationsAssetsAtomPermissions.createAsset.isAllowed(writer),
        isTrue,
      );

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:write alone without read omits Assets chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      // Matrix route entry ∪ — write alone satisfies entry.
      expect(
        OperationsAssetsAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      // Tab still requires read ∩.
      expect(
        OperationsAssetsAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      // Matrix create ∩ write alone — create helper allows write; chrome
      // collapses because tab read ∩ fails.
      expect(
        OperationsAssetsAtomPermissions.create.isAllowed(writeOnly),
        isTrue,
      );
      expect(canEnterOperationsWorkspace(writeOnly), isTrue);
      expect(canReadOperations(writeOnly), isFalse);

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Backup Generator (GEN-01)'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: operations:read alone satisfies entry and Assets chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy readOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsAssetsAtomPermissions.routeEntry.isAllowed(readOnly),
        isTrue,
      );
      expect(OperationsAssetsAtomPermissions.tab.isAllowed(readOnly), isTrue);
      expect(
        OperationsAssetsAtomPermissions.report.isAllowed(readOnly),
        isTrue,
      );

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: readOnly,
      );

      expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tabLabel('Assets'), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription strip: facilities-maintenance missing omits Assets',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(OperationsAssetsAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        OperationsAssetsAtomPermissions.create.isAllowed(noModule),
        isFalse,
      );

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Backup Generator (GEN-01)'), findsNothing);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC facility strip: missing facility context denies route entry ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
        facilityId: null,
      );
      expect(
        OperationsAssetsAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      // In-page read ∩ still allows without facility (ABAC on entry only).
      expect(OperationsAssetsAtomPermissions.tab.isAllowed(noFacility), isTrue);

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: noFacility,
      );

      // Workspace still renders in-page when policy override bypasses router.
      expect(_tabLabel('Assets'), findsOneWidget);
      expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: Assets has no nested cross-module UI',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      expect(
        OperationsAssetsAtomPermissions.nestedWrite.isAllowed(writer),
        isTrue,
      );
      expect(
        OperationsAssetsAtomPermissions.nestedRead.isAllowed(writer),
        isTrue,
      );

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      await tester.tap(find.text('Backup Generator (GEN-01)'));
      await tester.pumpAndSettle();

      // No cross-module nested write entry points on asset detail.
      expect(find.text('Triage'), findsNothing);
      expect(find.text('Assign'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Create request opens dialog; validation keeps it open',
    (WidgetTester tester) async {
      when(() => repository.createRequest(any())).thenAnswer(
        (_) async => const Result<OperationsWorkItem>.success(_openRequest),
      );

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Create request'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE REQUEST'), findsOneWidget);

      // Validation: submit without issue keeps dialog open (no mutation).
      await tester.tap(find.text('Create request').last);
      await tester.pumpAndSettle();

      expect(find.text('CREATE REQUEST'), findsOneWidget);
      expect(find.text('This field is required.'), findsWidgets);
      verifyNever(() => repository.createRequest(any()));
    },
  );

  testWidgets(
    'authorized Create request mutates, syncs workspace, and shows success',
    (WidgetTester tester) async {
      when(() => repository.createRequest(any())).thenAnswer(
        (_) async => const Result<OperationsWorkItem>.success(_openRequest),
      );

      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Create request'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE REQUEST'), findsOneWidget);

      // Text fields in dialog: facility, asset search, location, issue, notes.
      final Finder dialogFields = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dialogFields.at(3), 'Generator alarm');
      await tester.tap(find.text('Create request').last);
      await tester.pumpAndSettle();

      verify(() => repository.createRequest(any())).called(1);
      expect(find.text('Operations changes saved.'), findsOneWidget);
      expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  test(
    'createRequest write ∩ helper authorizes mutation path used after dialog',
    () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        OperationsAssetsAtomPermissions.createRequest.isAllowed(writer),
        isTrue,
      );
      expect(
        OperationsAssetsAtomPermissions.success.isAllowed(writer),
        isTrue,
      );
      expect(
        OperationsAssetsAtomPermissions.validation.isAllowed(writer),
        isTrue,
      );
      expect(
        OperationsAssetsAtomPermissions.createRequest.isAllowed(reader),
        isFalse,
      );
    },
  );

  testWidgets(
    'empty authorized Assets still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
        assets: const <OperationsAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No assets registered'), findsOneWidget);
      expect(find.textContaining('Create request'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty write-authorized Assets keeps Create request primary',
    (WidgetTester tester) async {
      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        assets: const <OperationsAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No assets registered'), findsOneWidget);
      expect(find.textContaining('Create request'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Assets',
    (WidgetTester tester) async {
      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        ),
        requestsOverride: const Result<AppPage<OperationsWorkItem>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on Assets', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.listRequests(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Result<AppPage<OperationsWorkItem>>.success(
        AppPage<OperationsWorkItem>(
          items: <OperationsWorkItem>[_openRequest],
          request: AppPageRequest(),
          totalItemCount: 1,
        ),
      );
    });
    when(() => repository.listAssets(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Result<AppPage<OperationsAsset>>.success(
        AppPage<OperationsAsset>(
          items: <OperationsAsset>[_generatorAsset],
          request: AppPageRequest(),
          totalItemCount: 1,
        ),
      );
    });
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
      initialLocation: '/operations?section=assets',
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
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Loading'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
  });

  testWidgets('mobile viewport keeps Assets row select and chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAssetsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Backup Generator'), findsOneWidget);
    expect(_tabLabel('Assets'), findsOneWidget);
    // Compact toolbar hides the Create label; tooltip remains.
    expect(find.byTooltip('Create request'), findsOneWidget);

    await tester.tap(find.textContaining('Backup Generator').first);
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));

    await _pumpAssetsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      ),
      physicalSize: const Size(390, 844),
    );
    expect(find.byTooltip('Create request'), findsNothing);
  });

  testWidgets('desktop viewport Assets write ∩ mounts Create and list chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAssetsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.byType(AppListTable<OperationsAsset>), findsOneWidget);
    expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
    expect(find.textContaining('Create request'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('dark theme Assets write ∩ still mounts Create request', (
    WidgetTester tester,
  ) async {
    await _pumpAssetsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
    expect(find.byTooltip('Create request'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('light theme Assets read ∩ keeps list; omits Create', (
    WidgetTester tester,
  ) async {
    await _pumpAssetsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Backup Generator (GEN-01)'), findsOneWidget);
    expect(find.textContaining('Create request'), findsNothing);
    expect(find.text('Report'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'Report summary opens for read ∩ (source Always narrowed to matrix read)',
    (WidgetTester tester) async {
      await _pumpAssetsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        ),
      );

      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Assets'), findsWidgets);
      expect(find.text('Preview'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  test(
    'capabilities and section helpers integrate with Assets atom map',
    () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
        },
      );
      final OperationsCapabilities readCaps =
          OperationsCapabilities.fromPolicy(reader);
      final OperationsCapabilities writeCaps =
          OperationsCapabilities.fromPolicy(writer);

      expect(readCaps.canRead, isTrue);
      expect(readCaps.canMutate, isFalse);
      expect(readCaps.canReport, isTrue);
      expect(writeCaps.canMutate, isTrue);
      expect(
        operationsAllowedSections(reader),
        contains(OperationsDeskSection.assets),
      );
      expect(
        canViewOperationsSection(writer, OperationsDeskSection.assets),
        isTrue,
      );
      expect(
        operationsSectionTabRequirement(OperationsDeskSection.assets),
        OperationsAssetsAtomPermissions.tab,
      );
    },
  );
}
