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
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_currency_rate_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_currency_rate.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_currency_rate_repository.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_currency_rate_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_currency_rates_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockCurrencyRateRepository extends Mock
    implements AccountsCurrencyRateRepository {}

final AccountsCurrencyRate _baseCurrency = AccountsCurrencyRate(
  humanFriendlyId: 'CUR-2026-0001',
  currencyCode: 'UGX',
  currencyName: 'Ugandan Shilling',
  symbol: 'USh',
  decimalPlaces: 0,
  baseCurrency: true,
  rateType: AccountsCurrencyRateType.spot,
  exchangeRate: 1,
  effectiveDate: DateTime.utc(2026),
  source: 'Bank of Uganda',
  status: AccountsCurrencyStatus.active,
  entityAndFacility: 'Kampala Main',
  version: 3,
);

final AccountsCurrencyRate _draftQuote = AccountsCurrencyRate(
  humanFriendlyId: 'CUR-2026-0002',
  currencyCode: 'USD',
  currencyName: 'US Dollar',
  symbol: r'$',
  decimalPlaces: 2,
  baseCurrency: false,
  rateType: AccountsCurrencyRateType.daily,
  exchangeRate: 3750.25,
  effectiveDate: DateTime.utc(2026, 2),
  source: 'Reuters',
  buyRate: 3740,
  sellRate: 3760,
  lastUpdatedAt: DateTime.utc(2026, 2, 1, 9, 30),
  updatedBy: 'A. Nakato',
  status: AccountsCurrencyStatus.draft,
  version: 1,
);

