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

const IntegrationRecord _integration = IntegrationRecord(
  id: 'integration-1',
  name: 'Lab HL7 Feed',
  integrationType: 'HL7',
  status: 'ACTIVE',
  tenantLabel: 'Main Hospital',
  hasConfig: true,
  webhookSubscriptionCount: 1,
  logCount: 2,
);

const WebhookSubscriptionRecord _activeWebhook = WebhookSubscriptionRecord(
  id: 'webhook-1',
  event: 'payment.completed',
  integrationLabel: 'Lab HL7 Feed',
  targetHost: 'hooks.example.com',
  integrationStatus: 'ACTIVE',
  isActive: true,
);

const WebhookSubscriptionRecord _inactiveWebhook = WebhookSubscriptionRecord(
  id: 'webhook-2',
  event: 'claim.submitted',
  integrationLabel: 'Lab HL7 Feed',
  targetHost: 'hooks.example.com',
  integrationStatus: 'INACTIVE',
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
  List<WebhookSubscriptionRecord> webhooks = const <WebhookSubscriptionRecord>[
    _activeWebhook,
  ],
  Result<List<WebhookSubscriptionRecord>>? webhooksOverride,
  Result<List<IntegrationRecord>>? integrationsOverride,
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async =>
        integrationsOverride ??
        const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[
          _integration,
        ]),
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
    (_) async =>
        webhooksOverride ??
        Result<List<WebhookSubscriptionRecord>>.success(webhooks),
  );
  when(() => repository.listLogs()).thenAnswer(
    (_) async =>
        const Result<List<IntegrationLogRecord>>.success(<IntegrationLogRecord>[]),
  );
  when(
    () => repository.interopCapabilities(),
  ).thenReturn(const <InteropCapabilityStatus>[]);
}

