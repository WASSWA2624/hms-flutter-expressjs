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
import 'package:hosspi_hms/features/communications/presentation/communications_messages_billing_inventory.dart';
import 'package:hosspi_hms/features/communications/presentation/pages/communications_workspace_page.dart';
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_compose_bar.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockCommunicationsRepository extends Mock
    implements CommunicationsRepository {}

const CommunicationsConversation _conversation = CommunicationsConversation(
  id: 'conversation-1',
  title: 'Critical lab follow-up',
  unread: true,
  messages: <CommunicationMessage>[
    CommunicationMessage(
      id: 'message-1',
      content: 'Please review potassium',
    ),
  ],
);

const AppModuleEntitlement _commsModule = AppModuleEntitlement(
  code: communicationsModule,
  licenseStatus: 'ACTIVE',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    _commsModule,
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
  Result<CommunicationsWorkspaceState>? failure,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (failure != null) {
      return failure;
    }
    final CommunicationsWorkspaceQuery query =
        invocation.positionalArguments.single as CommunicationsWorkspaceQuery;
    return Result<CommunicationsWorkspaceState>.success(
      CommunicationsWorkspaceState(
        query: query,
        summary: CommunicationsSummary(
          unreadThreads: conversations.where((c) => c.unread).length,
          notifications: 0,
          failedDeliveries: 0,
          templates: 0,
        ),
        metrics: const NotificationMetrics(total: 0, unread: 0),
        conversations: AppPage<CommunicationsConversation>(
          items: conversations,
          request: query.pageRequest,
          totalItemCount: conversations.length,
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
          items: const <CommunicationTemplate>[],
          request: query.pageRequest,
          totalItemCount: 0,
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
  when(
    () => repository.getReferenceStaff(search: any(named: 'search')),
  ).thenAnswer(
    (_) async => const Result<List<CommunicationStaffOption>>.success(
      <CommunicationStaffOption>[
        CommunicationStaffOption(id: 'staff-2', label: 'Alex Nurse'),
      ],
    ),
  );
  when(() => repository.sendMessage(any(), any())).thenAnswer(
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
          CommunicationMessage(id: 'message-2', content: 'Follow-up sent'),
        ],
      ),
    ),
  );
  when(() => repository.createConversation(any())).thenAnswer(
    (_) async => const Result<CommunicationsConversation>.success(
      CommunicationsConversation(
        id: 'conversation-2',
        title: 'New direct',
        unread: false,
      ),
    ),
  );
  when(() => repository.markConversationRead(any())).thenAnswer(
    (_) async => const Result<CommunicationsConversation>.success(
      CommunicationsConversation(
        id: 'conversation-1',
        title: 'Critical lab follow-up',
        unread: false,
      ),
    ),
  );
}

