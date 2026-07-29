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

const BiomedicalAsset _vendorAsset = BiomedicalAsset(
  id: 'SP-100',
  humanFriendlyId: 'SP-100',
  resource: BiomedicalResources.serviceProviders,
  title: 'Acme Biomedical Support',
  status: 'ACTIVE',
  priority: 'MEDIUM',
  categoryLabel: 'Vendor',
  facilityLabel: 'Main Campus',
  engineerLabel: 'Alex Engineer',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Ventilator A',
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Ventilator A'),
  ],
  facilities: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'FAC-1', label: 'Main Campus'),
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_vendorAsset],
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

Future<void> _pumpSupportTab(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_vendorAsset],
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
    initialLocation: '/biomedical?panel=support',
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
    'read-only: Support list visible; Report fault / write detail absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(BiomedicalSupportAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BiomedicalSupportAtomPermissions.reportFault.isAllowed(reader),
        isFalse,
      );
      expect(
        BiomedicalSupportAtomPermissions.logIncident.isAllowed(reader),
        isFalse,
      );
      expect(BiomedicalSupportAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpSupportTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Acme Biomedical Support'), findsOneWidget);
      expect(find.text('Support'), findsWidgets);
      expect(find.text('Location'), findsOneWidget);
      expect(find.byTooltip('Report fault'), findsNothing);
      expect(find.text('Review record'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Log incident'), findsNothing);
      expect(find.text('Transfer location'), findsNothing);
      expect(find.text('Create work order'), findsNothing);
      expect(find.text('Schedule maintenance'), findsNothing);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩ / source ∪: Report fault, detail writes, print mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.evidenceExport,
        },
      );
      expect(BiomedicalSupportAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        BiomedicalSupportAtomPermissions.reportFault.isAllowed(writer),
        isTrue,
      );
      expect(BiomedicalSupportAtomPermissions.print.isAllowed(writer), isTrue);

      await _pumpSupportTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Acme Biomedical Support'), findsOneWidget);
      expect(find.byTooltip('Report fault'), findsOneWidget);
      expect(find.text('Review record'), findsWidgets);

      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();

      expect(find.text('Log incident'), findsOneWidget);
      expect(find.text('Transfer location'), findsOneWidget);
      expect(find.text('Create work order'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∪: operations:write without biomed:write still mounts Support write atoms',
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
        BiomedicalSupportAtomPermissions.write.isAllowed(operationsWriter),
        isTrue,
      );
      expect(
        BiomedicalSupportAtomPermissions.reportFault.isAllowed(operationsWriter),
        isTrue,
      );

      await _pumpSupportTab(
        tester,
        repository: repository,
        accessPolicy: operationsWriter,
      );

      expect(find.byTooltip('Report fault'), findsOneWidget);

      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();

      expect(find.text('Log incident'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
    },
  );

  testWidgets(
    'route entry ∪: biomed:write alone without biomed:read omits Support chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      expect(
        BiomedicalSupportAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BiomedicalSupportAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpSupportTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Acme Biomedical Support'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Report fault'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: biomedical-engineering-suite missing omits Support',
    (WidgetTester tester) async {
      await _pumpSupportTab(
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
      expect(find.text('Acme Biomedical Support'), findsNothing);
      expect(find.byTooltip('Report fault'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: print absent without evidence:export; write mounts',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      );
      expect(
        BiomedicalSupportAtomPermissions.print.isAllowed(writerNoExport),
        isFalse,
      );
      expect(
        BiomedicalSupportAtomPermissions.nestedWrite.isAllowed(writerNoExport),
        isTrue,
      );
      expect(
        BiomedicalSupportAtomPermissions.reportFault.isAllowed(writerNoExport),
        isTrue,
      );

      await _pumpSupportTab(
        tester,
        repository: repository,
        accessPolicy: writerNoExport,
      );

      expect(find.byTooltip('Report fault'), findsOneWidget);

      await tester.tap(find.text('Acme Biomedical Support'));
      await tester.pumpAndSettle();

      expect(find.text('Log incident'), findsOneWidget);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Support Report fault opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      when(() => repository.createFaultReport(any())).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(asset: _vendorAsset),
        ),
      );

      await _pumpSupportTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Report fault'));
      await tester.pumpAndSettle();

      expect(find.text('REPORT EQUIPMENT FAULT'), findsOneWidget);

      final Finder formFields = find.descendant(
        of: find.byType(AppDialog).last,
        matching: find.byType(TextFormField),
      );
      expect(formFields, findsWidgets);
      for (int i = 0; i < formFields.evaluate().length; i++) {
        await tester.enterText(formFields.at(i), 'Pump alarm loop');
      }
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      verify(() => repository.createFaultReport(any())).called(1);
      expect(find.text('Biomedical changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'empty authorized Support still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpSupportTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No equipment records'), findsOneWidget);
      expect(find.byTooltip('Report fault'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Support',
    (WidgetTester tester) async {
      await _pumpSupportTab(
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

  testWidgets('mobile viewport: authorized Support chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpSupportTab(
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
    expect(find.text('Support'), findsWidgets);
    expect(find.byTooltip('Report fault'), findsOneWidget);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Acme'), findsWidgets);
  });

  testWidgets('desktop viewport: authorized Support chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpSupportTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
    );

    expect(find.text('Acme Biomedical Support'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Review record'), findsWidgets);
  });

  testWidgets('dark theme: authorized Support chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpSupportTab(
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

    expect(find.text('Acme Biomedical Support'), findsOneWidget);
    expect(find.byTooltip('Report fault'), findsOneWidget);

    await tester.tap(find.text('Acme Biomedical Support'));
    await tester.pumpAndSettle();
    expect(find.text('Print report'), findsOneWidget);
  });

  testWidgets('light theme: authorized Support chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpSupportTab(
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

    expect(find.text('Acme Biomedical Support'), findsOneWidget);
    expect(find.byTooltip('Report fault'), findsOneWidget);
    expect(find.text('Review record'), findsWidgets);
  });
}
