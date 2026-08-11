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
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountsRepository extends Mock implements AccountsRepository {}

const AccountsWorkItem _draftJournal = AccountsWorkItem(
  id: 'je-draft',
  kind: AccountsWorkItemKind.journal,
  displayId: 'JE-DRAFT',
  journalDisplayId: 'JE-DRAFT',
  periodLabel: '2026-08',
  status: 'DRAFT',
  amount: 250,
  sourceLabel: 'Manual',
  canPostFlag: true,
);

const AccountsWorkItem _postedJournal = AccountsWorkItem(
  id: 'je-draft',
  kind: AccountsWorkItemKind.journal,
  displayId: 'JE-DRAFT',
  journalDisplayId: 'JE-DRAFT',
  periodLabel: '2026-08',
  status: 'POSTED',
  amount: 250,
  sourceLabel: 'Manual',
  canPostFlag: false,
);

const AccountsSummary _summary = AccountsSummary(openWork: 1, toPost: 1);

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

void _stubRepository(
  _MockAccountsRepository repository, {
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_draftJournal],
  AccountsSummary summary = _summary,
  bool removeDraftAfterPost = false,
}) {
  var draftPosted = false;
  when(() => repository.getWorkspace(any())).thenAnswer((_) async {
    final AccountsSummary live = draftPosted && removeDraftAfterPost
        ? const AccountsSummary()
        : summary;
    return Result<AccountsWorkspaceOverview>.success(
      AccountsWorkspaceOverview(summary: live),
    );
  });
  when(() => repository.listWorkItems(any())).thenAnswer((_) async {
    final List<AccountsWorkItem> live =
        draftPosted && removeDraftAfterPost
        ? const <AccountsWorkItem>[]
        : items;
    return Result<AppPage<AccountsWorkItem>>.success(
      AppPage<AccountsWorkItem>(
        items: live,
        request: const AppPageRequest(pageSize: 20),
        totalItemCount: live.length,
      ),
    );
  });
  when(
    () => repository.postJournal(any(), notes: any(named: 'notes')),
  ).thenAnswer((_) async {
    draftPosted = true;
    return const Result<AccountsMutationResult>.success(
      AccountsMutationResult(item: _postedJournal),
    );
  });
}

