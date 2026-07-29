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

const BiomedicalAsset _maintenanceAsset = BiomedicalAsset(
  id: 'PM-100',
  humanFriendlyId: 'PM-100',
  resource: BiomedicalResources.maintenancePlans,
  title: 'Ventilator PM plan',
  status: 'DUE',
  priority: 'HIGH',
  categoryLabel: 'Life Support',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Ventilator A',
  nextDueAt: null,
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Ventilator A'),
  ],
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_maintenanceAsset],
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
        summary: const BiomedicalSummary(
          totalEquipment: 1,
          overduePm: 1,
          openWorkOrders: 0,
        ),
        queues: const <BiomedicalQueueSummary>[],
        panels: const <BiomedicalPanelSummary>[],
        lookups: _lookups,
        assets: AppPage<BiomedicalAsset>(
          items: assets,
          request: query.pageRequest,
          totalItemCount: assets.length,
        ),
      ),
    );
  });
}

Future<void> _pumpPreventiveTab(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_maintenanceAsset],
  Result<BiomedicalWorkbench>? workspaceOverride,
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
    initialLocation: '/biomedical?panel=preventive',
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
    'read-only: Preventive list visible; Schedule maintenance / write next-actions absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(BiomedicalPreventiveAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BiomedicalPreventiveAtomPermissions.scheduleMaintenance.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(
        BiomedicalPreventiveAtomPermissions.performMaintenance.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(
        BiomedicalPreventiveAtomPermissions.write.isAllowed(reader),
        isFalse,
      );

      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Ventilator PM plan'), findsOneWidget);
      expect(find.text('Preventive'), findsWidgets);
      expect(find.text('Next due'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Schedule maintenance'), findsNothing);
      expect(find.text('Perform maintenance'), findsNothing);
      expect(find.text('Review record'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.text('Transfer location'), findsNothing);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩ / source ∪: Schedule maintenance, write next-action, detail writes mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.evidenceExport,
        },
      );
      expect(BiomedicalPreventiveAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        BiomedicalPreventiveAtomPermissions.scheduleMaintenance.isAllowed(
          writer,
        ),
        isTrue,
      );
      expect(BiomedicalPreventiveAtomPermissions.print.isAllowed(writer), isTrue);

      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Ventilator PM plan'), findsOneWidget);
      expect(find.byTooltip('Schedule maintenance'), findsOneWidget);
      expect(find.text('Perform maintenance'), findsWidgets);

      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();

      expect(find.text('Create work order'), findsOneWidget);
      expect(find.text('Transfer location'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
      // Maintenance is the row next-action — omitted from complementary detail writes.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Schedule maintenance'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∪: operations:write without biomed:write still mounts Preventive write atoms',
    (WidgetTester tester) async {
      // operations:write is plan-gated to facilities-maintenance via grants().
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
        BiomedicalPreventiveAtomPermissions.write.isAllowed(operationsWriter),
        isTrue,
      );

      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: operationsWriter,
      );

      expect(find.byTooltip('Schedule maintenance'), findsOneWidget);
      expect(find.text('Perform maintenance'), findsWidgets);

      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();

      expect(find.text('Print report'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Schedule maintenance'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'route entry ∪: biomed:write alone without biomed:read omits Preventive chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      expect(
        BiomedicalPreventiveAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BiomedicalPreventiveAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Ventilator PM plan'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Schedule maintenance'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: biomedical-engineering-suite missing omits Preventive',
    (WidgetTester tester) async {
      await _pumpPreventiveTab(
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
      expect(find.text('Ventilator PM plan'), findsNothing);
      expect(find.byTooltip('Schedule maintenance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: print absent without evidence:export; PM write mounts',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      );
      expect(
        BiomedicalPreventiveAtomPermissions.print.isAllowed(writerNoExport),
        isFalse,
      );
      expect(
        BiomedicalPreventiveAtomPermissions.performMaintenance.isAllowed(
          writerNoExport,
        ),
        isTrue,
      );
      expect(
        BiomedicalPreventiveAtomPermissions.nestedWrite.isAllowed(
          writerNoExport,
        ),
        isTrue,
      );

      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: writerNoExport,
      );

      expect(find.text('Perform maintenance'), findsWidgets);

      await tester.tap(find.text('Ventilator PM plan'));
      await tester.pumpAndSettle();

      expect(find.text('Create work order'), findsOneWidget);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Preventive next-action opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      when(
        () => repository.createResource(any(), any()),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(asset: _maintenanceAsset),
        ),
      );

      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.text('Perform maintenance').first);
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULE MAINTENANCE'), findsOneWidget);

      final Finder formFields = find.descendant(
        of: find.byType(AppDialog).last,
        matching: find.byType(TextFormField),
      );
      expect(formFields, findsWidgets);
      // Plan name is required; fill text fields so validation passes.
      for (int i = 0; i < formFields.evaluate().length; i++) {
        await tester.enterText(formFields.at(i), 'Quarterly PM');
      }
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      verify(
        () => repository.createResource(
          BiomedicalResources.maintenancePlans,
          any(),
        ),
      ).called(1);
      expect(find.text('Biomedical changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Schedule maintenance validation keeps dialog open without mutation',
    (WidgetTester tester) async {
      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Schedule maintenance'));
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULE MAINTENANCE'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULE MAINTENANCE'), findsOneWidget);
      expect(find.textContaining('is required'), findsWidgets);
      verifyNever(() => repository.createResource(any(), any()));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty authorized Preventive still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No equipment records'), findsOneWidget);
      expect(find.byTooltip('Schedule maintenance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty write-authorized Preventive keeps Schedule maintenance primary',
    (WidgetTester tester) async {
      await _pumpPreventiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No equipment records'), findsOneWidget);
      expect(find.byTooltip('Schedule maintenance'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Preventive',
    (WidgetTester tester) async {
      await _pumpPreventiveTab(
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

  testWidgets('authorized loading then success on Preventive', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.getWorkspace(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<BiomedicalWorkbench>.success(
        BiomedicalWorkbench(
          summary: const BiomedicalSummary(
            totalEquipment: 1,
            overduePm: 1,
          ),
          queues: const <BiomedicalQueueSummary>[],
          panels: const <BiomedicalPanelSummary>[],
          lookups: _lookups,
          assets: AppPage<BiomedicalAsset>(
            items: const <BiomedicalAsset>[_maintenanceAsset],
            request: const AppPageRequest(pageSize: 20),
            totalItemCount: 1,
          ),
        ),
      );
    });

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/biomedical?panel=preventive',
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
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{AppPermissions.biomedRead},
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
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.textContaining('Loading').evaluate().isNotEmpty ||
          find.textContaining('Biomedical').evaluate().isNotEmpty,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('Ventilator PM plan'), findsOneWidget);
    expect(find.byTooltip('Schedule maintenance'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('mobile viewport: authorized Preventive chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpPreventiveTab(
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

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Preventive'), findsWidgets);
    expect(find.byTooltip('Schedule maintenance'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Ventilator'), findsWidgets);
  });

  testWidgets('desktop viewport: authorized Preventive chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpPreventiveTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
    );

    expect(find.text('Ventilator PM plan'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Next due'), findsOneWidget);
    expect(find.text('Perform maintenance'), findsWidgets);
  });

  testWidgets('dark theme: authorized Preventive chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpPreventiveTab(
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

    expect(find.text('Ventilator PM plan'), findsOneWidget);
    expect(find.byTooltip('Schedule maintenance'), findsOneWidget);

    await tester.tap(find.text('Ventilator PM plan'));
    await tester.pumpAndSettle();
    expect(find.text('Print report'), findsOneWidget);
  });

  testWidgets('light theme: authorized Preventive chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpPreventiveTab(
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

    expect(find.text('Ventilator PM plan'), findsOneWidget);
    expect(find.byTooltip('Schedule maintenance'), findsOneWidget);
    expect(find.text('Perform maintenance'), findsWidgets);
  });
}
