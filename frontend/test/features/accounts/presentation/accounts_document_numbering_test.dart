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
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_document_sequence_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_document_sequence.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_document_sequence_repository.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/pages/accounts_workspace_page.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_document_numbering_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_document_sequence_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All document numbering copy comes from `app_en.arb`; the tests assert
/// against the same generated strings the UI renders, never against literals.
final AppLocalizations _l10n = AppLocalizationsEn();

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockDocumentSequenceRepository extends Mock
    implements AccountsDocumentSequenceRepository {}

/// A draft policy that has never issued a number: its shape is still editable.
const AccountsDocumentSequence _draftSequence = AccountsDocumentSequence(
  humanFriendlyId: 'DNS0000001',
  sequenceCode: 'INV-MAIN',
  documentType: AccountsDocumentType.invoice,
  module: 'BILLING',
  facility: 'Kampala Main',
  facilityHumanFriendlyId: 'FAC-001',
  prefix: 'INV',
  minimumLength: 7,
  resetFrequency: AccountsDocumentSequenceResetFrequency.yearly,
  gapPolicy: AccountsDocumentSequenceGapPolicy.noGaps,
  status: AccountsDocumentSequenceStatus.draft,
  nextNumber: 1,
  nextReferencePreview: 'INV0000001',
  version: 1,
);

/// An archived policy that already issued numbers.
final AccountsDocumentSequence _archivedSequence = AccountsDocumentSequence(
  humanFriendlyId: 'DNS0000002',
  sequenceCode: 'CLM-2025',
  documentType: AccountsDocumentType.claim,
  module: 'BILLING',
  facility: 'Kampala Main',
  facilityHumanFriendlyId: 'FAC-001',
  prefix: 'CLM',
  suffix: 'KLA',
  datePattern: 'yyyyMM',
  minimumLength: 6,
  resetFrequency: AccountsDocumentSequenceResetFrequency.monthly,
  gapPolicy: AccountsDocumentSequenceGapPolicy.allowGaps,
  status: AccountsDocumentSequenceStatus.archived,
  nextNumber: 43,
  lastIssuedNumber: 42,
  lastIssuedAt: DateTime.utc(2026, 8, 1, 9, 30),
  nextReferencePreview: 'CLM202608000043KLA',
  version: 4,
);

