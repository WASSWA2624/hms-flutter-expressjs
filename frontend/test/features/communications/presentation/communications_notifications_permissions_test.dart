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

Finder _tableRowInkWell() => find.byWidgetPredicate(
  (Widget widget) => widget.runtimeType.toString() == 'TableRowInkWell',
);

const NotificationItem _notification = NotificationItem(
  id: 'notification-1',
  title: 'Critical lab result',
  message: 'Potassium critically high',
  priority: 'HIGH',
  notificationType: 'LAB_ALERT',
  targetPath: '/patients/patient-1',
);

final NotificationItem _readNotification = NotificationItem(
  id: 'notification-1',
  title: 'Critical lab result',
  message: 'Potassium critically high',
  priority: 'HIGH',
  notificationType: 'LAB_ALERT',
  readAt: DateTime.utc(2026, 5, 20, 9),
  targetPath: '/patients/patient-1',
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
  List<NotificationItem> notifications = const <NotificationItem>[
    _notification,
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
          notifications: notifications.length,
        ),
        metrics: NotificationMetrics(total: notifications.length),
        conversations: const AppPage<CommunicationsConversation>(
          items: <CommunicationsConversation>[],
          request: AppPageRequest(pageSize: 30),
          totalItemCount: 0,
        ),
        notifications: AppPage<NotificationItem>(
          items: notifications,
          request: query.pageRequest,
          totalItemCount: notifications.length,
        ),
        deliveries: const AppPage<NotificationDelivery>(
          items: <NotificationDelivery>[],
          request: AppPageRequest(pageSize: 30),
          totalItemCount: 0,
        ),
        templates: const AppPage<CommunicationTemplate>(
          items: <CommunicationTemplate>[],
          request: AppPageRequest(pageSize: 30),
          totalItemCount: 0,
        ),
        selectedNotification:
            query.panel == CommunicationsPanel.notifications &&
                query.notificationId != null
            ? notifications.cast<NotificationItem?>().firstWhere(
                (NotificationItem? item) => item?.id == query.notificationId,
                orElse: () => null,
              )
            : null,
      ),
    );
  });
}

