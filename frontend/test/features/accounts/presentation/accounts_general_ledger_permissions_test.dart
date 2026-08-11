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

void _stubEmpty(_MockAccountsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(),
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
    (_) async => const Result<AppPage<AccountsGlAccount>>.success(
      AppPage<AccountsGlAccount>(
        items: <AccountsGlAccount>[],
        request: AppPageRequest(pageSize: 100),
        totalItemCount: 0,
      ),
    ),
  );
}

Future<void> _pumpGl(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  String location = '/accounts?section=gl',
  void Function(_MockAccountsRepository repository)? customize,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  _stubEmpty(accounts);
  customize?.call(accounts);

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
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsGlQuery());
  });

  testWidgets('General ledger tab visible with accounts read', (
    WidgetTester tester,
  ) async {
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    expect(find.byType(AccountsWorkspacePage), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('General ledger'), findsWidgets);
    expect(find.byTooltip(
      'Facility account balances and activity by GL account',
    ), findsOneWidget);
    expect(find.byType(AccountsGlPanel), findsOneWidget);
    expect(find.text('No accounts match.'), findsWidgets);
  });

  testWidgets('Journal in Account ledger absent without accounts:write', (
    WidgetTester tester,
  ) async {
    const AccountsGlAccount account = AccountsGlAccount(
      id: 'acc-1',
      name: 'Cash',
      code: '1000',
      hasActivity: true,
    );
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      customize: (_MockAccountsRepository repository) {
        when(
          () => repository.listGlAccounts(
            any(),
            facilityId: any(named: 'facilityId'),
          ),
        ).thenAnswer(
          (_) async => const Result<AppPage<AccountsGlAccount>>.success(
            AppPage<AccountsGlAccount>(
              items: <AccountsGlAccount>[account],
              request: AppPageRequest(pageSize: 100),
              totalItemCount: 1,
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
            AccountsGlLedger(account: account),
          ),
        );
      },
    );

    final AppListTable<AccountsGlAccount> table = tester.widget(
      find.byType(AppListTable<AccountsGlAccount>),
    );
    expect(table.onRowSelected, isNotNull);
    table.onRowSelected!(account);
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT LEDGER'), findsOneWidget);
    expect(find.text('Journal'), findsNothing);
    expect(find.text('Post'), findsNothing);
  });
}
