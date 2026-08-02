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

const ApiKeyRecord _apiKey = ApiKeyRecord(
  id: 'api-key-1',
  name: 'Billing Export Key',
  userId: 'user-1',
  isActive: true,
  humanFriendlyId: 'key_billing',
);

const ApiKeyRecord _warningApiKey = ApiKeyRecord(
  id: 'api-key-2',
  name: 'Inactive Export Key',
  userId: 'user-1',
  humanFriendlyId: 'key_inactive',
);

const ApiKeyPermissionRecord _apiKeyPermission = ApiKeyPermissionRecord(
  id: 'grant-1',
  apiKeyId: 'api-key-1',
  permissionId: 'perm-billing-read',
);

const IntegrationPermissionOption _permissionOption =
    IntegrationPermissionOption(
      id: 'perm-billing-read',
      name: 'Billing read',
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
  List<ApiKeyRecord> apiKeys = const <ApiKeyRecord>[_apiKey, _warningApiKey],
  List<ApiKeyPermissionRecord> permissions =
      const <ApiKeyPermissionRecord>[_apiKeyPermission],
  Result<List<ApiKeyRecord>>? apiKeysOverride,
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async => const Result<List<IntegrationRecord>>.success(
      <IntegrationRecord>[],
    ),
  );
  when(() => repository.listApiKeys()).thenAnswer(
    (_) async =>
        apiKeysOverride ?? Result<List<ApiKeyRecord>>.success(apiKeys),
  );
  when(() => repository.listApiKeyPermissions()).thenAnswer(
    (_) async => Result<List<ApiKeyPermissionRecord>>.success(permissions),
  );
  when(() => repository.listPermissionOptions()).thenAnswer(
    (_) async => const Result<List<IntegrationPermissionOption>>.success(
      <IntegrationPermissionOption>[_permissionOption],
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
  ).thenReturn(const <InteropCapabilityStatus>[]);
}

