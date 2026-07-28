import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/repositories/physiotherapy_repository.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPhysiotherapyRepository extends Mock
    implements PhysiotherapyRepository {}

final DateTime _today = DateTime.now();

const TherapyWorkItem _referralItem = TherapyWorkItem(
  id: 'TH-REF',
  encounterId: 'ENC-REF',
  patientId: 'PAT-REF',
  patientDisplayName: 'Rita Referral',
);

final TherapyWorkItem _todayItem = TherapyWorkItem(
  id: 'TH-TODAY',
  encounterId: 'ENC-TODAY',
  patientId: 'PAT-TODAY',
  patientDisplayName: 'Tina Today',
  status: 'TODAY',
  sessionAt: DateTime(_today.year, _today.month, _today.day, 10),
);

const TherapyWorkItem _activePlanItem = TherapyWorkItem(
  id: 'TH-PLAN',
  encounterId: 'ENC-PLAN',
  patientId: 'PAT-PLAN',
  patientDisplayName: 'Alex ActivePlan',
  status: 'ACTIVE_PLAN',
);

const TherapyWorkItem _followUpItem = TherapyWorkItem(
  id: 'TH-FU',
  encounterId: 'ENC-FU',
  patientId: 'PAT-FU',
  patientDisplayName: 'Fay FollowUp',
  status: 'FOLLOW_UP_DUE',
);

const TherapyWorkItem _missedItem = TherapyWorkItem(
  id: 'TH-MISS',
  encounterId: 'ENC-MISS',
  patientId: 'PAT-MISS',
  patientDisplayName: 'Max Missed',
  status: 'MISSED',
  appointmentApiId: 'APT-MISS',
);

const TherapyWorkItem _completedItem = TherapyWorkItem(
  id: 'TH-DONE',
  encounterId: 'ENC-DONE',
  patientId: 'PAT-DONE',
  patientDisplayName: 'Cora Completed',
  status: 'COMPLETED',
);

AppAccessPolicy _therapyWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['PHYSIOTHERAPIST']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'physiotherapy', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

AppAccessPolicy _therapyReadOnlyPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['VIEWER']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.patientRead,
        AppPermissions.billingRead,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'physiotherapy', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

void _stubWorkItems(
  _MockPhysiotherapyRepository repository, {
  List<TherapyWorkItem> items = const <TherapyWorkItem>[],
}) {
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PhysiotherapyWorklistQuery query =
        invocation.positionalArguments.single as PhysiotherapyWorklistQuery;
    List<TherapyWorkItem> filtered = items
        .where(
          (TherapyWorkItem item) =>
              physiotherapyItemMatchesScope(item, query.scope),
        )
        .toList(growable: false);
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      filtered = filtered
          .where((TherapyWorkItem item) => item.matchesSearch(search))
          .toList(growable: false);
    }
    return Result<AppPage<TherapyWorkItem>>.success(
      AppPage<TherapyWorkItem>(
        items: filtered,
        request: query.pageRequest,
        totalItemCount: filtered.length,
      ),
    );
  });
  when(() => repository.loadDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final TherapyWorkItem item =
        invocation.positionalArguments.single as TherapyWorkItem;
    return Result<PhysiotherapyDetail>.success(PhysiotherapyDetail(item: item));
  });
}

AppListTable<TherapyWorkItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<TherapyWorkItem>>(
    find.byType(AppListTable<TherapyWorkItem>),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  // Adaptive polling keeps timers alive, so avoid pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await _pumpFrames(tester);
}

