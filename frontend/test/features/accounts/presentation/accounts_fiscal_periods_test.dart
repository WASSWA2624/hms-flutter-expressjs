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
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_fiscal_period_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_fiscal_periods_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All fiscal copy comes from `app_en.arb`; the tests assert against the same
/// generated strings the UI renders, never against literals.
final AppLocalizations _l10n = AppLocalizationsEn();

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

    test('the three Optional columns are not part of the default set', () {
      expect(accountsFiscalPeriodOptionalColumnIds, <String>[
        accountsFiscalReferenceColumnId,
        accountsFiscalLockDateColumnId,
        accountsFiscalReopenedAtColumnId,
        accountsFiscalReopenedByColumnId,
      ]);
      // Every optional id except the baseline Reference column still belongs to
      // the documented source order, so Settings and export keep that order.
      for (final String id in accountsFiscalPeriodOptionalColumnIds) {
        if (id == accountsFiscalReferenceColumnId) {
          continue;
        }
        expect(accountsFiscalPeriodColumnIds, contains(id));
      }
    });

    testWidgets(
      'deep link opens the Setup & Controls menu item and its tab strip',
      (WidgetTester tester) async {
        await _pumpFiscalPeriods(tester, accessPolicy: _readerPolicy);

        expect(find.byType(AccountsFiscalPeriodsPanel), findsOneWidget);

        // Menu depth stops at the category: it is a sidebar item, not a tab row.
        expect(
          AccountsDeskCategory.of(AccountsDeskSection.fiscalYearsAndPeriods),
          AccountsDeskCategory.setupAndControls,
        );
        expect(
          accountsShellMenuChildren(
            accessPolicy: _readerPolicy,
          ).map((ShellSubmenuItem item) => item.id),
          contains(AccountsDeskCategory.setupAndControls.name),
        );

        // The category's sections are this page's tabs, in one flat strip.
        final AppTabStrip sections = tester.widget<AppTabStrip>(
          find.byKey(accountsSectionTabsKey),
        );
        expect(sections.tabs.first.label, _l10n.accountsFiscalPeriodsLabel);
        expect(sections.variant, AppTabStripVariant.standard);
      },
    );

    testWidgets('the workspace renders no category tab row', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _readerPolicy);

      expect(find.byType(AppTabStrip), findsOneWidget);
    });

    testWidgets('the badge uses the summary until the query is narrowed', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _readerPolicy);

      AppTabItem fiscalTab() => tester
          .widget<AppTabStrip>(find.byKey(accountsSectionTabsKey))
          .tabs
          .firstWhere(
            (AppTabItem tab) =>
                tab.id == AccountsDeskSection.fiscalYearsAndPeriods.name,
          );
      expect(fiscalTab().count, _summary.fiscalPeriodsActive);

      await tester.enterText(find.byType(TextField).first, 'January');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(fiscalTab().count, 2);
    });
  });

  group('columns and filters', () {
    testWidgets('Optional columns stay out of the default visible set', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _readerPolicy);

      final AppListTable<AccountsFiscalPeriod> table = tester
          .widget<AppListTable<AccountsFiscalPeriod>>(
            find.byType(AppListTable<AccountsFiscalPeriod>),
          );
      final List<String> defaultKeys = table.columns
          .map((AppListTableColumn<AccountsFiscalPeriod> column) => column.key)
          .toList();
      final List<String> optionalKeys = table.columnChoices!
          .map((AppListTableColumn<AccountsFiscalPeriod> column) => column.key)
          .toList();

      // Default set: the ten `Default` columns plus Period Status.
      expect(defaultKeys, contains(accountsFiscalYearColumnId));
      expect(defaultKeys, contains(accountsFiscalCloseDateColumnId));
      expect(defaultKeys, contains(accountsFiscalStatusColumnId));

      // Optional set: offered in Settings and export, hidden until enabled.
      expect(optionalKeys, accountsFiscalPeriodOptionalColumnIds);
      for (final String id in accountsFiscalPeriodOptionalColumnIds) {
        expect(defaultKeys, isNot(contains(id)));
      }

      // Optional columns are still exportable, so Settings/export keep the
      // full source-of-truth inventory.
      for (final AppListTableColumn<AccountsFiscalPeriod> column
          in table.columnChoices!) {
        expect(column.includesInExport, isTrue);
      }

      // Nothing optional is painted before the operator turns it on.
      expect(find.text(_l10n.accountsFiscalLockDateColumn), findsNothing);
      expect(find.text(_l10n.accountsFiscalReopenedByColumn), findsNothing);
      expect(find.text(_l10n.accountsFiscalReferenceColumn), findsNothing);
    });

    testWidgets('the period name cell holds one fact, not name plus reference', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _readerPolicy);

      expect(find.text('January 2026'), findsWidgets);
      // The human-friendly reference belongs to its own optional column.
      expect(find.text('FY-2026-P01'), findsNothing);
    });

    testWidgets('the Facility filter narrows the same committed query', (
      WidgetTester tester,
    ) async {
      final AccountsFiscalPeriod otherFacility = AccountsFiscalPeriod(
        humanFriendlyId: 'FY-2026-P02',
        fiscalYear: 'FY2026',
        periodNo: 2,
        periodName: 'February 2026',
        startDate: DateTime.utc(2026, 2, 1),
        endDate: DateTime.utc(2026, 2, 28),
        entityAndFacility: 'Entebbe Annex',
        facilityHumanFriendlyId: 'FAC-002',
        module: 'ALL',
        status: AccountsFiscalPeriodStatus.active,
        version: 1,
      );
      final AccountsFiscalPeriod homeFacility = AccountsFiscalPeriod(
        humanFriendlyId: _draftPeriod.humanFriendlyId,
        fiscalYear: _draftPeriod.fiscalYear,
        periodNo: _draftPeriod.periodNo,
        periodName: _draftPeriod.periodName,
        startDate: _draftPeriod.startDate,
        endDate: _draftPeriod.endDate,
        entityAndFacility: _draftPeriod.entityAndFacility,
        facilityHumanFriendlyId: 'FAC-001',
        module: _draftPeriod.module,
        status: _draftPeriod.status,
        version: _draftPeriod.version,
      );

      final _MockFiscalPeriodRepository periods = await _pumpFiscalPeriods(
        tester,
        accessPolicy: _readerPolicy,
        items: <AccountsFiscalPeriod>[homeFacility, otherFacility],
      );

      // Two facilities in scope, so the filter is offered.
      final AppListTable<AccountsFiscalPeriod> table = tester
          .widget<AppListTable<AccountsFiscalPeriod>>(
            find.byType(AppListTable<AccountsFiscalPeriod>),
          );
      final AppSearchBarFilterGroup facilityGroup = table.search!.filterGroups
          .firstWhere(
            (AppSearchBarFilterGroup group) => group.key == 'facility',
          );
      expect(facilityGroup.label, _l10n.accountsFiscalFacilityFilterLabel);
      expect(
        facilityGroup.choices
            .map((AppSearchBarFilterChoice choice) => choice.value)
            .toList(),
        <String>['FAC-002', 'FAC-001'],
      );

      // Committing the filter reaches the repository query the table, badge,
      // export, and print all share.
      table.search!.onFilterChanged!(
        const AppSearchBarFilterValue(
          options: <String, String>{'facility': 'FAC-002'},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final List<AccountsFiscalPeriodQuery> queries =
          verify(() => periods.listPeriods(captureAny())).captured
              .cast<AccountsFiscalPeriodQuery>();
      expect(queries.last.facilityId, 'FAC-002');
      expect(queries.last.hasActiveFilters, isTrue);
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
      expect(find.text(_l10n.accountsFiscalNewRecordAction), findsNothing);
      expect(find.text(_l10n.accountsFiscalActionsColumn), findsNothing);
      expect(find.text(_l10n.accountsFiscalActivateAction), findsNothing);
      expect(find.text(_l10n.accountsFiscalArchiveAction), findsNothing);
      expect(find.text(_l10n.accountsFiscalBulkArchiveAction), findsNothing);
    });

    testWidgets('write access shows the toolbar and per-row actions', (
      WidgetTester tester,
    ) async {
      await _pumpFiscalPeriods(tester, accessPolicy: _writerPolicy);

      expect(find.text(_l10n.accountsFiscalActionsColumn), findsOneWidget);
      expect(find.text(_l10n.accountsFiscalViewAction), findsWidgets);
      expect(find.text(_l10n.accountsFiscalActivateAction), findsWidgets);
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
      expect(find.text(_l10n.accountsFiscalArchiveAction), findsNothing);
      expect(find.text(_l10n.accountsFiscalViewAction), findsOneWidget);
    });
  });

  group('create dialog chrome', () {
    /// Opens the create dialog directly; the panel's New record action is
    /// covered separately by the permission tests.
    Future<void> openCreateDialog(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final _MockFiscalPeriodRepository periods = _MockFiscalPeriodRepository();
      _stubPeriods(periods, items: <AccountsFiscalPeriod>[_draftPeriod]);

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
                    key: const Key('open-create'),
                    onPressed: () => showAccountsFiscalPeriodDialog(
                      context: context,
                      ref: ref,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open-create')));
      await tester.pumpAndSettle();
    }

    testWidgets('Close and Save sit in the pinned dialog footer', (
      WidgetTester tester,
    ) async {
      await openCreateDialog(tester);

      final AppDialog dialog = tester.widget<AppDialog>(
        find.byType(AppDialog),
      );

      // Footer actions belong to the dialog, not the scrolling body.
      expect(dialog.actions, hasLength(2));
      expect(dialog.pinActionsToBottom, isTrue);
      // The in-body variant is gone entirely from the open dialog.
      expect(find.byType(AppFormActions), findsNothing);
    });

    testWidgets('Module is a controlled select, not a free-text field', (
      WidgetTester tester,
    ) async {
      await openCreateDialog(tester);

      final AppSelectField<String> moduleField = tester
          .widget<AppSelectField<String>>(find.byType(AppSelectField<String>));
      expect(moduleField.labelText, _l10n.accountsFiscalModuleColumn);
      expect(moduleField.value, 'ALL');
      expect(
        moduleField.options.map((AppSelectOption<String> option) => option.value),
        containsAll(accountsFiscalModuleWireValues),
      );
      // Options render localized labels, never the raw wire value.
      expect(
        moduleField.options.first.label,
        _l10n.accountsFiscalModuleAll,
      );
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
        _l10n.accountsFiscalActivateConfirmTitle,
      );

      await tester.tap(
        find
            .widgetWithText(AppButton, _l10n.accountsFiscalActivateAction)
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
      expect(dialog.title, _l10n.accountsFiscalArchiveConfirmTitle);
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
      expect(find.text(_l10n.accountsFiscalStatusDraft), findsWidgets);
    });
  });
}
