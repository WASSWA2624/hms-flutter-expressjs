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
import 'package:hosspi_hms/features/biomedical/data/repositories/biomedical_repository_impl.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/domain/repositories/biomedical_repository.dart';
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_access.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBiomedicalRepository extends Mock implements BiomedicalRepository {}

const BiomedicalAsset _registryAsset = BiomedicalAsset(
  id: 'EQ-001',
  humanFriendlyId: 'EQ-001',
  resource: BiomedicalResources.registries,
  title: 'Defibrillator',
  status: 'ACTIVE',
  priority: 'HIGH',
  categoryLabel: 'Life Support',
  facilityLabel: 'Main Ward',
  engineerLabel: 'Alex Engineer',
);

const BiomedicalAsset _createdAsset = BiomedicalAsset(
  id: 'EQ-002',
  humanFriendlyId: 'EQ-002',
  resource: BiomedicalResources.registries,
  title: 'Infusion Pump',
  status: 'ACTIVE',
  priority: 'MEDIUM',
  categoryLabel: 'Infusion',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: biomedicalEngineeringSuiteModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BIOMED_ENGINEER'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockBiomedicalRepository repository, {
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_registryAsset],
  Result<BiomedicalWorkbench>? workspaceOverride,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (workspaceOverride != null) {
      return workspaceOverride;
    }
    final BiomedicalWorkspaceQuery query =
        invocation.positionalArguments.single as BiomedicalWorkspaceQuery;
    return Result<BiomedicalWorkbench>.success(
      BiomedicalWorkbench(
        summary: const BiomedicalSummary(totalEquipment: 1),
        queues: const <BiomedicalQueueSummary>[],
        panels: const <BiomedicalPanelSummary>[],
        lookups: BiomedicalLookupData.empty,
        assets: AppPage<BiomedicalAsset>(
          items: assets,
          request: query.pageRequest,
          totalItemCount: assets.length,
        ),
      ),
    );
  });
}

