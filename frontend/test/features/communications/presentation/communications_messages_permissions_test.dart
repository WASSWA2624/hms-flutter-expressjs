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
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_compose_bar.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_thread_view.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCommunicationsRepository extends Mock
    implements CommunicationsRepository {}

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

const CommunicationsConversation _conversation = CommunicationsConversation(
  id: 'conversation-1',
  title: 'Critical lab follow-up',
  unread: true,
  messages: <CommunicationMessage>[
    CommunicationMessage(
      id: 'message-1',
      content: 'Please review potassium',
      sentAt: null,
    ),
  ],
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
  List<CommunicationsConversation> conversations =
      const <CommunicationsConversation>[_conversation],
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
          unreadThreads: conversations.where((c) => c.unread).length,
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
          items: conversations,
          request: query.pageRequest,
          totalItemCount: conversations.length,
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
        selectedConversation: query.conversationId == null
            ? null
            : conversations
                  .where(
                    (CommunicationsConversation item) =>
                        item.id == query.conversationId,
                  )
                  .firstOrNull,
      ),
    );
  });
  when(() => repository.getConversation(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.single as String;
    final CommunicationsConversation match = conversations.firstWhere(
      (CommunicationsConversation item) => item.id == id,
      orElse: () => _conversation,
    );
    return Result<CommunicationsConversation>.success(match);
  });
  when(() => repository.getReferenceStaff(search: any(named: 'search')))
      .thenAnswer(
        (_) async =>
            const Result<List<CommunicationStaffOption>>.success(
              <CommunicationStaffOption>[],
            ),
      );
  when(
    () => repository.markConversationRead(any()),
  ).thenAnswer((Invocation invocation) async {
    final String id = invocation.positionalArguments.single as String;
    final CommunicationsConversation match = conversations.firstWhere(
      (CommunicationsConversation item) => item.id == id,
      orElse: () => _conversation,
    );
    return Result<CommunicationsConversation>.success(
      CommunicationsConversation(
        id: match.id,
        title: match.title,
        subject: match.subject,
        conversationType: match.conversationType,
        status: match.status,
        isSensitive: match.isSensitive,
        archived: match.archived,
        unread: false,
        isFavorite: match.isFavorite,
        isFlagged: match.isFlagged,
        lastMessageAt: match.lastMessageAt,
        createdAt: match.createdAt,
        targetPath: match.targetPath,
        participants: match.participants,
        lastMessage: match.lastMessage,
        messages: match.messages,
        attachmentCount: match.attachmentCount,
      ),
    );
  });
  when(
    () => repository.sendMessage(any(), any()),
  ).thenAnswer(
    (_) async => const Result<CommunicationsConversation>.success(
      CommunicationsConversation(
        id: 'conversation-1',
        title: 'Critical lab follow-up',
        unread: false,
        messages: <CommunicationMessage>[
          CommunicationMessage(
            id: 'message-1',
            content: 'Please review potassium',
          ),
          CommunicationMessage(
            id: 'message-2',
            content: 'Follow-up sent',
          ),
        ],
      ),
    ),
  );
}

