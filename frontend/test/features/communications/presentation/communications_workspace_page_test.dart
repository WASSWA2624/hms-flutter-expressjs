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
import 'package:hosspi_hms/features/communications/data/repositories/communications_repository_impl.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/domain/repositories/communications_repository.dart';
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

Finder _tabToolbarRefresh() => find.descendant(
  of: find.byType(AppTabStrip),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        (widget is AppTabToolbarAction && widget.label == 'Refresh') ||
        (widget is AppTabToolbarPrimary && widget.label == 'Refresh'),
  ),
);

const CommunicationsConversation _conversation = CommunicationsConversation(
  id: 'conversation-1',
  title: 'Critical lab follow-up',
  unread: true,
);

const NotificationItem _notification = NotificationItem(
  id: 'notification-1',
  title: 'Critical lab result',
  message: 'Potassium critically high',
  priority: 'HIGH',
  notificationType: 'LAB_ALERT',
);

const NotificationDelivery _delivery = NotificationDelivery(
  id: 'delivery-1',
  status: 'FAILED',
  channel: 'EMAIL',
  notificationTitle: 'Critical lab result',
  recipientTarget: 'nurse@example.com',
  attemptCount: 2,
);

const CommunicationTemplate _template = CommunicationTemplate(
  id: 'template-1',
  name: 'Discharge summary',
  channel: 'EMAIL',
  description: 'Patient discharge template',
  variableCount: 3,
);

AppAccessPolicy _communicationsWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['NURSE']),
      permissions: <AppPermission>{
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'notifications-communications',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

AppAccessPolicy _communicationsReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['HOUSE_KEEPER']),
      permissions: <AppPermission>{AppPermissions.communicationsRead},
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'notifications-communications',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

