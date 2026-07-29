import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/repositories/physiotherapy_repository.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/physiotherapy_access.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/widgets/physiotherapy_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPhysiotherapyRepository extends Mock
    implements PhysiotherapyRepository {}

const TherapyWorkItem _missedItem = TherapyWorkItem(
  id: 'TH-MISS',
  encounterId: 'ENC-MISS',
  encounterPublicId: 'ENC-MISS-PUB',
  patientId: 'PAT-MISS',
  patientPublicId: 'PAT-MISS-PUB',
  patientDisplayName: 'Max Missed',
  status: 'MISSED',
  billingStatus: 'AUTHORIZED',
  plan: 'Mobility protocol',
  therapistName: 'Dr. Therapist',
  appointmentApiId: 'APT-MISS',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsPatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.patientRead ||
        permission == AppPermissions.patientWrite,
  );
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
  );
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(code: 'physiotherapy', licenseStatus: 'ACTIVE'),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        if (needsPatient)
          const AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        if (needsBilling)
          const AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
    },
    roles: const <String>['CUSTOM_READER'],
  );
}

AppAccessPolicy _writerPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.patientRead,
      AppPermissions.billingRead,
    },
    roles: const <String>['DOCTOR'],
  );
}

AppAccessPolicy _billingReaderPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
      AppPermissions.billingRead,
    },
  );
}