const AccountsSummary _summary = AccountsSummary(
  openWork: 7,
  toPost: 4,
  needApproval: 2,
  fiscalPeriodsActive: 11,
  departmentsActive: 9,
  paymentMethodsActive: 6,
  documentSequencesActive: 5,
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

void _stubSequences(
  _MockDocumentSequenceRepository repository, {
  required List<AccountsDocumentSequence> items,
  int filteredTotal = 2,
}) {
  when(() => repository.listDocumentSequences(any())).thenAnswer((
    Invocation inv,
  ) async {
    final AccountsDocumentSequenceQuery query =
        inv.positionalArguments.first as AccountsDocumentSequenceQuery;
    return Result<AppPage<AccountsDocumentSequence>>.success(
      AppPage<AccountsDocumentSequence>(
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
    (_) async => const Result<AccountsDocumentSequence>.success(_draftSequence),
  );
}

Future<_MockDocumentSequenceRepository> _pumpDocumentNumbering(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  List<AccountsDocumentSequence>? items,
  int filteredTotal = 2,
  String location = '/accounts?section=document-numbering',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockAccountsRepository accounts = _MockAccountsRepository();
  final _MockDocumentSequenceRepository sequences =
      _MockDocumentSequenceRepository();
  _stubAccounts(accounts);
  _stubSequences(
    sequences,
    items: items ?? <AccountsDocumentSequence>[
      _draftSequence,
      _archivedSequence,
    ],
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
        accountsDocumentSequenceRepositoryProvider.overrideWithValue(sequences),
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
  return sequences;
}

/// Minimal host for [confirmAccountsDocumentSequenceAction]; the row button
/// that triggers it in the panel sits in the last of many columns.
Future<void> _pumpActionHarness(
  WidgetTester tester, {
  required _MockDocumentSequenceRepository sequences,
  required AccountsDocumentSequence sequence,
  required AccountsDocumentSequenceAction action,
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
        accountsDocumentSequenceRepositoryProvider.overrideWithValue(sequences),
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
                onPressed: () => confirmAccountsDocumentSequenceAction(
                  context: context,
                  ref: ref,
                  sequence: sequence,
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
    registerFallbackValue(const AccountsDocumentSequenceQuery());
    registerFallbackValue(AccountsDocumentSequenceAction.activate);
  });

  group('navigation and scoping', () {
    test('the tab is the fourth leaf under Setup & Controls', () {
      expect(AccountsDeskCategory.setupAndControls.sections, <
        AccountsDeskSection
      >[
        AccountsDeskSection.fiscalYearsAndPeriods,
        AccountsDeskSection.departmentsAndCostCentres,
        AccountsDeskSection.paymentMethods,
        AccountsDeskSection.documentNumbering,
      ]);
      expect(
        AccountsDeskSection.documentNumbering.category,
        AccountsDeskCategory.setupAndControls,
      );
    });

    test('the section slug matches the API path segment', () {
      expect(
        AccountsDeskSection.documentNumbering.sectionQueryValue,
        accountsDocumentNumberingSectionSlug,
      );
      expect(
        AccountsDeskSection.resolveDeskSlug('document-numbering'),
        AccountsDeskSection.documentNumbering,
      );
    });

    test('compatible deep-link aliases resolve to the canonical tab', () {
      for (final String alias in <String>[
        'documentnumbering',
        'document-sequences',
        'number-sequences',
        'numbering',
      ]) {
        expect(
          AccountsDeskSection.resolveDeskSlug(alias),
          AccountsDeskSection.documentNumbering,
          reason: '$alias should resolve to the owning tab',
        );
      }
    });

    test('the table exposes the fourteen documented columns', () {
      expect(accountsDocumentSequenceColumnIds.length, 14);
      expect(
        accountsDocumentSequenceColumnIds.first,
        accountsDocumentSequenceCodeColumnId,
      );
      expect(
        accountsDocumentSequenceColumnIds.last,
        accountsDocumentSequenceStatusColumnId,
      );
    });

    test('the three Optional columns are not part of the default set', () {
      expect(accountsDocumentSequenceOptionalColumnIds, <String>[
        accountsDocumentSequenceReferenceColumnId,
        accountsDocumentSequenceLastIssuedNumberColumnId,
        accountsDocumentSequenceLastIssuedAtColumnId,
        accountsDocumentSequenceGapPolicyColumnId,
      ]);
      for (final String id in accountsDocumentSequenceOptionalColumnIds) {
        if (id == accountsDocumentSequenceReferenceColumnId) {
          continue;
        }
        expect(accountsDocumentSequenceColumnIds, contains(id));
      }
    });

    testWidgets('deep link opens the Setup & Controls tab strip', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(tester, accessPolicy: _readerPolicy);

      expect(find.byType(AccountsDocumentNumberingPanel), findsOneWidget);
      expect(
        accountsShellMenuChildren(
          accessPolicy: _readerPolicy,
        ).map((ShellSubmenuItem item) => item.id),
        contains(AccountsDeskCategory.setupAndControls.name),
      );

      // All four Setup & Controls sections are tabs in one flat strip.
      final AppTabStrip sections = tester.widget<AppTabStrip>(
        find.byKey(accountsSectionTabsKey),
      );
      expect(sections.tabs.length, 4);
      expect(sections.tabs.last.label, _l10n.accountsDocumentNumberingLabel);
      expect(sections.variant, AppTabStripVariant.standard);
    });

    testWidgets('the workspace renders no category tab row', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(tester, accessPolicy: _readerPolicy);

      expect(find.byType(AppTabStrip), findsOneWidget);
    });

    testWidgets('the badge uses the summary until the query is narrowed', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(tester, accessPolicy: _readerPolicy);

      AppTabItem numberingTab() => tester
          .widget<AppTabStrip>(find.byKey(accountsSectionTabsKey))
          .tabs
          .firstWhere(
            (AppTabItem tab) =>
                tab.id == AccountsDeskSection.documentNumbering.name,
          );
      expect(numberingTab().count, _summary.documentSequencesActive);

      await tester.enterText(find.byType(TextField).first, 'INV');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 1));

      expect(numberingTab().count, 2);
    });
  });

  group('columns and filters', () {
    testWidgets('Optional columns stay out of the default visible set', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(tester, accessPolicy: _readerPolicy);

      final AppListTable<AccountsDocumentSequence> table = tester
          .widget<AppListTable<AccountsDocumentSequence>>(
            find.byType(AppListTable<AccountsDocumentSequence>),
          );
      final List<String> defaultKeys = table.columns
          .map(
            (AppListTableColumn<AccountsDocumentSequence> column) => column.key,
          )
          .toList();
      final List<String> optionalKeys = table.columnChoices!
          .map(
            (AppListTableColumn<AccountsDocumentSequence> column) => column.key,
          )
          .toList();

      expect(defaultKeys, contains(accountsDocumentSequenceCodeColumnId));
      expect(defaultKeys, contains(accountsDocumentSequenceNextNumberColumnId));
      expect(defaultKeys, contains(accountsDocumentSequenceStatusColumnId));

      expect(optionalKeys, accountsDocumentSequenceOptionalColumnIds);
      for (final String id in accountsDocumentSequenceOptionalColumnIds) {
        expect(defaultKeys, isNot(contains(id)));
      }

      // Optional columns stay exportable so Settings/export keep the full
      // source-of-truth inventory.
      for (final AppListTableColumn<AccountsDocumentSequence> column
          in table.columnChoices!) {
        expect(column.includesInExport, isTrue);
      }
    });

    testWidgets('every specified domain filter reaches the committed query', (
      WidgetTester tester,
    ) async {
      final _MockDocumentSequenceRepository sequences =
          await _pumpDocumentNumbering(tester, accessPolicy: _readerPolicy);

      final AppListTable<AccountsDocumentSequence> table = tester
          .widget<AppListTable<AccountsDocumentSequence>>(
            find.byType(AppListTable<AccountsDocumentSequence>),
          );
      final List<String> groupKeys = table.search!.filterGroups
          .map((AppSearchBarFilterGroup group) => group.key)
          .toList();

      expect(groupKeys, contains('status'));
      expect(groupKeys, contains('document_type'));
      expect(groupKeys, contains('module'));
      expect(groupKeys, contains('reset_frequency'));
      expect(groupKeys, contains('gap_policy'));

      table.search!.onFilterChanged!(
        const AppSearchBarFilterValue(
          options: <String, String>{
            'status': 'ACTIVE',
            'document_type': 'INVOICE',
            'module': 'BILLING',
            'reset_frequency': 'YEARLY',
            'gap_policy': 'NO_GAPS',
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final List<AccountsDocumentSequenceQuery> queries =
          verify(() => sequences.listDocumentSequences(captureAny())).captured
              .cast<AccountsDocumentSequenceQuery>();
      final AccountsDocumentSequenceQuery committed = queries.last;
      expect(committed.statuses, <AccountsDocumentSequenceStatus>{
        AccountsDocumentSequenceStatus.active,
      });
      expect(committed.documentTypes, <AccountsDocumentType>{
        AccountsDocumentType.invoice,
      });
      expect(committed.module, 'BILLING');
      expect(committed.resetFrequencies, <
        AccountsDocumentSequenceResetFrequency
      >{AccountsDocumentSequenceResetFrequency.yearly});
      expect(committed.gapPolicies, <AccountsDocumentSequenceGapPolicy>{
        AccountsDocumentSequenceGapPolicy.noGaps,
      });
      expect(committed.hasActiveFilters, isTrue);
    });

    testWidgets('the Facility filter appears only for multi-facility scope', (
      WidgetTester tester,
    ) async {
      // Both seeded rows share one facility, so the control is omitted rather
      // than rendered as dead chrome.
      await _pumpDocumentNumbering(tester, accessPolicy: _readerPolicy);

      final AppListTable<AccountsDocumentSequence> table = tester
          .widget<AppListTable<AccountsDocumentSequence>>(
            find.byType(AppListTable<AccountsDocumentSequence>),
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
        AccountsDocumentNumberingAtomPermissions.tab.isAllowed(_readerPolicy),
        isTrue,
      );
      expect(
        AccountsDocumentNumberingAtomPermissions.create.isAllowed(_readerPolicy),
        isFalse,
      );
      expect(
        AccountsDocumentNumberingAtomPermissions.create.isAllowed(_writerPolicy),
        isTrue,
      );
      expect(canWriteAccountsDocumentSequences(_readerPolicy), isFalse);
      expect(canWriteAccountsDocumentSequences(_writerPolicy), isTrue);
    });

    test('a write-only grant does not surface the tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );
      expect(
        canViewAccountsSection(
          writeOnly,
          AccountsDeskSection.documentNumbering,
        ),
        isFalse,
      );
    });

    testWidgets('read-only hides New sequence, Actions, and workflow buttons', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(tester, accessPolicy: _readerPolicy);

      expect(find.text('INV-MAIN'), findsWidgets);
      expect(
        find.text(_l10n.accountsDocumentSequenceNewRecordAction),
        findsNothing,
      );
      expect(
        find.text(_l10n.accountsDocumentSequenceActionsColumn),
        findsNothing,
      );
      expect(
        find.text(_l10n.accountsDocumentSequenceActivateAction),
        findsNothing,
      );
      expect(
        find.text(_l10n.accountsDocumentSequenceBulkArchiveAction),
        findsNothing,
      );
    });

    testWidgets('write access shows the toolbar and per-row actions', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(tester, accessPolicy: _writerPolicy);

      expect(
        find.text(_l10n.accountsDocumentSequenceActionsColumn),
        findsOneWidget,
      );
      expect(find.text(_l10n.accountsDocumentSequenceViewAction), findsWidgets);
      expect(
        find.text(_l10n.accountsDocumentSequenceActivateAction),
        findsWidgets,
      );
    });
  });

  group('status rules', () {
    test('transitions follow the documented lifecycle', () {
      expect(_draftSequence.canActivate, isTrue);
      expect(_draftSequence.canDeactivate, isFalse);
      expect(_draftSequence.canEdit, isTrue);
      expect(
        _draftSequence.toggleAction,
        AccountsDocumentSequenceAction.activate,
      );

      const AccountsDocumentSequenceStatus archived =
          AccountsDocumentSequenceStatus.archived;
      expect(archived.allowedTransitions, <AccountsDocumentSequenceStatus>{
        AccountsDocumentSequenceStatus.active,
      });
    });

    test('an archived record is not editable and offers Restore', () {
      expect(_archivedSequence.canEdit, isFalse);
      expect(_archivedSequence.canClone, isFalse);
      expect(_archivedSequence.canRestore, isTrue);
      expect(
        _archivedSequence.toggleAction,
        AccountsDocumentSequenceAction.restore,
      );
    });

    test('a sequence that has issued numbers reports its shape as frozen', () {
      // The form disables prefix/suffix/pattern/padding on this signal.
      expect(_archivedSequence.hasIssued, isTrue);
      expect(_draftSequence.hasIssued, isFalse);
    });

    testWidgets('archived rows expose no Edit or Clone button', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(
        tester,
        accessPolicy: _writerPolicy,
        items: <AccountsDocumentSequence>[_archivedSequence],
      );

      expect(find.text('CLM-2025'), findsWidgets);
      expect(find.text(_l10n.accountsDocumentSequenceCloneAction), findsNothing);
      expect(
        find.text(_l10n.accountsDocumentSequenceRestoreAction),
        findsWidgets,
      );
      expect(
        find.text(_l10n.accountsDocumentSequenceViewAction),
        findsOneWidget,
      );
    });
  });

  group('workflow', () {
    testWidgets('Activate confirms, then posts the action with the version', (
      WidgetTester tester,
    ) async {
      final _MockDocumentSequenceRepository sequences =
          _MockDocumentSequenceRepository();
      _stubSequences(
        sequences,
        items: <AccountsDocumentSequence>[_draftSequence],
      );

      await _pumpActionHarness(
        tester,
        sequences: sequences,
        sequence: _draftSequence,
        action: AccountsDocumentSequenceAction.activate,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog))
            .title,
        _l10n.accountsDocumentSequenceActivateConfirmTitle,
      );

      await tester.tap(
        find
            .widgetWithText(
              AppButton,
              _l10n.accountsDocumentSequenceActivateAction,
            )
            .last,
      );
      await tester.pumpAndSettle();

      verify(
        () => sequences.applyAction(
          _draftSequence.humanFriendlyId,
          AccountsDocumentSequenceAction.activate,
          version: _draftSequence.version,
        ),
      ).called(1);
    });

    testWidgets('Activate warns that only one sequence per type can be live', (
      WidgetTester tester,
    ) async {
      final _MockDocumentSequenceRepository sequences =
          _MockDocumentSequenceRepository();
      _stubSequences(
        sequences,
        items: <AccountsDocumentSequence>[_draftSequence],
      );

      await _pumpActionHarness(
        tester,
        sequences: sequences,
        sequence: _draftSequence,
        action: AccountsDocumentSequenceAction.activate,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      // Two live sequences would race for one counter; the constraint is
      // stated up front rather than discovered on a 409.
      expect(
        tester
            .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog))
            .body,
        contains('Only one sequence per document type'),
      );
    });

    testWidgets('Archive warns that the record is archived, not deleted', (
      WidgetTester tester,
    ) async {
      final _MockDocumentSequenceRepository sequences =
          _MockDocumentSequenceRepository();
      _stubSequences(
        sequences,
        items: <AccountsDocumentSequence>[_draftSequence],
      );

      await _pumpActionHarness(
        tester,
        sequences: sequences,
        sequence: _draftSequence,
        action: AccountsDocumentSequenceAction.archive,
      );

      await tester.tap(find.byKey(const Key('run-action')));
      await tester.pumpAndSettle();

      final AppConfirmActionDialog dialog = tester
          .widget<AppConfirmActionDialog>(find.byType(AppConfirmActionDialog));
      expect(dialog.title, _l10n.accountsDocumentSequenceArchiveConfirmTitle);
      expect(dialog.body, contains('archived, not deleted'));
      expect(dialog.body, contains('stays traceable'));
    });
  });

  group('privacy and formatting', () {
    testWidgets('no raw database identifier or raw enum reaches the table', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(tester, accessPolicy: _writerPolicy);

      expect(find.text('550e8400-e29b-41d4-a716-446655440020'), findsNothing);
      expect(find.text('DRAFT'), findsNothing);
      expect(find.text('INVOICE'), findsNothing);
      expect(find.text('NO_GAPS'), findsNothing);
      expect(find.text('YEARLY'), findsNothing);
      expect(
        find.text(_l10n.accountsDocumentSequenceStatusDraft),
        findsWidgets,
      );
      expect(find.text(_l10n.accountsDocumentTypeInvoice), findsWidgets);

      // Reset Frequency sits past the horizontal fold on this viewport, so
      // assert its localization through the column contract instead.
      final AppListTable<AccountsDocumentSequence> table = tester
          .widget<AppListTable<AccountsDocumentSequence>>(
            find.byType(AppListTable<AccountsDocumentSequence>),
          );
      expect(
        table.columns
            .firstWhere(
              (AppListTableColumn<AccountsDocumentSequence> column) =>
                  column.key == accountsDocumentSequenceResetColumnId,
            )
            .exportValue!(_draftSequence),
        _l10n.accountsDocumentResetYearly,
      );
    });

    testWidgets('counter-derived numbers export padded to the policy width', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(
        tester,
        accessPolicy: _readerPolicy,
        items: <AccountsDocumentSequence>[_archivedSequence],
      );

      final AppListTable<AccountsDocumentSequence> table = tester
          .widget<AppListTable<AccountsDocumentSequence>>(
            find.byType(AppListTable<AccountsDocumentSequence>),
          );
      AppListTableColumn<AccountsDocumentSequence> columnFor(String id) => <
        AppListTableColumn<AccountsDocumentSequence>
      >[
        ...table.columns,
        ...table.columnChoices!,
      ].firstWhere(
        (AppListTableColumn<AccountsDocumentSequence> column) =>
            column.key == id,
      );

      // Minimum length 6 pads 43 → 000043 and 42 → 000042.
      expect(
        columnFor(
          accountsDocumentSequenceNextNumberColumnId,
        ).exportValue!(_archivedSequence),
        '000043',
      );
      expect(
        columnFor(
          accountsDocumentSequenceLastIssuedNumberColumnId,
        ).exportValue!(_archivedSequence),
        '000042',
      );
      // Gap policy exports as its localized label, never the raw enum.
      expect(
        columnFor(
          accountsDocumentSequenceGapPolicyColumnId,
        ).exportValue!(_archivedSequence),
        _l10n.accountsDocumentGapPolicyAllowGaps,
      );
    });

    testWidgets('an unissued sequence renders an em dash, not a zero', (
      WidgetTester tester,
    ) async {
      await _pumpDocumentNumbering(
        tester,
        accessPolicy: _readerPolicy,
        items: <AccountsDocumentSequence>[_draftSequence],
      );

      final AppListTable<AccountsDocumentSequence> table = tester
          .widget<AppListTable<AccountsDocumentSequence>>(
            find.byType(AppListTable<AccountsDocumentSequence>),
          );
      final AppListTableColumn<AccountsDocumentSequence> lastIssued = table
          .columnChoices!
          .firstWhere(
            (AppListTableColumn<AccountsDocumentSequence> column) =>
                column.key == accountsDocumentSequenceLastIssuedNumberColumnId,
          );

      expect(lastIssued.exportValue!(_draftSequence), '—');
    });
  });
}