Future<void> _pumpApiKeysTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/integrations?section=api-keys',
  List<ApiKeyRecord> apiKeys = const <ApiKeyRecord>[_apiKey, _warningApiKey],
  List<ApiKeyPermissionRecord> permissions =
      const <ApiKeyPermissionRecord>[_apiKeyPermission],
  Result<List<ApiKeyRecord>>? apiKeysOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    apiKeys: apiKeys,
    permissions: permissions,
    apiKeysOverride: apiKeysOverride,
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

  group('IntegrationsApiKeysAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.tab,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.listChrome,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.viewNextAction,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.create,
          integrationsManageRequirement,
        ),
        isTrue,
      );
      // Matrix create/update ∩ write maps to source manage ∪ (write | admin).
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.update,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.writeNextAction,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.managePermissions,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.enableDisable,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.secretReveal,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.revoke,
          integrationsDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.routeEntry,
          integrationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.nestedRead,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsApiKeysAtomPermissions.nestedWrite,
          integrationsManageRequirement,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing integration:read fails tab / list chrome', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );
      expect(
        IntegrationsApiKeysAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(IntegrationsApiKeysAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        IntegrationsApiKeysAtomPermissions.listChrome.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        canViewIntegrationsSection(writeOnly, IntegrationDeskSection.apiKeys),
        isFalse,
      );
    });

    test('∪ allowance: facility:admin alone satisfies manage create', () {
      final AppAccessPolicy facilityAdmin = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.facilityAdmin,
        },
      );
      expect(
        IntegrationsApiKeysAtomPermissions.create.isAllowed(facilityAdmin),
        isTrue,
      );
      expect(
        IntegrationsApiKeysAtomPermissions.writeNextAction.isAllowed(
          facilityAdmin,
        ),
        isTrue,
      );
      expect(canManageIntegrations(facilityAdmin), isTrue);
      expect(canDeleteIntegrations(facilityAdmin), isFalse);
    });

    test('subscription strips manage without integrations-core module', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
          AppPermissions.integrationDelete,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(IntegrationsApiKeysAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        IntegrationsApiKeysAtomPermissions.create.isAllowed(noModule),
        isFalse,
      );
      expect(
        IntegrationsApiKeysAtomPermissions.delete.isAllowed(noModule),
        isFalse,
      );
    });
  });

  testWidgets(
    '∩ denial: missing integration:read omits API keys tab and list',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(_tab('API keys'), findsNothing);
      expect(find.text('Billing Export Key'), findsNothing);
      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full ∩ read: API keys list, chrome, and detail mount without mutations',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(IntegrationsApiKeysAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(IntegrationsApiKeysAtomPermissions.create.isAllowed(reader), isFalse);
      expect(IntegrationsApiKeysAtomPermissions.delete.isAllowed(reader), isFalse);

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('API keys'), findsOneWidget);
      expect(find.text('Billing Export Key'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.text('Review key'), findsNothing);
      expect(find.text('Revoke key'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      // Healthy key keeps view-only next-action; warning falls back to view.
      expect(find.text('Rotate or monitor'), findsWidgets);

      await tester.tap(find.text('Billing Export Key'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Manage permissions'), findsNothing);
      expect(find.text('Disable'), findsNothing);
      expect(find.text('Revoke key'), findsNothing);
      expect(find.text('Billing read'), findsOneWidget);
      expect(find.byTooltip('Remove permission'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∩ denial: warning key shows view next-action, not Review key',
    (WidgetTester tester) async {
      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        apiKeys: const <ApiKeyRecord>[_warningApiKey],
        permissions: const <ApiKeyPermissionRecord>[],
      );

      expect(find.text('Inactive Export Key'), findsWidgets);
      expect(find.text('Review key'), findsNothing);
      expect(find.text('Rotate or monitor'), findsWidgets);
      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∩ write without delete: create/update present; revoke absent',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      expect(IntegrationsApiKeysAtomPermissions.create.isAllowed(writer), isTrue);
      expect(IntegrationsApiKeysAtomPermissions.delete.isAllowed(writer), isFalse);

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.byTooltip('Create API key'), findsOneWidget);
      expect(find.text('Review key'), findsWidgets);

      await tester.tap(find.text('Billing Export Key'));
      await tester.pumpAndSettle();

      expect(find.text('Manage permissions'), findsOneWidget);
      expect(find.text('Disable'), findsOneWidget);
      expect(find.text('Revoke key'), findsNothing);
      expect(find.byTooltip('Remove permission'), findsOneWidget);
    },
  );

  testWidgets(
    'delete ∩ alone: no Create/Manage writes; Revoke mounts',
    (WidgetTester tester) async {
      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationDelete,
        },
      );
      expect(IntegrationsApiKeysAtomPermissions.create.isAllowed(deleter), isFalse);
      expect(IntegrationsApiKeysAtomPermissions.delete.isAllowed(deleter), isTrue);

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: deleter,
      );

      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.text('Review key'), findsNothing);
      expect(find.text('Rotate or monitor'), findsWidgets);

      await tester.tap(find.text('Billing Export Key'));
      await tester.pumpAndSettle();

      // Revoke needs delete; Enable/Manage need manage — with delete-only,
      // detail still shows Revoke (canDelete) but not manage writes.
      expect(find.text('Manage permissions'), findsNothing);
      expect(find.text('Disable'), findsNothing);
      expect(find.text('Revoke key'), findsOneWidget);
      expect(find.byTooltip('Remove permission'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write+delete: revoke and create mount; authorized flow syncs',
    (WidgetTester tester) async {
      final AppAccessPolicy manager = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
          AppPermissions.integrationDelete,
        },
      );

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: manager,
      );

      expect(find.byTooltip('Create API key'), findsOneWidget);
      expect(
        IntegrationsApiKeysAtomPermissions.secretReveal.isAllowed(manager),
        isTrue,
      );

      await tester.tap(find.text('Billing Export Key'));
      await tester.pumpAndSettle();

      expect(find.text('Revoke key'), findsOneWidget);
      expect(find.text('Manage permissions'), findsOneWidget);
      expect(find.text('Disable'), findsOneWidget);
      expect(find.byTooltip('Remove permission'), findsOneWidget);
    },
  );

  testWidgets(
    '∪ allowance widget: facility:admin mounts Create API key',
    (WidgetTester tester) async {
      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.facilityAdmin,
          },
        ),
      );

      expect(find.byTooltip('Create API key'), findsOneWidget);
      expect(find.text('Review key'), findsWidgets);
      expect(find.text('Revoke key'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: integration:write alone enters; API keys chrome omitted',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );
      expect(canEnterIntegrationsWorkspace(writeOnly), isTrue);
      expect(
        canViewIntegrationsSection(writeOnly, IntegrationDeskSection.apiKeys),
        isFalse,
      );

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: integrations-core missing omits API keys tab',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(IntegrationsApiKeysAtomPermissions.tab.isAllowed(noModule), isFalse);

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('API keys'), findsNothing);
      expect(find.text('Billing Export Key'), findsNothing);
      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'plan BASIC strips integrations-core: API keys absent despite grants',
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
      expect(IntegrationsApiKeysAtomPermissions.tab.isAllowed(basic), isFalse);
      expect(
        IntegrationsApiKeysAtomPermissions.create.isAllowed(basic),
        isFalse,
      );

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: basic,
      );

      expect(_tab('API keys'), findsNothing);
      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC: missing facility context still allows API keys read chrome '
    '(row/own scope remains backend-authoritative)',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
        facilityId: null,
      );
      expect(noFacility.hasFacilityContext, isFalse);
      expect(
        IntegrationsApiKeysAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        IntegrationsApiKeysAtomPermissions.create.isAllowed(noFacility),
        isFalse,
      );

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: noFacility,
      );

      expect(_tab('API keys'), findsOneWidget);
      expect(find.text('Billing Export Key'), findsWidgets);
      expect(find.text('Rotate or monitor'), findsWidgets);
      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix n/a: no foreign-module atoms on API keys',
    (WidgetTester tester) async {
      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
      );

      expect(find.textContaining('billing:'), findsNothing);
      expect(find.textContaining('clinical:'), findsNothing);
      expect(
        IntegrationsApiKeysAtomPermissions.nestedWrite,
        integrationsManageRequirement,
      );
    },
  );

  testWidgets('authorized empty API keys keeps chrome; no write affordances', (
    WidgetTester tester,
  ) async {
    await _pumpApiKeysTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      apiKeys: const <ApiKeyRecord>[],
      permissions: const <ApiKeyPermissionRecord>[],
    );

    expect(_tab('API keys'), findsOneWidget);
    expect(find.text('No integration items'), findsOneWidget);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byTooltip('Create API key'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets(
    'authorized error/retry surface remains observable on API keys',
    (WidgetTester tester) async {
      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        apiKeysOverride: const Result<List<ApiKeyRecord>>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'post-mutation sync: Disable API key updates list after confirm',
    (WidgetTester tester) async {
      const ApiKeyRecord disabled = ApiKeyRecord(
        id: 'api-key-1',
        name: 'Billing Export Key',
        userId: 'user-1',
        humanFriendlyId: 'key_billing',
      );
      when(() => repository.updateApiKey(any(), any())).thenAnswer(
        (_) async => const Result<ApiKeyRecord>.success(disabled),
      );

      await _pumpApiKeysTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
        apiKeys: const <ApiKeyRecord>[_apiKey],
      );

      await tester.tap(find.text('Billing Export Key'));
      await tester.pumpAndSettle();

      expect(find.text('Disable'), findsOneWidget);
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();

      final Finder confirm = find.widgetWithText(AppButton, 'Disable');
      expect(confirm, findsWidgets);
      await tester.tap(confirm.last);
      await tester.pumpAndSettle();

      verify(() => repository.updateApiKey('api-key-1', any())).called(1);
    },
  );

  testWidgets('mobile viewport keeps API keys chrome without clipping', (
    WidgetTester tester,
  ) async {
    await _pumpApiKeysTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(_tab('API keys'), findsOneWidget);
    expect(find.text('Billing Export Key'), findsWidgets);
    expect(find.text('Review key'), findsWidgets);
    expect(find.byTooltip('Create API key'), findsOneWidget);
  });

  testWidgets('desktop viewport: API keys columns and Create primary present', (
    WidgetTester tester,
  ) async {
    await _pumpApiKeysTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      ),
    );

    expect(_tab('API keys'), findsOneWidget);
    expect(find.byTooltip('Create API key'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Next action'),
      ),
      findsOneWidget,
    );
    expect(find.text('Billing Export Key'), findsWidgets);
  });

  testWidgets('light theme: API keys authorized chrome mounts', (
    WidgetTester tester,
  ) async {
    await _pumpApiKeysTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
    );

    expect(_tab('API keys'), findsOneWidget);
    expect(find.text('Billing Export Key'), findsOneWidget);
    expect(find.byTooltip('Create API key'), findsNothing);
  });

  testWidgets('dark theme keeps authorized API keys chrome', (
    WidgetTester tester,
  ) async {
    await _pumpApiKeysTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('API keys'), findsOneWidget);
    expect(find.text('Billing Export Key'), findsOneWidget);
    expect(find.byTooltip('Create API key'), findsNothing);
  });
}