void _stubWorkItems(
  _MockPhysiotherapyRepository repository, {
  List<TherapyWorkItem> items = const <TherapyWorkItem>[_missedItem],
  bool failLists = false,
}) {
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (failLists) {
      return const Result<AppPage<TherapyWorkItem>>.failure(
        AppFailure.network(),
      );
    }
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
  when(
    () => repository.markAttendance(
      item: any(named: 'item'),
      status: any(named: 'status'),
      note: any(named: 'note'),
    ),
  ).thenAnswer((Invocation invocation) async {
    final TherapyWorkItem item =
        invocation.namedArguments[#item] as TherapyWorkItem;
    return Result<PhysiotherapyDetail>.success(
      PhysiotherapyDetail(
        item: item.copyWith(status: 'TODAY'),
      ),
    );
  });
  when(
    () => repository.scheduleSession(
      item: any(named: 'item'),
      startAt: any(named: 'startAt'),
      endAt: any(named: 'endAt'),
      reason: any(named: 'reason'),
    ),
  ).thenAnswer((Invocation invocation) async {
    final TherapyWorkItem item =
        invocation.namedArguments[#item] as TherapyWorkItem;
    return Result<PhysiotherapyDetail>.success(
      PhysiotherapyDetail(
        item: item.copyWith(status: 'TODAY'),
      ),
    );
  });
  when(
    () => repository.updatePlan(
      item: any(named: 'item'),
      plan: any(named: 'plan'),
      startDate: any(named: 'startDate'),
      endDate: any(named: 'endDate'),
    ),
  ).thenAnswer((Invocation invocation) async {
    final TherapyWorkItem item =
        invocation.namedArguments[#item] as TherapyWorkItem;
    final String plan = invocation.namedArguments[#plan] as String;
    return Result<PhysiotherapyDetail>.success(
      PhysiotherapyDetail(item: item.copyWith(plan: plan)),
    );
  });
}

AppListTable<TherapyWorkItem> _table(WidgetTester tester) {
  return tester.widget<AppListTable<TherapyWorkItem>>(
    find.byType(AppListTable<TherapyWorkItem>),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await _pumpFrames(tester);
}

Future<void> _pumpMissedTab(
  WidgetTester tester, {
  required _MockPhysiotherapyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/physiotherapy?section=missed',
  List<TherapyWorkItem> items = const <TherapyWorkItem>[_missedItem],
  bool failLists = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkItems(repository, items: items, failLists: failLists);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/physiotherapy',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: PhysiotherapyWorkspacePage(
              initialQuery: PhysiotherapyWorkspaceQuery.fromUri(state.uri),
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
  await _pumpFrames(tester);
}

void main() {
  late _MockPhysiotherapyRepository repository;

  setUpAll(() {
    registerFallbackValue(const PhysiotherapyWorklistQuery());
    registerFallbackValue(_missedItem);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    repository = _MockPhysiotherapyRepository();
  });

  group('PhysiotherapyMissedAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.tab,
          physiotherapyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.write,
          physiotherapyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.markAttendance,
          physiotherapyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.scheduleSession,
          physiotherapyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.scheduleFollowUp,
          physiotherapyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.billingColumn,
          billingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.billingChip,
          physiotherapyBillingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.routeEntry,
          RouteAccessCatalog.physiotherapyEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          physiotherapySectionTabRequirement(PhysiotherapyQueueScope.missed),
          PhysiotherapyMissedAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          therapyNextActionRequirementForKind(
            TherapyNextActionKind.markAttendance,
          ),
          PhysiotherapyMissedAtomPermissions.markAttendance,
        ),
        isTrue,
      );
    });

    test('∩ denial: clinical:write alone missing strips write atoms', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(PhysiotherapyMissedAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        PhysiotherapyMissedAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.markAttendance.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.scheduleSession.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.updatePlan.isAllowed(reader),
        isFalse,
      );
      expect(canWritePhysiotherapy(reader), isFalse);
    });

    test('∩ denial: patient:write alone does not unlock therapy write', () {
      final AppAccessPolicy patientWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(
        PhysiotherapyMissedAtomPermissions.tab.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.write.isAllowed(patientWriter),
        isFalse,
      );
      expect(canWritePhysiotherapy(patientWriter), isFalse);
    });

    test('∪ allowance: clinical:read alone grants Missed read chrome', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      expect(
        PhysiotherapyMissedAtomPermissions.tab.isAllowed(clinicalOnly),
        isTrue,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.tab.isAllowed(patientOnly),
        isTrue,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.listChrome.isAllowed(clinicalOnly),
        isTrue,
      );
      expect(canViewPhysiotherapyMissed(clinicalOnly), isTrue);
      expect(canViewPhysiotherapyMissed(patientOnly), isTrue);
      expect(
        canViewPhysiotherapyTab(clinicalOnly, PhysiotherapyQueueScope.missed),
        isTrue,
      );
    });

    test('billing:read alone enters route but not Missed chrome', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(canEnterPhysiotherapyWorkspace(billingOnly), isTrue);
      expect(
        PhysiotherapyMissedAtomPermissions.tab.isAllowed(billingOnly),
        isFalse,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.billingColumn.isAllowed(billingOnly),
        isTrue,
      );
      expect(canViewPhysiotherapyBilling(billingOnly), isTrue);
    });

    test('full ∩ write set presents write atoms', () {
      final AppAccessPolicy writer = _writerPolicy();
      expect(PhysiotherapyMissedAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(
        PhysiotherapyMissedAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.markAttendance.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.scheduleSession.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.billingColumn.isAllowed(writer),
        isTrue,
      );
      expect(canWritePhysiotherapy(writer), isTrue);
      expect(canViewPhysiotherapyBilling(writer), isTrue);
    });

    test('subscription denial: permissions without physiotherapy module strip UI', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.patientRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        PhysiotherapyMissedAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(canViewPhysiotherapyMissed(noModule), isFalse);
    });

    test('ABAC session still evaluates Missed when facility is present', () {
      final AppAccessPolicy withFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
        },
      );
      expect(
        PhysiotherapyMissedAtomPermissions.tab.isAllowed(withFacility),
        isTrue,
      );
      expect(
        canViewPhysiotherapyTab(withFacility, PhysiotherapyQueueScope.missed),
        isTrue,
      );
    });

    test('route catalog entry matches AppRoutes physiotherapy ∪', () {
      expect(
        RouteAccessCatalog.physiotherapyEntry.anyPermissions.toSet(),
        <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.patientRead,
          AppPermissions.billingRead,
        },
      );
      expect(
        identical(
          PhysiotherapyMissedAtomPermissions.catalogEntry,
          RouteAccessCatalog.physiotherapyEntry,
        ),
        isTrue,
      );
    });

    test('nested cross-module write is n/a; billing is only nested read ∩', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(
        PhysiotherapyMissedAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.billingChip.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyMissedAtomPermissions.billingChip.isAllowed(
          _billingReaderPolicy(),
        ),
        isTrue,
      );
    });
  });

  group('Physiotherapy Missed tab UI gates', () {
    testWidgets('read-only: worklist present; Mark attendance absent', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.text('Max Missed'), findsOneWidget);
      expect(find.byTooltip('Mark attendance'), findsNothing);
      expect(find.textContaining('Missed'), findsWidgets);
      expect(find.byType(AppListTable<TherapyWorkItem>), findsOneWidget);
      expect(
        _table(tester).columnVisibilityStorageKey,
        'physiotherapy_missed',
      );
      expect(
        _table(tester).columnChoices?.any(
              (AppListTableColumn<TherapyWorkItem> c) => c.id == 'billing',
            ) ??
            false,
        isFalse,
      );
    });

    testWidgets('writer: Mark attendance next-action present', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byTooltip('Mark attendance'), findsWidgets);
      expect(find.text('Max Missed'), findsOneWidget);
      expect(
        _table(tester).columnChoices?.any(
              (AppListTableColumn<TherapyWorkItem> c) => c.id == 'billing',
            ) ??
            false,
        isTrue,
      );
    });

    testWidgets('∪ clinical:read alone shows Missed tab and list', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(find.textContaining('Missed'), findsWidgets);
      expect(find.text('Max Missed'), findsOneWidget);
      expect(find.byTooltip('Mark attendance'), findsNothing);
    });

    testWidgets('billing-only route entry mounts no Missed chrome', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byType(AppListTable<TherapyWorkItem>), findsNothing);
      expect(find.text('Max Missed'), findsNothing);
    });

    testWidgets('detail write / reschedule absent for read-only; present for writer', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );
      await tester.tap(find.text('Max Missed'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Update plan'), findsNothing);
      expect(find.text('Add progress note'), findsNothing);
      expect(find.text('Close episode'), findsNothing);
      expect(find.text('Schedule session'), findsNothing);
      expect(find.text('Schedule follow-up'), findsNothing);
      expect(find.text('Mark attendance'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );
      await tester.tap(find.text('Max Missed'));
      await _pumpAfterAction(tester);

      expect(find.text('Update plan'), findsWidgets);
      expect(find.text('Add progress note'), findsWidgets);
      expect(find.text('Close episode'), findsWidgets);
      // Reschedule path (schedule session) — write ∩; Mark attendance omitted
      // from detail because it is the row next-action.
      expect(find.text('Schedule session'), findsWidgets);
      expect(find.text('Schedule follow-up'), findsWidgets);
    });

    testWidgets('billing chip absent without billing:read; present with it', (
      WidgetTester tester,
    ) async {
      final AppLocalizations Function(BuildContext) l10nOf = AppLocalizations.of;

      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );
      await tester.tap(find.text('Max Missed'));
      await _pumpAfterAction(tester);
      final AppLocalizations l10n = l10nOf(
        tester.element(find.byType(AppDialog)),
      );
      expect(
        find.text(l10n.physiotherapyBillingAuthorizationLabel),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _billingReaderPolicy(),
      );
      await tester.tap(find.text('Max Missed'));
      await _pumpAfterAction(tester);
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(AppDialog)),
          ).physiotherapyBillingAuthorizationLabel,
        ),
        findsOneWidget,
      );
    });

    testWidgets('authorized mark attendance opens dialog (sync seam)', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.byTooltip('Mark attendance').first);
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.textContaining('attendance'), findsWidgets);
      verify(() => repository.listWorkItems(any())).called(greaterThan(0));
    });

    testWidgets('empty state remains observable for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        items: const <TherapyWorkItem>[],
      );

      expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
      expect(find.byTooltip('Mark attendance'), findsNothing);
    });

    testWidgets('error/retry remains observable for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        failLists: true,
      );

      expect(
        find.byType(AsyncStateScaffold<PhysiotherapyWorkspaceState>),
        findsOneWidget,
      );
    });

    testWidgets('mobile viewport: read chrome present, write absent', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Max Missed'), findsOneWidget);
      expect(find.byTooltip('Mark attendance'), findsNothing);
      expect(find.textContaining('Missed'), findsWidgets);
    });

    testWidgets('desktop viewport: writer next-action present', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        physicalSize: const Size(1440, 900),
      );

      expect(find.byTooltip('Mark attendance'), findsWidgets);
    });

    testWidgets('light + dark themes keep authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.light,
      );
      expect(find.byTooltip('Mark attendance'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpMissedTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );
      expect(find.byTooltip('Mark attendance'), findsWidgets);
      expect(find.text('Max Missed'), findsOneWidget);
    });
  });
}
