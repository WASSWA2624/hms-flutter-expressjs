import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hosspi_hms/features/integrations/presentation/pages/integrations_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

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

const IntegrationRecord _warningIntegration = IntegrationRecord(
  id: 'integration-2',
  name: 'Inactive Bridge',
  integrationType: 'FHIR',
  status: 'INACTIVE',
  tenantLabel: 'Main Hospital',
);

const IntegrationRecord _failedIntegration = IntegrationRecord(
  id: 'integration-3',
  name: 'Failed Sync',
  integrationType: 'LAB',
  status: 'FAILED',
  tenantLabel: 'Main Hospital',
  requiresAttention: true,
);

const ApiKeyRecord _apiKey = ApiKeyRecord(
  id: 'api-key-1',
  name: 'Billing Export Key',
  userId: 'user-1',
  isActive: true,
  humanFriendlyId: 'key_billing',
);

const WebhookSubscriptionRecord _webhook = WebhookSubscriptionRecord(
  id: 'webhook-1',
  event: 'payment.completed',
  integrationLabel: 'Lab HL7 Feed',
  targetHost: 'hooks.example.com',
  integrationStatus: 'ACTIVE',
  isActive: true,
);

const IntegrationLogRecord _log = IntegrationLogRecord(
  id: 'log-1',
  integrationLabel: 'Lab HL7 Feed',
  integrationType: 'HL7',
  status: 'SUCCESS',
  message: 'Message accepted',
);

const InteropCapabilityStatus _interop = InteropCapabilityStatus(
  id: 'fhir',
  title: 'FHIR_EXCHANGE',
  scope: 'FHIR_EXPORT_IMPORT',
  status: 'READY',
  nextAction: 'RUN_AVAILABLE_ACTION',
);

AppAccessPolicy _integrationsWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['ADMIN']),
      permissions: <AppPermission>{
        AppPermissions.integrationRead,
        AppPermissions.integrationWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'integrations-core',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

AppAccessPolicy _integrationsReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['NURSE']),
      permissions: <AppPermission>{AppPermissions.integrationRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'integrations-core',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

void _stubWorkspace(_MockIntegrationsRepository repository) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async =>
        const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[
          _integration,
          _warningIntegration,
          _failedIntegration,
        ]),
  );
  when(() => repository.listApiKeys()).thenAnswer(
    (_) async =>
        const Result<List<ApiKeyRecord>>.success(<ApiKeyRecord>[_apiKey]),
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
      <WebhookSubscriptionRecord>[_webhook],
    ),
  );
  when(() => repository.listLogs()).thenAnswer(
    (_) async => const Result<List<IntegrationLogRecord>>.success(
      <IntegrationLogRecord>[_log],
    ),
  );
  when(
    () => repository.interopCapabilities(),
  ).thenReturn(const <InteropCapabilityStatus>[_interop]);
}

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockIntegrationsRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpIntegrationsWorkspace(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  IntegrationWorkspaceQuery? initialQuery,
  String initialLocation = '/integrations',
  AppAccessPolicy? accessPolicy,
  Size physicalSize = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);

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
              initialQuery:
                  initialQuery ?? IntegrationWorkspaceQuery.fromUri(state.uri),
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
          accessPolicy ?? _integrationsWritePolicy(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return _Harness(repository: repository, router: router);
}

AppListTable<IntegrationWorkItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<IntegrationWorkItem>>(
    find.byType(AppListTable<IntegrationWorkItem>),
  );
}

