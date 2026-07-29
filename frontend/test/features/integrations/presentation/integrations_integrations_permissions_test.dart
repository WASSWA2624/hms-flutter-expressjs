import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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

AppAccessPolicy _policy({
  Set<AppPermission>? permissions,
  bool includeModule = true,
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
  List<String> roles = const <String>['INTEGRATION_ADMIN'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        tenantId: tenantId,
        facilityId: facilityId,
        roles: roles,
      ),
      permissions: permissions ??
          <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
            AppPermissions.integrationDelete,
          },
      moduleEntitlements: includeModule
          ? const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'integrations-core',
                licenseStatus: 'ACTIVE',
              ),
            ]
          : const <AppModuleEntitlement>[],
    ),
  );
}

void _stubWorkspace(_MockIntegrationsRepository repository) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async =>
        const Result<List<IntegrationRecord>>.success(<IntegrationRecord>[
          _integration,
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
  when(() => repository.syncNow(any(), any())).thenAnswer(
    (_) async => const Result<IntegrationActionResult>.success(
      IntegrationActionResult(title: 'Sync', status: 'QUEUED'),
    ),
  );
  when(() => repository.testConnection(any(), any())).thenAnswer(
    (_) async => const Result<IntegrationActionResult>.success(
      IntegrationActionResult(title: 'Test', status: 'OK'),
    ),
  );
  when(() => repository.updateIntegration(any(), any())).thenAnswer(
    (_) async => const Result<IntegrationRecord>.success(_integration),
  );
}

Future<void> _pumpIntegrationsTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/integrations?section=integrations',
  bool emptyIntegrations = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository);
  if (emptyIntegrations) {
    when(() => repository.listIntegrations()).thenAnswer(
      (_) async => const Result<List<IntegrationRecord>>.success(
        <IntegrationRecord>[],
      ),
    );
  }

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

  setUp(() {
    repository = _MockIntegrationsRepository();
    registerFallbackValue(<String, Object?>{});
  });

  group('IntegrationsIntegrationsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.tab,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.create,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.update,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.writeNextAction,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.delete,
          integrationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.routeEntry,
          integrationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.nestedRead,
          integrationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsIntegrationsAtomPermissions.nestedWrite,
          integrationsWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          integrationsSectionTabRequirement(IntegrationDeskSection.integrations),
          IntegrationsIntegrationsAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('∩ denial: missing integration:write denies create/update manage ∪', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.writeNextAction.isAllowed(
          reader,
        ),
        isFalse,
      );
      expect(canManageIntegrations(reader), isFalse);
    });

    test('∩ denial: missing integration:delete denies delete requirement', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(canDeleteIntegrations(writer), isFalse);
    });

    test('∪ allowance: route entry via write alone; tab read ∩ fails', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(canEnterIntegrationsWorkspace(writeOnly), isTrue);
      expect(canReadIntegrations(writeOnly), isFalse);
    });

    test('∪ allowance: tenant admin satisfies manage without integration:write', () {
      final AppAccessPolicy admin = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.tenantAdmin,
        },
      );
      // Source manage ∪ maps matrix ∩ write — admin any-of qualifies.
      expect(
        IntegrationsIntegrationsAtomPermissions.create.isAllowed(admin),
        isTrue,
      );
      expect(canManageIntegrations(admin), isTrue);
    });

    test('subscription strip: module absent denies all atoms', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
          AppPermissions.integrationDelete,
        },
        includeModule: false,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.create.isAllowed(noModule),
        isFalse,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.routeEntry.isAllowed(noModule),
        isFalse,
      );
    });

    test('nested cross-module matrix rows are n/a (same as workspace gates)', () {
      final AppAccessPolicy full = _policy();
      expect(
        IntegrationsIntegrationsAtomPermissions.nestedRead.isAllowed(full),
        isTrue,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.nestedWrite.isAllowed(full),
        isTrue,
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
    });

    test('full intersection set allows read + manage + delete atoms', () {
      final AppAccessPolicy full = _policy();
      expect(
        IntegrationsIntegrationsAtomPermissions.tab.isAllowed(full),
        isTrue,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.listChrome.isAllowed(full),
        isTrue,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.create.isAllowed(full),
        isTrue,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.configure.isAllowed(full),
        isTrue,
      );
      expect(
        IntegrationsIntegrationsAtomPermissions.delete.isAllowed(full),
        isTrue,
      );
    });
  });

  group('Integrations tab widget authorization', () {
    testWidgets(
      '∩ denial: read-only omits Create and write next-actions; list remains',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.integrationRead},
          ),
        );

        expect(_tab('Integrations'), findsOneWidget);
        expect(find.text('Lab HL7 Feed'), findsOneWidget);
        expect(find.byTooltip('Create integration'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Monitor'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'full manage ∩ presents Create and write next-action Monitor',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.integrationRead,
              AppPermissions.integrationWrite,
            },
          ),
        );

        expect(find.byTooltip('Create integration'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Monitor'), findsWidgets);
      },
    );

    testWidgets(
      '∪ allowance: tenant admin sees Create without integration:write string',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.integrationRead,
              AppPermissions.tenantAdmin,
            },
          ),
        );

        expect(find.byTooltip('Create integration'), findsOneWidget);
        expect(find.text('Lab HL7 Feed'), findsOneWidget);
      },
    );

    testWidgets(
      'authorized detail keeps Configure / Test / Disable; omits Sync when Monitor is next-action',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(),
        );

        await tester.tap(find.text('Lab HL7 Feed'));
        await tester.pumpAndSettle();

        expect(find.text('Configure'), findsOneWidget);
        expect(find.text('Test connection'), findsOneWidget);
        expect(find.text('Sync now'), findsNothing);
        expect(find.text('Disable'), findsOneWidget);
      },
    );

    testWidgets(
      'read-only detail omits Configure / Test / Sync / Enable·Disable',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.integrationRead},
          ),
        );

        await tester.tap(find.text('Lab HL7 Feed'));
        await tester.pumpAndSettle();

        expect(find.text('Configure'), findsNothing);
        expect(find.text('Test connection'), findsNothing);
        expect(find.text('Sync now'), findsNothing);
        expect(find.text('Disable'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'authorized Monitor next-action opens sync confirm (post-mutation path)',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.integrationRead,
              AppPermissions.integrationWrite,
            },
          ),
        );

        final Finder monitor = find.widgetWithText(AppButton, 'Monitor');
        expect(monitor, findsWidgets);
        await tester.ensureVisible(monitor.first);
        await tester.pumpAndSettle();
        await tester.tap(monitor.first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Sync now'), findsWidgets);
        expect(
          find.text(
            'The system will enqueue an immediate integration sync.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(AppButton, 'Sync now').last);
        await tester.pumpAndSettle();

        verify(() => repository.syncNow(any(), any())).called(1);
      },
    );

    testWidgets('authorized empty / loading chrome remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        emptyIntegrations: true,
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No integration items'), findsOneWidget);
    });

    testWidgets('mobile viewport keeps strip and omits create for read-only', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        physicalSize: const Size(720, 900),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_tab('Integrations'), findsOneWidget);
      expect(find.text('Lab HL7 Feed'), findsOneWidget);
      expect(find.byTooltip('Create integration'), findsNothing);
    });

    testWidgets('desktop + dark theme authorized create remains present', (
      WidgetTester tester,
    ) async {
      await _pumpIntegrationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.integrationRead,
            AppPermissions.integrationWrite,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Create integration'), findsOneWidget);
      expect(find.text('Lab HL7 Feed'), findsOneWidget);
    });

    testWidgets(
      'module strip collapses workspace chrome (no routine no-access banner)',
      (WidgetTester tester) async {
        await _pumpIntegrationsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.integrationRead,
              AppPermissions.integrationWrite,
            },
            includeModule: false,
          ),
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.byTooltip('Create integration'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );
  });
}