Future<void> _pumpMessages(
  WidgetTester tester, {
  required _MockCommunicationsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<CommunicationsConversation> conversations =
      const <CommunicationsConversation>[_conversation],
  Result<CommunicationsWorkspaceState>? failure,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, conversations: conversations, failure: failure);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/communications?panel=inbox',
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
    registerFallbackValue(const CommunicationMessageDraft(content: ''));
    registerFallbackValue(
      const CommunicationConversationDraft(participantIds: <String>[]),
    );
  });

  setUp(() {
    repository = _MockCommunicationsRepository();
  });

  group('Communications Messages financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        CommunicationsMessagesBillingInventory.messagesTabHasNoBillableActions,
        isTrue,
      );
      expect(
        CommunicationsMessagesBillingInventory
            .allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(CommunicationsMessagesBillingInventory.atoms, isNotEmpty);
      expect(
        CommunicationsMessagesBillingInventory.billableClasses.every(
          (CommunicationsMessagesFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(communicationsMessagesBillingScopeNote, contains('NOT_BILLED'));

      for (final CommunicationsMessagesFinancialAtom atom
          in CommunicationsMessagesBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<CommunicationsMessagesFinancialClass>[
            CommunicationsMessagesFinancialClass.notRequired,
            CommunicationsMessagesFinancialClass.notBilled,
            CommunicationsMessagesFinancialClass.noCharge,
          ]),
          reason: atom.id,
        );
        expect(
          atom.auditCode,
          isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
          reason: atom.id,
        );
      }
    });

    test('New message and New group stay NOT_BILLED', () {
      final CommunicationsMessagesFinancialAtom newMessage =
          CommunicationsMessagesBillingInventory.atoms.singleWhere(
            (CommunicationsMessagesFinancialAtom atom) =>
                atom.id == 'new_message_primary',
          );
      expect(
        newMessage.financialClass,
        CommunicationsMessagesFinancialClass.notBilled,
      );
      expect(newMessage.auditCode, 'NOT_BILLED');

      final CommunicationsMessagesFinancialAtom newGroup =
          CommunicationsMessagesBillingInventory.atoms.singleWhere(
            (CommunicationsMessagesFinancialAtom atom) =>
                atom.id == 'new_group_secondary',
          );
      expect(
        newGroup.financialClass,
        CommunicationsMessagesFinancialClass.notBilled,
      );
      expect(newGroup.auditCode, 'NOT_BILLED');
    });

    test('compose/send and thread menu stay NOT_BILLED', () {
      final CommunicationsMessagesFinancialAtom compose =
          CommunicationsMessagesBillingInventory.atoms.singleWhere(
            (CommunicationsMessagesFinancialAtom atom) =>
                atom.id == 'compose_send_attach_reply',
          );
      expect(compose.auditCode, 'NOT_BILLED');

      final CommunicationsMessagesFinancialAtom menu =
          CommunicationsMessagesBillingInventory.atoms.singleWhere(
            (CommunicationsMessagesFinancialAtom atom) =>
                atom.id == 'thread_menu_favorite_flag_read_archive',
          );
      expect(menu.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        CommunicationsMessagesBillingInventory.atoms
            .singleWhere(
              (CommunicationsMessagesFinancialAtom atom) =>
                  atom.id == 'paid_sms_notification_package',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsMessagesBillingInventory.atoms
            .singleWhere(
              (CommunicationsMessagesFinancialAtom atom) =>
                  atom.id == 'patient_clinical_charge_via_message',
            )
            .mounted,
        isFalse,
      );
      expect(
        CommunicationsMessagesBillingInventory.atoms
            .singleWhere(
              (CommunicationsMessagesFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(communicationsMessagesBillingScopeNote, contains('Billing'));
    });
  });

  group('Communications Messages billing bypass (AC2–AC4)', () {
    testWidgets('inbox has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.text('Critical lab follow-up'), findsOneWidget);
      expect(find.byTooltip('New message'), findsOneWidget);
      expect(find.byTooltip('New group'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('thread: no financial controls; compose stays NOT_BILLED path', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
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

      expect(find.byType(CommunicationsComposeBar), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect or send', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
      );

      expect(find.byTooltip('New message'), findsNothing);
      expect(find.byTooltip('New group'), findsNothing);
      expect(find.byType(CommunicationsComposeBar), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('billing:write alone does not mount Messages financial chrome', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.byTooltip('New message'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Adjust balance'), findsNothing);
    });

    testWidgets('New message dialog has no billing affordances', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
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
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expectFlatSections(tester);
      verifyNever(() => repository.createConversation(any()));
    });

    testWidgets('send message mutation syncs without billing gate', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
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

      await tester.enterText(
        find.descendant(
          of: find.byType(CommunicationsComposeBar),
          matching: find.byType(TextField),
        ),
        'Follow-up sent',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      verify(() => repository.sendMessage(any(), any())).called(1);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Invoice'), findsNothing);
    });
  });

  group('Communications Messages section layout (AC5)', () {
    testWidgets('desktop Messages: flat sibling sections on list + empty detail', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );

      expect(find.text('Messages'), findsWidgets);
      expect(find.text('Conversation detail'), findsOneWidget);
      expect(find.text('Select a conversation'), findsOneWidget);
      expect(find.byType(AppWorkspaceDetailPanel), findsWidgets);
      expectFlatSections(tester);
    });

    testWidgets('desktop Messages: flat sections after selecting thread', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );

      await tester.tap(find.text('Critical lab follow-up'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Messages: flat sections', (WidgetTester tester) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
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
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
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
      expectFlatSections(tester);
    });

    testWidgets('New group dialog: flat sections', (WidgetTester tester) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('New group'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Communications Messages sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        conversations: const <CommunicationsConversation>[],
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpMessages(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        ),
        failure: const Result<CommunicationsWorkspaceState>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('inventory reuses shared financial class vocabulary and gates', () {
      expect(
        CommunicationsMessagesBillingInventory.atoms.any(
          (CommunicationsMessagesFinancialAtom atom) =>
              atom.financialClass ==
              CommunicationsMessagesFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        CommunicationsMessagesAtomPermissions.tab,
        communicationsWorkspaceReadRequirement,
      );
      expect(
        CommunicationsMessagesAtomPermissions.newMessage,
        communicationsWorkspaceWriteRequirement,
      );
      expect(
        CommunicationsMessagesAtomPermissions.compose,
        communicationsWorkspaceWriteRequirement,
      );
    });
  });
}
