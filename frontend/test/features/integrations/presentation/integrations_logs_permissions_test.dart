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

const IntegrationLogRecord _healthyLog = IntegrationLogRecord(
  id: 'log-1',
  integrationLabel: 'Lab HL7 Feed',
  integrationType: 'HL7',
  status: 'SUCCESS',
  message: 'Message accepted',
);

const IntegrationLogRecord _attentionLog = IntegrationLogRecord(
  id: 'log-2',
  integrationLabel: 'Failed Delivery',
  integrationType: 'FHIR',
  status: 'FAILED',
  message: 'Delivery timed out',
  requiresAttention: true,
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
  List<String> roles = const <String>['NURSE'],
  bool isAuthorizationHydrated = true,
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
      isAuthorizationHydrated: isAuthorizationHydrated,
    ),
  );
}

void _stubWorkspace(
  _MockIntegrationsRepository repository, {
  List<IntegrationLogRecord> logs = const <IntegrationLogRecord>[_healthyLog],
}) {
  when(() => repository.listIntegrations()).thenAnswer(
    (_) async =>
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
    (_) async => Result<List<IntegrationLogRecord>>.success(logs),
  );
  when(() => repository.getLog(any())).thenAnswer((Invocation invocation) async {
    final String id = invocation.positionalArguments.first as String;
    final IntegrationLogRecord match = logs.firstWhere(
      (IntegrationLogRecord log) => log.id == id,
      orElse: () => logs.isEmpty ? _healthyLog : logs.first,
    );
    return Result<IntegrationLogRecord>.success(match);
  });
  when(
    () => repository.interopCapabilities(),
  ).thenReturn(const <InteropCapabilityStatus>[]);
}

