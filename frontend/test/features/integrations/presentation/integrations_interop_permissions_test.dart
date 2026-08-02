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
import 'package:hosspi_hms/features/integrations/data/repositories/integrations_repository_impl.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/domain/repositories/integrations_repository.dart';
import 'package:hosspi_hms/features/integrations/presentation/integrations_access.dart';
import 'package:hosspi_hms/features/integrations/presentation/pages/integrations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

Finder _tableRowInkWell() => find.byWidgetPredicate(
  (Widget widget) => widget.runtimeType.toString() == 'TableRowInkWell',
);

const InteropCapabilityStatus _fhirReady = InteropCapabilityStatus(
  id: 'fhir',
  title: 'FHIR_EXCHANGE',
  scope: 'FHIR_EXPORT_IMPORT',
  status: 'READY',
  nextAction: 'RUN_AVAILABLE_ACTION',
);

const InteropCapabilityStatus _readinessGap = InteropCapabilityStatus(
  id: 'readiness',
  title: 'EXTERNAL_READINESS_STATUS',
  scope: 'INTEROP_STATUS',
  status: 'UNAVAILABLE',
  nextAction: 'USE_INTEGRATION_STATUS_AND_LOGS',
  unavailableReason: 'INTEROP_READINESS_SIGNAL_UNAVAILABLE',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: integrationsActiveModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: const <String>['NURSE'],
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockIntegrationsRepository repository, {
  List<InteropCapabilityStatus> interop = const <InteropCapabilityStatus>[
    _fhirReady,
  ],
  Result<List<IntegrationRecord>>? integrationsOverride,
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async =>
        integrationsOverride ??
        const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[]),
  );
  when(() => repository.listApiKeys()).thenAnswer(
    (_) async => const Result<List<ApiKeyRecord>>.success(<ApiKeyRecord>[]),
  );
  when(() => repository.listApiKeyPermissions()).thenAnswer(
    (_) async => const Result<List<ApiKeyPermissionRecord>>.success(
      <ApiKeyPermissionRecord>[],
    ),
  );
  when(() => repository.listPermissionOptions()).thenAnswer(
    (_) async => const Result<List<IntegrationPermissionOption>>.success(
      <IntegrationPermissionOption>[],
    ),
  );
  when(() => repository.listWebhooks()).thenAnswer(
    (_) async => const Result<List<WebhookSubscriptionRecord>>.success(
      <WebhookSubscriptionRecord>[],
    ),
  );
  when(() => repository.listLogs()).thenAnswer(
    (_) async =>
        const Result<List<IntegrationLogRecord>>.success(<IntegrationLogRecord>[]),
  );
  when(() => repository.interopCapabilities()).thenReturn(interop);
}

