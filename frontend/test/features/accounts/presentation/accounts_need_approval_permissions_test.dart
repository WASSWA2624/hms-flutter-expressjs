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
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
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
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(summary: summary),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((_) async {
    return Result<AppPage<AccountsWorkItem>>.success(
      AppPage<AccountsWorkItem>(
        items: items,
        request: const AppPageRequest(pageSize: 20),
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.approveRequest(any(), notes: any(named: 'notes')))
      .thenAnswer(
    (_) async => const Result<AccountsMutationResult>.success(
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
    ),
  );
  when(
    () => repository.rejectRequest(
      any(),
      reason: any(named: 'reason'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer(
    (_) async => const Result<AccountsMutationResult>.success(
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
    ),
  );
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
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, summary: summary);

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
      await _pumpApprovalsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      expect(find.text(AccountsStrings.needApprovalLabel), findsWidgets);
      expect(find.text(AccountsStrings.approveAction), findsNothing);
      expect(find.text(AccountsStrings.rejectAction), findsNothing);
      expect(find.text('JE-001'), findsOneWidget);
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
    );

    await tester.tap(find.text(AccountsStrings.approveAction).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AccountsStrings.approveAction).last);
    await tester.pumpAndSettle();

    verify(
      () => repository.approveRequest('apr-1', notes: any(named: 'notes')),
    ).called(1);
    expect(find.text(AccountsStrings.saved), findsOneWidget);
  });
}
