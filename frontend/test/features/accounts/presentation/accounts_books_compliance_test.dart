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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_books_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

final AccountsFiscalPeriod _openPeriod = AccountsFiscalPeriod(
  id: 'period-1',
  label: 'FY2026-Q1',
  status: 'OPEN',
  openedAt: DateTime.utc(2026, 1, 1),
  unpostedJournalCount: 2,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 2,
  openPeriods: 8,
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
        AppModuleEntitlement(
          code: 'billing-payments',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockAccountsRepository repository, {
  int filteredTotal = 2,
  List<AccountsFiscalPeriod>? periods,
}) {
  final List<AccountsFiscalPeriod> items = periods ?? <AccountsFiscalPeriod>[_openPeriod];
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
  when(
    () => repository.listPeriods(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer((Invocation inv) async {
    final AccountsPeriodQuery query =
        inv.positionalArguments.first as AccountsPeriodQuery;
    final bool narrowed =
        query.search.trim().isNotEmpty || query.openOnly || query.overdueOnly;
    return Result<AppPage<AccountsFiscalPeriod>>.success(
      AppPage<AccountsFiscalPeriod>(
        items: items,
        request: const AppPageRequest(pageSize: 100),
        totalItemCount: narrowed ? filteredTotal : items.length,
      ),
    );
  });
}

Future<void> _pumpBooks(
  WidgetTester tester, {
  required _MockAccountsRepository repository,
  required AppAccessPolicy accessPolicy,
  int filteredTotal = 2,
  String location = '/accounts?section=books',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, filteredTotal: filteredTotal);

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
    registerFallbackValue(const AccountsPeriodQuery());
  });

  setUp(() {
    repository = _MockAccountsRepository();
  });

  test('Close books default columns are five (incl. Next)', () {
    expect(accountsBooksDefaultColumnIds, <String>[
      accountsBooksPeriodColumnId,
      accountsBooksStatusColumnId,
      accountsBooksOpenedColumnId,
      accountsBooksClosedColumnId,
      accountsBooksNextColumnId,
    ]);
    expect(
      accountsSectionCountTone(AccountsDeskSection.books),
      AppTabCountTone.warning,
    );
  });

  testWidgets(
    'Close books toolbar: Filters → Settings → Export → Print → Open/Close period',
    (WidgetTester tester) async {
      await _pumpBooks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
            AppPermissions.evidenceExport,
          },
        ),
      );

      final AppListTable<AccountsFiscalPeriod> table =
          tester.widget<AppListTable<AccountsFiscalPeriod>>(
            find.byType(AppListTable<AccountsFiscalPeriod>),
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
        table.columns.map((AppListTableColumn<AccountsFiscalPeriod> c) => c.id),
        containsAll(accountsBooksDefaultColumnIds),
      );
      expect(table.columnChoices?.length, 2);
      expect(
        table.search?.trailingActions.map((AppSearchBarAction a) => a.label),
        <String>[
          AccountsStrings.openPeriodAction,
          AccountsStrings.closePeriodAction,
        ],
      );
      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
    },
  );

  testWidgets(
    'Close books Export/Print omit without evidence:export; Open/Close omit without write',
    (WidgetTester tester) async {
      await _pumpBooks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      final AppListTable<AccountsFiscalPeriod> table =
          tester.widget<AppListTable<AccountsFiscalPeriod>>(
            find.byType(AppListTable<AccountsFiscalPeriod>),
          );
      expect(table.canExport, isFalse);
      expect(table.canPrint, isFalse);
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
      expect(find.byTooltip(AccountsStrings.openPeriodAction), findsNothing);
      expect(find.byTooltip(AccountsStrings.closePeriodAction), findsNothing);
      expect(table.columns.length, 5);
    },
  );

  testWidgets(
    'Close books Advanced filters footer Clear filters → Apply filters → Close',
    (WidgetTester tester) async {
      await _pumpBooks(
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
    'Close books badge uses summary; active search uses filtered total',
    (WidgetTester tester) async {
      await _pumpBooks(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        filteredTotal: 3,
        location: '/accounts?section=books&search=FY2026',
      );

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem books = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.closeBooksLabel,
      );
      final AppTabItem work = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.openWorkLabel,
      );
      expect(books.count, 3);
      expect(work.count, 7);
      expect(books.countTone, AppTabCountTone.warning);
    },
  );

  testWidgets('alias period-close selects Close books', (
    WidgetTester tester,
  ) async {
    await _pumpBooks(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      location: '/accounts?section=period-close',
    );
    expect(find.text(AccountsStrings.closeBooksLabel), findsWidgets);
    expect(find.text('FY2026-Q1'), findsOneWidget);
  });

  testWidgets('row opens Period detail with generic title', (
    WidgetTester tester,
  ) async {
    await _pumpBooks(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    await tester.tap(find.text('FY2026-Q1'));
    await tester.pumpAndSettle();
    expect(find.text('PERIOD'), findsWidgets);
    expect(find.textContaining('period-1'), findsNothing);
  });
}
