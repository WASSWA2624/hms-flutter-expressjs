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

void _stubChart(_MockChartRepository repository) {
  when(
    () => repository.listAccounts(
      any(),
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => const Result<AppPage<AccountsChartAccount>>.success(
      AppPage<AccountsChartAccount>(
        items: <AccountsChartAccount>[],
        request: AppPageRequest(pageSize: 100),
        totalItemCount: 0,
      ),
    ),
  );
}

Future<void> _pumpChart(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  String location = '/accounts?section=chart',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  final _MockChartRepository chart = _MockChartRepository();
  _stubAccounts(accounts);
  _stubChart(chart);

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
  });

  testWidgets('Account chart visible; Add absent without chart write', (
    WidgetTester tester,
  ) async {
    await _pumpChart(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    expect(find.byType(AccountsWorkspacePage), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AccountsChartPanel), findsOneWidget);
    expect(find.text(AccountsStrings.chartEmpty), findsOneWidget);
    expect(find.byTooltip('Add'), findsNothing);
    expect(find.text(AccountsStrings.chartActionsColumn), findsNothing);
    expect(find.text(AccountsStrings.nextColumn), findsNothing);
  });

  testWidgets('Account chart aliases select section=chart body', (
    WidgetTester tester,
  ) async {
    await _pumpChart(
      tester,
      location: '/accounts?section=coa',
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    expect(find.byType(AccountsChartPanel), findsOneWidget);
    expect(find.byTooltip('Add'), findsOneWidget);
  });

  testWidgets('Journal / Post all / period trailing absent on Account chart', (
    WidgetTester tester,
  ) async {
    await _pumpChart(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    expect(find.byType(AccountsChartPanel), findsOneWidget);
    expect(find.byTooltip(AccountsStrings.journalAction), findsNothing);
    expect(find.byTooltip(AccountsStrings.postAllAction), findsNothing);
    expect(find.byTooltip(AccountsStrings.openPeriodAction), findsNothing);
    expect(find.byTooltip(AccountsStrings.closePeriodAction), findsNothing);
  });
}
