import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
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
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsGlAccount _cash = AccountsGlAccount(
  id: 'acc-1',
  name: 'Cash',
  code: '1000',
  type: 'ASSET',
  hasActivity: true,
  debit: 100,
  credit: 20,
  balance: 80,
);

const AccountsGlAccount _inactive = AccountsGlAccount(
  id: 'acc-2',
  name: 'Dormant',
  code: '1999',
  type: 'ASSET',
  hasActivity: false,
);

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

void _stubBase(
  _MockAccountsRepository repository, {
  List<AccountsGlAccount> accounts = const <AccountsGlAccount>[_cash, _inactive],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(),
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
    () => repository.listGlAccounts(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => Result<AppPage<AccountsGlAccount>>.success(
      AppPage<AccountsGlAccount>(
        items: accounts,
        request: const AppPageRequest(pageSize: 100),
        totalItemCount: accounts.length,
      ),
    ),
  );
  when(
    () => repository.getAccountLedger(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => const Result<AccountsGlLedger>.success(
      AccountsGlLedger(
        account: _cash,
        summary: AccountsGlLedgerSummary(debit: 100, credit: 20, balance: 80),
        entries: <AccountsGlLedgerEntry>[
          AccountsGlLedgerEntry(
            id: 'e1',
            journal: 'JE-9',
            reference: 'REF-1',
            debit: 100,
          ),
        ],
      ),
    ),
  );
  when(() => repository.createJournal(any())).thenAnswer(
    (_) async => const Result<AccountsMutationResult>.success(
      AccountsMutationResult(),
    ),
  );
}

Future<_MockAccountsRepository> _pumpGl(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  String location = '/accounts?section=gl',
  List<AccountsGlAccount> accounts = const <AccountsGlAccount>[_cash, _inactive],
  List<dynamic> extraOverrides = const <dynamic>[],
  void Function(_MockAccountsRepository repository)? customize,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accountsRepo = _MockAccountsRepository();
  _stubBase(accountsRepo, accounts: accounts);
  customize?.call(accountsRepo);

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
        accountsRepositoryProvider.overrideWithValue(accountsRepo),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
        ...extraOverrides,
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
  await tester.pumpAndSettle();
  return accountsRepo;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsGlQuery());
    registerFallbackValue(
      AccountsJournalDraft(date: DateTime.utc(2026, 8, 1)),
    );
  });

  testWidgets('General ledger tab visible with accounts read', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policyFor(
      permissions: <AppPermission>{AppPermissions.accountsRead},
    );
    expect(AccountsGeneralLedgerAtomPermissions.tab.isAllowed(reader), isTrue);

    await _pumpGl(tester, accessPolicy: reader);

    expect(find.byType(AccountsWorkspacePage), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text(AccountsStrings.generalLedgerLabel), findsWidgets);
    expect(
      find.byTooltip(AccountsStrings.generalLedgerTooltip),
      findsOneWidget,
    );
    expect(find.byType(AccountsGlPanel), findsOneWidget);
    expect(find.text('1000 · Cash'), findsOneWidget);
    expect(find.text(AccountsStrings.nextGl), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('alias general-ledger selects General ledger', (
    WidgetTester tester,
  ) async {
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      location: '/accounts?section=general-ledger',
    );

    expect(find.text(AccountsStrings.generalLedgerLabel), findsWidgets);
    expect(find.byType(AccountsGlPanel), findsOneWidget);
  });

  testWidgets('empty state shows No accounts match.', (
    WidgetTester tester,
  ) async {
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      accounts: const <AccountsGlAccount>[],
    );

    expect(find.text(AccountsStrings.glEmpty), findsOneWidget);
  });

  testWidgets('Next GL omitted when account has no activity', (
    WidgetTester tester,
  ) async {
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      accounts: const <AccountsGlAccount>[_inactive],
    );

    expect(find.text('1999 · Dormant'), findsOneWidget);
    expect(find.text(AccountsStrings.nextGl), findsNothing);
  });

  testWidgets('Journal in Account ledger absent without accounts:write', (
    WidgetTester tester,
  ) async {
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
    );

    await tester.tap(find.text('1000 · Cash'));
    await tester.pumpAndSettle();

    expect(
      find.text(AccountsStrings.accountLedgerTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(AccountsStrings.journalAction), findsNothing);
    expect(find.text(AccountsStrings.postAction), findsNothing);
    expect(find.text(AccountsStrings.printAction), findsOneWidget);
  });

  testWidgets('write: Journal present in Account ledger; Post absent', (
    WidgetTester tester,
  ) async {
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      ),
    );

    await tester.tap(find.text(AccountsStrings.nextGl).first);
    await tester.pumpAndSettle();

    expect(find.text(AccountsStrings.journalAction), findsOneWidget);
    expect(find.text(AccountsStrings.postAction), findsNothing);
  });

  testWidgets('accountId deep link opens Account ledger', (
    WidgetTester tester,
  ) async {
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      location: '/accounts?section=gl&accountId=1000',
    );

    expect(
      find.text(AccountsStrings.accountLedgerTitle.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('Account ledger Print opens preview with section options', (
    WidgetTester tester,
  ) async {
    const PrintFormTemplateContext templateContext = PrintFormTemplateContext(
      appBranding: PrintFormBranding(
        name: 'Test HMS',
        kind: PrintFormBrandingKind.app,
      ),
    );
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      extraOverrides: [
        printFormTemplateContextReadyProvider.overrideWith(
          (ref) async => templateContext,
        ),
        printFormTemplateContextProvider.overrideWith(
          (ref) => templateContext,
        ),
      ],
    );

    await tester.tap(find.text('1000 · Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AccountsStrings.printAction));
    await tester.pumpAndSettle();

    expect(find.byType(AppPrintPreviewPanel), findsOneWidget);
    expect(find.text('Print sections'), findsOneWidget);
    expect(find.text('Account identity'), findsWidgets);
  });

  testWidgets('UUID-only account id is scrubbed from GL list', (
    WidgetTester tester,
  ) async {
    const String uuid = '550e8400-e29b-41d4-a716-446655440000';
    await _pumpGl(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      ),
      accounts: const <AccountsGlAccount>[
        AccountsGlAccount(
          id: uuid,
          name: uuid,
          code: '',
          hasActivity: true,
        ),
      ],
    );

    expect(find.textContaining(uuid), findsNothing);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('GL print HTML never includes raw UUID', (
    WidgetTester tester,
  ) async {
    const String uuid = '550e8400-e29b-41d4-a716-446655440000';
    const AccountsGlLedger ledger = AccountsGlLedger(
      account: AccountsGlAccount(
        id: uuid,
        name: 'Cash',
        code: '1000',
      ),
      entries: <AccountsGlLedgerEntry>[
        AccountsGlLedgerEntry(
          id: uuid,
          journal: 'JE-1',
          reference: uuid,
          memo: 'Ok',
          debit: 10,
        ),
      ],
    );

    late String html;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            html = accountsGlLedgerHtml(context, ledger);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html.contains(uuid), isFalse);
    expect(html.contains('1000'), isTrue);
    expect(html.contains('JE-1'), isTrue);
  });
}
