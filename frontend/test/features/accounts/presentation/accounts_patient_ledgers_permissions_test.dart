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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_ledgers_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_ledgers_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_patient_ledger_print_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsPatientBalance _balanced = AccountsPatientBalance(
  patientId: 'p-1',
  patientDisplayId: 'MRN-1',
  patientDisplayName: 'Ada',
  invoiced: 100,
  paid: 40,
  balance: 60,
);

const AccountsPatientBalance _cleared = AccountsPatientBalance(
  patientId: 'p-2',
  patientDisplayId: 'MRN-2',
  patientDisplayName: 'Ben',
  invoiced: 100,
  paid: 100,
  balance: 0,
  clearance: AccountsClearanceState.cleared,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'facility-accounts', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
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
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBase(
  _MockAccountsRepository repository, {
  List<AccountsPatientBalance> rows = const <AccountsPatientBalance>[
    _balanced,
    _cleared,
  ],
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
  when(() => repository.listGlAccounts(any())).thenAnswer(
    (_) async => const Result<AppPage<AccountsGlAccount>>.success(
      AppPage<AccountsGlAccount>(
        items: <AccountsGlAccount>[],
        request: AppPageRequest(pageSize: 100),
        totalItemCount: 0,
      ),
    ),
  );
  when(
    () => repository.listPatientLedgers(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => Result<AppPage<AccountsPatientBalance>>.success(
      AppPage<AccountsPatientBalance>(
        items: rows,
        request: const AppPageRequest(pageSize: 100),
        totalItemCount: rows.length,
      ),
    ),
  );
  when(
    () => repository.getPatientLedger(
      any(),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => const Result<AccountsPatientLedger>.success(
      AccountsPatientLedger(
        patientId: 'p-1',
        patientDisplayId: 'MRN-1',
        patientDisplayName: 'Ada',
        summary: AccountsPatientLedgerSummary(
          totalInvoiced: 100,
          netPaid: 40,
          balanceDue: 60,
        ),
        entries: <AccountsPatientLedgerEntry>[
          AccountsPatientLedgerEntry(
            id: 'e1',
            displayId: 'INV-9',
            action: 'Charge',
            amount: 60,
          ),
        ],
      ),
    ),
  );
}

Future<GoRouter> _pumpLedgers(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  String location = '/accounts?section=ledgers',
  List<AccountsPatientBalance> rows = const <AccountsPatientBalance>[
    _balanced,
    _cleared,
  ],
  List<dynamic> extraOverrides = const <dynamic>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository repository = _MockAccountsRepository();
  _stubBase(repository, rows: rows);

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
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: Text('billing:${state.uri.query}'),
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
  return router;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
    registerFallbackValue(const AccountsGlQuery());
    registerFallbackValue(const AccountsPatientLedgerQuery());
  });

  group('Patient ledgers permissions', () {
    test('tab requires accounts read ∩ facility-accounts', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
        modules: const <AppModuleEntitlement>[],
      );
      expect(canViewAccountsSection(reader, AccountsDeskSection.ledgers), isTrue);
      expect(
        canViewAccountsSection(noModule, AccountsDeskSection.ledgers),
        isFalse,
      );
      expect(
        AccountsPatientLedgersAtomPermissions.tab.isAllowed(reader),
        isTrue,
      );
    });

    test('Pay absent without billing write ∩ billing-payments', () {
      final AppAccessPolicy accountsOnly = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      expect(
        accountsPatientLedgerNextActionLabel(
          policy: accountsOnly,
          row: _balanced,
        ),
        AccountsStrings.ledgerAction,
      );
      expect(canPayFromAccounts(accountsOnly), isFalse);
    });

    test('Pay present with billing write ∩ billing-payments when balance', () {
      final AppAccessPolicy both = _policy(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        accountsPatientLedgerNextActionLabel(policy: both, row: _balanced),
        AccountsStrings.payAction,
      );
      expect(
        accountsPatientLedgerNextActionLabel(policy: both, row: _cleared),
        AccountsStrings.ledgerAction,
      );
    });

    test('Ledger present with accounts:read', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      expect(accountsPatientLedgerShowsLedger(reader), isTrue);
      expect(accountsLedgersShowsNextActionColumn(reader), isTrue);
    });

    test('patient-ledgers alias resolves to ledgers', () {
      expect(
        AccountsDeskSection.resolveDeskSlug('patient-ledgers'),
        AccountsDeskSection.ledgers,
      );
      expect(
        AccountsDeskSection.resolveDeskSlug('ledgers')?.sectionQueryValue,
        'ledgers',
      );
    });

    test('settings key is accounts_ledgers_v1', () {
      expect(accountsLedgersTableSettingsKey, 'accounts_ledgers_v1');
    });
  });

  group('Patient ledgers flows', () {
    testWidgets('tab visible with label and tooltip', (WidgetTester tester) async {
      await _pumpLedgers(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      expect(find.byType(AccountsLedgersPanel), findsOneWidget);
      expect(find.text(AccountsStrings.patientLedgersLabel), findsWidgets);
      expect(
        find.byTooltip(AccountsStrings.patientLedgersTooltip),
        findsOneWidget,
      );
      expect(find.textContaining('Ada'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('alias patient-ledgers selects Patient ledgers', (
      WidgetTester tester,
    ) async {
      await _pumpLedgers(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        location: '/accounts?section=patient-ledgers',
      );

      expect(find.byType(AccountsLedgersPanel), findsOneWidget);
      expect(find.text(AccountsStrings.patientLedgersLabel), findsWidgets);
    });

    testWidgets('empty state shows No patients match.', (
      WidgetTester tester,
    ) async {
      await _pumpLedgers(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        rows: const <AccountsPatientBalance>[],
      );

      expect(find.text(AccountsStrings.patientLedgersEmpty), findsOneWidget);
    });

    testWidgets('Pay absent without billing write; Ledger present', (
      WidgetTester tester,
    ) async {
      await _pumpLedgers(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      expect(find.text(AccountsStrings.payAction), findsNothing);
      expect(find.text(AccountsStrings.ledgerAction), findsWidgets);
    });

    testWidgets('Pay deep-links to Billing Collect due', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpLedgers(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.text(AccountsStrings.payAction), findsWidgets);
      await tester.tap(find.text(AccountsStrings.payAction).first);
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/billing');
      expect(router.state.uri.queryParameters['section'], 'collect');
      expect(router.state.uri.queryParameters['action'], 'pay');
      expect(router.state.uri.queryParameters['patientId'], 'p-1');
    });

    testWidgets('row click opens Patient ledger; Charge absent', (
      WidgetTester tester,
    ) async {
      await _pumpLedgers(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
      );

      await tester.tap(find.textContaining('Ada'));
      await tester.pumpAndSettle();

      expect(find.textContaining(AccountsStrings.patientLedgerTitle), findsWidgets);
      expect(find.text(AccountsStrings.printAction), findsOneWidget);
      expect(find.text('Charge'), findsNothing);
    });

    testWidgets('patientId deep link opens Patient ledger dialog', (
      WidgetTester tester,
    ) async {
      await _pumpLedgers(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        location: '/accounts?section=ledgers&patientId=MRN-1',
      );

      expect(find.textContaining(AccountsStrings.patientLedgerTitle), findsWidgets);
    });

    testWidgets('Patient ledger Print opens preview with section options', (
      WidgetTester tester,
    ) async {
      const PrintFormTemplateContext templateContext = PrintFormTemplateContext(
        appBranding: PrintFormBranding(
          name: 'Test HMS',
          kind: PrintFormBrandingKind.app,
        ),
      );
      await _pumpLedgers(
        tester,
        accessPolicy: _policy(
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

      await tester.tap(find.textContaining('Ada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AccountsStrings.printAction));
      await tester.pumpAndSettle();

      expect(find.byType(AppPrintPreviewPanel), findsOneWidget);
      expect(find.text('Print sections'), findsOneWidget);
      expect(find.text('Patient'), findsWidgets);
    });

    testWidgets('UUID-only patient id is scrubbed from list', (
      WidgetTester tester,
    ) async {
      const String uuid = '550e8400-e29b-41d4-a716-446655440000';
      await _pumpLedgers(
        tester,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        rows: const <AccountsPatientBalance>[
          AccountsPatientBalance(
            patientId: uuid,
            patientDisplayId: uuid,
            patientDisplayName: uuid,
            balance: 10,
          ),
        ],
      );

      expect(find.textContaining(uuid), findsNothing);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('patient ledger print HTML never includes raw UUID', (
      WidgetTester tester,
    ) async {
      const String uuid = '550e8400-e29b-41d4-a716-446655440000';
      const AccountsPatientLedger ledger = AccountsPatientLedger(
        patientId: uuid,
        patientDisplayId: 'MRN-9',
        patientDisplayName: 'Cara',
        entries: <AccountsPatientLedgerEntry>[
          AccountsPatientLedgerEntry(
            id: uuid,
            displayId: 'INV-1',
            action: uuid,
            amount: 5,
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
              html = accountsPatientLedgerHtml(context, ledger);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(html.contains(uuid), isFalse);
      expect(html.contains('MRN-9'), isTrue);
      expect(html.contains('INV-1'), isTrue);
    });
  });
}