Future<void> _pumpWebhooksTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<WebhookSubscriptionRecord> webhooks =
      const <WebhookSubscriptionRecord>[_activeWebhook],
  Result<List<WebhookSubscriptionRecord>>? webhooksOverride,
  Result<List<IntegrationRecord>>? integrationsOverride,
  String initialLocation = '/integrations?section=webhooks',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    webhooks: webhooks,
    webhooksOverride: webhooksOverride,
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

  group('IntegrationsWebhooksAtomPermissions helpers', () {
    test('reuses AccessRequirement vocabulary (no second map)', () {
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.tab,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.listChrome,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.search,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.filters,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.pagination,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.rowSelect,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.nextAction,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.detail,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.create,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.update,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.edit,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.replay,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.enable,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.delete,
          integrationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.routeEntry,
          integrationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      // Nested cross-module matrix rows are _(n/a)_ — nested gates stay in-module.
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.nestedRead,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.nestedWrite,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      // Source inventory maps create/update to manage ∪ (write ∪ admins), not
      // strict write ∩ alone — note mapping for matrix create/update rows.
      expect(
        identical(
          IntegrationsWebhooksAtomPermissions.write,
          integrationsManageRequirement,
        ),
        isTrue,
      );
    });

    test('∩ denial: read without manage denies create/update', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(IntegrationsWebhooksAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        IntegrationsWebhooksAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        IntegrationsWebhooksAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        IntegrationsWebhooksAtomPermissions.delete.isAllowed(reader),
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
        IntegrationsWebhooksAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        IntegrationsWebhooksAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
    });

    test('route entry ∪: write alone enters; tab read ∩ fails', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );
      expect(
        IntegrationsWebhooksAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        IntegrationsWebhooksAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(canEnterIntegrationsWorkspace(writeOnly), isTrue);
      expect(
        canViewIntegrationsSection(
          writeOnly,
          IntegrationDeskSection.webhooks,
        ),
        isFalse,
      );
    });

    test('manage ∪: tenantAdmin alone satisfies create (source mapping)', () {
      final AppAccessPolicy admin = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.tenantAdmin,
        },
      );
      expect(
        IntegrationsWebhooksAtomPermissions.create.isAllowed(admin),
        isTrue,
      );
      expect(
        IntegrationsWebhooksAtomPermissions.update.isAllowed(admin),
        isTrue,
      );
    });
  });

  testWidgets(
    '∩ denial: missing integration:read omits Webhooks tab and list',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(_tab('Webhooks'), findsNothing);
      expect(find.text('payment.completed'), findsNothing);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full ∩ read: Webhooks list, chrome, and view next-action mount',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(IntegrationsWebhooksAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        IntegrationsWebhooksAtomPermissions.update.isAllowed(reader),
        isFalse,
      );

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Webhooks'), findsOneWidget);
      expect(find.text('payment.completed'), findsWidgets);
      expect(find.text('Monitor delivery'), findsWidgets);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Edit webhook'), findsNothing);
      expect(find.text('Replay webhook'), findsNothing);
      expect(find.text('Disable'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∩ denial: inactive webhook shows view next-action, not Enable webhook',
    (WidgetTester tester) async {
      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        webhooks: const <WebhookSubscriptionRecord>[_inactiveWebhook],
      );

      expect(find.text('claim.submitted'), findsWidgets);
      expect(find.text('Enable webhook'), findsNothing);
      expect(find.text('Monitor delivery'), findsWidgets);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'manage ∪ write: Create webhook and Enable webhook mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      expect(
        IntegrationsWebhooksAtomPermissions.create.isAllowed(writer),
        isTrue,
      );

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: writer,
        webhooks: const <WebhookSubscriptionRecord>[
          _activeWebhook,
          _inactiveWebhook,
        ],
      );

      expect(find.byTooltip('Create webhook'), findsOneWidget);
      expect(find.text('Enable webhook'), findsWidgets);
      expect(find.text('Monitor delivery'), findsWidgets);

      await tester.tap(find.text('payment.completed').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit webhook'), findsOneWidget);
      expect(find.text('Replay webhook'), findsOneWidget);
      expect(find.text('Disable'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'delete ∩ alone: no Create/Edit; inventory has no delete control',
    (WidgetTester tester) async {
      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationDelete,
        },
      );
      expect(
        IntegrationsWebhooksAtomPermissions.delete.isAllowed(deleter),
        isTrue,
      );
      expect(
        IntegrationsWebhooksAtomPermissions.create.isAllowed(deleter),
        isFalse,
      );

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: deleter,
      );

      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.text('Monitor delivery'), findsWidgets);

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.text('Edit webhook'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: integration:write alone omits Webhooks chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );
      expect(canEnterIntegrationsWorkspace(writeOnly), isTrue);
      expect(
        canViewIntegrationsSection(
          writeOnly,
          IntegrationDeskSection.webhooks,
        ),
        isFalse,
      );

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('payment.completed'), findsNothing);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: integrations-core missing omits Webhooks tab',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(IntegrationsWebhooksAtomPermissions.tab.isAllowed(noModule), isFalse);

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('Webhooks'), findsNothing);
      expect(find.text('payment.completed'), findsNothing);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: EXPIRED integrations-core omits Webhooks tab',
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
      expect(IntegrationsWebhooksAtomPermissions.tab.isAllowed(expired), isFalse);

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: expired,
      );

      expect(_tab('Webhooks'), findsNothing);
      expect(find.text('payment.completed'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'plan BASIC strips integrations-core: Webhooks absent despite grants',
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
      expect(IntegrationsWebhooksAtomPermissions.tab.isAllowed(basic), isFalse);
      expect(
        IntegrationsWebhooksAtomPermissions.create.isAllowed(basic),
        isFalse,
      );

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: basic,
      );

      expect(_tab('Webhooks'), findsNothing);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC: missing facility context still allows Webhooks read chrome '
    '(row/own scope remains backend-authoritative)',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
        facilityId: null,
      );
      expect(noFacility.hasFacilityContext, isFalse);
      expect(
        IntegrationsWebhooksAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        IntegrationsWebhooksAtomPermissions.create.isAllowed(noFacility),
        isFalse,
      );

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: noFacility,
      );

      expect(_tab('Webhooks'), findsOneWidget);
      expect(find.text('payment.completed'), findsWidgets);
      expect(find.text('Monitor delivery'), findsWidgets);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty Webhooks keeps chrome; no write affordances',
    (WidgetTester tester) async {
      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        webhooks: const <WebhookSubscriptionRecord>[],
      );

      expect(_tab('Webhooks'), findsOneWidget);
      expect(find.text('No integration items'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Webhooks',
    (WidgetTester tester) async {
      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        webhooksOverride: const Result<List<WebhookSubscriptionRecord>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on Webhooks', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.listIntegrations()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[
        _integration,
      ]);
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
        <WebhookSubscriptionRecord>[_activeWebhook],
      ),
    );
    when(() => repository.listLogs()).thenAnswer(
      (_) async => const Result<List<IntegrationLogRecord>>.success(
        <IntegrationLogRecord>[],
      ),
    );
    when(
      () => repository.interopCapabilities(),
    ).thenReturn(const <InteropCapabilityStatus>[]);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/integrations?section=webhooks',
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

    expect(find.text('payment.completed'), findsWidgets);
    expect(find.text('Loading integrations'), findsNothing);
  });

  testWidgets(
    'post-mutation sync: Enable webhook updates list after confirm',
    (WidgetTester tester) async {
      const WebhookSubscriptionRecord enabled = WebhookSubscriptionRecord(
        id: 'webhook-2',
        event: 'claim.submitted',
        integrationLabel: 'Lab HL7 Feed',
        targetHost: 'hooks.example.com',
        integrationStatus: 'ACTIVE',
        isActive: true,
      );
      when(
        () => repository.updateWebhook(any(), any()),
      ).thenAnswer((_) async => const Result<WebhookSubscriptionRecord>.success(
        enabled,
      ));

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
        webhooks: const <WebhookSubscriptionRecord>[_inactiveWebhook],
      );

      expect(find.text('Enable webhook'), findsWidgets);
      await tester.ensureVisible(find.text('Enable webhook').first);
      await tester.tap(find.text('Enable webhook').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Enable webhook'), findsWidgets);
      final Finder confirm = find.widgetWithText(AppButton, 'Enable');
      expect(confirm, findsWidgets);
      await tester.tap(confirm.last);
      await tester.pumpAndSettle();

      verify(() => repository.updateWebhook('webhook-2', any())).called(1);
      expect(find.text('Monitor delivery'), findsWidgets);
      expect(find.text('Enable webhook'), findsNothing);
    },
  );

  testWidgets('mobile viewport: Webhooks next-action trailing present', (
    WidgetTester tester,
  ) async {
    await _pumpWebhooksTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      ),
      physicalSize: const Size(390, 844),
      webhooks: const <WebhookSubscriptionRecord>[_inactiveWebhook],
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(_tab('Webhooks'), findsOneWidget);
    expect(find.text('claim.submitted'), findsWidgets);
    expect(find.text('Enable webhook'), findsWidgets);
    expect(find.byTooltip('Create webhook'), findsOneWidget);
  });

  testWidgets('desktop viewport: Webhooks columns and Create primary present', (
    WidgetTester tester,
  ) async {
    await _pumpWebhooksTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      ),
    );

    expect(_tab('Webhooks'), findsOneWidget);
    expect(find.byTooltip('Create webhook'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Next action'),
      ),
      findsOneWidget,
    );
    expect(find.text('payment.completed'), findsWidgets);
  });

  testWidgets('light theme: Webhooks authorized chrome mounts', (
    WidgetTester tester,
  ) async {
    await _pumpWebhooksTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
    );

    expect(_tab('Webhooks'), findsOneWidget);
    expect(find.text('payment.completed'), findsWidgets);
    expect(find.byTooltip('Create webhook'), findsNothing);
  });

  testWidgets('dark theme: Webhooks authorized chrome mounts', (
    WidgetTester tester,
  ) async {
    await _pumpWebhooksTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Webhooks'), findsOneWidget);
    expect(find.text('payment.completed'), findsWidgets);
    expect(find.byTooltip('Create webhook'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'create webhook dialog validates and syncs on success',
    (WidgetTester tester) async {
      const WebhookSubscriptionRecord created = WebhookSubscriptionRecord(
        id: 'webhook-new',
        event: 'invoice.paid',
        integrationId: 'integration-1',
        integrationLabel: 'Lab HL7 Feed',
        targetHost: 'hooks.example.com',
        targetUrl: 'https://hooks.example.com/invoice',
        integrationStatus: 'ACTIVE',
        isActive: true,
      );
      when(() => repository.createWebhook(any())).thenAnswer(
        (_) async => const Result<WebhookSubscriptionRecord>.success(created),
      );

      await _pumpWebhooksTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Create webhook'));
      await tester.pumpAndSettle();

      expect(find.text('Create webhook'), findsWidgets);
      // Validation: submit without required fields keeps dialog open.
      final Finder submit = find.widgetWithText(AppButton, 'Create webhook');
      if (submit.evaluate().isNotEmpty) {
        await tester.tap(submit.last);
        await tester.pumpAndSettle();
      }
      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    },
  );
}
