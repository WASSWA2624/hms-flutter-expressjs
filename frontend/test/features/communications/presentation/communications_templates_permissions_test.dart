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
import 'package:hosspi_hms/features/communications/data/repositories/communications_repository_impl.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/domain/repositories/communications_repository.dart';
import 'package:hosspi_hms/features/communications/presentation/communications_access.dart';
import 'package:hosspi_hms/features/communications/presentation/pages/communications_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCommunicationsRepository extends Mock
    implements CommunicationsRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

const CommunicationTemplate _template = CommunicationTemplate(
  id: 'template-1',
  name: 'Discharge summary',
  channel: 'EMAIL',
  subject: 'Your discharge summary',
  description: 'Patient discharge template',
  body: 'Hello {{patientName}}, your discharge is ready.',
  previewSubject: 'Your discharge summary',
  previewBody: 'Hello Jane Doe, your discharge is ready.',
  variableCount: 3,
  isActive: true,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: communicationsActiveModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['NURSE'],
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
  _MockCommunicationsRepository repository, {
  List<CommunicationTemplate> templates = const <CommunicationTemplate>[
    _template,
  ],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (workspaceOverride != null) {
      return workspaceOverride;
    }
    final CommunicationsWorkspaceQuery query =
        invocation.positionalArguments.single as CommunicationsWorkspaceQuery;
    return Result<CommunicationsWorkspaceState>.success(
      CommunicationsWorkspaceState(
        query: query,
        summary: CommunicationsSummary(
          unreadThreads: 0,
          notifications: 0,
          failedDeliveries: 0,
          templates: templates.length,
        ),
        metrics: const NotificationMetrics(
          total: 0,
          unread: 0,
          attentionRequired: 0,
          failedDeliveries: 0,
        ),
        conversations: AppPage<CommunicationsConversation>(
          items: const <CommunicationsConversation>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        notifications: AppPage<NotificationItem>(
          items: const <NotificationItem>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        deliveries: AppPage<NotificationDelivery>(
          items: const <NotificationDelivery>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        templates: AppPage<CommunicationTemplate>(
          items: templates,
          request: query.pageRequest,
          totalItemCount: templates.length,
        ),
        selectedTemplate: query.panel == CommunicationsPanel.templates
            ? templates.firstOrNull
            : null,
      ),
    );
  });
}

Future<void> _pumpTemplatesTab(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<CommunicationTemplate> templates = const <CommunicationTemplate>[
    _template,
  ],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
  String initialLocation = '/communications?panel=templates',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    templates: templates,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/communications',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: CommunicationsWorkspacePage(
              initialQuery: CommunicationsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communicationsRepositoryProvider.overrideWithValue(repository),
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
  late _MockCommunicationsRepository repository;

  setUpAll(() {
    registerFallbackValue(const CommunicationsWorkspaceQuery());
  });

  setUp(() {
    repository = _MockCommunicationsRepository();
  });

  testWidgets(
    '∩ denial: missing communications:read omits Templates tab and list',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      expect(
        CommunicationsTemplatesAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.listChrome.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(_tab('Templates'), findsNothing);
      expect(find.text('Discharge summary'), findsNothing);
      expect(find.byTooltip('Filters'), findsNothing);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full ∩ read: Templates list, chrome, and detail preview mount',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      expect(
        CommunicationsTemplatesAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.detail.isAllowed(reader),
        isTrue,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );

      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Templates'), findsOneWidget);
      expect(find.text('Discharge summary'), findsWidgets);
      expect(find.text('Patient discharge template'), findsWidgets);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('TEMPLATE DETAIL'), findsAtLeastNWidgets(1));
      expect(find.text('Hello Jane Doe, your discharge is ready.'), findsOneWidget);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∩ write without delete: Templates remain preview-only (no mutation chrome)',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      );
      expect(
        CommunicationsTemplatesAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );

      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      // New message/group are Messages-tab only — absent on Templates.
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Delete'), findsNothing);

      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();

      expect(find.text('TEMPLATE DETAIL'), findsAtLeastNWidgets(1));
      expect(find.text('Create'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: communications:write alone enters; Templates chrome omitted',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      expect(canEnterCommunications(writeOnly), isTrue);
      expect(
        canViewCommunicationsPanel(writeOnly, CommunicationsPanel.templates),
        isFalse,
      );

      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Discharge summary'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: communications:read alone shows Templates atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      expect(
        CommunicationsTemplatesAtomPermissions.routeEntry.isAllowed(reader),
        isTrue,
      );

      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Templates'), findsOneWidget);
      expect(find.text('Discharge summary'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module _(n/a)_: write/delete rights do not invent Templates mutations',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
      );
      expect(
        CommunicationsTemplatesAtomPermissions.write.isAllowed(full),
        isTrue,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.delete.isAllowed(full),
        isTrue,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.nestedRead.isAllowed(full),
        isTrue,
      );

      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.text('Create'), findsNothing);
      expect(find.text('Delete'), findsNothing);

      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();

      expect(find.text('TEMPLATE DETAIL'), findsAtLeastNWidgets(1));
      expect(find.text('Create'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: notifications-communications missing omits Templates',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        CommunicationsTemplatesAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );

      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('Templates'), findsNothing);
      expect(find.text('Discharge summary'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'plan BASIC strips delete ∩ even when role grants communications:delete',
    (WidgetTester tester) async {
      final AppAccessPolicy basic = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: communicationsActiveModule,
            licenseStatus: 'ACTIVE',
            planTierCode: 'BASIC',
          ),
        ],
      );
      expect(
        CommunicationsTemplatesAtomPermissions.tab.isAllowed(basic),
        isTrue,
      );
      expect(
        CommunicationsTemplatesAtomPermissions.delete.isAllowed(basic),
        isFalse,
      );

      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: basic,
      );

      expect(_tab('Templates'), findsOneWidget);
      expect(find.text('Discharge summary'), findsWidgets);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty Templates keeps chrome; no write affordances',
    (WidgetTester tester) async {
      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        templates: const <CommunicationTemplate>[],
      );

      expect(_tab('Templates'), findsOneWidget);
      expect(find.text('No templates'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Templates',
    (WidgetTester tester) async {
      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        workspaceOverride: const Result<CommunicationsWorkspaceState>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized loading then success on Templates', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.getWorkspace(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<CommunicationsWorkspaceState>.success(
        CommunicationsWorkspaceState(
          query: const CommunicationsWorkspaceQuery(
            panel: CommunicationsPanel.templates,
          ),
          summary: const CommunicationsSummary(templates: 1),
          metrics: const NotificationMetrics(),
          conversations: const AppPage<CommunicationsConversation>(
            items: <CommunicationsConversation>[],
            request: AppPageRequest(pageSize: 30),
            totalItemCount: 0,
          ),
          notifications: const AppPage<NotificationItem>(
            items: <NotificationItem>[],
            request: AppPageRequest(pageSize: 30),
            totalItemCount: 0,
          ),
          deliveries: const AppPage<NotificationDelivery>(
            items: <NotificationDelivery>[],
            request: AppPageRequest(pageSize: 30),
            totalItemCount: 0,
          ),
          templates: const AppPage<CommunicationTemplate>(
            items: <CommunicationTemplate>[_template],
            request: AppPageRequest(pageSize: 30),
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
      initialLocation: '/communications?panel=templates',
      routes: <RouteBase>[
        GoRoute(
          path: '/communications',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: CommunicationsWorkspacePage(
                initialQuery: CommunicationsWorkspaceQuery.fromUri(state.uri),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communicationsRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{AppPermissions.communicationsRead},
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
    expect(find.text('Loading communications'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(find.text('Discharge summary'), findsWidgets);
    expect(find.text('Loading communications'), findsNothing);
  });

  testWidgets(
    'authorized detail opens; list sync via search refresh',
    (WidgetTester tester) async {
      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
      );

      clearInteractions(repository);
      await tester.enterText(find.byType(TextField).first, 'Discharge');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      verify(() => repository.getWorkspace(any())).called(greaterThan(0));

      await tester.tap(find.text('Discharge summary').first);
      await tester.pumpAndSettle();

      expect(find.text('TEMPLATE DETAIL'), findsAtLeastNWidgets(1));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'deep link templateId opens detail when read ∩ allowed',
    (WidgetTester tester) async {
      await _pumpTemplatesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        initialLocation:
            '/communications?panel=templates&templateId=template-1',
      );

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('TEMPLATE DETAIL'), findsAtLeastNWidgets(1));
      expect(find.text('Hello Jane Doe, your discharge is ready.'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    },
  );

  testWidgets('Templates mobile viewport keeps read chrome accessible', (
    WidgetTester tester,
  ) async {
    await _pumpTemplatesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('Templates'), findsOneWidget);
    expect(find.textContaining('Discharge'), findsWidgets);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byTooltip('New message'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('Templates desktop dark theme keeps authorized atoms', (
    WidgetTester tester,
  ) async {
    await _pumpTemplatesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Templates'), findsOneWidget);
    expect(find.text('Discharge summary'), findsWidgets);
    expect(find.byTooltip('New message'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('Templates light theme ∩ read presents list chrome', (
    WidgetTester tester,
  ) async {
    await _pumpTemplatesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.text('Discharge summary'), findsWidgets);
  });

  test(
    'atom map reuses feature *Requirement helpers (no second vocabulary)',
    () {
      expect(
        identical(
          CommunicationsTemplatesAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsTemplatesAtomPermissions.create,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsTemplatesAtomPermissions.update,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsTemplatesAtomPermissions.delete,
          communicationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsTemplatesAtomPermissions.routeEntry,
          communicationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(communicationsActiveModule, communicationsModule),
        isTrue,
      );
    },
  );
}
