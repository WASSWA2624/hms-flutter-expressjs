import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
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
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_approval_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsWorkItem _approvalItem = AccountsWorkItem(
  id: 'apr-1',
  kind: AccountsWorkItemKind.approval,
  displayId: 'JE-001',
  journalDisplayId: 'JE-001',
  status: 'PENDING',
  amount: 250,
  requestType: 'JOURNAL_POST',
  requestReason: 'Post month end',
  requestedByDisplayId: 'ACC-1',
  periodLabel: '2026-08',
  canApproveFlag: true,
);

const AccountsSummary _summary = AccountsSummary(needApproval: 1);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'facility-accounts', licenseStatus: 'ACTIVE'),
    // financial:approve is plan-mapped to billing-payments.
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['ACCOUNTANT'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockAccountsRepository repository, {
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_approvalItem],
  AccountsSummary summary = _summary,
  bool removeAfterDecision = false,
}) {
  var decided = false;
  when(() => repository.getWorkspace(any())).thenAnswer((_) async {
    final AccountsSummary live = decided && removeAfterDecision
        ? const AccountsSummary()
        : summary;
    return Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(summary: live),
    );
  });
  when(() => repository.listWorkItems(any())).thenAnswer((_) async {
    final List<AccountsWorkItem> live = decided && removeAfterDecision
        ? const <AccountsWorkItem>[]
        : items;
    return Result<AppPage<AccountsWorkItem>>.success(
      AppPage<AccountsWorkItem>(
        items: live,
        request: const AppPageRequest(pageSize: 20),
        totalItemCount: live.length,
      ),
    );
  });
  when(() => repository.approveRequest(any(), notes: any(named: 'notes')))
      .thenAnswer((_) async {
        decided = true;
        return const Result<AccountsMutationResult>.success(
          AccountsMutationResult(
            item: AccountsWorkItem(
              id: 'apr-1',
              kind: AccountsWorkItemKind.approval,
              displayId: 'JE-001',
              status: 'APPROVED',
              amount: 250,
              canApproveFlag: false,
            ),
          ),
        );
      });
  when(
    () => repository.rejectRequest(
      any(),
      reason: any(named: 'reason'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer((_) async {
    decided = true;
    return const Result<AccountsMutationResult>.success(
      AccountsMutationResult(
        item: AccountsWorkItem(
          id: 'apr-1',
          kind: AccountsWorkItemKind.approval,
          displayId: 'JE-001',
          status: 'REJECTED',
          amount: 250,
          canApproveFlag: false,
        ),
      ),
    );
  });
  when(() => repository.listGlAccounts(any())).thenAnswer(
    (_) async => Result<AppPage<AccountsGlAccount>>.success(
      AppPage<AccountsGlAccount>(
        items: const <AccountsGlAccount>[],
        request: const AppPageRequest(pageSize: 20),
        totalItemCount: 0,
      ),
    ),
  );
}

Future<void> _pumpApprovalsTab(
  WidgetTester tester, {
  required _MockAccountsRepository repository,
  required AppAccessPolicy accessPolicy,
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_approvalItem],
  AccountsSummary summary = _summary,
  String location = '/accounts?section=approvals',
  bool removeAfterDecision = false,
  List<dynamic> extraOverrides = const <dynamic>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items,
    summary: summary,
    removeAfterDecision: removeAfterDecision,
  );

  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      GoRoute(
        path: '/accounts',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: AccountsWorkspacePage(
              initialQuery: AccountsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
        ...extraOverrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
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
  late _MockAccountsRepository repository;

  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsGlQuery());
  });

  setUp(() {
    repository = _MockAccountsRepository();
  });

  testWidgets(
    'read-only: Need approval visible; Approve/Reject absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      expect(AccountsNeedApprovalAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        AccountsNeedApprovalAtomPermissions.approve.isAllowed(reader),
        isFalse,
      );

      await _pumpApprovalsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text(AccountsStrings.needApprovalLabel), findsWidgets);
      expect(find.text(AccountsStrings.approveAction), findsNothing);
      expect(find.text(AccountsStrings.rejectAction), findsNothing);
      expect(find.text('JE-001'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text(AccountsStrings.nextColumn),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'write without financial:approve: Approve/Reject absent',
    (WidgetTester tester) async {
      await _pumpApprovalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
          },
        ),
      );

      expect(find.text(AccountsStrings.approveAction), findsNothing);
      expect(find.text(AccountsStrings.rejectAction), findsNothing);
    },
  );

  testWidgets(
    'financial:approve without write: Approve/Reject absent',
    (WidgetTester tester) async {
      await _pumpApprovalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.financialApprove,
          },
        ),
      );

      expect(find.text(AccountsStrings.approveAction), findsNothing);
      expect(find.text(AccountsStrings.rejectAction), findsNothing);
    },
  );

  testWidgets(
    'write ∩ financial:approve: Approve Next present; Reject only in Detail',
    (WidgetTester tester) async {
      await _pumpApprovalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
            AppPermissions.financialApprove,
          },
        ),
      );

      expect(find.text(AccountsStrings.approveAction), findsWidgets);
      expect(find.text(AccountsStrings.rejectAction), findsNothing);

      await tester.tap(find.text('JE-001'));
      await tester.pumpAndSettle();

      expect(find.text(AccountsStrings.rejectAction), findsOneWidget);
      expect(find.text(AccountsStrings.approveAction), findsWidgets);
      expect(find.text(AccountsStrings.printAction), findsOneWidget);
    },
  );

  testWidgets(
    'alias approval-required selects Need approval',
    (WidgetTester tester) async {
      await _pumpApprovalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        location: '/accounts?section=approval-required',
      );

      expect(find.text(AccountsStrings.needApprovalLabel), findsWidgets);
      expect(find.text(AccountsStrings.needApprovalEmpty), findsNothing);
    },
  );

  testWidgets('empty state shows No pending approvals.', (
    WidgetTester tester,
  ) async {
    await _pumpApprovalsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      items: const <AccountsWorkItem>[],
      summary: const AccountsSummary(),
    );

    expect(find.text(AccountsStrings.needApprovalEmpty), findsOneWidget);
  });

  testWidgets('Approve from Next calls repository and refreshes', (
    WidgetTester tester,
  ) async {
    await _pumpApprovalsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
          AppPermissions.financialApprove,
        },
      ),
      removeAfterDecision: true,
    );

    await tester.tap(find.text(AccountsStrings.approveAction).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AccountsStrings.approveAction).last);
    await tester.pumpAndSettle();

    verify(
      () => repository.approveRequest('apr-1', notes: any(named: 'notes')),
    ).called(1);
    expect(find.text(AccountsStrings.saved), findsOneWidget);
    expect(find.text('JE-001'), findsNothing);
    expect(find.text(AccountsStrings.needApprovalEmpty), findsOneWidget);
  });

  testWidgets('Reject from Detail calls repository', (WidgetTester tester) async {
    await _pumpApprovalsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
          AppPermissions.financialApprove,
        },
      ),
      removeAfterDecision: true,
    );

    await tester.tap(find.text('JE-001'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AccountsStrings.rejectAction));
    await tester.tap(find.text(AccountsStrings.rejectAction));
    await tester.pumpAndSettle();

    expect(find.text(AccountsStrings.reasonLabel), findsOneWidget);
    await tester.enterText(find.byType(AppTextField).first, 'Duplicate request');
    await tester.pump();
    await tester.tap(find.text(AccountsStrings.rejectAction).last);
    await tester.pumpAndSettle();

    verify(
      () => repository.rejectRequest(
        'apr-1',
        reason: any(named: 'reason'),
        notes: any(named: 'notes'),
      ),
    ).called(1);
    expect(find.text(AccountsStrings.saved), findsOneWidget);
    expect(find.text(AccountsStrings.needApprovalEmpty), findsOneWidget);
  });

  testWidgets(
    'Detail Print opens approval preview with section options',
    (WidgetTester tester) async {
      const PrintFormTemplateContext templateContext = PrintFormTemplateContext(
        appBranding: PrintFormBranding(
          name: 'Test HMS',
          kind: PrintFormBrandingKind.app,
        ),
      );
      await _pumpApprovalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
            AppPermissions.financialApprove,
          },
        ),
        extraOverrides: [
          printFormTemplateContextReadyProvider.overrideWith(
            (ref) async => templateContext,
          ),
          printFormTemplateContextProvider.overrideWith(
            (ref) => templateContext,
          ),
        ],
      );

      await tester.tap(find.text('JE-001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AccountsStrings.printAction));
      await tester.pumpAndSettle();

      expect(find.byType(AppPrintPreviewPanel), findsOneWidget);
      expect(find.text('Print sections'), findsOneWidget);
      expect(find.text('Request summary'), findsWidgets);
    },
  );

  testWidgets('UUID-only journal id is scrubbed from Need approval list', (
    WidgetTester tester,
  ) async {
    const String uuid = '550e8400-e29b-41d4-a716-446655440000';
    await _pumpApprovalsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      items: const <AccountsWorkItem>[
        AccountsWorkItem(
          id: uuid,
          kind: AccountsWorkItemKind.approval,
          displayId: uuid,
          journalDisplayId: uuid,
          status: 'PENDING',
          amount: 10,
          canApproveFlag: true,
        ),
      ],
    );

    expect(find.textContaining(uuid), findsNothing);
  });

  testWidgets('approval print HTML never includes raw UUID', (
    WidgetTester tester,
  ) async {
    const String uuid = '550e8400-e29b-41d4-a716-446655440000';
    const AccountsWorkItem item = AccountsWorkItem(
      id: uuid,
      kind: AccountsWorkItemKind.approval,
      displayId: 'JE-9',
      journalDisplayId: 'JE-9',
      status: 'PENDING',
      amount: 40,
      requestType: 'VOID',
      requestedByDisplayId: uuid,
      requestReason: uuid,
      canApproveFlag: true,
    );

    late String html;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            html = accountsApprovalHtml(context, item);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html.contains(uuid), isFalse);
    expect(html.contains('JE-9'), isTrue);
    expect(html.contains('Request summary'), isTrue);
  });
}