Future<void> _pumpRegistryTab(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_registryAsset],
  Result<BiomedicalWorkbench>? workspaceOverride,
  String initialLocation = '/biomedical',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    assets: assets,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/biomedical',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: BiomedicalWorkspacePage(
              initialQuery: BiomedicalRouteQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        biomedicalRepositoryProvider.overrideWithValue(repository),
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
  late _MockBiomedicalRepository repository;

  setUpAll(() {
    registerFallbackValue(const BiomedicalWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockBiomedicalRepository();
  });

  testWidgets(
    'read-only: Registry list visible; Register asset / detail writes absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(BiomedicalRegistryAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BiomedicalRegistryAtomPermissions.registerAsset.isAllowed(reader),
        isFalse,
      );
      expect(
        BiomedicalRegistryAtomPermissions.editAsset.isAllowed(reader),
        isFalse,
      );
      expect(BiomedicalRegistryAtomPermissions.create.isAllowed(reader), isFalse);
      expect(BiomedicalRegistryAtomPermissions.update.isAllowed(reader), isFalse);
      expect(BiomedicalRegistryAtomPermissions.delete.isAllowed(reader), isFalse);
      expect(BiomedicalRegistryAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Defibrillator'), findsOneWidget);
      expect(find.text('Registry'), findsWidgets);
      expect(find.text('Location'), findsOneWidget);
      expect(find.byTooltip('Register asset'), findsNothing);
      expect(find.text('Review record'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Edit asset'), findsNothing);
      expect(find.text('Transfer location'), findsNothing);
      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩ / source ∪: Register asset, detail writes, and print mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.evidenceExport,
        },
      );
      expect(BiomedicalRegistryAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        BiomedicalRegistryAtomPermissions.registerAsset.isAllowed(writer),
        isTrue,
      );
      expect(BiomedicalRegistryAtomPermissions.print.isAllowed(writer), isTrue);

      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Defibrillator'), findsOneWidget);
      expect(find.byTooltip('Register asset'), findsOneWidget);
      expect(find.text('Review record'), findsWidgets);

      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();

      expect(find.text('Edit asset'), findsOneWidget);
      expect(find.text('Transfer location'), findsOneWidget);
      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Create work order'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∪: operations:write without biomed:write still mounts Registry write atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy operationsWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.operationsWrite,
          AppPermissions.evidenceExport,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: biomedicalEngineeringSuiteModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        BiomedicalRegistryAtomPermissions.write.isAllowed(operationsWriter),
        isTrue,
      );
      expect(
        BiomedicalRegistryAtomPermissions.registerAsset.isAllowed(
          operationsWriter,
        ),
        isTrue,
      );

      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: operationsWriter,
      );

      expect(find.byTooltip('Register asset'), findsOneWidget);

      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();

      expect(find.text('Edit asset'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
    },
  );

  testWidgets(
    'route entry ∪: biomed:write alone without biomed:read omits Registry chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      expect(
        BiomedicalRegistryAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BiomedicalRegistryAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Defibrillator'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Register asset'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: biomedical-engineering-suite missing omits Registry',
    (WidgetTester tester) async {
      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Defibrillator'), findsNothing);
      expect(find.byTooltip('Register asset'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: print absent without evidence:export',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      );
      expect(
        BiomedicalRegistryAtomPermissions.print.isAllowed(writerNoExport),
        isFalse,
      );
      expect(
        BiomedicalRegistryAtomPermissions.nestedWrite.isAllowed(writerNoExport),
        isTrue,
      );

      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: writerNoExport,
      );

      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();

      expect(find.text('Edit asset'), findsOneWidget);
      expect(find.text('Schedule maintenance'), findsOneWidget);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Registry Register asset opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      when(
        () => repository.createResource(any(), any()),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(asset: _createdAsset),
        ),
      );

      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Register asset'));
      await tester.pumpAndSettle();

      expect(find.text('REGISTER EQUIPMENT'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Infusion Pump');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      verify(
        () => repository.createResource(
          BiomedicalResources.registries,
          any(),
        ),
      ).called(1);
      expect(find.text('Biomedical changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Registry Edit asset mutation syncs detail write',
    (WidgetTester tester) async {
      when(
        () => repository.updateResource(any(), any(), any()),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(asset: _registryAsset),
        ),
      );

      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.text('Defibrillator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit asset'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT EQUIPMENT'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verify(
        () => repository.updateResource(
          BiomedicalResources.registries,
          'EQ-001',
          any(),
        ),
      ).called(1);
      expect(find.text('Biomedical changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'empty authorized Registry still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No equipment records'), findsOneWidget);
      expect(find.byTooltip('Register asset'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Registry',
    (WidgetTester tester) async {
      await _pumpRegistryTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
        workspaceOverride: const Result<BiomedicalWorkbench>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('mobile viewport: authorized Registry chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpRegistryTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Registry'), findsWidgets);
    expect(find.byType(AppListTable<BiomedicalAsset>), findsOneWidget);
    expect(find.byTooltip('Register asset'), findsOneWidget);
    expect(
      find.textContaining('Defibrillator').evaluate().isNotEmpty ||
          find.byType(AppListTableMobileItem).evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('desktop viewport: authorized Registry chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpRegistryTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Defibrillator'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.byTooltip('Register asset'), findsOneWidget);
    expect(find.text('Review record'), findsWidgets);
  });

  testWidgets('dark theme: authorized Registry chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpRegistryTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.evidenceExport,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Defibrillator'), findsOneWidget);
    expect(find.byTooltip('Register asset'), findsOneWidget);

    await tester.tap(find.text('Defibrillator'));
    await tester.pumpAndSettle();
    expect(find.text('Print report'), findsOneWidget);
  });

  testWidgets('light theme: authorized Registry chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpRegistryTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Defibrillator'), findsOneWidget);
    expect(find.byTooltip('Register asset'), findsOneWidget);
    expect(find.text('Review record'), findsWidgets);
  });
}
