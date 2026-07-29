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

const BiomedicalAsset _calibrationAsset = BiomedicalAsset(
  id: 'CAL-100',
  humanFriendlyId: 'CAL-100',
  resource: BiomedicalResources.calibrationLogs,
  title: 'Ventilator calibration',
  status: 'DUE',
  priority: 'HIGH',
  categoryLabel: 'Life Support',
  facilityLabel: 'ICU',
  engineerLabel: 'Alex Engineer',
  equipmentId: 'EQ-100',
  equipmentLabel: 'Ventilator A',
);

const BiomedicalAsset _downtimeAsset = BiomedicalAsset(
  id: 'DT-100',
  humanFriendlyId: 'DT-100',
  resource: BiomedicalResources.downtimeLogs,
  title: 'MRI downtime',
  status: 'OPEN',
  priority: 'CRITICAL',
  facilityLabel: 'Imaging',
  equipmentId: 'EQ-200',
  equipmentLabel: 'MRI Suite',
);

const BiomedicalAsset _recallAsset = BiomedicalAsset(
  id: 'RC-100',
  humanFriendlyId: 'RC-100',
  resource: BiomedicalResources.recallNotices,
  title: 'Pump recall notice',
  status: 'ACTIVE',
  priority: 'HIGH',
  facilityLabel: 'Ward A',
  equipmentId: 'EQ-300',
  equipmentLabel: 'Infusion Pump',
);

