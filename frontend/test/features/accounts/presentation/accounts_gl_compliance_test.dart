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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsGlAccount _cash = AccountsGlAccount(
  id: 'acc-1',
  name: 'Cash',
  code: '1000',
  type: 'ASSET',
  hasActivity: true,
  debit: 100,
  credit: 20,
  balance: 80,
);

const AccountsGlAccount _dormant = AccountsGlAccount(
  id: 'acc-2',
  name: 'Dormant',
  code: '1999',
  type: 'ASSET',
  hasActivity: false,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 2,
  glActivity: 9,
);

AppAccessPolicy _policy({required Set<AppPermission> permissions}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
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

void _stubRepository(
  _MockAccountsRepository repository, {
  int glTotal = 2,
  List<AccountsGlAccount> accounts = const <AccountsGlAccount>[_cash, _dormant],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(summary: _summary),
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
  ).thenAnswer((Invocation inv) async {
    final AccountsGlQuery query =
        inv.positionalArguments.first as AccountsGlQuery;
    final bool narrowed =
        query.search.trim().isNotEmpty ||
        query.accountType.trim().isNotEmpty ||
        query.period.trim().isNotEmpty ||
        query.hasActivity != null;
    return Result<AppPage<AccountsGlAccount>>.success(
      AppPage<AccountsGlAccount>(
        items: accounts,
        request: const AppPageRequest(pageSize: 100),
        totalItemCount: narrowed ? glTotal : accounts.length,
      ),
    );
  });
  when(
    () => repository.getAccountLedger(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => const Result<AccountsGlLedger>.success(
      AccountsGlLedger(
        account: _cash,
        summary: AccountsGlLedgerSummary(debit: 100, credit: 20, balance: 80),
        entries: <AccountsGlLedgerEntry>[],
      ),
    ),
  );
}

Future<void> _pumpGl(
  WidgetTester tester, {
  required _MockAccountsRepository repository,
  required AppAccessPolicy accessPolicy,
  int glTotal = 2,
  List<AccountsGlAccount> accounts = const <AccountsGlAccount>[_cash, _dormant],
  String location = '/accounts?section=gl',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, glTotal: glTotal, accounts: accounts);

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
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(seconds: 1));
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

  test('General ledger default columns are five (incl. Next)', () {
    expect(accountsGlDefaultColumnIds, <String>[
      accountsGlAccountColumnId,
      accountsGlDebitColumnId,
      accountsGlCreditColumnId,
      accountsGlBalanceColumnId,
      accountsGlNextColumnId,
    ]);
    expect(
      accountsSectionCountTone(AccountsDeskSection.gl),
      AppTabCountTone.info,
    );
  });

  testWidgets(
    'General ledger toolbar: Filters → Settings → Export → Print (no context)',
    (WidgetTester tester) async {
      await _pumpGl(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.evidenceExport,
          },
        ),
      );

      final AppListTable<AccountsGlAccount> table =
          tester.widget<AppListTable<AccountsGlAccount>>(
            find.byType(AppListTable<AccountsGlAccount>),
          );
      expect(table.search?.advancedFilterButtonLabel, 'Filters');
      expect(table.search?.advancedFilterApplyLabel, 'Apply filters');
      expect(table.search?.advancedFilterResetLabel, 'Clear filters');
      expect(table.search?.advancedFilterCloseLabel, 'Close');
      expect(table.columnVisibilityLabel, 'Settings');
      expect(table.enableExport, isTrue);
      expect(table.canExport, isTrue);
      expect(table.enablePrint, isTrue);
      expect(table.canPrint, isTrue);
      expect(table.printLabel, 'Print');
      expect(table.columns.length, 5);
      expect(
        table.columns.map((AppListTableColumn<AccountsGlAccount> c) => c.id),
        containsAll(accountsGlDefaultColumnIds),
      );
      expect(table.columnChoices?.length, 3);
      expect(
        table.search?.trailingActions ?? const <AppSearchBarAction>[],
        isEmpty,
      );
      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
    },
  );

  testWidgets(
    'General ledger Export/Print omit without evidence:export',
    (WidgetTester tester) async {
      await _pumpGl(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      final AppListTable<AccountsGlAccount> table =
          tester.widget<AppListTable<AccountsGlAccount>>(
            find.byType(AppListTable<AccountsGlAccount>),
          );
      expect(table.canExport, isFalse);
      expect(table.canPrint, isFalse);
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
    },
  );

  testWidgets(
    'General ledger Advanced filters footer Clear filters → Apply filters → Close',
    (WidgetTester tester) async {
      await _pumpGl(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('ADVANCED FILTERS'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Apply filters'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('ADVANCED FILTERS'), findsNothing);
    },
  );

  testWidgets(
    'General ledger badge uses summary; active search uses filtered total',
    (WidgetTester tester) async {
      await _pumpGl(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        glTotal: 2,
        location: '/accounts?section=gl&search=Cash',
      );

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byKey(accountsSectionTabsKey),
      );
      final AppTabItem gl = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.generalLedgerLabel,
      );
      final AppTabItem work = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.openWorkLabel,
      );
      expect(gl.count, 2);
      expect(work.count, 7);
      expect(gl.countTone, AppTabCountTone.info);
    },
  );

  testWidgets('alias ledger selects General ledger', (WidgetTester tester) async {
    await _pumpGl(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      location: '/accounts?section=ledger',
    );
    expect(find.text(AccountsStrings.generalLedgerLabel), findsWidgets);
    expect(find.text('1000 · Cash'), findsOneWidget);
  });

  testWidgets('row opens Account ledger with generic title; dormant is inert', (
    WidgetTester tester,
  ) async {
    await _pumpGl(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    await tester.tap(find.text('1999 · Dormant'));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT LEDGER'), findsNothing);

    await tester.tap(find.text('1000 · Cash'));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT LEDGER'), findsWidgets);
    expect(find.textContaining('acc-1'), findsNothing);
  });
}
