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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_approvals_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsWorkItem _pendingApproval = AccountsWorkItem(
  id: 'apr-1',
  kind: AccountsWorkItemKind.approval,
  displayId: 'APR-1',
  journalDisplayId: 'JE-200',
  status: 'PENDING',
  amount: 100,
  requestType: 'JOURNAL_POST',
  canApproveFlag: true,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 5,
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
  int filteredTotal = 1,
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_pendingApproval],
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

Future<void> _pumpApprovals(
  WidgetTester tester, {
  required _MockAccountsRepository repository,
  required AppAccessPolicy accessPolicy,
  int filteredTotal = 1,
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_pendingApproval],
  String location = '/accounts?section=approvals',
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

  test('Need approval default columns are five (incl. Type + Next)', () {
    expect(accountsApprovalsDefaultColumnIds, <String>[
      accountsApprovalsJournalColumnId,
      accountsApprovalsTypeColumnId,
      accountsApprovalsAmountColumnId,
      accountsApprovalsStatusColumnId,
      accountsApprovalsNextColumnId,
    ]);
    expect(
      accountsSectionCountTone(AccountsDeskSection.approvals),
      AppTabCountTone.warning,
    );
  });

  testWidgets(
    'Need approval toolbar: Filters → Settings → Export → Print (no context)',
    (WidgetTester tester) async {
      await _pumpApprovals(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
            AppPermissions.financialApprove,
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
          accountsApprovalsJournalColumnId,
          accountsApprovalsTypeColumnId,
          accountsApprovalsAmountColumnId,
          accountsApprovalsStatusColumnId,
          accountsApprovalsNextColumnId,
        ]),
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
    'Need approval Export/Print omit without evidence:export; Next omit without approve',
    (WidgetTester tester) async {
      await _pumpApprovals(
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
      // Justified: Next omitted without financial:approve → 4 defaults.
      expect(table.columns.length, 4);
      expect(
        table.columns.any(
          (AppListTableColumn<AccountsWorkItem> c) =>
              c.id == accountsApprovalsNextColumnId,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'Need approval Advanced filters footer Clear filters → Apply filters → Close',
    (WidgetTester tester) async {
      await _pumpApprovals(
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
    'Need approval badge uses summary; active search uses filtered total',
    (WidgetTester tester) async {
      await _pumpApprovals(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        filteredTotal: 2,
        location: '/accounts?section=approvals&search=APR',
      );

      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem approvals = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.needApprovalLabel,
      );
      final AppTabItem work = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label == AccountsStrings.openWorkLabel,
      );
      expect(approvals.count, 2);
      expect(work.count, 7);
      expect(approvals.countTone, AppTabCountTone.warning);
    },
  );

  testWidgets('Need approval alias approval-required selects section', (
    WidgetTester tester,
  ) async {
    await _pumpApprovals(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      location: '/accounts?section=approval-required',
    );
    expect(find.text(AccountsStrings.needApprovalLabel), findsWidgets);
    expect(find.text('JE-200'), findsWidgets);
  });

  testWidgets('row opens detail with generic Approval title', (
    WidgetTester tester,
  ) async {
    await _pumpApprovals(
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

    await tester.tap(find.text('JE-200').first);
    await tester.pumpAndSettle();
    expect(find.text('APPROVAL'), findsWidgets);
    expect(find.textContaining('apr-1'), findsNothing);
  });
}
