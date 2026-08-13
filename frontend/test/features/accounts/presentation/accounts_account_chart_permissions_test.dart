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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockChartRepository extends Mock implements AccountsChartRepository {}

const AccountsChartAccount _sampleAccount = AccountsChartAccount(
  id: '550e8400-e29b-41d4-a716-446655440020',
  code: '1000',
  name: 'Cash',
  accountType: 'ASSET',
  currency: 'UGX',
  isActive: true,
);

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
}) {
  return AppAccessPolicy.fromSession(_sessionFor(permissions: permissions));
}

AuthSession _sessionFor({required Set<AppPermission> permissions}) {
  return AuthSession(
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
  );
}

void _stubAccounts(_MockAccountsRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(summary: AccountsSummary()),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<AccountsWorkItem>>.success(
      AppPage<AccountsWorkItem>(
        items: <AccountsWorkItem>[],
        request: AppPageRequest(pageSize: 20),
        totalItemCount: 0,
      ),
    ),
  );
}

void _stubChart(
  _MockChartRepository repository, {
  List<AccountsChartAccount> items = const <AccountsChartAccount>[],
}) {
  when(
    () => repository.listAccounts(
      any(),
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => Result<AppPage<AccountsChartAccount>>.success(
      AppPage<AccountsChartAccount>(
        items: items,
        request: const AppPageRequest(pageSize: 100),
        totalItemCount: items.length,
      ),
    ),
  );
  when(() => repository.deactivateAccount(any())).thenAnswer(
    (_) async => const Result<void>.success(null),
  );
  when(() => repository.createAccount(any())).thenAnswer(
    (_) async => const Result<AccountsChartAccount>.success(_sampleAccount),
  );
  when(() => repository.updateAccount(any(), any())).thenAnswer(
    (_) async => const Result<AccountsChartAccount>.success(_sampleAccount),
  );
}

Future<void> _pumpChart(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  String location = '/accounts?section=chart',
  List<AccountsChartAccount> chartItems = const <AccountsChartAccount>[],
  _MockChartRepository? chartRepository,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  final _MockChartRepository chart = chartRepository ?? _MockChartRepository();
  _stubAccounts(accounts);
  if (chartRepository == null) {
    _stubChart(chart, items: chartItems);
  }

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
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsChartQuery());
    registerFallbackValue(<String, Object?>{});
  });

  testWidgets('Account chart visible; Add / Actions absent without chart write', (
    WidgetTester tester,
  ) async {
    final Set<AppPermission> permissions = <AppPermission>{
      AppPermissions.accountsRead,
    };
    await _pumpChart(
      tester,
      accessPolicy: _policyFor(permissions: permissions),
      chartItems: <AccountsChartAccount>[_sampleAccount],
    );

    expect(find.byType(AccountsWorkspacePage), findsOneWidget);
    expect(find.byKey(accountsSectionTabsKey), findsOneWidget);
    expect(find.byType(AccountsChartPanel), findsOneWidget);
    expect(find.text('Cash'), findsWidgets);
    expect(find.byTooltip('Add'), findsNothing);
    expect(find.text(AccountsStrings.chartActionsColumn), findsNothing);
    expect(find.text(AccountsStrings.chartDeactivateAction), findsNothing);
    expect(find.text(AccountsStrings.nextColumn), findsNothing);
    expect(find.text(_sampleAccount.id), findsNothing);
    // Print lives in AppListTable toolbar; omitted without evidence:export.
    expect(find.byTooltip(AccountsStrings.chartPrintAction), findsNothing);
    expect(find.byTooltip('Print'), findsNothing);
  });

  testWidgets('Account chart Export/Print present with evidence:export', (
    WidgetTester tester,
  ) async {
    final Set<AppPermission> permissions = <AppPermission>{
      AppPermissions.accountsRead,
      AppPermissions.evidenceExport,
    };
    await _pumpChart(
      tester,
      accessPolicy: _policyFor(permissions: permissions),
      chartItems: <AccountsChartAccount>[_sampleAccount],
    );

    expect(find.byTooltip('Export'), findsOneWidget);
    expect(find.byTooltip('Print'), findsOneWidget);
    expect(find.byTooltip('Add'), findsNothing);
  });

  testWidgets('Account chart aliases select section=chart body', (
    WidgetTester tester,
  ) async {
    final Set<AppPermission> permissions = <AppPermission>{
      AppPermissions.accountsRead,
      AppPermissions.accountsWrite,
    };
    await _pumpChart(
      tester,
      location: '/accounts?section=coa',
      accessPolicy: _policyFor(permissions: permissions),
    );

    expect(find.byType(AccountsChartPanel), findsOneWidget);
    expect(find.byTooltip('Add'), findsOneWidget);
  });

  testWidgets('Write access shows Add / Edit / Deactivate; no UUID', (
    WidgetTester tester,
  ) async {
    final Set<AppPermission> permissions = <AppPermission>{
      AppPermissions.accountsRead,
      AppPermissions.accountsWrite,
    };
    await _pumpChart(
      tester,
      accessPolicy: _policyFor(permissions: permissions),
      chartItems: <AccountsChartAccount>[_sampleAccount],
    );

    expect(find.byTooltip('Add'), findsOneWidget);
    expect(find.text(AccountsStrings.chartActionsColumn), findsOneWidget);
    expect(find.byTooltip(AccountsStrings.chartDeactivateAction), findsOneWidget);
    expect(find.text(_sampleAccount.id), findsNothing);
    expect(find.text('1000'), findsWidgets);
  });

  testWidgets('Journal / Post all / period trailing absent on Account chart', (
    WidgetTester tester,
  ) async {
    final Set<AppPermission> permissions = <AppPermission>{
      AppPermissions.accountsRead,
      AppPermissions.accountsWrite,
    };
    await _pumpChart(
      tester,
      accessPolicy: _policyFor(permissions: permissions),
    );

    expect(find.byType(AccountsChartPanel), findsOneWidget);
    expect(find.byTooltip(AccountsStrings.journalAction), findsNothing);
    expect(find.byTooltip(AccountsStrings.postAllAction), findsNothing);
    expect(find.byTooltip(AccountsStrings.openPeriodAction), findsNothing);
    expect(find.byTooltip(AccountsStrings.closePeriodAction), findsNothing);
  });

  testWidgets('Deactivate refreshes chart after confirm', (
    WidgetTester tester,
  ) async {
    final Set<AppPermission> permissions = <AppPermission>{
      AppPermissions.accountsRead,
      AppPermissions.accountsWrite,
    };
    final _MockChartRepository chart = _MockChartRepository();
    _stubChart(chart, items: <AccountsChartAccount>[_sampleAccount]);

    await _pumpChart(
      tester,
      accessPolicy: _policyFor(permissions: permissions),
      chartItems: <AccountsChartAccount>[_sampleAccount],
      chartRepository: chart,
    );

    final Finder deactivate = find.byTooltip(
      AccountsStrings.chartDeactivateAction,
    );
    expect(deactivate, findsOneWidget);
    await tester.ensureVisible(deactivate);
    await tester.tap(deactivate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Finder confirm = find.widgetWithText(
      AppButton,
      AccountsStrings.chartDeactivateAction,
    );
    expect(confirm, findsWidgets);
    await tester.tap(confirm.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verify(() => chart.deactivateAccount(_sampleAccount.id)).called(1);
    verify(
      () => chart.listAccounts(
        any(),
        tenantId: any(named: 'tenantId'),
        facilityId: any(named: 'facilityId'),
      ),
    ).called(greaterThan(1));
  });
}
