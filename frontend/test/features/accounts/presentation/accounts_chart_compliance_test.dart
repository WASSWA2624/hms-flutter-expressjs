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
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_chart_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_chart_repository.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockChartRepository extends Mock implements AccountsChartRepository {}

const AccountsChartAccount _cash = AccountsChartAccount(
  id: '550e8400-e29b-41d4-a716-446655440020',
  code: '1000',
  name: 'Cash',
  accountType: 'ASSET',
  currency: 'UGX',
  isActive: true,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 2,
  chartActive: 14,
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

void _stubAccounts(_MockAccountsRepository repository) {
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

void _stubChart(
  _MockChartRepository repository, {
  int filteredTotal = 2,
  List<AccountsChartAccount> items = const <AccountsChartAccount>[_cash],
}) {
  when(
    () => repository.listAccounts(
      any(),
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer((Invocation inv) async {
    final AccountsChartQuery query =
        inv.positionalArguments.first as AccountsChartQuery;
    final bool narrowed =
        query.search.trim().isNotEmpty ||
        query.accountType.trim().isNotEmpty ||
        query.currency.trim().isNotEmpty ||
        query.isActive != null;
    return Result<AppPage<AccountsChartAccount>>.success(
      AppPage<AccountsChartAccount>(
        items: items,
        request: const AppPageRequest(pageSize: 100),
        totalItemCount: narrowed ? filteredTotal : items.length,
      ),
    );
  });
}

Future<void> _pumpChart(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  int filteredTotal = 2,
  List<AccountsChartAccount> items = const <AccountsChartAccount>[_cash],
  String location = '/accounts?section=chart',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  final _MockChartRepository chart = _MockChartRepository();
  _stubAccounts(accounts);
  _stubChart(chart, filteredTotal: filteredTotal, items: items);

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
        accountsChartRepositoryProvider.overrideWithValue(chart),
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
  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsGlQuery());
    registerFallbackValue(const AccountsChartQuery());
  });

  test('Account chart default columns are five (incl. Actions)', () {
    expect(accountsChartDefaultColumnIds, <String>[
      accountsChartAccountColumnId,
      accountsChartTypeColumnId,
      accountsChartCodeColumnId,
      accountsChartStatusColumnId,
      accountsChartActionsColumnId,
    ]);
    expect(
      accountsSectionCountTone(AccountsDeskSection.chart),
      AppTabCountTone.info,
    );
  });

  testWidgets(
    'Account chart toolbar: Filters → Settings → Export → Print → Add',
    (WidgetTester tester) async {
      await _pumpChart(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      final AppListTable<AccountsChartAccount> table =
          tester.widget<AppListTable<AccountsChartAccount>>(
            find.byType(AppListTable<AccountsChartAccount>),
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
        table.columns.map((AppListTableColumn<AccountsChartAccount> c) => c.id),
        containsAll(accountsChartDefaultColumnIds),
      );
      expect(table.columnChoices?.length, 3);
      expect(
        table.search?.trailingActions.map((AppSearchBarAction a) => a.label),
        <String>['Add'],
      );
      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
      expect(find.byTooltip('Add'), findsOneWidget);
    },
  );

  testWidgets(
    'Account chart Export/Print omit without evidence:export; Actions omit without write',
    (WidgetTester tester) async {
      await _pumpChart(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      final AppListTable<AccountsChartAccount> table =
          tester.widget<AppListTable<AccountsChartAccount>>(
            find.byType(AppListTable<AccountsChartAccount>),
          );
      expect(table.canExport, isFalse);
      expect(table.canPrint, isFalse);
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
      expect(find.byTooltip('Add'), findsNothing);
      // Justified: Actions omitted without chart write → 4 defaults.
      expect(table.columns.length, 4);
      expect(
        table.columns.any(
          (AppListTableColumn<AccountsChartAccount> c) =>
              c.id == accountsChartActionsColumnId,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'Account chart Advanced filters footer Clear filters → Apply filters → Close',
    (WidgetTester tester) async {
      await _pumpChart(
        tester,
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
    'Account chart badge uses summary; active search uses filtered total',
    (WidgetTester tester) async {
      await _pumpChart(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        filteredTotal: 3,
      );

      final Finder searchField = find.descendant(
        of: find.byType(AppListTable<AccountsChartAccount>),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField.first, 'Cash');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byKey(accountsSectionTabsKey),
      );
      final AppTabItem chart = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.accountChartLabel,
      );
      final AppTabItem work = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.openWorkLabel,
      );
      expect(chart.count, 3);
      expect(work.count, 7);
      expect(chart.countTone, AppTabCountTone.info);
    },
  );

  testWidgets('alias coa selects Account chart', (WidgetTester tester) async {
    await _pumpChart(
      tester,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      location: '/accounts?section=coa',
    );
    expect(find.text(AccountsStrings.accountChartLabel), findsWidgets);
    expect(find.text('Cash'), findsWidgets);
  });

  testWidgets('row opens Edit account with generic title when write', (
    WidgetTester tester,
  ) async {
    await _pumpChart(
      tester,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    await tester.tap(find.text('Cash').first);
    await tester.pumpAndSettle();
    expect(find.text(AccountsStrings.chartEditTitle.toUpperCase()), findsWidgets);
    expect(find.textContaining(_cash.id), findsNothing);
  });
}
