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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_books_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<String> modules = const <String>[
    'facility-accounts',
    'billing-payments',
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['ACCOUNTS'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: <AppModuleEntitlement>[
        for (final String code in modules)
          AppModuleEntitlement(code: code, licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(_MockAccountsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(
        summary: AccountsSummary(openPeriods: 1),
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
    () => repository.listPeriods(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => Result<AppPage<AccountsFiscalPeriod>>.success(
      AppPage<AccountsFiscalPeriod>(
        items: <AccountsFiscalPeriod>[
          AccountsFiscalPeriod(
            id: 'period-1',
            label: 'FY2026-Q1',
            status: 'OPEN',
            openedAt: DateTime.utc(2026, 1, 1),
            unpostedJournalCount: 2,
            pendingApprovalsCount: 1,
          ),
          AccountsFiscalPeriod(
            id: 'period-2',
            label: 'FY2025-Q4',
            status: 'PENDING_APPROVAL',
            openedAt: DateTime.utc(2025, 10, 1),
            pendingApprovalId: 'approval-1',
            pendingApprovalsCount: 1,
          ),
        ],
        request: const AppPageRequest(pageSize: 100),
        totalItemCount: 2,
      ),
    ),
  );
}

Future<void> _pumpBooks(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  String location = '/accounts?section=books',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository repository = _MockAccountsRepository();
  _stubWorkspace(repository);

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
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsPeriodQuery());
  });

  testWidgets('Close books tab visible with tooltip; write trailing present', (
    WidgetTester tester,
  ) async {
    await _pumpBooks(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    expect(find.byType(AccountsWorkspacePage), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip(AccountsStrings.closeBooksTooltip), findsWidgets);
    expect(find.byType(AccountsBooksPanel), findsOneWidget);
    expect(find.byTooltip(AccountsStrings.openPeriodAction), findsOneWidget);
    expect(find.byTooltip(AccountsStrings.closePeriodAction), findsOneWidget);
    expect(find.text(AccountsStrings.closeAction), findsWidgets);
  });

  testWidgets('Open/Close trailing absent without accounts:write', (
    WidgetTester tester,
  ) async {
    await _pumpBooks(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    expect(find.byType(AccountsBooksPanel), findsOneWidget);
    expect(find.byTooltip(AccountsStrings.openPeriodAction), findsNothing);
    expect(find.byTooltip(AccountsStrings.closePeriodAction), findsNothing);
    expect(find.text(AccountsStrings.closeAction), findsNothing);
  });

  testWidgets('Approve Next absent without financial:approve', (
    WidgetTester tester,
  ) async {
    await _pumpBooks(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    expect(find.text(AccountsStrings.approveAction), findsNothing);
    expect(find.text(AccountsStrings.booksAction), findsWidgets);
  });

  testWidgets('Approve Next present with write ∩ financial:approve', (
    WidgetTester tester,
  ) async {
    await _pumpBooks(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
          AppPermissions.financialApprove,
        },
      ),
    );

    expect(
      find.byTooltip(AccountsStrings.approveActionTooltip),
      findsWidgets,
    );
    expect(find.text(AccountsStrings.closeAction), findsWidgets);
  });

  testWidgets('Alias period-close selects Close books and writes section=books', (
    WidgetTester tester,
  ) async {
    await _pumpBooks(
      tester,
      location: '/accounts?section=period-close',
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    expect(find.byType(AccountsBooksPanel), findsOneWidget);
  });

  testWidgets('Empty periods show No periods match.', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final _MockAccountsRepository repository = _MockAccountsRepository();
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
      () => repository.listPeriods(
        any(),
        facilityId: any(named: 'facilityId'),
      ),
    ).thenAnswer(
      (_) async => const Result<AppPage<AccountsFiscalPeriod>>.success(
        AppPage<AccountsFiscalPeriod>(
          items: <AccountsFiscalPeriod>[],
          request: AppPageRequest(pageSize: 100),
          totalItemCount: 0,
        ),
      ),
    );

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/accounts?section=books',
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
          appAccessPolicyProvider.overrideWithValue(
            _policyFor(
              permissions: <AppPermission>{AppPermissions.accountsRead},
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(AccountsStrings.booksEmpty), findsWidgets);
  });
}
