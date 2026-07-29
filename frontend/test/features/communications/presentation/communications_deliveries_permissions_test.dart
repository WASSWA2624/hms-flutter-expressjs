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

const NotificationDelivery _delivery = NotificationDelivery(
  id: 'delivery-1',
  status: 'FAILED',
  channel: 'EMAIL',
  notificationTitle: 'Critical lab result',
  recipientTarget: 'nurse@example.com',
  attemptCount: 2,
  errorMessage: 'Mailbox full',
  targetPath: '/patients/patient-1',
);

const NotificationDelivery _deliveryNoPath = NotificationDelivery(
  id: 'delivery-2',
  status: 'SENT',
  channel: 'SMS',
  notificationTitle: 'Appointment reminder',
  recipientTarget: '+256700000000',
  attemptCount: 1,
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
  List<NotificationDelivery> deliveries = const <NotificationDelivery>[
    _delivery,
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
          failedDeliveries: deliveries.length,
          templates: 0,
        ),
        metrics: NotificationMetrics(
          total: 0,
          unread: 0,
          attentionRequired: 0,
          failedDeliveries: deliveries.length,
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
          items: deliveries,
          request: query.pageRequest,
          totalItemCount: deliveries.length,
        ),
        templates: AppPage<CommunicationTemplate>(
          items: const <CommunicationTemplate>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
        selectedDelivery: query.panel == CommunicationsPanel.deliveries
            ? deliveries.firstOrNull
            : null,
      ),
    );
  });
}