final AccountsCurrencyRate _archivedQuote = AccountsCurrencyRate(
  humanFriendlyId: 'CUR-2025-0009',
  currencyCode: 'KES',
  currencyName: 'Kenyan Shilling',
  symbol: 'KSh',
  decimalPlaces: 2,
  baseCurrency: false,
  rateType: AccountsCurrencyRateType.monthly,
  exchangeRate: 28.4,
  effectiveDate: DateTime.utc(2025, 12),
  status: AccountsCurrencyStatus.archived,
  archivedAt: DateTime.utc(2026),
  version: 5,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 2,
  fiscalPeriodsActive: 11,
  currencyRatesActive: 6,
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

void _stubRates(
  _MockCurrencyRateRepository repository, {
  required List<AccountsCurrencyRate> items,
  int filteredTotal = 2,
}) {
  when(() => repository.listRates(any())).thenAnswer((Invocation inv) async {
    final AccountsCurrencyRateQuery query =
        inv.positionalArguments.first as AccountsCurrencyRateQuery;
    return Result<AppPage<AccountsCurrencyRate>>.success(
      AppPage<AccountsCurrencyRate>(
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
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).thenAnswer((_) async => Result<AccountsCurrencyRate>.success(_draftQuote));
}

Future<_MockCurrencyRateRepository> _pumpCurrencyRates(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  List<AccountsCurrencyRate>? items,
  int filteredTotal = 2,
  String location = '/accounts?section=currencies-and-exchange-rates',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  final _MockCurrencyRateRepository rates = _MockCurrencyRateRepository();
  _stubAccounts(accounts);
  _stubRates(
    rates,
    items: items ?? <AccountsCurrencyRate>[_baseCurrency, _draftQuote],
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
        accountsCurrencyRateRepositoryProvider.overrideWithValue(rates),
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
  return rates;
}

/// Minimal host for [confirmAccountsCurrencyRateAction]; in the panel the same
/// call sits behind a row button in the trailing Actions column.
Future<void> _pumpActionHarness(
  WidgetTester tester, {
  required _MockCurrencyRateRepository rates,
  required AccountsCurrencyRate rate,
  required AccountsCurrencyRateAction action,
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
        accountsCurrencyRateRepositoryProvider.overrideWithValue(rates),
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
                onPressed: () => confirmAccountsCurrencyRateAction(
                  context: context,
                  ref: ref,
                  rate: rate,
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
    registerFallbackValue(const AccountsCurrencyRateQuery());
    registerFallbackValue(AccountsCurrencyRateAction.activate);
  });

  group('navigation and scoping', () {
    test('the tab is a leaf under Setup & Controls', () {
      expect(
        AccountsDeskCategory.setupAndControls.sections,
        contains(AccountsDeskSection.currenciesAndExchangeRates),
      );
      expect(
        AccountsDeskSection.currenciesAndExchangeRates.category,
        AccountsDeskCategory.setupAndControls,
      );
    });

    test('the section slug matches the API path segment', () {
      expect(
        AccountsDeskSection.currenciesAndExchangeRates.sectionQueryValue,
        accountsCurrencyRatesSectionSlug,
      );
      expect(
        AccountsDeskSection.resolveDeskSlug('currencies-and-exchange-rates'),
        AccountsDeskSection.currenciesAndExchangeRates,
      );
      expect(
        AccountsDeskSection.resolveDeskSlug('exchange-rates'),
        AccountsDeskSection.currenciesAndExchangeRates,
      );
    });

    test('the table exposes the fourteen documented columns', () {
      expect(accountsCurrencyRateColumnIds.length, 14);
      expect(accountsCurrencyRateColumnIds.first, accountsCurrencyCodeColumnId);
      expect(
        accountsCurrencyRateColumnIds.last,
        accountsCurrencyStatusColumnId,
      );
      expect(
        accountsCurrencyRateOptionalColumnIds.every(
          accountsCurrencyRateColumnIds.contains,
        ),
        isTrue,
      );
      expect(
        accountsCurrencyRateDefaultColumnIds.every(
          accountsCurrencyRateColumnIds.contains,
        ),
        isTrue,
      );
      expect(
        accountsCurrencyRateDefaultColumnIds.any(
          accountsCurrencyRateOptionalColumnIds.contains,
        ),
        isFalse,
      );
    });

    testWidgets('deep link opens the tab under the Setup & Controls folder', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(tester, accessPolicy: _readerPolicy);

      expect(find.byType(AccountsCurrencyRatesPanel), findsOneWidget);

      final AppTabStrip categories = tester.widget<AppTabStrip>(
        find.byKey(accountsCategoryTabsKey),
      );
      expect(categories.selectedId, AccountsDeskCategory.setupAndControls.name);

      final AppTabStrip sections = tester.widget<AppTabStrip>(
        find.byKey(accountsSectionTabsKey),
      );
      expect(sections.selectedId, 'currenciesAndExchangeRates');
      expect(
        sections.tabs.map((AppTabItem tab) => tab.label),
        contains(AccountsStrings.currenciesLabel),
      );
    });

    testWidgets('sibling leaves stay reachable from the same folder', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(tester, accessPolicy: _readerPolicy);

      final AppTabStrip sections = tester.widget<AppTabStrip>(
        find.byKey(accountsSectionTabsKey),
      );
      expect(
        sections.tabs.map((AppTabItem tab) => tab.label),
        containsAll(<String>[
          AccountsStrings.fiscalPeriodsLabel,
          AccountsStrings.currenciesLabel,
        ]),
      );
    });

    testWidgets('the badge uses the summary until the query is narrowed', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(tester, accessPolicy: _readerPolicy);

      AppTabItem tab() => tester
          .widget<AppTabStrip>(find.byKey(accountsSectionTabsKey))
          .tabs
          .firstWhere(
            (AppTabItem item) => item.label == AccountsStrings.currenciesLabel,
          );
      expect(tab().count, _summary.currencyRatesActive);

      await tester.enterText(find.byType(TextField).first, 'Dollar');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(tab().count, 2);
    });
  });

  group('permissions', () {
    test('every atom resolves to an accounts permission', () {
      expect(
        AccountsCurrencyRatesAtomPermissions.tab.isAllowed(_readerPolicy),
        isTrue,
      );
      expect(
        AccountsCurrencyRatesAtomPermissions.create.isAllowed(_readerPolicy),
        isFalse,
      );
      expect(
        AccountsCurrencyRatesAtomPermissions.create.isAllowed(_writerPolicy),
        isTrue,
      );
      expect(canWriteAccountsCurrencyRates(_readerPolicy), isFalse);
      expect(canWriteAccountsCurrencyRates(_writerPolicy), isTrue);
    });

    test('a write-only grant does not surface the tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );
      expect(
        canViewAccountsSection(
          writeOnly,
          AccountsDeskSection.currenciesAndExchangeRates,
        ),
        isFalse,
      );
    });

    testWidgets('read-only hides New record, Actions, and workflow buttons', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(tester, accessPolicy: _readerPolicy);

      expect(find.text('Ugandan Shilling'), findsWidgets);
      expect(find.text(AccountsStrings.currencyNewRecordAction), findsNothing);
      expect(find.text(AccountsStrings.currencyActionsColumn), findsNothing);
      expect(find.text(AccountsStrings.currencyActivateAction), findsNothing);
      expect(find.text(AccountsStrings.currencyArchiveAction), findsNothing);
      expect(find.text(AccountsStrings.currencyBulkArchiveAction), findsNothing);
    });

    testWidgets('write access shows the toolbar and per-row actions', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(tester, accessPolicy: _writerPolicy);

      expect(find.text(AccountsStrings.currencyActionsColumn), findsOneWidget);
      expect(find.text(AccountsStrings.currencyViewAction), findsWidgets);
      expect(find.text(AccountsStrings.currencyActivateAction), findsWidgets);
    });
  });

  group('status rules', () {
    test('transitions follow the documented lifecycle', () {
      expect(_draftQuote.canActivate, isTrue);
      expect(_draftQuote.canDeactivate, isFalse);
      expect(_draftQuote.canEdit, isTrue);
      expect(_draftQuote.toggleAction, AccountsCurrencyRateAction.activate);

      expect(
        AccountsCurrencyStatus.archived.allowedTransitions,
        <AccountsCurrencyStatus>{AccountsCurrencyStatus.active},
      );
      expect(_archivedQuote.canEdit, isFalse);
      expect(_archivedQuote.canClone, isFalse);
      expect(_archivedQuote.toggleAction, AccountsCurrencyRateAction.restore);
    });

    test('the base currency cannot be deactivated or archived', () {
      expect(_baseCurrency.baseCurrency, isTrue);
      expect(_baseCurrency.canDeactivate, isFalse);
      expect(_baseCurrency.canArchive, isFalse);
      expect(_baseCurrency.toggleAction, isNull);
      expect(_baseCurrency.exchangeRate, 1);
    });

    testWidgets('base-currency rows expose no Deactivate or Archive button', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(
        tester,
        accessPolicy: _writerPolicy,
        items: <AccountsCurrencyRate>[_baseCurrency],
      );

      expect(find.text('Ugandan Shilling'), findsWidgets);
      expect(find.text(AccountsStrings.currencyDeactivateAction), findsNothing);
      expect(find.text(AccountsStrings.currencyArchiveAction), findsNothing);
      expect(find.text(AccountsStrings.currencyViewAction), findsOneWidget);
    });
  });

  group('workflow', () {
    testWidgets('Activate confirms, then posts the action with the version', (
      WidgetTester tester,
    ) async {
      final _MockCurrencyRateRepository rates = _MockCurrencyRateRepository();
      _stubRates(rates, items: <AccountsCurrencyRate>[_draftQuote]);

      await _pumpActionHarness(
        tester,
        rates: rates,
        rate: _draftQuote,
        action: AccountsCurrencyRateAction.activate,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog))
            .title,
        AccountsStrings.currencyActivateConfirmTitle,
      );

      await tester.tap(
        find
            .widgetWithText(AppButton, AccountsStrings.currencyActivateAction)
            .last,
      );
      await tester.pumpAndSettle();

      final VerificationResult call = verify(
        () => rates.applyAction(
          _draftQuote.humanFriendlyId,
          AccountsCurrencyRateAction.activate,
          version: _draftQuote.version,
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      )..called(1);
      expect(call.captured.single, isA<String>().having(
        (String key) => key.trim(),
        'idempotency key',
        isNotEmpty,
      ));
    });

    testWidgets('Archive warns that the rate is archived, not deleted', (
      WidgetTester tester,
    ) async {
      final _MockCurrencyRateRepository rates = _MockCurrencyRateRepository();
      _stubRates(rates, items: <AccountsCurrencyRate>[_draftQuote]);

      await _pumpActionHarness(
        tester,
        rates: rates,
        rate: _draftQuote,
        action: AccountsCurrencyRateAction.archive,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      final AppConfirmActionDialog dialog = tester
          .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog));
      expect(dialog.title, AccountsStrings.currencyArchiveConfirmTitle);
      expect(dialog.body, contains('archived, not deleted'));
      expect(find.textContaining('archived, not deleted'), findsOneWidget);
    });
  });

  group('table chrome', () {
    testWidgets('the pinned footer totals the server-filtered result', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(tester, accessPolicy: _readerPolicy);

      expect(find.text(AccountsStrings.currencyRowsTotal(2)), findsOneWidget);
      expect(find.text(AccountsStrings.currencyActiveTotal(1)), findsOneWidget);
    });

    testWidgets('optional columns stay hidden until enabled in Settings', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(tester, accessPolicy: _readerPolicy);

      expect(find.text(AccountsStrings.currencyCodeColumn), findsOneWidget);
      expect(
        find.text(AccountsStrings.currencyExchangeRateColumn),
        findsOneWidget,
      );
      expect(find.text(AccountsStrings.currencyBaseColumn), findsOneWidget);
      expect(find.text(AccountsStrings.currencyStatusColumn), findsOneWidget);
      expect(find.text(AccountsStrings.currencySellRateColumn), findsNothing);
      expect(find.text(AccountsStrings.currencyUpdatedByColumn), findsNothing);
      expect(find.text(AccountsStrings.currencySymbolColumn), findsNothing);
    });
  });

  group('privacy', () {
    testWidgets('no raw database identifier or wire enum reaches the table', (
      WidgetTester tester,
    ) async {
      await _pumpCurrencyRates(tester, accessPolicy: _writerPolicy);

      expect(find.text('550e8400-e29b-41d4-a716-446655440020'), findsNothing);
      expect(find.text('DRAFT'), findsNothing);
      expect(find.text('SPOT'), findsNothing);
      expect(find.text(AccountsStrings.currencyStatusDraft), findsWidgets);
      expect(find.text(AccountsStrings.currencyRateTypeSpot), findsWidgets);
    });
  });
}
