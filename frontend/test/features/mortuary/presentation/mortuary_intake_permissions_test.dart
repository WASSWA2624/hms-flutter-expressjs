import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/features/mortuary/presentation/mortuary_access.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMortuaryRepository extends Mock implements MortuaryRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

const MortuaryBillableEvent _billingEvent = MortuaryBillableEvent(
  id: 'bill-1',
  eventType: 'STORAGE',
  description: 'Cold storage day',
  amountText: '50.00',
  currency: 'USD',
  status: 'OPEN',
);

const MortuaryWorkspaceItem _caseItem = MortuaryWorkspaceItem(
  id: 'case-1',
  displayId: 'MOR-001',
  status: 'RECEIVED',
  identificationStatus: 'PENDING',
  billingStatus: 'UNSETTLED',
  deceasedProfileLabel: 'Amina K.',
  billableEvents: <MortuaryBillableEvent>[_billingEvent],
);

const AppModuleEntitlement _mortuaryModule = AppModuleEntitlement(
  code: mortuaryActiveModule,
  licenseStatus: 'ACTIVE',
);

const AppModuleEntitlement _billingModule = AppModuleEntitlement(
  code: 'billing-payments',
  licenseStatus: 'ACTIVE',
);

const AppModuleEntitlement _reportsModule = AppModuleEntitlement(
  code: 'reporting-analytics',
  licenseStatus: 'ACTIVE',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    _mortuaryModule,
  ],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
  List<String> roles = const <String>['MORTUARY_STAFF'],
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
    ),
  );
}

MortuaryWorkspacePayload _payload(
  MortuaryWorkspaceQuery query, {
  List<MortuaryWorkspaceItem> items = const <MortuaryWorkspaceItem>[_caseItem],
}) {
  return MortuaryWorkspacePayload(
    items: AppPage<MortuaryWorkspaceItem>(
      items: items,
      request: query.pageRequest,
      totalItemCount: items.length,
    ),
    lookups: const MortuaryLookupData(),
    summary: const <MortuarySummaryItem>[
      MortuarySummaryItem(id: 'total_cases', value: 1),
      MortuarySummaryItem(id: 'identification_pending', value: 1),
    ],
    queues: const <MortuaryQueueSummary>[
      MortuaryQueueSummary(
        queue: mortuaryQueueIdentificationPending,
        count: 1,
        panel: mortuaryPanelIntake,
        resource: mortuaryResourceCases,
      ),
    ],
    panels: const <MortuaryPanelSummary>[
      MortuaryPanelSummary(
        id: mortuaryPanelOverview,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelIntake,
        count: 1,
        defaultResource: mortuaryResourceCases,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelStorage,
        count: 0,
        defaultResource: mortuaryResourceStorageAssignments,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelCustody,
        count: 0,
        defaultResource: mortuaryResourceCustodyEvents,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelRelease,
        count: 0,
        defaultResource: mortuaryResourceReleaseAuthorisations,
      ),
      MortuaryPanelSummary(
        id: mortuaryPanelReporting,
        count: 0,
        defaultResource: mortuaryResourcePostMortemRequests,
      ),
    ],
    filters: query,
    lastUpdatedAt: DateTime.parse('2026-05-20T10:00:00.000Z'),
  );
}

void _stubWorkspace(
  _MockMortuaryRepository repository, {
  List<MortuaryWorkspaceItem> items = const <MortuaryWorkspaceItem>[_caseItem],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final MortuaryWorkspaceQuery query =
        invocation.positionalArguments.single as MortuaryWorkspaceQuery;
    return Result<MortuaryWorkspacePayload>.success(
      _payload(query, items: items),
    );
  });
  when(
    () => repository.getItem(
      resource: any(named: 'resource'),
      id: any(named: 'id'),
      baseQuery: any(named: 'baseQuery'),
    ),
  ).thenAnswer(
    (_) async => Result<MortuaryWorkspaceItem>.success(
      items.isEmpty ? _caseItem : items.first,
    ),
  );
}

