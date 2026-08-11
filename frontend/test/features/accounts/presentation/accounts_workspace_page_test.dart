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
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_gl_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsGlAccount _cash = AccountsGlAccount(
  id: 'acc-cash',
  name: 'Cash on hand',
  code: '1000',
  debit: 500,
  credit: 100,
  balance: 400,
  hasActivity: true,
);

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['ACCOUNTANT'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'facility-accounts',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBase(
  _MockAccountsRepository repository, {
  List<AccountsGlAccount> glAccounts = const <AccountsGlAccount>[],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(
        summary: AccountsSummary(glActivity: glAccounts.length),
      ),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<AccountsWorkItem>>.success(
      AppPage<AccountsWorkItem>(
        items: <AccountsWorkItem>[],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(
    () => repository.listGlAccounts(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => Result<AppPage<AccountsGlAccount>>.success(
      AppPage<AccountsGlAccount>(
        items: glAccounts,
        request: const AppPageRequest(pageSize: 100),
        totalItemCount: glAccounts.length,
      ),
    ),
  );
  when(
    () => repository.getAccountLedger(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => const Result<AccountsGlLedger>.success(
      AccountsGlLedger(
        account: _cash,
        summary: AccountsGlLedgerSummary(debit: 500, credit: 100, balance: 400),
      ),
    ),
  );
}

Future<GoRouter> _pumpAccounts(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  required String location,
  List<AccountsGlAccount> glAccounts = const <AccountsGlAccount>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  _stubBase(accounts, glAccounts: glAccounts);

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
        accountsRepositoryProvider.overrideWithValue(accounts),
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
  return router;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsGlQuery());
  });

  test('section URL aliases resolve to gl', () {
    expect(
      AccountsWorkspaceQuery.fromUri(Uri.parse('/accounts?section=gl')).section,
      AccountsDeskSection.gl,
    );
    expect(
      AccountsWorkspaceQuery.fromUri(
        Uri.parse('/accounts?section=general-ledger'),
      ).section,
      AccountsDeskSection.gl,
    );
    expect(
      AccountsWorkspaceQuery.fromUri(
        Uri.parse('/accounts?section=ledger'),
      ).section,
      AccountsDeskSection.gl,
    );
    expect(
      AccountsWorkspaceQuery.fromUri(Uri.parse('/accounts?tab=gl')).section,
      AccountsDeskSection.gl,
    );
  });

  testWidgets('section=gl selects General ledger and shows empty state', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpAccounts(
      tester,
      location: '/accounts?section=gl',
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    expect(find.byType(AccountsGlPanel), findsOneWidget);
    expect(find.text('No accounts match.'), findsWidgets);
    expect(router.routeInformationProvider.value.uri.queryParameters['section'],
        anyOf('gl', isNull));
  });

  testWidgets('general-ledger alias selects GL body', (WidgetTester tester) async {
    await _pumpAccounts(
      tester,
      location: '/accounts?section=general-ledger',
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    expect(find.byType(AccountsGlPanel), findsOneWidget);
  });

  testWidgets('row opens Account ledger; Journal present with write', (
    WidgetTester tester,
  ) async {
    await _pumpAccounts(
      tester,
      location: '/accounts?section=gl',
      glAccounts: const <AccountsGlAccount>[_cash],
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    expect(find.textContaining('Cash on hand'), findsWidgets);
    expect(find.text('GL'), findsOneWidget);

    final AppListTable<AccountsGlAccount> table = tester.widget(
      find.byType(AppListTable<AccountsGlAccount>),
    );
    expect(table.onRowSelected, isNotNull);
    table.onRowSelected!(_cash);
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT LEDGER'), findsOneWidget);
    expect(find.text('Debit'), findsWidgets);
    expect(find.text('Credit'), findsWidgets);
    expect(find.text('Balance'), findsWidgets);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Post'), findsNothing);
  });

  testWidgets('Next GL opens Account ledger', (WidgetTester tester) async {
    await _pumpAccounts(
      tester,
      location: '/accounts?section=gl',
      glAccounts: const <AccountsGlAccount>[_cash],
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    final AppListTable<AccountsGlAccount> table = tester.widget(
      find.byType(AppListTable<AccountsGlAccount>),
    );
    expect(table.onRowSelected, isNotNull);
    table.onRowSelected!(_cash);
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT LEDGER'), findsOneWidget);
    expect(find.text('Journal'), findsNothing);
  });

  testWidgets('accountId deep link opens Account ledger after load', (
    WidgetTester tester,
  ) async {
    await _pumpAccounts(
      tester,
      location: '/accounts?section=gl&accountId=acc-cash',
      glAccounts: const <AccountsGlAccount>[_cash],
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    expect(find.text('ACCOUNT LEDGER'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
  });

  testWidgets('Journal omitted without write on deep-linked ledger', (
    WidgetTester tester,
  ) async {
    await _pumpAccounts(
      tester,
      location: '/accounts?section=gl&accountId=acc-cash',
      glAccounts: const <AccountsGlAccount>[_cash],
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    expect(find.text('ACCOUNT LEDGER'), findsOneWidget);
    expect(find.text('Journal'), findsNothing);
    expect(find.text('Post'), findsNothing);
  });
}
