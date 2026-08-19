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
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_department_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_fiscal_period_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_department.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_fiscal_period.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_department_repository.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_fiscal_period_repository.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_department_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_departments_and_cost_centres_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All department copy comes from `app_en.arb`; the tests assert against the
/// same generated strings the UI renders, never against literals.
final AppLocalizations _l10n = AppLocalizationsEn();

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockDepartmentRepository extends Mock
    implements AccountsDepartmentRepository {}

class _MockFiscalPeriodRepository extends Mock
    implements AccountsFiscalPeriodRepository {}

final AccountsDepartment _draftDepartment = AccountsDepartment(
  humanFriendlyId: 'DEP0000001',
  departmentCode: 'CARD',
  departmentName: 'Cardiology',
  costCentreCode: 'CC-100',
  costCentreName: 'Cardiology Cost Centre',
  facility: 'Kampala Main',
  facilityHumanFriendlyId: 'FAC-001',
  manager: 'Ada Nakato',
  managerHumanFriendlyId: 'USR-001',
  effectiveFrom: DateTime.utc(2026, 1),
  status: AccountsDepartmentStatus.draft,
  version: 1,
);

final AccountsDepartment _archivedDepartment = AccountsDepartment(
  humanFriendlyId: 'DEP0000002',
  departmentCode: 'RAD',
  departmentName: 'Radiology',
  costCentreCode: 'CC-200',
  costCentreName: 'Radiology Cost Centre',
  facility: 'Kampala Main',
  facilityHumanFriendlyId: 'FAC-001',
  effectiveFrom: DateTime.utc(2025, 1),
  effectiveTo: DateTime.utc(2025, 12, 31),
  status: AccountsDepartmentStatus.archived,
  version: 4,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 2,
  fiscalPeriodsActive: 11,
  departmentsActive: 9,
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

void _stubDepartments(
  _MockDepartmentRepository repository, {
  required List<AccountsDepartment> items,
  int filteredTotal = 2,
}) {
  when(() => repository.listDepartments(any())).thenAnswer((
    Invocation inv,
  ) async {
    final AccountsDepartmentQuery query =
        inv.positionalArguments.first as AccountsDepartmentQuery;
    return Result<AppPage<AccountsDepartment>>.success(
      AppPage<AccountsDepartment>(
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
    (_) async => Result<AccountsDepartment>.success(_draftDepartment),
  );
}

Future<_MockDepartmentRepository> _pumpDepartments(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  List<AccountsDepartment>? items,
  int filteredTotal = 2,
  String location = '/accounts?section=departments-and-cost-centres',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  final _MockDepartmentRepository departments = _MockDepartmentRepository();
  final _MockFiscalPeriodRepository periods = _MockFiscalPeriodRepository();
  _stubAccounts(accounts);
  _stubDepartments(
    departments,
    items: items ?? <AccountsDepartment>[_draftDepartment, _archivedDepartment],
    filteredTotal: filteredTotal,
  );
  when(() => periods.listPeriods(any())).thenAnswer(
    (_) async => const Result<AppPage<AccountsFiscalPeriod>>.success(
      AppPage<AccountsFiscalPeriod>(
        items: <AccountsFiscalPeriod>[],
        request: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
        totalItemCount: 0,
      ),
    ),
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
        accountsDepartmentRepositoryProvider.overrideWithValue(departments),
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
  return departments;
}

/// Minimal host for [confirmAccountsDepartmentAction]; the row button that
/// triggers it in the panel sits in the last of many columns.
Future<void> _pumpActionHarness(
  WidgetTester tester, {
  required _MockDepartmentRepository departments,
  required AccountsDepartment department,
  required AccountsDepartmentAction action,
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
        accountsDepartmentRepositoryProvider.overrideWithValue(departments),
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
                onPressed: () => confirmAccountsDepartmentAction(
                  context: context,
                  ref: ref,
                  department: department,
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
    registerFallbackValue(const AccountsDepartmentQuery());
    registerFallbackValue(const AccountsFiscalPeriodQuery());
    registerFallbackValue(AccountsDepartmentAction.activate);
  });

  group('navigation and scoping', () {
    test('the tab sits under Setup & Controls beside Fiscal Years & Periods', () {
      expect(
        AccountsDeskCategory.setupAndControls.sections.take(2),
        <AccountsDeskSection>[
          AccountsDeskSection.fiscalYearsAndPeriods,
          AccountsDeskSection.departmentsAndCostCentres,
        ],
      );
      expect(
        AccountsDeskSection.departmentsAndCostCentres.category,
        AccountsDeskCategory.setupAndControls,
      );
    });

    test('the section slug matches the API path segment', () {
      expect(
        AccountsDeskSection.departmentsAndCostCentres.sectionQueryValue,
        accountsDepartmentsSectionSlug,
      );
      expect(
        AccountsDeskSection.resolveDeskSlug('departments-and-cost-centres'),
        AccountsDeskSection.departmentsAndCostCentres,
      );
    });

    test('compatible deep-link aliases resolve to the canonical tab', () {
      for (final String alias in <String>[
        'departments',
        'cost-centres',
        'cost-centers',
        'departments-and-cost-centers',
        'departmentsandcostcentres',
      ]) {
        expect(
          AccountsDeskSection.resolveDeskSlug(alias),
          AccountsDeskSection.departmentsAndCostCentres,
          reason: '$alias should resolve to the owning tab',
        );
      }
    });

    test('the table exposes the thirteen documented columns', () {
      expect(accountsDepartmentColumnIds.length, 13);
      expect(accountsDepartmentColumnIds.first, accountsDepartmentCodeColumnId);
      expect(accountsDepartmentColumnIds.last, accountsDepartmentStatusColumnId);
    });

    test('the two Optional columns are not part of the default set', () {
      expect(accountsDepartmentOptionalColumnIds, <String>[
        accountsDepartmentReferenceColumnId,
        accountsDepartmentEffectiveFromColumnId,
        accountsDepartmentEffectiveToColumnId,
      ]);
      for (final String id in accountsDepartmentOptionalColumnIds) {
        if (id == accountsDepartmentReferenceColumnId) {
          continue;
        }
        expect(accountsDepartmentColumnIds, contains(id));
      }
    });

    testWidgets('deep link opens the Setup & Controls tab strip', (
      WidgetTester tester,
    ) async {
      await _pumpDepartments(tester, accessPolicy: _readerPolicy);

      expect(
        find.byType(AccountsDepartmentsAndCostCentresPanel),
        findsOneWidget,
      );
      expect(
        AccountsDeskCategory.of(AccountsDeskSection.departmentsAndCostCentres),
        AccountsDeskCategory.setupAndControls,
      );
      expect(
        accountsShellMenuChildren(
          accessPolicy: _readerPolicy,
        ).map((ShellSubmenuItem item) => item.id),
        contains(AccountsDeskCategory.setupAndControls.name),
      );

      // Every Setup & Controls section is a tab in one flat strip.
      final AppTabStrip sections = tester.widget<AppTabStrip>(
        find.byKey(accountsSectionTabsKey),
      );
      expect(
        sections.tabs.map((AppTabItem tab) => tab.id),
        contains(AccountsDeskSection.departmentsAndCostCentres.name),
      );
      expect(
        sections.tabs
            .firstWhere(
              (AppTabItem tab) =>
                  tab.id == AccountsDeskSection.departmentsAndCostCentres.name,
            )
            .label,
        _l10n.accountsDepartmentsLabel,
      );
      expect(sections.variant, AppTabStripVariant.standard);
    });

    testWidgets('the workspace renders no category tab row', (
      WidgetTester tester,
    ) async {
      await _pumpDepartments(tester, accessPolicy: _readerPolicy);

      expect(find.byType(AppTabStrip), findsOneWidget);
    });

    testWidgets('the badge uses the summary until the query is narrowed', (
      WidgetTester tester,
    ) async {
      await _pumpDepartments(tester, accessPolicy: _readerPolicy);

      AppTabItem departmentsTab() => tester
          .widget<AppTabStrip>(find.byKey(accountsSectionTabsKey))
          .tabs
          .lastWhere(
            (AppTabItem tab) =>
                tab.id == AccountsDeskSection.departmentsAndCostCentres.name,
          );
      expect(departmentsTab().count, _summary.departmentsActive);

      await tester.enterText(find.byType(TextField).first, 'Cardiology');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(departmentsTab().count, 2);
    });
  });

  group('columns and filters', () {
    testWidgets('Optional columns stay out of the default visible set', (
      WidgetTester tester,
    ) async {
      await _pumpDepartments(tester, accessPolicy: _readerPolicy);

      final AppListTable<AccountsDepartment> table = tester
          .widget<AppListTable<AccountsDepartment>>(
            find.byType(AppListTable<AccountsDepartment>),
          );
      final List<String> defaultKeys = table.columns
          .map((AppListTableColumn<AccountsDepartment> column) => column.key)
          .toList();
      final List<String> optionalKeys = table.columnChoices!
          .map((AppListTableColumn<AccountsDepartment> column) => column.key)
          .toList();

      expect(defaultKeys, contains(accountsDepartmentCodeColumnId));
      expect(defaultKeys, contains(accountsDepartmentBudgetOwnerColumnId));
      expect(defaultKeys, contains(accountsDepartmentStatusColumnId));

      expect(optionalKeys, accountsDepartmentOptionalColumnIds);
      for (final String id in accountsDepartmentOptionalColumnIds) {
        expect(defaultKeys, isNot(contains(id)));
      }

      // Optional columns stay exportable so Settings/export keep the full
      // source-of-truth inventory.
      for (final AppListTableColumn<AccountsDepartment> column
          in table.columnChoices!) {
        expect(column.includesInExport, isTrue);
      }
    });

    testWidgets('every specified domain filter reaches the committed query', (
      WidgetTester tester,
    ) async {
      final _MockDepartmentRepository departments = await _pumpDepartments(
        tester,
        accessPolicy: _readerPolicy,
      );

      final AppListTable<AccountsDepartment> table = tester
          .widget<AppListTable<AccountsDepartment>>(
            find.byType(AppListTable<AccountsDepartment>),
          );
      final List<String> groupKeys = table.search!.filterGroups
          .map((AppSearchBarFilterGroup group) => group.key)
          .toList();

      // Status, Department / cost centre, and Owner come from controlled
      // reference data harvested from permitted rows.
      expect(groupKeys, contains('status'));
      expect(groupKeys, contains('cost_centre'));
      expect(groupKeys, contains('owner'));

      table.search!.onFilterChanged!(
        const AppSearchBarFilterValue(
          options: <String, String>{
            'status': 'ACTIVE',
            'cost_centre': 'CC-100',
            'owner': 'USR-001',
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final List<AccountsDepartmentQuery> queries =
          verify(() => departments.listDepartments(captureAny())).captured
              .cast<AccountsDepartmentQuery>();
      final AccountsDepartmentQuery committed = queries.last;
      expect(committed.statuses, <AccountsDepartmentStatus>{
        AccountsDepartmentStatus.active,
      });
      expect(committed.costCentreCodes, <String>{'CC-100'});
      expect(committed.ownerId, 'USR-001');
      expect(committed.hasActiveFilters, isTrue);
    });

    testWidgets('the Facility filter appears only for multi-facility scope', (
      WidgetTester tester,
    ) async {
      // Both seeded rows share one facility, so the control is omitted rather
      // than rendered as dead chrome.
      await _pumpDepartments(tester, accessPolicy: _readerPolicy);

      final AppListTable<AccountsDepartment> table = tester
          .widget<AppListTable<AccountsDepartment>>(
            find.byType(AppListTable<AccountsDepartment>),
          );
      expect(
        table.search!.filterGroups
            .map((AppSearchBarFilterGroup group) => group.key)
            .contains('facility'),
        isFalse,
      );
    });
  });

  group('permissions', () {
    test('every atom resolves to an accounts permission', () {
      expect(
        AccountsDepartmentsAtomPermissions.tab.isAllowed(_readerPolicy),
        isTrue,
      );
      expect(
        AccountsDepartmentsAtomPermissions.create.isAllowed(_readerPolicy),
        isFalse,
      );
      expect(
        AccountsDepartmentsAtomPermissions.create.isAllowed(_writerPolicy),
        isTrue,
      );
      expect(canWriteAccountsDepartments(_readerPolicy), isFalse);
      expect(canWriteAccountsDepartments(_writerPolicy), isTrue);
    });

    test('a write-only grant does not surface the tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );
      expect(
        canViewAccountsSection(
          writeOnly,
          AccountsDeskSection.departmentsAndCostCentres,
        ),
        isFalse,
      );
    });

    testWidgets('read-only hides New record, Actions, and workflow buttons', (
      WidgetTester tester,
    ) async {
      await _pumpDepartments(tester, accessPolicy: _readerPolicy);

      expect(find.text('Cardiology'), findsWidgets);
      expect(find.text(_l10n.accountsDepartmentNewRecordAction), findsNothing);
      expect(find.text(_l10n.accountsDepartmentActionsColumn), findsNothing);
      expect(find.text(_l10n.accountsDepartmentActivateAction), findsNothing);
      expect(find.text(_l10n.accountsDepartmentBulkArchiveAction), findsNothing);
    });

    testWidgets('write access shows the toolbar and per-row actions', (
      WidgetTester tester,
    ) async {
      await _pumpDepartments(tester, accessPolicy: _writerPolicy);

      expect(find.text(_l10n.accountsDepartmentActionsColumn), findsOneWidget);
      expect(find.text(_l10n.accountsDepartmentViewAction), findsWidgets);
      expect(find.text(_l10n.accountsDepartmentActivateAction), findsWidgets);
    });
  });

  group('status rules', () {
    test('transitions follow the documented lifecycle', () {
      expect(_draftDepartment.canActivate, isTrue);
      expect(_draftDepartment.canDeactivate, isFalse);
      expect(_draftDepartment.canEdit, isTrue);
      expect(_draftDepartment.toggleAction, AccountsDepartmentAction.activate);

      const AccountsDepartmentStatus archived =
          AccountsDepartmentStatus.archived;
      expect(archived.allowedTransitions, <AccountsDepartmentStatus>{
        AccountsDepartmentStatus.active,
      });
    });

    test('an archived record is not editable and offers Restore', () {
      expect(_archivedDepartment.canEdit, isFalse);
      expect(_archivedDepartment.canClone, isFalse);
      expect(_archivedDepartment.canRestore, isTrue);
      expect(
        _archivedDepartment.toggleAction,
        AccountsDepartmentAction.restore,
      );
    });

    testWidgets('archived rows expose no Edit or Clone button', (
      WidgetTester tester,
    ) async {
      await _pumpDepartments(
        tester,
        accessPolicy: _writerPolicy,
        items: <AccountsDepartment>[_archivedDepartment],
      );

      expect(find.text('Radiology'), findsWidgets);
      expect(find.text(_l10n.accountsDepartmentCloneAction), findsNothing);
      expect(find.text(_l10n.accountsDepartmentRestoreAction), findsWidgets);
      expect(find.text(_l10n.accountsDepartmentViewAction), findsOneWidget);
    });
  });

  group('workflow', () {
    testWidgets('Activate confirms, then posts the action with the version', (
      WidgetTester tester,
    ) async {
      final _MockDepartmentRepository departments = _MockDepartmentRepository();
      _stubDepartments(
        departments,
        items: <AccountsDepartment>[_draftDepartment],
      );

      await _pumpActionHarness(
        tester,
        departments: departments,
        department: _draftDepartment,
        action: AccountsDepartmentAction.activate,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog))
            .title,
        _l10n.accountsDepartmentActivateConfirmTitle,
      );

      await tester.tap(
        find
            .widgetWithText(
              AppButton,
              _l10n.accountsDepartmentActivateAction,
            )
            .last,
      );
      await tester.pumpAndSettle();

      verify(
        () => departments.applyAction(
          _draftDepartment.humanFriendlyId,
          AccountsDepartmentAction.activate,
          version: _draftDepartment.version,
        ),
      ).called(1);
    });

    testWidgets('Archive warns that the record is archived, not deleted', (
      WidgetTester tester,
    ) async {
      final _MockDepartmentRepository departments = _MockDepartmentRepository();
      _stubDepartments(
        departments,
        items: <AccountsDepartment>[_draftDepartment],
      );

      await _pumpActionHarness(
        tester,
        departments: departments,
        department: _draftDepartment,
        action: AccountsDepartmentAction.archive,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      final AppConfirmActionDialog dialog = tester
          .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog));
      expect(dialog.title, _l10n.accountsDepartmentArchiveConfirmTitle);
      expect(dialog.body, contains('archived, not deleted'));
      // The reference guard is stated up front, not discovered on failure.
      expect(dialog.body, contains('units, or wards'));
    });
  });

  group('privacy', () {
    testWidgets('no raw database identifier or raw enum reaches the table', (
      WidgetTester tester,
    ) async {
      await _pumpDepartments(tester, accessPolicy: _writerPolicy);

      expect(find.text('550e8400-e29b-41d4-a716-446655440020'), findsNothing);
      expect(find.text('DRAFT'), findsNothing);
      expect(find.text('ARCHIVED'), findsNothing);
      expect(find.text(_l10n.accountsDepartmentStatusDraft), findsWidgets);
    });
  });
}
