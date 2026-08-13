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
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_fiscal_period_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_fiscal_period.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_fiscal_period_repository.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_fiscal_period_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_fiscal_periods_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockFiscalPeriodRepository extends Mock
    implements AccountsFiscalPeriodRepository {}

final AccountsFiscalPeriod _draftPeriod = AccountsFiscalPeriod(
  humanFriendlyId: 'FY-2026-P01',
  fiscalYear: 'FY2026',
  periodNo: 1,
  periodName: 'January 2026',
  startDate: DateTime.utc(2026, 1, 1),
  endDate: DateTime.utc(2026, 1, 31),
  entityAndFacility: 'Kampala Main',
  module: 'ALL',
  openDate: DateTime.utc(2026, 1, 1),
  status: AccountsFiscalPeriodStatus.draft,
  version: 1,
);

final AccountsFiscalPeriod _lockedPeriod = AccountsFiscalPeriod(
  humanFriendlyId: 'FY-2025-P12',
  fiscalYear: 'FY2025',
  periodNo: 12,
  periodName: 'December 2025',
  startDate: DateTime.utc(2025, 12),
  endDate: DateTime.utc(2025, 12, 31),
  entityAndFacility: 'Kampala Main',
  module: 'ALL',
  closeDate: DateTime.utc(2026, 1, 5),
  lockDate: DateTime.utc(2026, 1, 10),
  status: AccountsFiscalPeriodStatus.inactive,
  isLocked: true,
  version: 4,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 2,
  fiscalPeriodsActive: 11,
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
        AppModuleEntitlement(code: 'facility-accounts', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy get _readerPolicy => _policy(
  permissions: <AppPermission>{
    AppPermissions.accountsRead,
    AppPermissions.evidenceExport,
  },
);

AppAccessPolicy get _writerPolicy => _policy(
  permissions: <AppPermission>{
    AppPermissions.accountsRead,
    AppPermissions.accountsWrite,
    AppPermissions.evidenceExport,
  },
);

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
    () => repository.listGlAccounts(any(), facilityId: any(named: 'facilityId')),
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

void _stubPeriods(
  _MockFiscalPeriodRepository repository, {
  required List<AccountsFiscalPeriod> items,
  int filteredTotal = 2,
}) {
  when(() => repository.listPeriods(any())).thenAnswer((Invocation inv) async {
    final AccountsFiscalPeriodQuery query =
        inv.positionalArguments.first as AccountsFiscalPeriodQuery;
    return Result<AppPage<AccountsFiscalPeriod>>.success(
      AppPage<AccountsFiscalPeriod>(
        items: items,
        request: const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
        totalItemCount: query.isNarrowed ? filteredTotal : items.length,
      ),
    );
  });
  when(
    () => repository.applyAction(
      any(),
      any(),
      reason: any(named: 'reason'),
      version: any(named: 'version'),
    ),
  ).thenAnswer(
    (_) async => Result<AccountsFiscalPeriod>.success(_draftPeriod),
  );
}

Future<_MockFiscalPeriodRepository> _pumpFiscalPeriods(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  List<AccountsFiscalPeriod>? items,
  int filteredTotal = 2,
  String location = '/accounts?section=fiscal-years-and-periods',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  final _MockFiscalPeriodRepository periods = _MockFiscalPeriodRepository();
  _stubAccounts(accounts);
  _stubPeriods(
    periods,
    items: items ?? <AccountsFiscalPeriod>[_draftPeriod, _lockedPeriod],
    filteredTotal: filteredTotal,
  );

  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      GoRoute(
        path: '/accounts',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: AccountsWorkspacePage(
            initialQuery: AccountsWorkspaceQuery.fromUri(state.uri),
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsRepositoryProvider.overrideWithValue(accounts),
        accountsFiscalPeriodRepositoryProvider.overrideWithValue(periods),
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
  return periods;
}

/// Minimal host for [confirmAccountsFiscalPeriodAction]; the row button that
/// triggers it in the panel sits in the last of fifteen columns.
Future<void> _pumpActionHarness(
  WidgetTester tester, {
  required _MockFiscalPeriodRepository periods,
  required AccountsFiscalPeriod period,
  required AccountsFiscalPeriodAction action,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsFiscalPeriodRepositoryProvider.overrideWithValue(periods),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(_writerPolicy),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('run-action'),
                onPressed: () => confirmAccountsFiscalPeriodAction(
                  context: context,
                  ref: ref,
                  period: period,
                  action: action,
                ),
                child: const Text('run'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsGlQuery());
    registerFallbackValue(const AccountsFiscalPeriodQuery());
    registerFallbackValue(AccountsFiscalPeriodAction.activate);
  });

  group('navigation and scoping', () {
    test('the tab is the first leaf under Setup & Controls', () {
      expect(
        AccountsDeskCategory.setupAndControls.sections.first,
        AccountsDeskSection.fiscalYearsAndPeriods,
      );
      expect(
        AccountsDeskSection.fiscalYearsAndPeriods.category,
        AccountsDeskCategory.setupAndControls,
      );
    });

    test('the section slug matches the API path segment', () {
      expect(
        AccountsDeskSection.fiscalYearsAndPeriods.sectionQueryValue,
        accountsFiscalPeriodsSectionSlug,
      );
      expect(
        AccountsDeskSection.resolveDeskSlug('fiscal-years-and-periods'),
        AccountsDeskSection.fiscalYearsAndPeriods,
      );
    });

    test('the table exposes the fourteen documented columns', () {
      expect(accountsFiscalPeriodColumnIds.length, 14);
      expect(accountsFiscalPeriodColumnIds.first, accountsFiscalYearColumnId);
      expect(accountsFiscalPeriodColumnIds.last, accountsFiscalStatusColumnId);
    });

    testWidgets('deep link opens the tab under the Setup & Controls folder', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _readerPolicy);

      expect(find.byType(AccountsFiscalPeriodsPanel), findsOneWidget);
      expect(find.byKey(accountsCategoryTabsKey), findsOneWidget);

      final AppTabStrip categories = tester.widget<AppTabStrip>(
        find.byKey(accountsCategoryTabsKey),
      );
      expect(
        categories.selectedId,
        AccountsDeskCategory.setupAndControls.name,
      );

      final AppTabStrip sections = tester.widget<AppTabStrip>(
        find.byKey(accountsSectionTabsKey),
      );
      expect(sections.tabs.first.label, AccountsStrings.fiscalPeriodsLabel);
      expect(sections.variant, AppTabStripVariant.nested);
    });

    testWidgets('the badge uses the summary until the query is narrowed', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _readerPolicy);

      AppTabItem tab() => tester
          .widget<AppTabStrip>(find.byKey(accountsSectionTabsKey))
          .tabs
          .firstWhere(
            (AppTabItem item) =>
                item.label == AccountsStrings.fiscalPeriodsLabel,
          );
      expect(tab().count, _summary.fiscalPeriodsActive);

      await tester.enterText(find.byType(TextField).first, 'January');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(tab().count, 2);
    });
  });

  group('permissions', () {
    test('every atom resolves to an accounts permission', () {
      expect(
        AccountsFiscalPeriodsAtomPermissions.tab.isAllowed(_readerPolicy),
        isTrue,
      );
      expect(
        AccountsFiscalPeriodsAtomPermissions.create.isAllowed(_readerPolicy),
        isFalse,
      );
      expect(
        AccountsFiscalPeriodsAtomPermissions.create.isAllowed(_writerPolicy),
        isTrue,
      );
      expect(canWriteAccountsFiscalPeriods(_readerPolicy), isFalse);
      expect(canWriteAccountsFiscalPeriods(_writerPolicy), isTrue);
    });

    test('a write-only grant does not surface the tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );
      expect(
        canViewAccountsSection(
          writeOnly,
          AccountsDeskSection.fiscalYearsAndPeriods,
        ),
        isFalse,
      );
      expect(
        canViewAccountsCategory(
          writeOnly,
          AccountsDeskCategory.setupAndControls,
        ),
        isFalse,
      );
    });

    testWidgets('read-only hides New record, Actions, and workflow buttons', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _readerPolicy);

      expect(find.text('January 2026'), findsWidgets);
      expect(find.text(AccountsStrings.fiscalNewRecordAction), findsNothing);
      expect(find.text(AccountsStrings.fiscalActionsColumn), findsNothing);
      expect(find.text(AccountsStrings.fiscalActivateAction), findsNothing);
      expect(find.text(AccountsStrings.fiscalArchiveAction), findsNothing);
      expect(find.text(AccountsStrings.fiscalBulkArchiveAction), findsNothing);
    });

    testWidgets('write access shows the toolbar and per-row actions', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _writerPolicy);

      expect(find.text(AccountsStrings.fiscalActionsColumn), findsOneWidget);
      expect(find.text(AccountsStrings.fiscalViewAction), findsWidgets);
      expect(find.text(AccountsStrings.fiscalActivateAction), findsWidgets);
    });
  });

  group('status rules', () {
    test('transitions follow the documented lifecycle', () {
      expect(_draftPeriod.canActivate, isTrue);
      expect(_draftPeriod.canDeactivate, isFalse);
      expect(_draftPeriod.canEdit, isTrue);
      expect(_draftPeriod.toggleAction, AccountsFiscalPeriodAction.activate);

      const AccountsFiscalPeriodStatus archived =
          AccountsFiscalPeriodStatus.archived;
      expect(archived.allowedTransitions, <AccountsFiscalPeriodStatus>{
        AccountsFiscalPeriodStatus.active,
      });
    });

    test('a locked period is neither editable nor archivable', () {
      expect(_lockedPeriod.isLocked, isTrue);
      expect(_lockedPeriod.canEdit, isFalse);
      expect(_lockedPeriod.canArchive, isFalse);
    });

    testWidgets('locked rows expose no Edit or Archive button', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(
        tester,
        accessPolicy: _writerPolicy,
        items: <AccountsFiscalPeriod>[_lockedPeriod],
      );

      expect(find.text('December 2025'), findsWidgets);
      expect(find.text(AccountsStrings.fiscalArchiveAction), findsNothing);
      expect(find.text(AccountsStrings.fiscalViewAction), findsOneWidget);
    });
  });

  group('workflow', () {
    testWidgets('Activate confirms, then posts the action with the version', (
      WidgetTester tester,
    ) async {
      final _MockFiscalPeriodRepository periods = _MockFiscalPeriodRepository();
      _stubPeriods(periods, items: <AccountsFiscalPeriod>[_draftPeriod]);

      await _pumpActionHarness(
        tester,
        periods: periods,
        period: _draftPeriod,
        action: AccountsFiscalPeriodAction.activate,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppConfirmActionDialog>(
              find.byType(AppConfirmActionDialog),
            )
            .title,
        AccountsStrings.fiscalActivateConfirmTitle,
      );

      await tester.tap(
        find
            .widgetWithText(AppButton, AccountsStrings.fiscalActivateAction)
            .last,
      );
      await tester.pumpAndSettle();

      verify(
        () => periods.applyAction(
          _draftPeriod.humanFriendlyId,
          AccountsFiscalPeriodAction.activate,
          version: _draftPeriod.version,
        ),
      ).called(1);
    });

    testWidgets('Archive warns that the record is archived, not deleted', (
      WidgetTester tester,
    ) async {
      final _MockFiscalPeriodRepository periods = _MockFiscalPeriodRepository();
      _stubPeriods(periods, items: <AccountsFiscalPeriod>[_draftPeriod]);

      await _pumpActionHarness(
        tester,
        periods: periods,
        period: _draftPeriod,
        action: AccountsFiscalPeriodAction.archive,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      final AppConfirmActionDialog dialog = tester
          .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog));
      expect(dialog.title, AccountsStrings.fiscalArchiveConfirmTitle);
      expect(dialog.body, contains('archived, not deleted'));
      expect(find.textContaining('archived, not deleted'), findsOneWidget);
    });
  });

  group('privacy', () {
    testWidgets('no raw database identifier reaches the table', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _writerPolicy);

      expect(
        find.text('550e8400-e29b-41d4-a716-446655440020'),
        findsNothing,
      );
      expect(find.text('DRAFT'), findsNothing);
      expect(find.text(AccountsStrings.fiscalStatusDraft), findsWidgets);
    });
  });
}