void main() {
  late _MockIntegrationsRepository repository;

  setUp(() {
    repository = _MockIntegrationsRepository();
  });

  testWidgets('renders AppTabStrip with five section tabs and counts', (
    WidgetTester tester,
  ) async {
    await _pumpIntegrationsWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(_tab('Integrations'), findsOneWidget);
    expect(_tab('API keys'), findsOneWidget);
    expect(_tab('Webhooks'), findsOneWidget);
    expect(_tab('Logs'), findsOneWidget);
    expect(_tab('Interop'), findsOneWidget);
    expect(find.text('Lab HL7 Feed'), findsOneWidget);
    expect(find.byTooltip('Create integration'), findsOneWidget);
  });

  testWidgets('tab toolbar omits status shortcuts and refresh', (
    WidgetTester tester,
  ) async {
    await _pumpIntegrationsWorkspace(tester, repository: repository);

    expect(find.byType(AppWorkspaceToolbar), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.byTooltip('Active'), findsNothing);
    expect(find.byTooltip('Warnings'), findsNothing);
    expect(find.byTooltip('Failed'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Total items'), findsNothing);
    expect(find.byTooltip('Create integration'), findsOneWidget);
  });

  testWidgets('logs and interop tabs have no create or refresh toolbar', (
    WidgetTester tester,
  ) async {
    await _pumpIntegrationsWorkspace(tester, repository: repository);

    await tester.tap(_tab('Logs'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Create integration'), findsNothing);
    expect(find.byTooltip('Create API key'), findsNothing);
    expect(find.byTooltip('Create webhook'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Active'), findsNothing);

    await tester.tap(_tab('Interop'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Active'), findsNothing);
    expect(find.byTooltip('Warnings'), findsNothing);
    expect(find.byTooltip('Failed'), findsNothing);
  });

  testWidgets(
    'integrations table uses standardized search chrome and columns',
    (WidgetTester tester) async {
      await _pumpIntegrationsWorkspace(tester, repository: repository);

      final AppListTable<IntegrationWorkItem> table = _table(tester);
      expect(table.search?.advancedFilterTitle, 'Advanced filters');
      expect(table.columnVisibilityTitle, 'Table Settings');
      expect(table.columnChoices, isNotNull);
      expect(table.columns.length, 5);
      expect(
        table.columns.map((AppListTableColumn<IntegrationWorkItem> c) => c.id),
        <String>['name', 'type', 'last_updated', 'status', 'next_action'],
      );
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsOneWidget,
      );

      final bool Function(IntegrationWorkItem, String) matcher =
          table.search!.matcher;
      final IntegrationWorkItem integrationItem =
          IntegrationWorkItem.integration(_integration);
      expect(matcher(integrationItem, 'Main Hospital'), isTrue);
      expect(matcher(integrationItem, 'nonexistent-xyz-query'), isFalse);
    },
  );

  testWidgets('switching tabs updates section query and columns', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpIntegrationsWorkspace(
      tester,
      repository: repository,
    );

    expect(
      _table(tester).columnVisibilityStorageKey,
      'integrations_integrations',
    );
    expect(_table(tester).columns.length, 5);
    expect(
      _table(
        tester,
      ).columns.map((AppListTableColumn<IntegrationWorkItem> c) => c.id),
      <String>['name', 'type', 'last_updated', 'status', 'next_action'],
    );
    expect(_table(tester).columnChoices?.length, greaterThan(5));

    await tester.tap(_tab('API keys'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'api-keys');
    expect(find.text('Billing Export Key'), findsOneWidget);
    expect(find.byTooltip('Create API key'), findsOneWidget);
    expect(find.byTooltip('Create integration'), findsNothing);
    expect(_table(tester).columnVisibilityStorageKey, 'integrations_apiKeys');
    expect(_table(tester).columns.length, 5);
    expect(
      _table(
        tester,
      ).columns.map((AppListTableColumn<IntegrationWorkItem> c) => c.id),
      <String>['name', 'key_id', 'last_used', 'status', 'next_action'],
    );

    await tester.tap(_tab('Webhooks'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'webhooks');
    expect(find.text('payment.completed'), findsOneWidget);
    expect(find.byTooltip('Create webhook'), findsOneWidget);
    expect(_table(tester).columns.length, 5);
    expect(
      _table(
        tester,
      ).columns.map((AppListTableColumn<IntegrationWorkItem> c) => c.id),
      <String>['event', 'integration', 'target_host', 'status', 'next_action'],
    );

    await tester.tap(_tab('Logs'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'logs');
    expect(find.byTooltip('Create integration'), findsNothing);
    expect(find.byTooltip('Create API key'), findsNothing);
    expect(find.byTooltip('Create webhook'), findsNothing);
    expect(_table(tester).columnVisibilityStorageKey, 'integrations_logs');
    expect(_table(tester).columns.length, 5);
    expect(
      _table(
        tester,
      ).columns.map((AppListTableColumn<IntegrationWorkItem> c) => c.id),
      <String>['integration', 'message', 'logged_at', 'status', 'next_action'],
    );

    await tester.tap(_tab('Interop'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['section'], 'interop');
    expect(_table(tester).columnVisibilityStorageKey, 'integrations_interop');
    expect(_table(tester).columns.length, 5);
    expect(
      _table(
        tester,
      ).columns.map((AppListTableColumn<IntegrationWorkItem> c) => c.id),
      <String>['title', 'scope', 'last_updated', 'status', 'next_action'],
    );
  });

  testWidgets('deep link section=api-keys selects API Keys tab', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpIntegrationsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/integrations?section=api-keys',
      initialQuery: IntegrationWorkspaceQuery.fromUri(
        Uri.parse('/integrations?section=api-keys'),
      ),
    );

    expect(harness.router.state.uri.queryParameters['section'], 'api-keys');
    expect(find.text('Billing Export Key'), findsOneWidget);
    expect(find.byTooltip('Create API key'), findsOneWidget);
    expect(find.text('Lab HL7 Feed'), findsNothing);
    expect(_table(tester).columnVisibilityStorageKey, 'integrations_apiKeys');
  });

  testWidgets('deep link via IntegrationWorkspaceQuery filter selects tab', (
    WidgetTester tester,
  ) async {
    await _pumpIntegrationsWorkspace(
      tester,
      repository: repository,
      initialQuery: const IntegrationWorkspaceQuery(
        filter: IntegrationWorkspaceFilter.apiKeys,
      ),
    );

    expect(find.text('Billing Export Key'), findsOneWidget);
    expect(find.byTooltip('Create API key'), findsOneWidget);
    expect(_table(tester).columnVisibilityStorageKey, 'integrations_apiKeys');
  });

  testWidgets('hides create actions when user lacks write permission', (
    WidgetTester tester,
  ) async {
    await _pumpIntegrationsWorkspace(
      tester,
      repository: repository,
      accessPolicy: _integrationsReadOnlyPolicy(),
    );

    expect(_tab('Integrations'), findsOneWidget);
    expect(find.byTooltip('Create integration'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
  });

  testWidgets(
    'narrow viewport keeps tab strip and list with next-action control',
    (WidgetTester tester) async {
      await _pumpIntegrationsWorkspace(
        tester,
        repository: repository,
        physicalSize: const Size(720, 900),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tab('Integrations'), findsOneWidget);
      expect(find.text('Lab HL7 Feed'), findsOneWidget);
      expect(find.byType(AppWorkspaceStatusBadge), findsWidgets);
      expect(find.text('Monitor'), findsWidgets);
    },
  );

  testWidgets(
    'detail omits Sync now when row next-action is Monitor',
    (WidgetTester tester) async {
      await _pumpIntegrationsWorkspace(tester, repository: repository);

      await tester.tap(find.text('Lab HL7 Feed'));
      await tester.pumpAndSettle();

      expect(find.text('Configure'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
      expect(find.text('Disable'), findsOneWidget);
    },
  );

  testWidgets(
    'authorized Monitor next-action opens sync confirm without detail shell',
    (WidgetTester tester) async {
      await _pumpIntegrationsWorkspace(tester, repository: repository);

      final Finder monitor = find.widgetWithText(AppButton, 'Monitor');
      expect(monitor, findsWidgets);
      await tester.ensureVisible(monitor.first);
      await tester.pumpAndSettle();
      await tester.tap(monitor.first);
      await tester.pumpAndSettle();

      expect(find.text('Sync now?'), findsOneWidget);
      expect(find.text('Configure'), findsNothing);
    },
  );
}