Future<void> _pumpMessagesTab(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/communications?panel=inbox',
  List<CommunicationsConversation> conversations =
      const <CommunicationsConversation>[_conversation],
  Result<CommunicationsWorkspaceState>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(
    repository,
    conversations: conversations,
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
        routerConfig: router,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
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
    registerFallbackValue(
      const CommunicationMessageDraft(content: 'fallback'),
    );
  });

  setUp(() {
    repository = _MockCommunicationsRepository();
  });

  group('CommunicationsMessagesAtomPermissions helpers', () {
    test('reuses AccessRequirement vocabulary (no second map)', () {
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.newMessage,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.compose,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.threadMenu,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.delete,
          communicationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.routeEntry,
          communicationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      // Nested cross-module matrix rows are _(n/a)_ — nested gates stay in-module.
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.nestedRead,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.nestedWrite,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
    });

    test('∩ denial: write without delete denies hard-delete requirement', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      );
      expect(
        CommunicationsMessagesAtomPermissions.delete.isAllowed(writer),
        isFalse,
      );
      expect(
        CommunicationsMessagesAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
    });

    test('route entry ∪: write alone enters; tab read ∩ fails', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      expect(
        CommunicationsMessagesAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        CommunicationsMessagesAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
    });
  });

  testWidgets(
    '∩ denial: missing communications:write hides New message/group and compose',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      expect(
        CommunicationsMessagesAtomPermissions.newMessage.isAllowed(reader),
        isFalse,
      );
      expect(
        CommunicationsMessagesAtomPermissions.compose.isAllowed(reader),
        isFalse,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Messages'), findsOneWidget);
      expect(find.text('Critical lab follow-up'), findsOneWidget);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Critical lab follow-up'));
      await tester.pumpAndSettle();

      expect(find.byType(CommunicationsThreadView), findsOneWidget);
      expect(find.byType(CommunicationsComposeBar), findsNothing);
      expect(find.byTooltip('Conversation actions'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    },
  );

  testWidgets(
    '∩ present: communications:read ∩ write shows New message/group',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      );
      expect(
        CommunicationsMessagesAtomPermissions.newMessage.isAllowed(writer),
        isTrue,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(_tab('Messages'), findsOneWidget);
      expect(find.byTooltip('New message'), findsOneWidget);
      expect(find.byTooltip('New group'), findsOneWidget);
      expect(find.text('Critical lab follow-up'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'delete ∩: hard-delete thread chrome stays absent (not in inventory UI)',
    (WidgetTester tester) async {
      // Source inventory: conversation archive stays on write ∩; hard delete
      // thread is matrix delete ∩ when exposed — currently not mounted.
      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
      );
      expect(
        CommunicationsMessagesAtomPermissions.delete.isAllowed(deleter),
        isTrue,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: deleter,
      );

      await tester.tap(find.text('Critical lab follow-up'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Conversation actions'), findsOneWidget);
      await tester.tap(find.byTooltip('Conversation actions'));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsNothing);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ route entry: write alone without read omits Messages chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      expect(
        CommunicationsMessagesAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        CommunicationsMessagesAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(canEnterCommunicationsWorkspace(writeOnly), isTrue);

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(_tab('Messages'), findsNothing);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.text('Critical lab follow-up'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: communications:read alone shows Messages list chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      expect(
        CommunicationsMessagesAtomPermissions.routeEntry.isAllowed(reader),
        isTrue,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(_tab('Messages'), findsOneWidget);
      expect(find.text('Critical lab follow-up'), findsOneWidget);
      expect(find.byTooltip('New message'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: missing notifications-communications omits Messages',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        CommunicationsMessagesAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'plan BASIC strips delete ∩; write Messages chrome remains',
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
      expect(CommunicationsMessagesAtomPermissions.tab.isAllowed(basic), isTrue);
      expect(
        CommunicationsMessagesAtomPermissions.write.isAllowed(basic),
        isTrue,
      );
      expect(
        CommunicationsMessagesAtomPermissions.delete.isAllowed(basic),
        isFalse,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: basic,
      );

      expect(_tab('Messages'), findsOneWidget);
      expect(find.byTooltip('New message'), findsOneWidget);
      expect(find.byTooltip('New group'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module matrix _(n/a)_: no foreign-module nested write chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy full = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      );
      expect(
        CommunicationsMessagesAtomPermissions.nestedWrite.isAllowed(full),
        isTrue,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: full,
      );

      // Messages has no nested billing/clinical write entry points.
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Record vitals'), findsNothing);
      expect(
        CommunicationsMessagesAtomPermissions.nestedWrite.allPermissions
            .toList(growable: false),
        <AppPermission>[AppPermissions.communicationsWrite],
      );
    },
  );

  testWidgets('authorized New message opens compose dialog (validation path)', (
    WidgetTester tester,
  ) async {
    await _pumpMessagesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      ),
    );

    await tester.tap(find.byTooltip('New message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppDialog), findsWidgets);
    expect(find.text('Start conversation'), findsWidgets);
  });

  testWidgets(
    'authorized empty Messages keeps chrome; no write affordances for reader',
    (WidgetTester tester) async {
      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        conversations: const <CommunicationsConversation>[],
      );

      expect(_tab('Messages'), findsOneWidget);
      expect(find.text('No conversations'), findsOneWidget);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Messages',
    (WidgetTester tester) async {
      await _pumpMessagesTab(
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

  testWidgets(
    'authorized compose sync path: selecting thread mounts Send/Attach chrome',
    (WidgetTester tester) async {
      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Critical lab follow-up'));
      await tester.pumpAndSettle();

      // Post-select list/detail stay in sync: thread + compose chrome mount.
      expect(find.byType(CommunicationsThreadView), findsOneWidget);
      expect(find.byType(CommunicationsComposeBar), findsOneWidget);
      expect(find.byTooltip('Send message'), findsOneWidget);
      expect(find.byTooltip('Attach file'), findsOneWidget);
      expect(find.byTooltip('Conversation actions'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'post-mutation sync: sendMessage refreshes thread without leftover write lock',
    (WidgetTester tester) async {
      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        ),
      );

      await tester.tap(find.text('Critical lab follow-up'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Follow-up sent');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      verify(
        () => repository.sendMessage(_conversation.id, any()),
      ).called(1);
      expect(find.byType(CommunicationsComposeBar), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: EXPIRED notifications-communications omits Messages',
    (WidgetTester tester) async {
      final AppAccessPolicy expired = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: communicationsActiveModule,
            licenseStatus: 'EXPIRED',
          ),
        ],
      );
      expect(
        CommunicationsMessagesAtomPermissions.tab.isAllowed(expired),
        isFalse,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: expired,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.text('Critical lab follow-up'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'ABAC: missing facility context still allows Messages read chrome '
    '(row/own scope remains backend-authoritative)',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            roles: <String>['NURSE'],
            tenantId: 'tenant-1',
          ),
          permissions: <AppPermission>{AppPermissions.communicationsRead},
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: communicationsActiveModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );
      expect(noFacility.hasFacilityContext, isFalse);
      expect(
        CommunicationsMessagesAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        CommunicationsMessagesAtomPermissions.listChrome.isAllowed(noFacility),
        isTrue,
      );

      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: noFacility,
      );

      expect(_tab('Messages'), findsOneWidget);
      expect(find.text('Critical lab follow-up'), findsOneWidget);
      expect(find.byTooltip('New message'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∩ denial: manage members nested write absent for read-only thread',
    (WidgetTester tester) async {
      const CommunicationsConversation group = CommunicationsConversation(
        id: 'conversation-1',
        title: 'Critical lab follow-up',
        unread: true,
        conversationType: 'GROUP',
        messages: <CommunicationMessage>[
          CommunicationMessage(
            id: 'message-1',
            content: 'Please review potassium',
            sentAt: null,
          ),
        ],
      );
      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        conversations: const <CommunicationsConversation>[group],
      );

      await tester.tap(find.text('Critical lab follow-up'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Conversation actions'), findsNothing);
      expect(find.text('Manage members'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized group thread mounts Manage members under write ∩',
    (WidgetTester tester) async {
      const CommunicationsConversation group = CommunicationsConversation(
        id: 'conversation-1',
        title: 'Critical lab follow-up',
        unread: false,
        conversationType: 'GROUP',
        messages: <CommunicationMessage>[
          CommunicationMessage(
            id: 'message-1',
            content: 'Please review potassium',
            sentAt: null,
          ),
        ],
      );
      await _pumpMessagesTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        ),
        conversations: const <CommunicationsConversation>[group],
      );

      await tester.tap(find.text('Critical lab follow-up'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Conversation actions'), findsOneWidget);
      await tester.tap(find.byTooltip('Conversation actions'));
      await tester.pumpAndSettle();

      expect(find.text('Manage members'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized Messages chrome', (
    WidgetTester tester,
  ) async {
    await _pumpMessagesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(_tab('Messages'), findsOneWidget);
    expect(find.byTooltip('New message'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop viewport keeps authorized Messages row readable', (
    WidgetTester tester,
  ) async {
    await _pumpMessagesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Critical lab follow-up'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip('New message'), findsOneWidget);
    expect(find.byTooltip('New group'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Messages chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpMessagesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(_tab('Messages'), findsOneWidget);
    expect(find.byTooltip('New message'), findsOneWidget);
    expect(find.text('Critical lab follow-up'), findsOneWidget);
  });

  testWidgets('light theme: authorized Messages chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpMessagesTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(_tab('Messages'), findsOneWidget);
    expect(find.byTooltip('New message'), findsOneWidget);
    expect(find.text('Critical lab follow-up'), findsOneWidget);
  });
}