void _stubWorkspace(_MockCommunicationsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final CommunicationsWorkspaceQuery query =
        invocation.positionalArguments.single as CommunicationsWorkspaceQuery;
    return Result<CommunicationsWorkspaceState>.success(
      CommunicationsWorkspaceState(
        query: query,
        summary: const CommunicationsSummary(
          unreadThreads: 1,
          notifications: 1,
          failedDeliveries: 1,
          templates: 1,
        ),
        metrics: const NotificationMetrics(
          total: 1,
          unread: 1,
          attentionRequired: 1,
          failedDeliveries: 1,
        ),
        conversations: AppPage<CommunicationsConversation>(
          items: const <CommunicationsConversation>[_conversation],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        notifications: AppPage<NotificationItem>(
          items: const <NotificationItem>[_notification],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        deliveries: AppPage<NotificationDelivery>(
          items: const <NotificationDelivery>[_delivery],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        templates: AppPage<CommunicationTemplate>(
          items: const <CommunicationTemplate>[_template],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
        selectedNotification: query.panel == CommunicationsPanel.notifications
            ? _notification
            : null,
        selectedDelivery: query.panel == CommunicationsPanel.deliveries
            ? _delivery
            : null,
        selectedTemplate: query.panel == CommunicationsPanel.templates
            ? _template
            : null,
      ),
    );
  });
}

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockCommunicationsRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpCommunicationsWorkspace(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  CommunicationsWorkspaceQuery? initialQuery,
  String initialLocation = '/communications',
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
        path: '/communications',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: CommunicationsWorkspacePage(
              initialQuery:
                  initialQuery ??
                  CommunicationsWorkspaceQuery.fromUri(state.uri),
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
          accessPolicy ?? _communicationsWritePolicy(),
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

void main() {
  late _MockCommunicationsRepository repository;

  setUpAll(() {
    registerFallbackValue(const CommunicationsWorkspaceQuery());
  });

  setUp(() {
    repository = _MockCommunicationsRepository();
  });

  testWidgets('renders tab strip with panel counts and inbox rows', (
    WidgetTester tester,
  ) async {
    await _pumpCommunicationsWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(_tab('Messages'), findsOneWidget);
    expect(_tab('Notifications'), findsOneWidget);
    expect(_tab('Deliveries'), findsOneWidget);
    expect(_tab('Templates'), findsOneWidget);
    expect(find.text('Critical lab follow-up'), findsOneWidget);
    expect(find.byTooltip('New message'), findsOneWidget);
    expect(find.byTooltip('New group'), findsOneWidget);
    expect(_tabToolbarRefresh(), findsOneWidget);
    expect(find.text('Unread threads'), findsNothing);
    expect(find.text('Failed deliveries'), findsNothing);
  });

  testWidgets('New message primary action only shows on inbox with write', (
    WidgetTester tester,
  ) async {
    await _pumpCommunicationsWorkspace(tester, repository: repository);

    expect(find.byTooltip('New message'), findsOneWidget);
    expect(find.byTooltip('New group'), findsOneWidget);

    await tester.tap(_tab('Notifications'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('New message'), findsNothing);
    expect(find.byTooltip('New group'), findsNothing);
    expect(_tabToolbarRefresh(), findsOneWidget);
    expect(find.text('Critical lab result'), findsWidgets);
  });

  testWidgets('hides New message when user lacks write permission', (
    WidgetTester tester,
  ) async {
    await _pumpCommunicationsWorkspace(
      tester,
      repository: repository,
      accessPolicy: _communicationsReadOnlyPolicy(),
    );

    expect(find.byTooltip('New message'), findsNothing);
    expect(find.byTooltip('New group'), findsNothing);
    expect(_tabToolbarRefresh(), findsOneWidget);
    expect(_tab('Messages'), findsOneWidget);
  });

  testWidgets('switching tabs updates the panel query parameter', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpCommunicationsWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(_tab('Deliveries'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['panel'], 'deliveries');
    expect(find.text('Critical lab result'), findsWidgets);
    expect(find.text('nurse@example.com'), findsWidgets);
  });

  testWidgets('deep link panel=notifications selects Notifications tab', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpCommunicationsWorkspace(
      tester,
      repository: repository,
      initialLocation: '/communications?panel=notifications',
      initialQuery: CommunicationsWorkspaceQuery.fromUri(
        Uri.parse('/communications?panel=notifications'),
      ),
    );

    expect(harness.router.state.uri.queryParameters['panel'], 'notifications');
    expect(find.text('Critical lab result'), findsWidgets);
    expect(find.byTooltip('New message'), findsNothing);
    expect(find.text('Critical lab follow-up'), findsNothing);
  });

  testWidgets('templates tab shows template rows', (WidgetTester tester) async {
    final _Harness harness = await _pumpCommunicationsWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(_tab('Templates'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.queryParameters['panel'], 'templates');
    expect(find.text('Discharge summary'), findsWidgets);
    expect(find.text('Critical lab follow-up'), findsNothing);
  });

  testWidgets('mobile breakpoint keeps tab strip and conversation list', (
    WidgetTester tester,
  ) async {
    await _pumpCommunicationsWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Critical lab follow-up'), findsOneWidget);
    expect(find.byTooltip('New message'), findsOneWidget);
    expect(_tabToolbarRefresh(), findsOneWidget);
  });

  testWidgets('notifications tab exposes Filters and Settings labels', (
    WidgetTester tester,
  ) async {
    await _pumpCommunicationsWorkspace(tester, repository: repository);

    await tester.tap(_tab('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Communication filters'), findsNothing);
    expect(find.text('Table settings'), findsNothing);
  });

  testWidgets('New group appears in tab toolbar not conversation list', (
    WidgetTester tester,
  ) async {
    await _pumpCommunicationsWorkspace(tester, repository: repository);

    expect(
      find.descendant(
        of: find.byType(AppTabStrip),
        matching: find.byTooltip('New group'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppSearchBar),
        matching: find.byTooltip('New group'),
      ),
      findsNothing,
    );
  });
}