Future<GoRouter> _pumpPhysiotherapyWorkspace(
  WidgetTester tester, {
  required _MockPhysiotherapyRepository repository,
  PhysiotherapyWorkspaceQuery? initialQuery,
  String initialLocation = '/physiotherapy',
  Size viewport = const Size(1440, 900),
  List<TherapyWorkItem>? items,
  AppAccessPolicy? accessPolicy,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _stubWorkItems(
    repository,
    items:
        items ??
        <TherapyWorkItem>[
          _referralItem,
          _todayItem,
          _activePlanItem,
          _followUpItem,
          _missedItem,
          _completedItem,
        ],
  );

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/physiotherapy',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: PhysiotherapyWorkspacePage(
              initialQuery:
                  initialQuery ??
                  PhysiotherapyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        physiotherapyRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _therapyWritePolicy(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await _pumpFrames(tester);
  return router;
}

void main() {
  late _MockPhysiotherapyRepository repository;

  setUpAll(() {
    registerFallbackValue(const PhysiotherapyWorklistQuery());
    registerFallbackValue(
      const TherapyWorkItem(id: 'fallback', encounterId: 'ENC-FALLBACK'),
    );
  });

  setUp(() {
    repository = _MockPhysiotherapyRepository();
  });

  testWidgets('renders AppTabStrip with six section tabs and worklist table', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppWorkspaceToolbar), findsNothing);
    expect(find.byType(AppListTable<TherapyWorkItem>), findsOneWidget);
    expect(find.textContaining('Referrals'), findsWidgets);
    expect(find.textContaining('Today'), findsWidgets);
    expect(find.textContaining('Active plans'), findsWidgets);
    expect(find.textContaining('Follow-up due'), findsWidgets);
    expect(find.textContaining('Missed'), findsWidgets);
    expect(find.textContaining('Completed'), findsWidgets);
    expect(find.text('Rita Referral'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Schedule session'), findsNothing);
    expect(find.byType(AppTabToolbarAction), findsNothing);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(
      _table(tester).columnVisibilityStorageKey,
      'physiotherapy_referrals',
    );
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).columnVisibilityTitle, 'Table Settings');
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
    expect(_table(tester).search?.advancedFilterTitle, 'Advanced filters');
    expect(find.text('Accept referral'), findsWidgets);
  });

  testWidgets('tab strip has no Refresh or stage primary', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(tester, repository: repository);

    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byType(AppTabToolbarPrimary), findsNothing);
    expect(find.byType(AppTabToolbarAction), findsNothing);
  });

  testWidgets('advanced filters omit queue scope group', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(tester, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    final List<AppSearchBarFilterGroup>? groups =
        _table(tester).search?.filterGroups;
    expect(groups, isNotNull);
    expect(
      groups!.any((AppSearchBarFilterGroup group) => group.key == 'scope'),
      isFalse,
    );
    expect(
      groups.any(
        (AppSearchBarFilterGroup group) =>
            group.label == l10n.physiotherapyQueueFilterLabel,
      ),
      isFalse,
    );
  });

  testWidgets('advanced filters keep status on Referrals and omit on stage tabs', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(tester, repository: repository);

    List<AppSearchBarFilterGroup>? groups =
        _table(tester).search?.filterGroups;
    expect(groups, isNotNull);
    expect(
      groups!.any((AppSearchBarFilterGroup group) => group.key == 'status'),
      isTrue,
    );
    final AppSearchBarFilterGroup statusGroup = groups.firstWhere(
      (AppSearchBarFilterGroup group) => group.key == 'status',
    );
    expect(
      statusGroup.choices.map((AppSearchBarFilterChoice c) => c.value),
      <String>['REFERRAL', 'ACCEPTED', 'ASSESSMENT'],
    );

    clearInteractions(repository);
    _stubWorkItems(repository, items: <TherapyWorkItem>[_activePlanItem]);
    await tester.tap(find.textContaining('Active plans').first);
    await tester.pumpAndSettle();

    groups = _table(tester).search?.filterGroups;
    expect(
      groups!.any((AppSearchBarFilterGroup group) => group.key == 'status'),
      isFalse,
    );

    clearInteractions(repository);
    _stubWorkItems(repository, items: <TherapyWorkItem>[_missedItem]);
    await tester.tap(find.textContaining('Missed').first);
    await tester.pumpAndSettle();

    groups = _table(tester).search?.filterGroups;
    expect(
      groups!.any((AppSearchBarFilterGroup group) => group.key == 'status'),
      isFalse,
    );

    clearInteractions(repository);
    _stubWorkItems(repository, items: <TherapyWorkItem>[_completedItem]);
    await tester.tap(find.textContaining('Completed').first);
    await tester.pumpAndSettle();

    groups = _table(tester).search?.filterGroups;
    expect(
      groups!.any((AppSearchBarFilterGroup group) => group.key == 'status'),
      isFalse,
    );
  });

  testWidgets('detail overview omits restated status/billing; empty gaps hidden', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
      items: <TherapyWorkItem>[_referralItem],
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    await tester.tap(find.text('Rita Referral'));
    await _pumpAfterAction(tester);

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    expect(find.byType(AppQuickActions), findsOneWidget);
    // Overview keeps distinct therapy fields (source/attendance/plan).
    expect(find.text(l10n.physiotherapySourceLabel), findsWidgets);
    expect(find.text(l10n.physiotherapyAttendanceLabel), findsWidgets);
    expect(find.text(l10n.physiotherapyPlanLabel), findsWidgets);
    // Empty backend-gaps panel stays hidden.
    expect(find.text(l10n.physiotherapyBackendGapsPanelTitle), findsNothing);
  });

  testWidgets('does not paint a dedicated physiotherapy title header', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(tester, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );
    expect(find.text(l10n.physiotherapyTitle), findsNothing);
  });

  testWidgets('switching tabs updates section query and storage keys', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
    );
    clearInteractions(repository);
    _stubWorkItems(
      repository,
      items: <TherapyWorkItem>[
        _referralItem,
        _todayItem,
        _activePlanItem,
        _followUpItem,
        _missedItem,
        _completedItem,
      ],
    );

    await tester.tap(find.textContaining('Today').first);
    await _pumpFrames(tester);

    expect(router.state.uri.queryParameters['section'], 'today');
    expect(_table(tester).columnVisibilityStorageKey, 'physiotherapy_today');
    expect(find.text('Record session'), findsWidgets);
    expect(find.byTooltip('Refresh'), findsNothing);
    final List<PhysiotherapyWorklistQuery> todayQueries = verify(
      () => repository.listWorkItems(captureAny()),
    ).captured.cast<PhysiotherapyWorklistQuery>();
    expect(
      todayQueries.any(
        (PhysiotherapyWorklistQuery q) =>
            q.scope == PhysiotherapyQueueScope.today,
      ),
      isTrue,
    );

    clearInteractions(repository);
    _stubWorkItems(
      repository,
      items: <TherapyWorkItem>[_activePlanItem, _followUpItem],
    );

    await tester.tap(find.textContaining('Active plans').first);
    await _pumpFrames(tester);

    expect(router.state.uri.queryParameters['section'], 'active-plans');
    expect(
      _table(tester).columnVisibilityStorageKey,
      'physiotherapy_activePlans',
    );
    expect(find.text('Schedule follow-up'), findsWidgets);
    expect(find.byTooltip('Refresh'), findsNothing);

    clearInteractions(repository);
    _stubWorkItems(repository, items: <TherapyWorkItem>[_followUpItem]);

    await tester.tap(find.textContaining('Follow-up due').first);
    await _pumpFrames(tester);

    expect(router.state.uri.queryParameters['section'], 'follow-up');
    expect(find.text('Schedule follow-up'), findsWidgets);
    expect(find.byTooltip('Refresh'), findsNothing);

    clearInteractions(repository);
    _stubWorkItems(repository, items: <TherapyWorkItem>[_missedItem]);

    await tester.tap(find.textContaining('Missed').first);
    await _pumpFrames(tester);

    expect(router.state.uri.queryParameters['section'], 'missed');
    expect(find.text('Mark attendance'), findsWidgets);
    expect(find.byTooltip('Refresh'), findsNothing);

    clearInteractions(repository);
    _stubWorkItems(repository, items: <TherapyWorkItem>[_completedItem]);

    await tester.tap(find.textContaining('Completed').first);
    await _pumpFrames(tester);

    expect(router.state.uri.queryParameters['section'], 'completed');
    expect(find.text('Print instructions'), findsWidgets);
    expect(find.byTooltip('Refresh'), findsNothing);
  });

  testWidgets('deep link section=today selects Today tab', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
      initialLocation: '/physiotherapy?section=today',
      initialQuery: PhysiotherapyWorkspaceQuery.fromUri(
        Uri.parse('/physiotherapy?section=today'),
      ),
    );

    final List<PhysiotherapyWorklistQuery> queries = verify(
      () => repository.listWorkItems(captureAny()),
    ).captured.cast<PhysiotherapyWorklistQuery>();
    expect(
      queries.any(
        (PhysiotherapyWorklistQuery q) =>
            q.scope == PhysiotherapyQueueScope.today,
      ),
      isTrue,
    );
    expect(find.text('Record session'), findsWidgets);
    expect(_table(tester).columnVisibilityStorageKey, 'physiotherapy_today');
  });

  testWidgets('default route lands on Referrals without section param', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
    );

    expect(router.state.uri.queryParameters.containsKey('section'), isFalse);
    expect(find.text('Accept referral'), findsWidgets);
    expect(
      _table(tester).columnVisibilityStorageKey,
      'physiotherapy_referrals',
    );
  });

  testWidgets('search chrome remains wired for applySearch', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(tester, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    final AppListTableSearch<TherapyWorkItem>? search = _table(tester).search;
    expect(search, isNotNull);
    expect(search!.onSubmitted, isNotNull);
    expect(search.onClear, isNotNull);
    expect(search.semanticLabel, l10n.physiotherapySearchLabel);
    expect(search.hintText, l10n.physiotherapySearchHint);
  });

  testWidgets('accept-referral next-action opens dialog without detail shell', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
      items: <TherapyWorkItem>[_referralItem],
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    await tester.tap(find.byTooltip(l10n.physiotherapyAcceptReferralAction));
    await _pumpAfterAction(tester);

    expect(find.byType(ClinicalFreeTextActionDialog), findsOneWidget);
    expect(find.byType(AppQuickActions), findsNothing);
  });

  testWidgets('detail omits accept-referral when it is the row next-action', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
      items: <TherapyWorkItem>[_referralItem],
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    await tester.tap(find.text('Rita Referral'));
    await _pumpAfterAction(tester);

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    expect(
      find.descendant(
        of: find.byType(AppQuickActions),
        matching: find.text(l10n.physiotherapyAcceptReferralAction),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppQuickActions),
        matching: find.text(l10n.physiotherapyAddProgressNoteAction),
      ),
      findsOneWidget,
    );
  });

  testWidgets('detail omits record-session when it is the row next-action', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
      items: <TherapyWorkItem>[_todayItem],
      initialLocation: '/physiotherapy?section=today',
      initialQuery: PhysiotherapyWorkspaceQuery.fromUri(
        Uri.parse('/physiotherapy?section=today'),
      ),
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    await tester.tap(find.text('Tina Today'));
    await _pumpAfterAction(tester);

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    expect(
      find.descendant(
        of: find.byType(AppQuickActions),
        matching: find.text(l10n.physiotherapyRecordSessionAction),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppQuickActions),
        matching: find.text(l10n.physiotherapyAddProgressNoteAction),
      ),
      findsOneWidget,
    );
  });

  testWidgets('unauthorized policy hides write next-actions', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
      items: <TherapyWorkItem>[_referralItem, _completedItem],
      accessPolicy: _therapyReadOnlyPolicy(),
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    expect(find.text(l10n.physiotherapyAcceptReferralAction), findsNothing);

    await tester.tap(find.textContaining('Completed').first);
    await _pumpFrames(tester);

    expect(find.text(l10n.physiotherapyPrintInstructionsAction), findsWidgets);
  });

  testWidgets('AppTabStrip renders next-action trailing on mobile viewport', (
    WidgetTester tester,
  ) async {
    await _pumpPhysiotherapyWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
      items: <TherapyWorkItem>[_referralItem],
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Referrals'), findsWidgets);
    expect(find.text('Accept referral'), findsWidgets);
    expect(find.byType(AppListTableMobileItem), findsOneWidget);
  });
}
