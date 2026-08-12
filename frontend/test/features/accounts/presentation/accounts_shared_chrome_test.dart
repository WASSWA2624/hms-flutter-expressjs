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
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsWorkItem _draftJournal = AccountsWorkItem(
  id: 'jnl-draft',
  kind: AccountsWorkItemKind.journal,
  displayId: 'JE-100',
  journalDisplayId: 'JE-100',
  sourceLabel: 'Manual',
  status: 'DRAFT',
  amount: 250,
  canPostFlag: true,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 1,
  toPost: 1,
  needApproval: 1,
  glActivity: 3,
  ledgersWithBalance: 2,
  chartActive: 4,
  openPeriods: 1,
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

void _stubRepository(_MockAccountsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(summary: _summary),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => Result<AppPage<AccountsWorkItem>>.success(
      AppPage<AccountsWorkItem>(
        items: const <AccountsWorkItem>[_draftJournal],
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: 1,
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

Future<void> _pumpAccounts(
  WidgetTester tester, {
  required _MockAccountsRepository repository,
  required AppAccessPolicy accessPolicy,
  String location = '/accounts?section=work',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

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

  testWidgets(
    'shared chrome: Filters → Settings → Export → Print → context order',
    (WidgetTester tester) async {
      await _pumpAccounts(
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
      expect(table.columnVisibilityLabel, isNotNull);
      expect(table.enableExport, isTrue);
      expect(table.canExport, isTrue);
      expect(table.enablePrint, isTrue);
      expect(table.canPrint, isTrue);
      expect(table.printLabel, 'Print');
      expect(table.onPrint, isNotNull);

      final List<AppSearchBarAction> trailing =
          table.search?.trailingActions ?? const <AppSearchBarAction>[];
      expect(trailing.isNotEmpty, isTrue);
      expect(trailing.last.label, 'Journal');

      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);
    },
  );

  testWidgets(
    'shared chrome: Export/Print omitted without evidence:export',
    (WidgetTester tester) async {
      await _pumpAccounts(
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
    },
  );

  testWidgets('shared chrome: strip uses authoritative summary counts', (
    WidgetTester tester,
  ) async {
    await _pumpAccounts(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    final AppTabStrip strip = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    final AppTabItem work = strip.tabs.firstWhere(
      (AppTabItem tab) => tab.label == 'Open work',
    );
    final AppTabItem journals = strip.tabs.firstWhere(
      (AppTabItem tab) => tab.label == 'To post',
    );
    expect(work.count, 1);
    expect(journals.count, 1);
    expect(work.countTone, AppTabCountTone.info);
    expect(journals.countTone, AppTabCountTone.warning);
  });
}