const BiomedicalLookupData _lookups = BiomedicalLookupData(
  equipment: <BiomedicalLookupOption>[
    BiomedicalLookupOption(id: 'EQ-100', label: 'Ventilator A'),
    BiomedicalLookupOption(id: 'EQ-200', label: 'MRI Suite'),
    BiomedicalLookupOption(id: 'EQ-300', label: 'Infusion Pump'),
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
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_calibrationAsset],
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
          criticalDowntime: 1,
          activeRecalls: 1,
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

Future<void> _pumpComplianceTab(
  WidgetTester tester, {
  required _MockBiomedicalRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BiomedicalAsset> assets = const <BiomedicalAsset>[_calibrationAsset],
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
    initialLocation: '/biomedical?panel=compliance',
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
    'read-only: Compliance list visible; Record calibration / write next-actions absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(BiomedicalComplianceAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BiomedicalComplianceAtomPermissions.recordCalibration.isAllowed(reader),
        isFalse,
      );
      expect(
        BiomedicalComplianceAtomPermissions.closeDowntime.isAllowed(reader),
        isFalse,
      );
      expect(
        BiomedicalComplianceAtomPermissions.acknowledgeRecall.isAllowed(reader),
        isFalse,
      );
      expect(BiomedicalComplianceAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpComplianceTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Ventilator calibration'), findsOneWidget);
      expect(find.text('Compliance'), findsWidgets);
      expect(find.text('Next due'), findsOneWidget);
      expect(find.byTooltip('Record calibration'), findsNothing);
      expect(find.text('Review compliance'), findsNothing);
      expect(find.text('Review record'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Ventilator calibration'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Record calibration'), findsNothing);
      expect(find.text('Record safety test'), findsNothing);
      expect(find.text('Report downtime'), findsNothing);
      expect(find.text('Close downtime'), findsNothing);
      expect(find.text('Acknowledge recall'), findsNothing);
      expect(find.text('Print report'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩ / source ∪: Record calibration, write next-action, detail writes mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
          AppPermissions.evidenceExport,
        },
      );
      expect(BiomedicalComplianceAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        BiomedicalComplianceAtomPermissions.recordCalibration.isAllowed(writer),
        isTrue,
      );
      expect(BiomedicalComplianceAtomPermissions.print.isAllowed(writer), isTrue);

      await _pumpComplianceTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Ventilator calibration'), findsOneWidget);
      expect(find.byTooltip('Record calibration'), findsOneWidget);
      expect(find.text('Review compliance'), findsWidgets);

      await tester.tap(find.text('Ventilator calibration'));
      await tester.pumpAndSettle();

      expect(find.text('Record safety test'), findsOneWidget);
      expect(find.text('Report downtime'), findsOneWidget);
      expect(find.text('Print report'), findsOneWidget);
      // Calibration is the row next-action — omitted from complementary detail writes.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Record calibration'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∪: operations:write without biomed:write still mounts Compliance write atoms',
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
        BiomedicalComplianceAtomPermissions.write.isAllowed(operationsWriter),
        isTrue,
      );

      await _pumpComplianceTab(
        tester,
        repository: repository,
        accessPolicy: operationsWriter,
        assets: const <BiomedicalAsset>[_downtimeAsset],
      );

      expect(find.byTooltip('Record calibration'), findsOneWidget);
      expect(find.text('Return to service'), findsWidgets);

      await tester.tap(find.text('MRI downtime'));
      await tester.pumpAndSettle();

      expect(find.text('Acknowledge recall'), findsNothing);
      expect(find.text('Print report'), findsOneWidget);
      // Close downtime is the next-action — omitted from complementary detail.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Close downtime'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'route entry ∪: biomed:write alone without biomed:read omits Compliance chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      expect(
        BiomedicalComplianceAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BiomedicalComplianceAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpComplianceTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Ventilator calibration'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Record calibration'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: biomedical-engineering-suite missing omits Compliance',
    (WidgetTester tester) async {
      await _pumpComplianceTab(
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
      expect(find.text('Ventilator calibration'), findsNothing);
      expect(find.byTooltip('Record calibration'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: print absent without evidence:export; recall write mounts',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      );
      expect(
        BiomedicalComplianceAtomPermissions.print.isAllowed(writerNoExport),
        isFalse,
      );
      expect(
        BiomedicalComplianceAtomPermissions.acknowledgeRecall.isAllowed(
          writerNoExport,
        ),
        isTrue,
      );
      expect(
        BiomedicalComplianceAtomPermissions.nestedWrite.isAllowed(
          writerNoExport,
        ),
        isTrue,
      );

      await _pumpComplianceTab(
        tester,
        repository: repository,
        accessPolicy: writerNoExport,
        assets: const <BiomedicalAsset>[_recallAsset],
      );

      expect(find.text('Review recall'), findsWidgets);

      await tester.tap(find.text('Pump recall notice'));
      await tester.pumpAndSettle();

      // Primary tooltip + complementary detail both say Record calibration.
      expect(find.text('Record calibration'), findsWidgets);
      expect(find.text('Print report'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Acknowledge recall'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Compliance next-action opens dialog and mutation syncs list',
    (WidgetTester tester) async {
      when(
        () => repository.createResource(any(), any()),
      ).thenAnswer(
        (_) async => const Result<BiomedicalMutationResult>.success(
          BiomedicalMutationResult(asset: _calibrationAsset),
        ),
      );

      await _pumpComplianceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        ),
      );

      await tester.tap(find.text('Review compliance').first);
      await tester.pumpAndSettle();

      expect(find.text('RECORD CALIBRATION'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      verify(
        () => repository.createResource(
          BiomedicalResources.calibrationLogs,
          any(),
        ),
      ).called(1);
      expect(find.text('Biomedical changes saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'empty authorized Compliance still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpComplianceTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        ),
        assets: const <BiomedicalAsset>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No equipment records'), findsOneWidget);
      expect(find.byTooltip('Record calibration'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Compliance',
    (WidgetTester tester) async {
      await _pumpComplianceTab(
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

  testWidgets('mobile viewport: authorized Compliance chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpComplianceTab(
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
    expect(find.text('Compliance'), findsWidgets);
    expect(find.byTooltip('Record calibration'), findsOneWidget);
    // Mobile list rows use AppListTableMobileItem (title may share chrome space).
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('Ventilator'), findsWidgets);
  });

  testWidgets('desktop viewport: authorized Compliance chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpComplianceTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
      ),
    );

    expect(find.text('Ventilator calibration'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Next due'), findsOneWidget);
    expect(find.text('Review compliance'), findsWidgets);
  });

  testWidgets('dark theme: authorized Compliance chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpComplianceTab(
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

    expect(find.text('Ventilator calibration'), findsOneWidget);
    expect(find.byTooltip('Record calibration'), findsOneWidget);

    await tester.tap(find.text('Ventilator calibration'));
    await tester.pumpAndSettle();
    expect(find.text('Print report'), findsOneWidget);
  });

  testWidgets('light theme: authorized Compliance chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpComplianceTab(
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

    expect(find.text('Ventilator calibration'), findsOneWidget);
    expect(find.byTooltip('Record calibration'), findsOneWidget);
    expect(find.text('Review compliance'), findsWidgets);
  });
}