Future<void> _pumpLogsTab(
  WidgetTester tester, {
  required _MockIntegrationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IntegrationLogRecord> logs = const <IntegrationLogRecord>[_healthyLog],
  String initialLocation = '/integrations?section=logs',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, logs: logs);

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

  testWidgets(
    '∩ denial: missing integration:read omits Logs tab and list',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.integrationWrite},
      );
      // Route entry ∪ allows write alone; tab read ∩ does not.
      expect(
        IntegrationsLogsAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(IntegrationsLogsAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        IntegrationsLogsAtomPermissions.listChrome.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(_tab('Logs'), findsNothing);
      expect(find.text('Message accepted'), findsNothing);
      expect(find.text('Replay or escalate'), findsNothing);
      expect(find.byTooltip('Filters'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full ∩ read: Logs list, chrome, next action Review, and detail mount',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(IntegrationsLogsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(IntegrationsLogsAtomPermissions.detail.isAllowed(reader), isTrue);
      expect(IntegrationsLogsAtomPermissions.replay.isAllowed(reader), isFalse);
      expect(IntegrationsLogsAtomPermissions.delete.isAllowed(reader), isFalse);
      // Matrix create ∩ write maps to source manage ∪ — reader lacks both.
      expect(IntegrationsLogsAtomPermissions.create.isAllowed(reader), isFalse);

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Logs'), findsOneWidget);
      expect(find.text('Lab HL7 Feed'), findsWidgets);
      expect(find.text('Message accepted'), findsWidgets);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Review'), findsWidgets);
      expect(find.text('Replay or escalate'), findsNothing);
      expect(find.text('Replay log'), findsNothing);
      expect(find.byTooltip('Create integration'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Sanitized log message'), findsWidgets);
      expect(find.text('Message accepted'), findsWidgets);
      expect(find.text('Replay log'), findsNothing);
      expect(find.text('Close'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'manage ∪ (source write|admin): Replay next-action and detail Replay mount',
    (WidgetTester tester) async {
      final AppAccessPolicy manager = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
      );
      expect(IntegrationsLogsAtomPermissions.replay.isAllowed(manager), isTrue);
      expect(integrationsManageRequirement.isAllowed(manager), isTrue);

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: manager,
        logs: const <IntegrationLogRecord>[_attentionLog, _healthyLog],
      );

      expect(find.text('Failed Delivery'), findsWidgets);
      expect(find.text('Replay or escalate'), findsWidgets);
      expect(find.byTooltip('Create integration'), findsNothing);

      // Attention row: write next-action mounts Replay confirm entry.
      await tester.ensureVisible(find.text('Replay or escalate').first);
      await tester.tap(find.text('Replay or escalate').first);
      await tester.pumpAndSettle();

      expect(find.text('REPLAY LOG?'), findsWidgets);
      expect(find.text('Replay log'), findsWidgets);

      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();

      // Healthy row detail still exposes Replay when not the next-action.
      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();

      expect(find.text('Sanitized log message'), findsWidgets);
      expect(find.text('Replay log'), findsWidgets);
    },
  );

  testWidgets(
    'route entry ∪: tenantAdmin alone enters; Logs chrome omitted without read ∩',
    (WidgetTester tester) async {
      final AppAccessPolicy adminOnly = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
        roles: const <String>['TENANT_ADMIN'],
      );
      expect(canEnterIntegrations(adminOnly), isTrue);
      expect(IntegrationsLogsAtomPermissions.tab.isAllowed(adminOnly), isFalse);
      // Manage ∪ allows admin without explicit write — mapping noted vs matrix ∩.
      expect(
        IntegrationsLogsAtomPermissions.replay.isAllowed(adminOnly),
        isTrue,
      );

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: adminOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Message accepted'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: integration:read alone shows Logs atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      );
      expect(
        IntegrationsLogsAtomPermissions.routeEntry.isAllowed(reader),
        isTrue,
      );

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Logs'), findsOneWidget);
      expect(find.text('Lab HL7 Feed'), findsWidgets);
      expect(find.text('Review'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module _(n/a)_: write/delete rights do not invent Logs mutations beyond Replay',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
          AppPermissions.integrationDelete,
        },
      );
      expect(IntegrationsLogsAtomPermissions.write.isAllowed(full), isTrue);
      expect(IntegrationsLogsAtomPermissions.delete.isAllowed(full), isTrue);
      expect(IntegrationsLogsAtomPermissions.nestedRead.isAllowed(full), isTrue);

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      expect(find.byTooltip('Create integration'), findsNothing);
      expect(find.byTooltip('Create API key'), findsNothing);
      expect(find.byTooltip('Create webhook'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Revoke'), findsNothing);

      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();

      expect(find.text('Sanitized log message'), findsWidgets);
      expect(find.text('Replay log'), findsWidgets);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: integrations-core missing omits Logs',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.integrationRead,
          AppPermissions.integrationWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(IntegrationsLogsAtomPermissions.tab.isAllowed(noModule), isFalse);

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('Logs'), findsNothing);
      expect(find.text('Message accepted'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: EXPIRED integrations-core omits Logs',
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
      expect(IntegrationsLogsAtomPermissions.tab.isAllowed(expired), isFalse);

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: expired,
      );

      expect(_tab('Logs'), findsNothing);
      expect(find.text('Message accepted'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'plan BASIC strips integration rights; Logs chrome omitted',
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
      expect(IntegrationsLogsAtomPermissions.tab.isAllowed(basic), isFalse);
      expect(IntegrationsLogsAtomPermissions.replay.isAllowed(basic), isFalse);

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: basic,
      );

      expect(_tab('Logs'), findsNothing);
      expect(find.text('Message accepted'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC: missing facility context still allows Logs read chrome '
    '(row/own scope remains backend-authoritative)',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
        facilityId: null,
      );
      expect(noFacility.hasFacilityContext, isFalse);
      expect(IntegrationsLogsAtomPermissions.tab.isAllowed(noFacility), isTrue);

      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: noFacility,
      );

      expect(_tab('Logs'), findsOneWidget);
      expect(find.text('Lab HL7 Feed'), findsWidgets);
      expect(find.text('Replay log'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Replay syncs list after mutation success',
    (WidgetTester tester) async {
      when(
        () => repository.replayLog(any(), any()),
      ).thenAnswer((_) async {
        return const Result<IntegrationActionResult>.success(
          IntegrationActionResult(
            title: 'Replay',
            status: 'SUCCESS',
            message: 'Replayed',
          ),
        );
      });

      var listCalls = 0;
      when(() => repository.listLogs()).thenAnswer((_) async {
        listCalls += 1;
        return Result<List<IntegrationLogRecord>>.success(
          listCalls <= 1
              ? const <IntegrationLogRecord>[_attentionLog]
              : const <IntegrationLogRecord>[
                  _attentionLog,
                  IntegrationLogRecord(
                    id: 'log-replayed',
                    integrationLabel: 'Failed Delivery',
                    status: 'SUCCESS',
                    message: 'Replayed copy',
                  ),
                ],
        );
      });
      when(() => repository.getLog(any())).thenAnswer((_) async {
        return const Result<IntegrationLogRecord>.success(_attentionLog);
      });
      when(() => repository.listIntegrations()).thenAnswer(
        (_) async => const Result<List<IntegrationRecord>>.success(
          <IntegrationRecord>[],
        ),
      );
      when(() => repository.listApiKeys()).thenAnswer(
        (_) async =>
            const Result<List<ApiKeyRecord>>.success(<ApiKeyRecord>[]),
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
      when(
        () => repository.interopCapabilities(),
      ).thenReturn(const <InteropCapabilityStatus>[]);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/integrations?section=logs',
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
                permissions: <AppPermission>{
                  AppPermissions.integrationRead,
                  AppPermissions.integrationWrite,
                },
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
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Replay or escalate'), findsWidgets);
      await tester.tap(find.text('Replay or escalate').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay log').last);
      await tester.pumpAndSettle();

      verify(() => repository.replayLog('log-2', any())).called(1);
      expect(listCalls, greaterThan(1));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty state remains observable on Logs', (
    WidgetTester tester,
  ) async {
    await _pumpLogsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      logs: const <IntegrationLogRecord>[],
    );

    expect(_tab('Logs'), findsOneWidget);
    expect(find.text('No integration items'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('authorized error/retry remains observable on Logs load failure', (
    WidgetTester tester,
  ) async {
    when(() => repository.listIntegrations()).thenAnswer(
      (_) async =>
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
      (_) async => const Result<List<IntegrationLogRecord>>.failure(
        AppFailure.network(),
      ),
    );
    when(
      () => repository.interopCapabilities(),
    ).thenReturn(const <InteropCapabilityStatus>[]);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: IntegrationsWorkspacePage(
              initialQuery: IntegrationWorkspaceQuery(
                filter: IntegrationWorkspaceFilter.logs,
              ),
            ),
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Try again'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('Logs mobile viewport keeps read chrome accessible', (
    WidgetTester tester,
  ) async {
    await _pumpLogsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('Logs'), findsOneWidget);
    expect(find.text('Lab HL7 Feed'), findsWidgets);
    expect(find.text('Review'), findsWidgets);
    expect(find.byTooltip('Filters'), findsOneWidget);
  });

  testWidgets(
    'Logs mobile: Review opens detail; Replay absent for read-only',
    (WidgetTester tester) async {
      await _pumpLogsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.integrationRead},
        ),
        physicalSize: const Size(390, 844),
        logs: const <IntegrationLogRecord>[_attentionLog],
      );

      expect(find.text('Replay or escalate'), findsNothing);
      expect(find.text('Review'), findsWidgets);

      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Sanitized log message'), findsOneWidget);
      expect(find.text('Replay log'), findsNothing);
    },
  );

  testWidgets('Logs desktop dark theme keeps authorized atoms', (
    WidgetTester tester,
  ) async {
    await _pumpLogsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Logs'), findsOneWidget);
    expect(find.text('Lab HL7 Feed'), findsWidgets);
    expect(find.text('Review'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('Logs light theme ∩ read presents list chrome', (
    WidgetTester tester,
  ) async {
    await _pumpLogsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.integrationRead},
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Message accepted'), findsWidgets);
  });

  test(
    'reuse: Logs atom map uses shared *Requirement helpers (no second vocabulary)',
    () {
      expect(
        identical(
          IntegrationsLogsAtomPermissions.tab,
          integrationsReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsLogsAtomPermissions.replay,
          integrationsManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsLogsAtomPermissions.delete,
          integrationsDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          IntegrationsLogsAtomPermissions.routeEntry,
          integrationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    },
  );
}
