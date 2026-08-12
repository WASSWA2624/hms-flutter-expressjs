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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_table_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsWorkItem _draftJournal = AccountsWorkItem(
  id: 'je-draft',
  kind: AccountsWorkItemKind.journal,
  displayId: 'JE-DRAFT',
  journalDisplayId: 'JE-DRAFT',
  periodLabel: '2026-08',
  status: 'DRAFT',
  amount: 250,
  sourceLabel: 'Manual',
  canPostFlag: true,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 5,
  needApproval: 2,
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
  int filteredTotal = 1,
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_draftJournal],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(summary: _summary),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((Invocation inv) async {
    final AccountsWorkspaceQuery query =
        inv.positionalArguments.first as AccountsWorkspaceQuery;
    final bool narrowed =
        query.search.trim().isNotEmpty || query.hasActiveFilters;
    return Result<AppPage<AccountsWorkItem>>.success(
      AppPage<AccountsWorkItem>(
        items: items,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: narrowed ? filteredTotal : items.length,
      ),
    );
  });
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

Future<void> _pumpJournals(
  WidgetTester tester, {
  required _MockAccountsRepository repository,
  required AppAccessPolicy accessPolicy,
  int filteredTotal = 1,
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_draftJournal],
  String location = '/accounts?section=journals',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, filteredTotal: filteredTotal, items: items);

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

  test('To post default columns are five (incl. Post Next)', () {
    expect(accountsDefaultColumnIds[AccountsDeskSection.journals], <String>[
      accountsJournalColumnId,
      accountsPeriodColumnId,
      accountsAmountColumnId,
      accountsStatusColumnId,
      accountsNextActionColumnId,
    ]);
    expect(
      accountsSectionCountTone(AccountsDeskSection.journals),
      AppTabCountTone.warning,
    );
  });

  testWidgets(
    'To post toolbar: Filters → Settings → Export → Print → Post all',
    (WidgetTester tester) async {
      await _pumpJournals(
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

      final AppListTable<AccountsWorkItem> table =
          tester.widget<AppListTable<AccountsWorkItem>>(
            find.byType(AppListTable<AccountsWorkItem>),
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
        table.columns.map((AppListTableColumn<AccountsWorkItem> c) => c.id),
        containsAll(<String>[
          accountsJournalColumnId,
          accountsPeriodColumnId,
          accountsAmountColumnId,
          accountsStatusColumnId,
          accountsNextActionColumnId,
        ]),
      );
      final List<AppSearchBarAction> trailing =
          table.search?.trailingActions ?? const <AppSearchBarAction>[];
      expect(trailing.last.label, AccountsStrings.postAllAction);
      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
      expect(find.byTooltip(AccountsStrings.postAllAction), findsOneWidget);
    },
  );

  testWidgets(
    'To post Export/Print/Post all omit without grants; Next column omit without write',
    (WidgetTester tester) async {
      await _pumpJournals(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      final AppListTable<AccountsWorkItem> table =
          tester.widget<AppListTable<AccountsWorkItem>>(
            find.byType(AppListTable<AccountsWorkItem>),
          );
      expect(table.canExport, isFalse);
      expect(table.canPrint, isFalse);
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
      expect(find.byTooltip(AccountsStrings.postAllAction), findsNothing);
      // Justified: Next omitted without accounts:write → 4 defaults.
      expect(table.columns.length, 4);
      expect(
        table.columns.any(
          (AppListTableColumn<AccountsWorkItem> c) =>
              c.id == accountsNextActionColumnId,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'To post Advanced filters footer Clear filters → Apply filters → Close',
    (WidgetTester tester) async {
      await _pumpJournals(
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
    'To post badge uses summary; active search uses filtered total',
    (WidgetTester tester) async {
      await _pumpJournals(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        filteredTotal: 2,
        location: '/accounts?section=journals&search=JE',
      );

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem journals = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.toPostLabel,
      );
      final AppTabItem work = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.openWorkLabel,
      );
      expect(journals.count, 2);
      expect(work.count, 7);
      expect(journals.countTone, AppTabCountTone.warning);
    },
  );

  testWidgets('To post aliases unposted/ready-to-post select journals', (
    WidgetTester tester,
  ) async {
    await _pumpJournals(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      location: '/accounts?section=unposted',
    );
    expect(find.text(AccountsStrings.toPostLabel), findsWidgets);
    expect(find.text('JE-DRAFT'), findsWidgets);
  });

  testWidgets('row opens detail with generic Journal title', (
    WidgetTester tester,
  ) async {
    await _pumpJournals(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    await tester.tap(find.text('JE-DRAFT').first);
    await tester.pumpAndSettle();
    expect(find.text('JOURNAL'), findsWidgets);
    expect(find.textContaining('je-draft'), findsNothing);
  });
}