Future<void> _pumpNotificationsTab(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<NotificationItem> notifications = const <NotificationItem>[
    _notification,
  ],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    notifications: notifications,
    workspaceOverride: workspaceOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/communications?panel=notifications',
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

  group('CommunicationsNotificationsAtomPermissions helpers', () {
    test('reuses AccessRequirement vocabulary (no second map)', () {
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.markRead,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.archive,
          communicationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.routeEntry,
          communicationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      // Nested cross-module matrix rows are _(n/a)_ — nested gates stay in-module.
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.nestedRead,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.nestedWrite,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
    });

    test('∩ denial: write without delete denies archive', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      );
      expect(
        CommunicationsNotificationsAtomPermissions.archive.isAllowed(writer),
        isFalse,
      );
      expect(
        CommunicationsNotificationsAtomPermissions.markRead.isAllowed(writer),
        isTrue,
      );
    });

    test('route entry ∪: write alone enters; tab read ∩ fails', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      expect(
        CommunicationsNotificationsAtomPermissions.routeEntry.isAllowed(
          writeOnly,
        ),
        isTrue,
      );
      expect(
        CommunicationsNotificationsAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
    });
  });

  testWidgets(
    '∩ denial: missing communications:read omits Notifications tab and list',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(_tab('Notifications'), findsNothing);
      expect(find.text('Critical lab result'), findsNothing);
      expect(find.text('Mark read'), findsNothing);
      expect(find.byTooltip('Filters'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full ∩ read: Notifications list, chrome, and View next-action mount',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      expect(
        CommunicationsNotificationsAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
      expect(
        CommunicationsNotificationsAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        CommunicationsNotificationsAtomPermissions.archive.isAllowed(reader),
        isFalse,
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Notifications'), findsOneWidget);
      expect(find.text('Critical lab result'), findsWidgets);
      expect(find.text('View notification'), findsWidgets);
      expect(find.text('Mark read'), findsNothing);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('NOTIFICATION DETAIL'), findsWidgets);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Mark read'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∩: Mark read next-action present; Archive absent without delete',
    (WidgetTester tester) async {
      // Inventory previously gated Archive on write; matrix + backend bulk
      // archive use communications:delete — Archive must stay absent here.
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      );
      expect(
        CommunicationsNotificationsAtomPermissions.markRead.isAllowed(writer),
        isTrue,
      );
      expect(
        CommunicationsNotificationsAtomPermissions.archive.isAllowed(writer),
        isFalse,
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Mark read'), findsWidgets);
      expect(find.text('View notification'), findsNothing);

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Mark read'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'delete ∩: Archive mounts; Mark read still needs write',
    (WidgetTester tester) async {
      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsDelete,
        },
      );
      expect(
        CommunicationsNotificationsAtomPermissions.archive.isAllowed(deleter),
        isTrue,
      );
      expect(
        CommunicationsNotificationsAtomPermissions.markRead.isAllowed(deleter),
        isFalse,
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: deleter,
      );

      expect(find.text('View notification'), findsWidgets);
      expect(find.text('Mark read'), findsNothing);

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: communications:write alone omits Notifications chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      expect(canEnterCommunicationsWorkspace(writeOnly), isTrue);
      expect(
        canViewCommunicationsPanel(
          writeOnly,
          CommunicationsPanel.notifications,
        ),
        isFalse,
      );

      await _pumpNotificationsTab(
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
    'route entry ∪: communications:read alone shows Notifications atoms',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      expect(
        CommunicationsNotificationsAtomPermissions.routeEntry.isAllowed(reader),
        isTrue,
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Notifications'), findsOneWidget);
      expect(find.text('Critical lab result'), findsWidgets);
      expect(find.text('View notification'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module _(n/a)_: nestedWrite does not invent extra chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
      );
      expect(
        CommunicationsNotificationsAtomPermissions.nestedWrite.isAllowed(full),
        isTrue,
      );
      expect(
        CommunicationsNotificationsAtomPermissions.nestedRead.isAllowed(full),
        isTrue,
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      // Notifications has no New message/group (Messages-only create).
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.text('Mark read'), findsWidgets);

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: notifications-communications missing omits tab',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        CommunicationsNotificationsAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(_tab('Notifications'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'plan BASIC strips delete: Archive absent despite role grant',
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
        CommunicationsNotificationsAtomPermissions.archive.isAllowed(basic),
        isFalse,
      );
      expect(
        CommunicationsNotificationsAtomPermissions.markRead.isAllowed(basic),
        isTrue,
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: basic,
      );

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized empty Notifications keeps chrome; no write affordances',
    (WidgetTester tester) async {
      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        notifications: const <NotificationItem>[],
      );

      expect(_tab('Notifications'), findsOneWidget);
      expect(find.text('No notifications'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.text('Mark read'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Notifications',
    (WidgetTester tester) async {
      await _pumpNotificationsTab(
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

  testWidgets('authorized loading then success on Notifications', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    when(() => repository.getWorkspace(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return Result<CommunicationsWorkspaceState>.success(
        CommunicationsWorkspaceState(
          query: const CommunicationsWorkspaceQuery(
            panel: CommunicationsPanel.notifications,
          ),
          summary: const CommunicationsSummary(notifications: 1),
          metrics: const NotificationMetrics(total: 1),
          conversations: const AppPage<CommunicationsConversation>(
            items: <CommunicationsConversation>[],
            request: AppPageRequest(pageSize: 30),
            totalItemCount: 0,
          ),
          notifications: const AppPage<NotificationItem>(
            items: <NotificationItem>[_notification],
            request: AppPageRequest(pageSize: 30),
            totalItemCount: 1,
          ),
          deliveries: const AppPage<NotificationDelivery>(
            items: <NotificationDelivery>[],
            request: AppPageRequest(pageSize: 30),
            totalItemCount: 0,
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
      initialLocation: '/communications?panel=notifications',
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
    'Mark read syncs list and shows success snackbar',
    (WidgetTester tester) async {
      when(() => repository.markNotificationRead('notification-1')).thenAnswer(
        (_) async => Result<NotificationItem>.success(_readNotification),
      );
      when(() => repository.getNotificationMetrics()).thenAnswer(
        (_) async => const Result<NotificationMetrics>.success(
          NotificationMetrics(total: 1),
        ),
      );

      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Mark read').first);
      await tester.pumpAndSettle();

      verify(() => repository.markNotificationRead('notification-1')).called(1);
      expect(find.text('Communication action saved.'), findsOneWidget);
      expect(find.text('Mark as read'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'Archive confirm syncs after delete-authorized mutation',
    (WidgetTester tester) async {
      when(() => repository.archiveNotification('notification-1')).thenAnswer(
        (_) async => const Result<void>.success(null),
      );
      when(() => repository.getNotificationMetrics()).thenAnswer(
        (_) async => const Result<NotificationMetrics>.success(
          NotificationMetrics(total: 0),
        ),
      );

      // Compact desktop size keeps dialog action buttons in hit-test bounds.
      await _pumpNotificationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsDelete,
          },
        ),
        physicalSize: const Size(1024, 900),
      );

      await tester.tap(_tableRowInkWell().first);
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsWidgets);
      await tester.tap(find.text('Archive').first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('ARCHIVE COMMUNICATION'), findsWidgets);
      await tester.tap(find.text('Archive').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      verify(() => repository.archiveNotification('notification-1')).called(1);
      expect(find.text('Communication action saved.'), findsOneWidget);
    },
  );

  testWidgets('Notifications mobile viewport keeps read chrome accessible', (
    WidgetTester tester,
  ) async {
    await _pumpNotificationsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('Notifications'), findsOneWidget);
    expect(find.textContaining('Critical lab'), findsWidgets);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byTooltip('New message'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('Notifications desktop viewport with write+delete chrome', (
    WidgetTester tester,
  ) async {
    await _pumpNotificationsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Mark read'), findsWidgets);
    expect(find.text('Action'), findsOneWidget);

    await tester.tap(_tableRowInkWell().first);
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsWidgets);
  });

  testWidgets('Notifications light theme authorized chrome', (
    WidgetTester tester,
  ) async {
    await _pumpNotificationsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      ),
      themeMode: ThemeMode.light,
    );

    expect(_tab('Notifications'), findsOneWidget);
    expect(find.text('Critical lab result'), findsWidgets);
  });

  testWidgets('Notifications dark theme authorized chrome', (
    WidgetTester tester,
  ) async {
    await _pumpNotificationsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      ),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Notifications'), findsOneWidget);
    expect(find.text('Critical lab result'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });
}