Future<void> _pumpToPostTab(
  WidgetTester tester, {
  required _MockAccountsRepository repository,
  required AppAccessPolicy accessPolicy,
  String location = '/accounts?section=journals',
  List<AccountsWorkItem> items = const <AccountsWorkItem>[_draftJournal],
  AccountsSummary summary = _summary,
  bool removeDraftAfterPost = false,
  List<dynamic> extraOverrides = const <dynamic>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items,
    summary: summary,
    removeDraftAfterPost: removeDraftAfterPost,
  );

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
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late _MockAccountsRepository repository;

  setUpAll(() {
    registerFallbackValue(const AccountsWorkspaceQuery());
  });

  setUp(() {
    repository = _MockAccountsRepository();
  });

  testWidgets(
    'read-only: To post visible; Post / Post all absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      expect(AccountsToPostAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(AccountsToPostAtomPermissions.post.isAllowed(reader), isFalse);
      expect(AccountsToPostAtomPermissions.postAll.isAllowed(reader), isFalse);

      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text(AccountsStrings.toPostLabel), findsWidgets);
      expect(find.text('JE-DRAFT'), findsOneWidget);
      expect(find.text(AccountsStrings.postAllAction), findsNothing);
      expect(find.byTooltip(AccountsStrings.postActionTooltip), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text(AccountsStrings.nextColumn),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write: Post next-action and Post all mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      );
      expect(AccountsToPostAtomPermissions.post.isAllowed(writer), isTrue);

      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('JE-DRAFT'), findsOneWidget);
      expect(find.text(AccountsStrings.postAllAction), findsOneWidget);
      expect(find.byTooltip(AccountsStrings.postActionTooltip), findsWidgets);
      // Trailing Journal belongs on Open work only; column header is also
      // "Journal", so assert Post all is the trailing action instead.
      expect(find.byTooltip(AccountsStrings.journalAction), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'facility-accounts missing omits To post chrome',
    (WidgetTester tester) async {
      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('JE-DRAFT'), findsNothing);
      expect(find.text(AccountsStrings.postAllAction), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'empty state shows No drafts to post.',
    (WidgetTester tester) async {
      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        items: const <AccountsWorkItem>[],
        summary: const AccountsSummary(),
      );

      expect(find.text(AccountsStrings.toPostEmpty), findsOneWidget);
    },
  );

  testWidgets(
    'aliases ready-to-post select To post',
    (WidgetTester tester) async {
      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        location: '/accounts?section=ready-to-post',
      );

      expect(find.text(AccountsStrings.toPostLabel), findsWidgets);
      expect(find.text('JE-DRAFT'), findsOneWidget);
    },
  );

  testWidgets(
    'Post from Next completes without Detail',
    (WidgetTester tester) async {
      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
          },
        ),
        removeDraftAfterPost: true,
      );

      final Finder postNext = find.byTooltip(AccountsStrings.postActionTooltip);
      expect(postNext, findsWidgets);
      await tester.ensureVisible(postNext.first);
      await tester.tap(postNext.first);
      // AppDialog uppercases plain Text titles.
      final String dialogTitle =
          AccountsStrings.postDialogTitle.toUpperCase();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text(dialogTitle).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.text(dialogTitle), findsOneWidget);
      await tester.tap(find.text(AccountsStrings.postAction).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => repository.postJournal('je-draft', notes: any(named: 'notes')),
      ).called(1);
      expect(find.text(AccountsStrings.posted), findsOneWidget);
      expect(find.text('JE-DRAFT'), findsNothing);
      expect(find.text(AccountsStrings.toPostEmpty), findsOneWidget);
    },
  );

  testWidgets(
    'Post all confirms then bulk-posts page',
    (WidgetTester tester) async {
      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
          },
        ),
        removeDraftAfterPost: true,
      );

      await tester.tap(find.text(AccountsStrings.postAllAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text(AccountsStrings.postAllConfirmTitle.toUpperCase()),
        findsOneWidget,
      );
      await tester.tap(find.text(AccountsStrings.postAllAction).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => repository.postJournal('je-draft', notes: any(named: 'notes')),
      ).called(1);
      expect(find.text(AccountsStrings.posted), findsOneWidget);
      expect(find.text(AccountsStrings.toPostEmpty), findsOneWidget);
    },
  );

  testWidgets(
    'action=post deep link opens Post modal',
    (WidgetTester tester) async {
      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
          },
        ),
        location: '/accounts?section=journals&action=post&id=JE-DRAFT',
      );

      final String dialogTitle =
          AccountsStrings.postDialogTitle.toUpperCase();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text(dialogTitle).evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text(dialogTitle), findsOneWidget);
    },
  );

  testWidgets(
    'UUID-only journal id is scrubbed from To post list',
    (WidgetTester tester) async {
      const String uuid = '550e8400-e29b-41d4-a716-446655440000';
      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.accountsRead},
        ),
        items: const <AccountsWorkItem>[
          AccountsWorkItem(
            id: uuid,
            kind: AccountsWorkItemKind.journal,
            displayId: uuid,
            journalDisplayId: uuid,
            periodLabel: '2026-08',
            status: 'DRAFT',
            amount: 10,
            canPostFlag: true,
          ),
        ],
      );

      expect(find.textContaining(uuid), findsNothing);
      expect(find.text('—'), findsWidgets);
    },
  );

  testWidgets(
    'Detail Print opens print preview with section options',
    (WidgetTester tester) async {
      const PrintFormTemplateContext templateContext = PrintFormTemplateContext(
        appBranding: PrintFormBranding(
          name: 'Test HMS',
          kind: PrintFormBrandingKind.app,
        ),
      );
      await _pumpToPostTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
          },
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

      await tester.tap(find.text('JE-DRAFT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AccountsStrings.printAction), findsOneWidget);
      await tester.tap(find.text(AccountsStrings.printAction));
      await tester.pumpAndSettle();

      expect(find.byType(AppPrintPreviewPanel), findsOneWidget);
      expect(find.text('Print sections'), findsOneWidget);
      expect(
        find.text(AccountsStrings.detailTitleJournal.toUpperCase()),
        findsWidgets,
      );
    },
  );
}