Future<void> _pumpIntake(
  WidgetTester tester, {
  required _MockMortuaryRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<MortuaryWorkspaceItem> items = const <MortuaryWorkspaceItem>[_caseItem],
  String initialLocation = '/mortuary?panel=intake',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/mortuary',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: MortuaryWorkspacePage(
              initialQuery: MortuaryRouteQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mortuaryRepositoryProvider.overrideWithValue(repository),
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

AppListTable<MortuaryWorkspaceItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<MortuaryWorkspaceItem>>(
    find.byType(AppListTable<MortuaryWorkspaceItem>),
  );
}

Future<void> _openDetail(WidgetTester tester) async {
  final AppListTable<MortuaryWorkspaceItem> table = _table(tester);
  expect(table.onRowSelected, isNotNull);
  table.onRowSelected!(_caseItem);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  late _MockMortuaryRepository repository;

  setUpAll(() {
    registerFallbackValue(const MortuaryWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockMortuaryRepository();
  });

  group('MortuaryIntakeAtomPermissions inventory (AC1)', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          MortuaryIntakeAtomPermissions.tab,
          mortuaryWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryIntakeAtomPermissions.create,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryIntakeAtomPermissions.receiveCase,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryIntakeAtomPermissions.update,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryIntakeAtomPermissions.delete,
          mortuaryWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryIntakeAtomPermissions.printDocuments,
          mortuaryExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryIntakeAtomPermissions.billingPanel,
          mortuaryBillingPanelRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          MortuaryIntakeAtomPermissions.routeEntry,
          RouteAccessCatalog.mortuaryEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelTabRequirement(mortuaryPanelIntake),
          MortuaryIntakeAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelPrintRequirement(mortuaryPanelIntake),
          MortuaryIntakeAtomPermissions.printDocuments,
        ),
        isTrue,
      );
      expect(
        identical(
          mortuaryPanelBillingRequirement(mortuaryPanelIntake),
          MortuaryIntakeAtomPermissions.billingPanel,
        ),
        isTrue,
      );
    });

    test('∩ read denied without mortuary:read; ∪ route entry allows write', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryWrite},
      );
      expect(
        MortuaryIntakeAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(MortuaryIntakeAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(MortuaryIntakeAtomPermissions.create.isAllowed(writeOnly), isTrue);
      expect(
        MortuaryIntakeAtomPermissions.receiveCase.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        MortuaryIntakeAtomPermissions.printDocuments.isAllowed(writeOnly),
        isFalse,
      );
    });

    test('full ∩ read grants list chrome; write/export denied', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
      );
      expect(MortuaryIntakeAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(MortuaryIntakeAtomPermissions.search.isAllowed(reader), isTrue);
      expect(MortuaryIntakeAtomPermissions.filters.isAllowed(reader), isTrue);
      expect(MortuaryIntakeAtomPermissions.rowSelect.isAllowed(reader), isTrue);
      expect(MortuaryIntakeAtomPermissions.detail.isAllowed(reader), isTrue);
      expect(MortuaryIntakeAtomPermissions.create.isAllowed(reader), isFalse);
      expect(
        MortuaryIntakeAtomPermissions.receiveCase.isAllowed(reader),
        isFalse,
      );
      expect(MortuaryIntakeAtomPermissions.success.isAllowed(reader), isFalse);
      expect(
        MortuaryIntakeAtomPermissions.printDocuments.isAllowed(reader),
        isFalse,
      );
      expect(
        MortuaryIntakeAtomPermissions.billingPanel.isAllowed(reader),
        isFalse,
      );
    });

    test('∩ billing panel needs mortuary:billing_event and billing:read', () {
      final AppAccessPolicy mortuaryBillingOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryBillingEvent,
        },
      );
      final AppAccessPolicy withBillingRead = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryBillingEvent,
          AppPermissions.billingRead,
        },
        modules: const <AppModuleEntitlement>[_mortuaryModule, _billingModule],
      );
      expect(
        MortuaryIntakeAtomPermissions.billingPanel.isAllowed(
          mortuaryBillingOnly,
        ),
        isFalse,
      );
      expect(
        MortuaryIntakeAtomPermissions.billingPanel.isAllowed(withBillingRead),
        isTrue,
      );
    });

    test('∪ export allows mortuary:export or reports:read', () {
      final AppAccessPolicy viaExport = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryExport,
        },
      );
      final AppAccessPolicy viaReports = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[_mortuaryModule, _reportsModule],
      );
      expect(
        MortuaryIntakeAtomPermissions.printDocuments.isAllowed(viaExport),
        isTrue,
      );
      expect(
        MortuaryIntakeAtomPermissions.printDocuments.isAllowed(viaReports),
        isTrue,
      );
    });

    test('subscription/ABAC strip module or facility from tab gate', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      final AppAccessPolicy basicPlan = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: mortuaryActiveModule,
            licenseStatus: 'ACTIVE',
            planTierCode: 'BASIC',
          ),
        ],
      );
      final AppAccessPolicy expired = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: mortuaryActiveModule,
            licenseStatus: 'EXPIRED',
          ),
        ],
      );
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
        facilityId: null,
      );
      expect(MortuaryIntakeAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(MortuaryIntakeAtomPermissions.tab.isAllowed(basicPlan), isFalse);
      expect(MortuaryIntakeAtomPermissions.tab.isAllowed(expired), isFalse);
      expect(
        MortuaryIntakeAtomPermissions.routeEntry.isAllowed(noFacility),
        isFalse,
      );
      expect(MortuaryIntakeAtomPermissions.tab.isAllowed(noFacility), isFalse);
    });
  });

  testWidgets(
    '∩ denial: missing mortuary module omits Intake (subscription strip)',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(MortuaryIntakeAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        MortuaryIntakeAtomPermissions.routeEntry.isAllowed(noModule),
        isFalse,
      );

      await _pumpIntake(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('Intake'), findsNothing);
      expect(find.text('Amina K.'), findsNothing);
      expect(find.text('Receive case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full ∩ read: Intake list chrome present; write/export atoms absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
      );

      await _pumpIntake(tester, repository: repository, accessPolicy: reader);

      expect(_tab('Intake'), findsOneWidget);
      expect(find.text('Amina K.'), findsWidgets);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Receive case'), findsNothing);
      expect(find.text('Print documents'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await _openDetail(tester);
      expect(find.text('CASE DETAIL'), findsOneWidget);
      expect(find.text('Print documents'), findsNothing);
      expect(find.text('Billing'), findsNothing);
      expect(find.text('Cold storage day'), findsNothing);
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Receive case'), findsNothing);
    },
  );

  testWidgets(
    '∪ allowance: reports:read alone mounts Print documents on Intake detail',
    (WidgetTester tester) async {
      final AppAccessPolicy viaReports = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[_mortuaryModule, _reportsModule],
      );
      expect(
        MortuaryIntakeAtomPermissions.printDocuments.isAllowed(viaReports),
        isTrue,
      );

      await _pumpIntake(
        tester,
        repository: repository,
        accessPolicy: viaReports,
      );
      await _openDetail(tester);

      expect(find.text('Print documents'), findsOneWidget);
      expect(find.text('Receive case'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∩ billing: Billing section mounts only with billing_event ∩ billing:read',
    (WidgetTester tester) async {
      final AppAccessPolicy withoutBillingRead = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryBillingEvent,
        },
      );
      await _pumpIntake(
        tester,
        repository: repository,
        accessPolicy: withoutBillingRead,
      );
      await _openDetail(tester);
      expect(find.text('Billing'), findsNothing);
      expect(find.text('Cold storage day'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryBillingEvent,
          AppPermissions.billingRead,
        },
        modules: const <AppModuleEntitlement>[_mortuaryModule, _billingModule],
      );
      await _pumpIntake(
        tester,
        repository: repository,
        accessPolicy: withBilling,
      );
      await _openDetail(tester);
      expect(find.text('Billing'), findsOneWidget);
      expect(find.textContaining('Cold storage day'), findsOneWidget);
    },
  );

  testWidgets(
    '∪ route entry with write: Receive case still absent (not mounted)',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryWrite,
        },
      );
      expect(MortuaryIntakeAtomPermissions.create.isAllowed(writer), isTrue);
      expect(
        MortuaryIntakeAtomPermissions.receiveCase.isAllowed(writer),
        isTrue,
      );

      await _pumpIntake(tester, repository: repository, accessPolicy: writer);

      expect(_tab('Intake'), findsOneWidget);
      expect(find.text('Receive case'), findsNothing);
      expect(find.text('Assign storage'), findsNothing);
    },
  );

  testWidgets('authorized empty Intake worklist remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpIntake(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
      ),
      items: const <MortuaryWorkspaceItem>[],
    );

    expect(_tab('Intake'), findsOneWidget);
    expect(find.byType(AppListTable<MortuaryWorkspaceItem>), findsOneWidget);
    expect(find.text('Receive case'), findsNothing);
  });

  testWidgets('authorized loading then list remains without no-access banner', (
    WidgetTester tester,
  ) async {
    await _pumpIntake(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
      ),
    );

    expect(find.text('Amina K.'), findsWidgets);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
    expect(find.text('Receive case'), findsNothing);
  });

  testWidgets('row select syncs detail via getItem (authorized path)', (
    WidgetTester tester,
  ) async {
    await _pumpIntake(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryExport,
        },
      ),
    );
    await _openDetail(tester);

    expect(find.text('CASE DETAIL'), findsOneWidget);
    expect(find.text('Print documents'), findsOneWidget);
    verify(
      () => repository.getItem(
        resource: any(named: 'resource'),
        id: any(named: 'id'),
        baseQuery: any(named: 'baseQuery'),
      ),
    ).called(1);
  });

  testWidgets('Intake mobile viewport keeps authorized chrome', (
    WidgetTester tester,
  ) async {
    await _pumpIntake(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('Intake'), findsOneWidget);
    expect(find.text('Amina K.'), findsWidgets);
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    expect(find.text('Receive case'), findsNothing);
  });

  testWidgets('Intake desktop dark theme keeps authorized atoms', (
    WidgetTester tester,
  ) async {
    await _pumpIntake(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.mortuaryRead,
          AppPermissions.mortuaryExport,
          AppPermissions.mortuaryBillingEvent,
          AppPermissions.billingRead,
        },
        modules: const <AppModuleEntitlement>[_mortuaryModule, _billingModule],
      ),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Intake'), findsOneWidget);
    expect(find.text('Amina K.'), findsWidgets);
    await _openDetail(tester);
    expect(find.text('Print documents'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Receive case'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('deep link panel=intake selects Intake for authorized reader', (
    WidgetTester tester,
  ) async {
    await _pumpIntake(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.mortuaryRead},
      ),
    );

    final AppTabStrip strip = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    expect(strip.selectedId, mortuaryPanelIntake);
    expect(_table(tester).columnVisibilityStorageKey, 'mortuary_intake');
  });
}
