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
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_payment_method_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_payment_method.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_payment_method_repository.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_payment_method_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_payment_methods_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All payment method copy comes from `app_en.arb`; the tests assert against
/// the same generated strings the UI renders, never against literals.
final AppLocalizations _l10n = AppLocalizationsEn();

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockPaymentMethodRepository extends Mock
    implements AccountsPaymentMethodRepository {}

final AccountsPaymentMethod _draftMethod = AccountsPaymentMethod(
  humanFriendlyId: 'PMT0000001',
  methodCode: 'MOMO',
  methodName: 'Mobile Money',
  methodType: AccountsPaymentMethodType.mobileMoney,
  direction: AccountsPaymentMethodDirection.incoming,
  provider: 'MTN',
  requiresExternalReference: true,
  facilityScope: 'Kampala Main',
  facilityHumanFriendlyId: 'FAC-001',
  effectiveFrom: DateTime.utc(2026, 1),
  status: AccountsPaymentMethodStatus.draft,
  version: 1,
);

final AccountsPaymentMethod _archivedMethod = AccountsPaymentMethod(
  humanFriendlyId: 'PMT0000002',
  methodCode: 'CHEQUE',
  methodName: 'Bank Cheque',
  methodType: AccountsPaymentMethodType.bankCheck,
  direction: AccountsPaymentMethodDirection.outgoing,
  requiresApproval: true,
  facilityScope: 'Kampala Main',
  facilityHumanFriendlyId: 'FAC-001',
  effectiveFrom: DateTime.utc(2025, 1),
  effectiveTo: DateTime.utc(2025, 12, 31),
  status: AccountsPaymentMethodStatus.archived,
  version: 4,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 2,
  fiscalPeriodsActive: 11,
  departmentsActive: 9,
  paymentMethodsActive: 6,
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

void _stubMethods(
  _MockPaymentMethodRepository repository, {
  required List<AccountsPaymentMethod> items,
  int filteredTotal = 2,
}) {
  when(() => repository.listPaymentMethods(any())).thenAnswer((
    Invocation inv,
  ) async {
    final AccountsPaymentMethodQuery query =
        inv.positionalArguments.first as AccountsPaymentMethodQuery;
    return Result<AppPage<AccountsPaymentMethod>>.success(
      AppPage<AccountsPaymentMethod>(
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
    (_) async => Result<AccountsPaymentMethod>.success(_draftMethod),
  );
}

Future<_MockPaymentMethodRepository> _pumpPaymentMethods(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  List<AccountsPaymentMethod>? items,
  int filteredTotal = 2,
  String location = '/accounts?section=payment-methods',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  final _MockPaymentMethodRepository methods = _MockPaymentMethodRepository();
  _stubAccounts(accounts);
  _stubMethods(
    methods,
    items: items ?? <AccountsPaymentMethod>[_draftMethod, _archivedMethod],
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
        accountsPaymentMethodRepositoryProvider.overrideWithValue(methods),
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
  return methods;
}

/// Minimal host for [confirmAccountsPaymentMethodAction]; the row button that
/// triggers it in the panel sits in the last of many columns.
Future<void> _pumpActionHarness(
  WidgetTester tester, {
  required _MockPaymentMethodRepository methods,
  required AccountsPaymentMethod method,
  required AccountsPaymentMethodAction action,
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
        accountsPaymentMethodRepositoryProvider.overrideWithValue(methods),
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
                onPressed: () => confirmAccountsPaymentMethodAction(
                  context: context,
                  ref: ref,
                  method: method,
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
    registerFallbackValue(const AccountsPaymentMethodQuery());
    registerFallbackValue(AccountsPaymentMethodAction.activate);
  });

  group('navigation and scoping', () {
    test('the tab is the third leaf under Setup & Controls', () {
      expect(AccountsDeskCategory.setupAndControls.sections, <
        AccountsDeskSection
      >[
        AccountsDeskSection.fiscalYearsAndPeriods,
        AccountsDeskSection.departmentsAndCostCentres,
        AccountsDeskSection.paymentMethods,
      ]);
      expect(
        AccountsDeskSection.paymentMethods.category,
        AccountsDeskCategory.setupAndControls,
      );
    });

    test('the section slug matches the API path segment', () {
      expect(
        AccountsDeskSection.paymentMethods.sectionQueryValue,
        accountsPaymentMethodsSectionSlug,
      );
      expect(
        AccountsDeskSection.resolveDeskSlug('payment-methods'),
        AccountsDeskSection.paymentMethods,
      );
    });

    test('compatible deep-link aliases resolve to the canonical tab', () {
      for (final String alias in <String>[
        'paymentmethods',
        'payment-method',
        'tenders',
      ]) {
        expect(
          AccountsDeskSection.resolveDeskSlug(alias),
          AccountsDeskSection.paymentMethods,
          reason: '$alias should resolve to the owning tab',
        );
      }
    });

    test('the table exposes the fourteen documented columns', () {
      expect(accountsPaymentMethodColumnIds.length, 14);
      expect(
        accountsPaymentMethodColumnIds.first,
        accountsPaymentMethodCodeColumnId,
      );
      expect(
        accountsPaymentMethodColumnIds.last,
        accountsPaymentMethodStatusColumnId,
      );
    });

    test('the three Optional columns are not part of the default set', () {
      expect(accountsPaymentMethodOptionalColumnIds, <String>[
        accountsPaymentMethodReferenceColumnId,
        accountsPaymentMethodFacilityScopeColumnId,
        accountsPaymentMethodEffectiveFromColumnId,
        accountsPaymentMethodEffectiveToColumnId,
      ]);
      for (final String id in accountsPaymentMethodOptionalColumnIds) {
        if (id == accountsPaymentMethodReferenceColumnId) {
          continue;
        }
        expect(accountsPaymentMethodColumnIds, contains(id));
      }
    });

    testWidgets('deep link opens the Setup & Controls tab strip', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(tester, accessPolicy: _readerPolicy);

      expect(find.byType(AccountsPaymentMethodsPanel), findsOneWidget);
      expect(
        accountsShellMenuChildren(
          accessPolicy: _readerPolicy,
        ).map((ShellSubmenuItem item) => item.id),
        contains(AccountsDeskCategory.setupAndControls.name),
      );

      // All three Setup & Controls sections are tabs in one flat strip.
      final AppTabStrip sections = tester.widget<AppTabStrip>(
        find.byKey(accountsSectionTabsKey),
      );
      expect(sections.tabs.length, 3);
      expect(sections.tabs.last.label, _l10n.accountsPaymentMethodsLabel);
      expect(sections.variant, AppTabStripVariant.standard);
    });

    testWidgets('the workspace renders no category tab row', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(tester, accessPolicy: _readerPolicy);

      expect(find.byType(AppTabStrip), findsOneWidget);
    });

    testWidgets('the badge uses the summary until the query is narrowed', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(tester, accessPolicy: _readerPolicy);

      AppTabItem methodsTab() => tester
          .widget<AppTabStrip>(find.byKey(accountsSectionTabsKey))
          .tabs
          .firstWhere(
            (AppTabItem tab) =>
                tab.id == AccountsDeskSection.paymentMethods.name,
          );
      expect(methodsTab().count, _summary.paymentMethodsActive);

      await tester.enterText(find.byType(TextField).first, 'Mobile');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(methodsTab().count, 2);
    });
  });

  group('columns and filters', () {
    testWidgets('Optional columns stay out of the default visible set', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(tester, accessPolicy: _readerPolicy);

      final AppListTable<AccountsPaymentMethod> table = tester
          .widget<AppListTable<AccountsPaymentMethod>>(
            find.byType(AppListTable<AccountsPaymentMethod>),
          );
      final List<String> defaultKeys = table.columns
          .map((AppListTableColumn<AccountsPaymentMethod> column) => column.key)
          .toList();
      final List<String> optionalKeys = table.columnChoices!
          .map((AppListTableColumn<AccountsPaymentMethod> column) => column.key)
          .toList();

      expect(defaultKeys, contains(accountsPaymentMethodCodeColumnId));
      expect(defaultKeys, contains(accountsPaymentMethodFeeRuleColumnId));
      expect(defaultKeys, contains(accountsPaymentMethodStatusColumnId));

      expect(optionalKeys, accountsPaymentMethodOptionalColumnIds);
      for (final String id in accountsPaymentMethodOptionalColumnIds) {
        expect(defaultKeys, isNot(contains(id)));
      }

      // Optional columns stay exportable so Settings/export keep the full
      // source-of-truth inventory.
      for (final AppListTableColumn<AccountsPaymentMethod> column
          in table.columnChoices!) {
        expect(column.includesInExport, isTrue);
      }
    });

    testWidgets('every specified domain filter reaches the committed query', (
      WidgetTester tester,
    ) async {
      final _MockPaymentMethodRepository methods = await _pumpPaymentMethods(
        tester,
        accessPolicy: _readerPolicy,
      );

      final AppListTable<AccountsPaymentMethod> table = tester
          .widget<AppListTable<AccountsPaymentMethod>>(
            find.byType(AppListTable<AccountsPaymentMethod>),
          );
      final List<String> groupKeys = table.search!.filterGroups
          .map((AppSearchBarFilterGroup group) => group.key)
          .toList();

      expect(groupKeys, contains('status'));
      expect(groupKeys, contains('method_type'));
      expect(groupKeys, contains('direction'));
      expect(groupKeys, contains('requires_reference'));
      expect(groupKeys, contains('requires_approval'));

      table.search!.onFilterChanged!(
        const AppSearchBarFilterValue(
          options: <String, String>{
            'status': 'ACTIVE',
            'method_type': 'MOBILE_MONEY',
            'direction': 'INCOMING',
            'requires_reference': 'true',
            'requires_approval': 'false',
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final List<AccountsPaymentMethodQuery> queries =
          verify(() => methods.listPaymentMethods(captureAny())).captured
              .cast<AccountsPaymentMethodQuery>();
      final AccountsPaymentMethodQuery committed = queries.last;
      expect(committed.statuses, <AccountsPaymentMethodStatus>{
        AccountsPaymentMethodStatus.active,
      });
      expect(committed.methodTypes, <AccountsPaymentMethodType>{
        AccountsPaymentMethodType.mobileMoney,
      });
      expect(committed.directions, <AccountsPaymentMethodDirection>{
        AccountsPaymentMethodDirection.incoming,
      });
      expect(committed.requiresExternalReference, isTrue);
      expect(committed.requiresApproval, isFalse);
      expect(committed.hasActiveFilters, isTrue);
    });

    testWidgets('the Facility filter appears only for multi-facility scope', (
      WidgetTester tester,
    ) async {
      // Both seeded rows share one facility, so the control is omitted rather
      // than rendered as dead chrome.
      await _pumpPaymentMethods(tester, accessPolicy: _readerPolicy);

      final AppListTable<AccountsPaymentMethod> table = tester
          .widget<AppListTable<AccountsPaymentMethod>>(
            find.byType(AppListTable<AccountsPaymentMethod>),
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
        AccountsPaymentMethodsAtomPermissions.tab.isAllowed(_readerPolicy),
        isTrue,
      );
      expect(
        AccountsPaymentMethodsAtomPermissions.create.isAllowed(_readerPolicy),
        isFalse,
      );
      expect(
        AccountsPaymentMethodsAtomPermissions.create.isAllowed(_writerPolicy),
        isTrue,
      );
      expect(canWriteAccountsPaymentMethods(_readerPolicy), isFalse);
      expect(canWriteAccountsPaymentMethods(_writerPolicy), isTrue);
    });

    test('a write-only grant does not surface the tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );
      expect(
        canViewAccountsSection(writeOnly, AccountsDeskSection.paymentMethods),
        isFalse,
      );
    });

    testWidgets('read-only hides New record, Actions, and workflow buttons', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(tester, accessPolicy: _readerPolicy);

      expect(find.text('Mobile Money'), findsWidgets);
      expect(
        find.text(_l10n.accountsPaymentMethodNewRecordAction),
        findsNothing,
      );
      expect(find.text(_l10n.accountsPaymentMethodActionsColumn), findsNothing);
      expect(
        find.text(_l10n.accountsPaymentMethodActivateAction),
        findsNothing,
      );
      expect(
        find.text(_l10n.accountsPaymentMethodBulkArchiveAction),
        findsNothing,
      );
    });

    testWidgets('write access shows the toolbar and per-row actions', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(tester, accessPolicy: _writerPolicy);

      expect(
        find.text(_l10n.accountsPaymentMethodActionsColumn),
        findsOneWidget,
      );
      expect(find.text(_l10n.accountsPaymentMethodViewAction), findsWidgets);
      expect(find.text(_l10n.accountsPaymentMethodActivateAction), findsWidgets);
    });
  });

  group('status rules', () {
    test('transitions follow the documented lifecycle', () {
      expect(_draftMethod.canActivate, isTrue);
      expect(_draftMethod.canDeactivate, isFalse);
      expect(_draftMethod.canEdit, isTrue);
      expect(_draftMethod.toggleAction, AccountsPaymentMethodAction.activate);

      const AccountsPaymentMethodStatus archived =
          AccountsPaymentMethodStatus.archived;
      expect(archived.allowedTransitions, <AccountsPaymentMethodStatus>{
        AccountsPaymentMethodStatus.active,
      });
    });

    test('an archived record is not editable and offers Restore', () {
      expect(_archivedMethod.canEdit, isFalse);
      expect(_archivedMethod.canClone, isFalse);
      expect(_archivedMethod.canRestore, isTrue);
      expect(
        _archivedMethod.toggleAction,
        AccountsPaymentMethodAction.restore,
      );
    });

    testWidgets('archived rows expose no Edit or Clone button', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(
        tester,
        accessPolicy: _writerPolicy,
        items: <AccountsPaymentMethod>[_archivedMethod],
      );

      expect(find.text('Bank Cheque'), findsWidgets);
      expect(find.text(_l10n.accountsPaymentMethodCloneAction), findsNothing);
      expect(find.text(_l10n.accountsPaymentMethodRestoreAction), findsWidgets);
      expect(find.text(_l10n.accountsPaymentMethodViewAction), findsOneWidget);
    });
  });

  group('workflow', () {
    testWidgets('Activate confirms, then posts the action with the version', (
      WidgetTester tester,
    ) async {
      final _MockPaymentMethodRepository methods =
          _MockPaymentMethodRepository();
      _stubMethods(methods, items: <AccountsPaymentMethod>[_draftMethod]);

      await _pumpActionHarness(
        tester,
        methods: methods,
        method: _draftMethod,
        action: AccountsPaymentMethodAction.activate,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog))
            .title,
        _l10n.accountsPaymentMethodActivateConfirmTitle,
      );

      await tester.tap(
        find
            .widgetWithText(
              AppButton,
              _l10n.accountsPaymentMethodActivateAction,
            )
            .last,
      );
      await tester.pumpAndSettle();

      verify(
        () => methods.applyAction(
          _draftMethod.humanFriendlyId,
          AccountsPaymentMethodAction.activate,
          version: _draftMethod.version,
        ),
      ).called(1);
    });

    testWidgets('Archive warns that the record is archived, not deleted', (
      WidgetTester tester,
    ) async {
      final _MockPaymentMethodRepository methods =
          _MockPaymentMethodRepository();
      _stubMethods(methods, items: <AccountsPaymentMethod>[_draftMethod]);

      await _pumpActionHarness(
        tester,
        methods: methods,
        method: _draftMethod,
        action: AccountsPaymentMethodAction.archive,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      final AppConfirmActionDialog dialog = tester
          .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog));
      expect(dialog.title, _l10n.accountsPaymentMethodArchiveConfirmTitle);
      expect(dialog.body, contains('archived, not deleted'));
      // The reference guard is stated up front, not discovered on failure.
      expect(dialog.body, contains('recorded payments'));
    });
  });

  group('privacy', () {
    testWidgets('no raw database identifier or raw enum reaches the table', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(tester, accessPolicy: _writerPolicy);

      expect(find.text('550e8400-e29b-41d4-a716-446655440020'), findsNothing);
      expect(find.text('DRAFT'), findsNothing);
      expect(find.text('MOBILE_MONEY'), findsNothing);
      expect(find.text('INCOMING'), findsNothing);
      expect(find.text(_l10n.accountsPaymentMethodStatusDraft), findsWidgets);
      expect(
        find.text(_l10n.accountsPaymentMethodTypeMobileMoney),
        findsWidgets,
      );
    });

    testWidgets('requirement flags export as localized Yes/No, not booleans', (
      WidgetTester tester,
    ) async {
      await _pumpPaymentMethods(
        tester,
        accessPolicy: _readerPolicy,
        items: <AccountsPaymentMethod>[_draftMethod],
      );

      final AppListTable<AccountsPaymentMethod> table = tester
          .widget<AppListTable<AccountsPaymentMethod>>(
            find.byType(AppListTable<AccountsPaymentMethod>),
          );
      AppListTableColumn<AccountsPaymentMethod> columnFor(String id) =>
          table.columns.firstWhere(
            (AppListTableColumn<AccountsPaymentMethod> column) =>
                column.key == id,
          );

      // The seeded row requires an external reference but not approval, so the
      // two flags must localize in opposite directions.
      expect(
        columnFor(
          accountsPaymentMethodRequiresReferenceColumnId,
        ).exportValue!(_draftMethod),
        _l10n.accountsPaymentMethodYes,
      );
      expect(
        columnFor(
          accountsPaymentMethodRequiresApprovalColumnId,
        ).exportValue!(_draftMethod),
        _l10n.accountsPaymentMethodNo,
      );

      // A raw boolean never reaches the sheet.
      expect(find.text('true'), findsNothing);
      expect(find.text('false'), findsNothing);
    });
  });
}
