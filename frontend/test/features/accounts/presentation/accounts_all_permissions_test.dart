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
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_form_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
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

const AccountsWorkItem _approvalItem = AccountsWorkItem(
  id: 'apr-1',
  kind: AccountsWorkItemKind.approval,
  displayId: 'APR-1',
  journalDisplayId: 'JE-200',
  status: 'PENDING',
  amount: 100,
  canApproveFlag: true,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 1,
  toPost: 1,
  needApproval: 1,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'facility-accounts', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockAccountsRepository repository, {
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_draftJournal],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(summary: _summary),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((_) async {
    return Result<AppPage<AccountsWorkItem>>.success(
      AppPage<AccountsWorkItem>(
        items: items,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.createJournal(any())).thenAnswer(
    (_) async => const Result<AccountsMutationResult>.success(
      AccountsMutationResult(item: _draftJournal, message: 'Saved.'),
    ),
  );
  when(() => repository.postJournal(any(), notes: any(named: 'notes')))
      .thenAnswer(
    (_) async => const Result<AccountsMutationResult>.success(
      AccountsMutationResult(
        item: AccountsWorkItem(
          id: 'jnl-draft',
          kind: AccountsWorkItemKind.journal,
          displayId: 'JE-100',
          status: 'POSTED',
          amount: 250,
          canPostFlag: false,
        ),
      ),
    ),
  );
  when(() => repository.approveRequest(any(), notes: any(named: 'notes')))
      .thenAnswer(
    (_) async => const Result<AccountsMutationResult>.success(
      AccountsMutationResult(item: _approvalItem, message: 'Saved.'),
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

Future<void> _pumpOpenWork(
  WidgetTester tester, {
  required _MockAccountsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_draftJournal],
  String initialLocation = '/accounts?section=work',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
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
        themeMode: themeMode,
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
    registerFallbackValue(
      AccountsJournalDraft(date: DateTime.utc(2026, 1, 1)),
    );
    registerFallbackValue(const AccountsGlQuery());
    registerFallbackValue(
      const AccountsWorkItem(id: 'x', kind: AccountsWorkItemKind.journal),
    );
  });

  setUp(() {
    repository = _MockAccountsRepository();
  });

  testWidgets(
    'read-only: Open work visible; Journal and Next absent; no no-access',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      expect(AccountsOpenWorkAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(AccountsOpenWorkAtomPermissions.journal.isAllowed(reader), isFalse);

      await _pumpOpenWork(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text(AccountsStrings.openWorkLabel), findsWidgets);
      // Trailing Journal uses tooltip (column header is also "Journal").
      expect(find.byTooltip(AccountsStrings.journalAction), findsNothing);
      expect(find.byTooltip(AccountsStrings.journalActionTooltip), findsNothing);
      expect(find.text(AccountsStrings.postAction), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.text('Analytics'), findsNothing);
      expect(find.text('Charge'), findsNothing);
      expect(find.text('Collect due'), findsNothing);
      expect(find.text('Trial balance'), findsNothing);
    },
  );

  testWidgets('write: Journal present; Post Next on draft', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.accountsRead,
        AppPermissions.accountsWrite,
      },
    );
    await _pumpOpenWork(
      tester,
      repository: repository,
      accessPolicy: writer,
    );

    expect(find.byTooltip(AccountsStrings.journalActionTooltip), findsWidgets);
    expect(find.text(AccountsStrings.postAction), findsWidgets);
  });

  testWidgets('write+financial:approve: Approve Next on approval item', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy approver = _policy(
      permissions: <AppPermission>{
        AppPermissions.accountsRead,
        AppPermissions.accountsWrite,
        AppPermissions.financialApprove,
      },
      modules: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'facility-accounts',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'billing-payments',
          licenseStatus: 'ACTIVE',
        ),
      ],
    );
    expect(
      AccountsOpenWorkAtomPermissions.approve.isAllowed(approver),
      isTrue,
    );
    await _pumpOpenWork(
      tester,
      repository: repository,
      accessPolicy: approver,
      items: const <AccountsWorkItem>[_approvalItem],
    );

    expect(find.text(AccountsStrings.approveAction), findsWidgets);
  });

  testWidgets('module missing: no strip / shrink', (WidgetTester tester) async {
    final AppAccessPolicy noModule = _policy(
      permissions: <AppPermission>{
        AppPermissions.accountsRead,
        AppPermissions.accountsWrite,
      },
      modules: const <AppModuleEntitlement>[],
    );
    await _pumpOpenWork(
      tester,
      repository: repository,
      accessPolicy: noModule,
    );

    expect(find.text(AccountsStrings.openWorkLabel), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('aliases all/inbox/tab select Open work', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.accountsRead},
    );
    for (final String location in <String>[
      '/accounts?section=all',
      '/accounts?section=inbox',
      '/accounts?tab=work',
    ]) {
      await _pumpOpenWork(
        tester,
        repository: repository,
        accessPolicy: reader,
        initialLocation: location,
      );
      expect(find.text(AccountsStrings.openWorkLabel), findsWidgets);
    }
  });

  testWidgets('Next Approve without opening Detail first', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy approver = _policy(
      permissions: <AppPermission>{
        AppPermissions.accountsRead,
        AppPermissions.accountsWrite,
        AppPermissions.financialApprove,
      },
      modules: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'facility-accounts',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'billing-payments',
          licenseStatus: 'ACTIVE',
        ),
      ],
    );
    await _pumpOpenWork(
      tester,
      repository: repository,
      accessPolicy: approver,
      items: const <AccountsWorkItem>[_approvalItem],
    );

    await tester.ensureVisible(
      find.widgetWithText(TextButton, AccountsStrings.approveAction).first,
    );
    await tester.tap(
      find.widgetWithText(TextButton, AccountsStrings.approveAction).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AccountsNotesForm), findsOneWidget);
    expect(find.text(AccountsStrings.detailTitleApproval), findsNothing);
  });

  testWidgets('empty state shows No open work.', (WidgetTester tester) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.accountsRead},
    );
    await _pumpOpenWork(
      tester,
      repository: repository,
      accessPolicy: reader,
      items: const <AccountsWorkItem>[],
    );
    expect(find.text(AccountsStrings.openWorkEmpty), findsOneWidget);
  });

  testWidgets('Next Post without opening Detail first', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.accountsRead,
        AppPermissions.accountsWrite,
      },
    );
    await _pumpOpenWork(
      tester,
      repository: repository,
      accessPolicy: writer,
    );

    await tester.ensureVisible(
      find.widgetWithText(TextButton, AccountsStrings.postAction).first,
    );
    await tester.tap(
      find.widgetWithText(TextButton, AccountsStrings.postAction).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 1));

    // Next opens Post notes modal (not Detail-first).
    expect(find.byType(AccountsNotesForm), findsOneWidget);
    expect(find.text(AccountsStrings.detailTitleApproval), findsNothing);
    expect(find.text(AccountsStrings.postAction), findsWidgets);
  });

  testWidgets('Journal flow lands on To post', (WidgetTester tester) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.accountsRead,
        AppPermissions.accountsWrite,
      },
    );
    await _pumpOpenWork(
      tester,
      repository: repository,
      accessPolicy: writer,
    );

    await tester.tap(find.byTooltip(AccountsStrings.journalActionTooltip).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byType(AccountsJournalDialog), findsOneWidget);

    final Finder fields = find.descendant(
      of: find.byType(AccountsJournalDialog),
      matching: find.byType(TextFormField),
    );
    // Period, Source, line1 Account/Debit/Credit/Memo, line2 Account/Debit/Credit/Memo, Notes.
    await tester.enterText(fields.at(0), '2026-01');
    await tester.enterText(fields.at(1), 'Manual');
    await tester.enterText(fields.at(2), '1000');
    await tester.enterText(fields.at(3), '10');
    await tester.enterText(fields.at(6), '2000');
    await tester.enterText(fields.at(8), '10');
    await tester.pump();

    await tester.tap(find.text('Save').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 1));

    verify(() => repository.createJournal(any())).called(1);
    expect(find.text(AccountsStrings.toPostLabel), findsWidgets);
  });

  testWidgets('mobile + dark theme smoke: Journal with write', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.accountsRead,
        AppPermissions.accountsWrite,
      },
    );
    await _pumpOpenWork(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );
    expect(find.byTooltip(AccountsStrings.journalActionTooltip), findsWidgets);
  });
}