Future<void> _pumpInteropTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<InteropCapabilityStatus> interop = const <InteropCapabilityStatus>[
    _fhirReady,
  ],
  Result<List<IntegrationRecord>>? integrationsOverride,
  String initialLocation = '/integrations?section=interop',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    interop: interop,
    integrationsOverride: integrationsOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/integrations',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IntegrationsWorkspacePage(
              initialQuery: IntegrationWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        integrationsRepositoryProvider.overrideWithValue(repository),
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
  late _MockIntegrationsRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockIntegrationsRepository();
  });

  group('IntegrationsInteropAtomPermissions helpers', () {
    test('reuses AccessRequirement vocabulary (no second map)', () {
      expect(
        identical(
          IntegrationsInteropAtomPermissions.tab,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.listChrome,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.search,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.filters,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.pagination,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.rowSelect,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.nextAction,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.viewNextAction,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.detail,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.readiness,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.create,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.update,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.runProbe,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.delete,
          integrationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.routeEntry,
          integrationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      // Nested cross-module matrix rows are _(n/a)_ — nested gates stay in-module.
      expect(
        identical(
          IntegrationsInteropAtomPermissions.nestedRead,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsInteropAtomPermissions.nestedWrite,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      // Source inventory: create/update/runProbe map to manage ∪ (write ∪ admins),
      // not strict write ∩ alone — note mapping for matrix create/update rows.
      expect(
        identical(
          IntegrationsInteropAtomPermissions.write,
          integrationsManageRequirement,
        ),
        isTrue,
      );
      expect(
        integrationNextActionRequiresWrite('RUN_AVAILABLE_ACTION'),
        isFalse,
        reason:
            'Source inventory opens detail for Interop next-actions (view-only)',
      );
      expect(
        integrationNextActionRequiresWrite('USE_INTEGRATION_STATUS_AND_LOGS'),
        isFalse,
      );
    });

    test('∩ denial: read without manage denies create/update/runProbe', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(IntegrationsInteropAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        IntegrationsInteropAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        IntegrationsInteropAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        IntegrationsInteropAtomPermissions.runProbe.isAllowed(reader),
        isFalse,
      );
      expect(
        IntegrationsInteropAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );
    });

    test('∩ denial: write without delete denies delete atom', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      expect(
        IntegrationsInteropAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        IntegrationsInteropAtomPermissions.runProbe.isAllowed(writer),
        isTrue,
      );
      expect(
        IntegrationsInteropAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
    });

    test('route entry ∪: write alone enters; tab read ∩ fails', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );
      expect(
        IntegrationsInteropAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        IntegrationsInteropAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(canEnterIntegrationsWorkspace(writeOnly), isTrue);
      expect(
        canViewIntegrationsSection(
          writeOnly,
          IntegrationDeskSection.interop,
        ),
        isFalse,
      );
    });

    test('manage ∪: tenantAdmin alone satisfies update/runProbe', () {
      final AppAccessPolicy admin = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.tenantAdmin,
        },
      );
      expect(
        IntegrationsInteropAtomPermissions.update.isAllowed(admin),
        isTrue,
      );
      expect(
        IntegrationsInteropAtomPermissions.runProbe.isAllowed(admin),
        isTrue,
      );
    });
  });

  testWidgets(
    '∩ denial: missing integration:read omits Interop tab and list',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(_tab('Interop'), findsNothing);
      expect(find.text('FHIR exchange'), findsNothing);
      expect(find.text('Run action'), findsNothing);
      expect(find.byTooltip('Create integration'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full ∩ read: Interop list, chrome, and view next-action mount',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(IntegrationsInteropAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        IntegrationsInteropAtomPermissions.update.isAllowed(reader),
        isFalse,
      );

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        interop: const <InteropCapabilityStatus>[_fhirReady, _readinessGap],
      );

      expect(_tab('Interop'), findsOneWidget);
      expect(find.text('FHIR exchange'), findsWidgets);
      expect(find.text('Run action'), findsWidgets);
      expect(find.text('Use status logs'), findsWidgets);
      expect(find.byTooltip('Create integration'), findsNothing);
      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('FHIR exchange').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Interoperability actions are available.'), findsWidgets);
      // Source inventory: Interop detail has no write actions.
      expect(find.text('Test connection'), findsNothing);
      expect(find.text('Sync now'), findsNothing);
      expect(find.text('Enable'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'manage ∪ write: Interop stays create-less; readiness detail only',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      expect(
        IntegrationsInteropAtomPermissions.runProbe.isAllowed(writer),
        isTrue,
      );

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      // Interop tab strip has no create primary (inventory).
      expect(find.byTooltip('Create integration'), findsNothing);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.text('Run action'), findsWidgets);

      await tester.tap(find.text('FHIR exchange').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Interoperability actions are available.'), findsWidgets);
      expect(find.text('Test connection'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'delete ∩ alone: no create; inventory has no Interop delete control',
    (WidgetTester tester) async {
      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationDelete,
        },
      );
      expect(
        IntegrationsInteropAtomPermissions.delete.isAllowed(deleter),
        isTrue,
      );
      expect(
        IntegrationsInteropAtomPermissions.create.isAllowed(deleter),
        isFalse,
      );

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: deleter,
      );

      expect(find.text('Run action'), findsWidgets);
      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: integration:write alone omits Interop chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );
      expect(canEnterIntegrationsWorkspace(writeOnly), isTrue);
      expect(
        canViewIntegrationsSection(
          writeOnly,
          IntegrationDeskSection.interop,
        ),
        isFalse,
      );

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('FHIR exchange'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: integrations-core missing omits Interop tab',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(IntegrationsInteropAtomPermissions.tab.isAllowed(noModule), isFalse);

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('Interop'), findsNothing);
      expect(find.text('FHIR exchange'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: EXPIRED integrations-core omits Interop tab',
    (WidgetTester tester) async {
      final AppAccessPolicy expired = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: integrationsActiveModule,
            licenseStatus: 'EXPIRED',
          ),
        ],
      );
      expect(IntegrationsInteropAtomPermissions.tab.isAllowed(expired), isFalse);

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: expired,
      );

      expect(_tab('Interop'), findsNothing);
      expect(find.text('FHIR exchange'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'plan BASIC strips integrations-core: Interop absent despite grants',
    (WidgetTester tester) async {
      final AppAccessPolicy basic = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
          AppPermissions.integrationDelete,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: integrationsActiveModule,
            licenseStatus: 'ACTIVE',
            planTierCode: 'BASIC',
          ),
        ],
      );
      expect(IntegrationsInteropAtomPermissions.tab.isAllowed(basic), isFalse);
      expect(
        IntegrationsInteropAtomPermissions.create.isAllowed(basic),
        isFalse,
      );

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: basic,
      );

      expect(_tab('Interop'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC: missing facility context still allows Interop read chrome '
    '(row/own scope remains backend-authoritative)',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
        facilityId: null,
      );
      expect(noFacility.hasFacilityContext, isFalse);
      expect(
        IntegrationsInteropAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        IntegrationsInteropAtomPermissions.runProbe.isAllowed(noFacility),
        isFalse,
      );

      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: noFacility,
      );

      expect(_tab('Interop'), findsOneWidget);
      expect(find.text('FHIR exchange'), findsWidgets);
      expect(find.text('Run action'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty Interop keeps chrome; no write affordances',
    (WidgetTester tester) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        interop: const <InteropCapabilityStatus>[],
      );

      expect(_tab('Interop'), findsOneWidget);
      expect(find.text('No integration items'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.text('Run action'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Interop',
    (WidgetTester tester) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        integrationsOverride: const Result<List<IntegrationRecord>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on Interop', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.listIntegrations()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[]);
    });
    when(() => repository.listApiKeys()).thenAnswer(
      (_) async => const Result<List<ApiKeyRecord>>.success(<ApiKeyRecord>[]),
    );
    when(() => repository.listApiKeyPermissions()).thenAnswer(
      (_) async => const Result<List<ApiKeyPermissionRecord>>.success(
        <ApiKeyPermissionRecord>[],
      ),
    );
    when(() => repository.listPermissionOptions()).thenAnswer(
      (_) async => const Result<List<IntegrationPermissionOption>>.success(
        <IntegrationPermissionOption>[],
      ),
    );
    when(() => repository.listWebhooks()).thenAnswer(
      (_) async => const Result<List<WebhookSubscriptionRecord>>.success(
        <WebhookSubscriptionRecord>[],
      ),
    );
    when(() => repository.listLogs()).thenAnswer(
      (_) async => const Result<List<IntegrationLogRecord>>.success(
        <IntegrationLogRecord>[],
      ),
    );
    when(
      () => repository.interopCapabilities(),
    ).thenReturn(const <InteropCapabilityStatus>[_fhirReady]);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/integrations?section=interop',
      routes: <RouteBase>[
        GoRoute(
          path: '/integrations',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: IntegrationsWorkspacePage(
                initialQuery: IntegrationWorkspaceQuery.fromUri(state.uri),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          integrationsRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{AppPermissions.integrationRead},
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
    expect(find.text('Loading integrations'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.text('FHIR exchange'), findsWidgets);
    expect(find.text('Loading integrations'), findsNothing);
  });

  testWidgets(
    'authorized detail open/close keeps Interop list synchronized '
    '(no mutation UI on this tab)',
    (WidgetTester tester) async {
      await _pumpInteropTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
        interop: const <InteropCapabilityStatus>[_fhirReady, _readinessGap],
      );

      expect(find.text('FHIR exchange'), findsWidgets);
      await tester.tap(find.text('Run action').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Interoperability actions are available.'), findsWidgets);

      await tester.tap(find.widgetWithText(AppButton, 'Close').last);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(find.text('FHIR exchange'), findsWidgets);
      expect(find.text('Run action'), findsWidgets);
      expect(find.text('Use status logs'), findsWidgets);
    },
  );

  testWidgets('mobile viewport: Interop next-action trailing present', (
    WidgetTester tester,
  ) async {
    await _pumpInteropTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(_tab('Interop'), findsOneWidget);
    expect(find.text('FHIR exchange'), findsWidgets);
    expect(find.text('Run action'), findsWidgets);
  });

  testWidgets('desktop viewport: Interop columns and view next-action present', (
    WidgetTester tester,
  ) async {
    await _pumpInteropTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(_tab('Interop'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Next action'),
      ),
      findsOneWidget,
    );
    expect(find.text('FHIR exchange'), findsWidgets);
    expect(find.text('Run action'), findsWidgets);
  });

  testWidgets('light theme: Interop authorized chrome mounts', (
    WidgetTester tester,
  ) async {
    await _pumpInteropTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      themeMode: ThemeMode.light,
    );

    expect(_tab('Interop'), findsOneWidget);
    expect(find.text('FHIR exchange'), findsWidgets);
  });

  testWidgets('dark theme: Interop authorized chrome mounts', (
    WidgetTester tester,
  ) async {
    await _pumpInteropTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Interop'), findsOneWidget);
    expect(find.text('FHIR exchange'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });
}