Future<void> _pumpDeliveriesTab(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<NotificationDelivery> deliveries = const <NotificationDelivery>[
    _delivery,
  ],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    deliveries: deliveries,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/communications?panel=deliveries',
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
      GoRoute(
        path: '/patients/:id',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Patient detail'));
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
    '∩ denial: missing communications:read omits Deliveries tab and list',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.listChrome.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(_tab('Deliveries'), findsNothing);
      expect(find.text('Critical lab result'), findsNothing);
      expect(find.text('View error'), findsNothing);
      expect(find.byTooltip('Filters'), findsNothing);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full ∩ read: Deliveries list, chrome, next action, and detail mount',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.detail.isAllowed(reader),
        isTrue,
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );

      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Deliveries'), findsOneWidget);
      expect(find.text('Critical lab result'), findsWidgets);
      expect(find.text('nurse@example.com'), findsWidgets);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Open linked record'), findsWidgets);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Open linked record').first);
      await tester.pumpAndSettle();

      // Next-action with path navigates away (read navigate atom).
      expect(find.text('Patient detail'), findsOneWidget);
    },
  );

  testWidgets(
    'full ∩ read: row select opens delivery detail without write/delete chrome',
    (WidgetTester tester) async {
      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        deliveries: const <NotificationDelivery>[_deliveryNoPath],
      );

      await tester.tap(find.text('View delivery').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('DELIVERY DETAIL'), findsOneWidget);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Open linked record'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: communications:write alone enters; Deliveries chrome omitted',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      expect(canEnterCommunications(writeOnly), isTrue);
      expect(canViewCommunicationsPanel(
        writeOnly,
        CommunicationsPanel.deliveries,
      ), isFalse);

      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Critical lab result'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: communications:read alone shows Deliveries atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.routeEntry.isAllowed(reader),
        isTrue,
      );

      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Deliveries'), findsOneWidget);
      expect(find.text('Critical lab result'), findsWidgets);
      expect(find.text('Open linked record'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module _(n/a)_: write/delete rights do not mount mutations on Deliveries',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.write.isAllowed(full),
        isTrue,
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.delete.isAllowed(full),
        isTrue,
      );
      // Nested matrix rows are n/a — same-module write must not invent Deliveries
      // mutation chrome; nestedRead still tracks list/detail read.
      expect(
        CommunicationsDeliveriesAtomPermissions.nestedRead.isAllowed(full),
        isTrue,
      );

      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Archive'), findsNothing);

      await tester.tap(find.text('Open linked record').first);
      await tester.pumpAndSettle();

      expect(find.text('Patient detail'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: notifications-communications missing omits Deliveries',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        CommunicationsDeliveriesAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );

      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('Deliveries'), findsNothing);
      expect(find.text('Critical lab result'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty Deliveries keeps chrome; no write affordances',
    (WidgetTester tester) async {
      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        deliveries: const <NotificationDelivery>[],
      );

      expect(_tab('Deliveries'), findsOneWidget);
      expect(find.text('No deliveries'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Deliveries',
    (WidgetTester tester) async {
      await _pumpDeliveriesTab(
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

  testWidgets('authorized loading then success on Deliveries', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.getWorkspace(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<CommunicationsWorkspaceState>.success(
        CommunicationsWorkspaceState(
          query: const CommunicationsWorkspaceQuery(
            panel: CommunicationsPanel.deliveries,
          ),
          summary: const CommunicationsSummary(failedDeliveries: 1),
          metrics: const NotificationMetrics(failedDeliveries: 1),
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
            items: <NotificationDelivery>[_delivery],
            request: AppPageRequest(pageSize: 30),
            totalItemCount: 1,
          ),
          templates: const AppPage<CommunicationTemplate>(
            items: <CommunicationTemplate>[],
            request: AppPageRequest(pageSize: 30),
            totalItemCount: 0,
          ),
        ),
      );
    });

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/communications?panel=deliveries',
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

    expect(find.text('Critical lab result'), findsWidgets);
    expect(find.text('Loading communications'), findsNothing);
  });

  testWidgets(
    'authorized detail Open linked navigates; read-only sync via search refresh',
    (WidgetTester tester) async {
      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
      );

      clearInteractions(repository);
      await tester.enterText(
        find.byType(TextField).first,
        'Critical',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      verify(() => repository.getWorkspace(any())).called(greaterThan(0));

      await tester.tap(find.text('Open linked record').first);
      await tester.pumpAndSettle();

      expect(find.text('Patient detail'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'delivery without path shows View delivery next-action; detail mounts',
    (WidgetTester tester) async {
      await _pumpDeliveriesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        deliveries: const <NotificationDelivery>[_deliveryNoPath],
      );

      expect(find.text('View delivery'), findsWidgets);
      expect(find.text('Open linked record'), findsNothing);

      await tester.tap(find.text('View delivery').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('DELIVERY DETAIL'), findsOneWidget);
      expect(find.text('Open linked record'), findsNothing);
    },
  );

  testWidgets('Deliveries mobile viewport keeps read chrome accessible', (
    WidgetTester tester,
  ) async {
    await _pumpDeliveriesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('Deliveries'), findsOneWidget);
    expect(find.textContaining('Critical lab'), findsWidgets);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byTooltip('New message'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('Deliveries desktop dark theme keeps authorized atoms', (
    WidgetTester tester,
  ) async {
    await _pumpDeliveriesTab(
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

    expect(_tab('Deliveries'), findsOneWidget);
    expect(find.text('Critical lab result'), findsWidgets);
    expect(find.text('Open linked record'), findsWidgets);
    expect(find.byTooltip('New message'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('Deliveries light theme ∩ read presents list chrome', (
    WidgetTester tester,
  ) async {
    await _pumpDeliveriesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.text('Critical lab result'), findsWidgets);
  });

  test(
    'atom map reuses feature *Requirement helpers (no second vocabulary)',
    () {
      expect(
        identical(
          CommunicationsDeliveriesAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsDeliveriesAtomPermissions.create,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsDeliveriesAtomPermissions.delete,
          communicationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsDeliveriesAtomPermissions.routeEntry,
          communicationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(identical(communicationsActiveModule, communicationsModule), isTrue);
    },
  );
}
