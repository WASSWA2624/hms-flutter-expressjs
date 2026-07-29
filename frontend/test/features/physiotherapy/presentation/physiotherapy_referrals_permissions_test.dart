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
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPhysiotherapyRepository extends Mock
    implements PhysiotherapyRepository {}

const TherapyWorkItem _referralItem = TherapyWorkItem(
  id: 'TH-REF',
  encounterId: 'ENC-REF',
  encounterPublicId: 'ENC-REF-PUB',
  patientId: 'PAT-REF',
  patientPublicId: 'PAT-REF-PUB',
  patientDisplayName: 'Rita Referral',
  status: 'REFERRAL',
  billingStatus: 'AUTHORIZED',
  referralReason: 'Post-op mobility',
  therapistName: 'Dr. Therapist',
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
  List<TherapyWorkItem> items = const <TherapyWorkItem>[_referralItem],
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
    () => repository.acceptReferral(
      item: any(named: 'item'),
      note: any(named: 'note'),
    ),
  ).thenAnswer((Invocation invocation) async {
    final TherapyWorkItem item =
        invocation.namedArguments[#item] as TherapyWorkItem;
    return Result<PhysiotherapyDetail>.success(
      PhysiotherapyDetail(
        item: item.copyWith(status: 'ACCEPTED'),
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

Future<void> _pumpReferralsTab(
  WidgetTester tester, {
  required _MockPhysiotherapyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/physiotherapy?section=referrals',
  List<TherapyWorkItem> items = const <TherapyWorkItem>[_referralItem],
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
    registerFallbackValue(_referralItem);
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    repository = _MockPhysiotherapyRepository();
  });

  group('PhysiotherapyReferralsAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        identical(
          PhysiotherapyReferralsAtomPermissions.tab,
          physiotherapyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyReferralsAtomPermissions.write,
          physiotherapyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyReferralsAtomPermissions.acceptReferral,
          physiotherapyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyReferralsAtomPermissions.billingColumn,
          billingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyReferralsAtomPermissions.billingChip,
          physiotherapyBillingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyReferralsAtomPermissions.routeEntry,
          RouteAccessCatalog.physiotherapyEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          physiotherapySectionTabRequirement(PhysiotherapyQueueScope.referrals),
          PhysiotherapyReferralsAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          therapyNextActionRequirementForKind(
            TherapyNextActionKind.acceptReferral,
          ),
          PhysiotherapyReferralsAtomPermissions.acceptReferral,
        ),
        isTrue,
      );
      expect(
        identical(
          therapyNextActionWriteRequirement,
          physiotherapyNextActionWriteRequirement,
        ),
        isTrue,
      );
    });

    test('∩ denial: clinical:write alone missing strips write atoms', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(PhysiotherapyReferralsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        PhysiotherapyReferralsAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.acceptReferral.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.updatePlan.isAllowed(reader),
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
        PhysiotherapyReferralsAtomPermissions.tab.isAllowed(patientWriter),
        isTrue,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.write.isAllowed(patientWriter),
        isFalse,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.acceptReferral.isAllowed(
          patientWriter,
        ),
        isFalse,
      );
      expect(canWritePhysiotherapy(patientWriter), isFalse);
    });

    test('∪ allowance: clinical:read alone grants Referrals read chrome', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      final AppAccessPolicy patientOnly = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.tab.isAllowed(clinicalOnly),
        isTrue,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.tab.isAllowed(patientOnly),
        isTrue,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.listChrome.isAllowed(clinicalOnly),
        isTrue,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.filters.isAllowed(patientOnly),
        isTrue,
      );
      expect(canViewPhysiotherapyReferrals(clinicalOnly), isTrue);
      expect(canViewPhysiotherapyReferrals(patientOnly), isTrue);
      expect(
        canViewPhysiotherapyTab(clinicalOnly, PhysiotherapyQueueScope.referrals),
        isTrue,
      );
    });

    test('billing:read alone enters route but not Referrals chrome', () {
      final AppAccessPolicy billingOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(canEnterPhysiotherapyWorkspace(billingOnly), isTrue);
      expect(
        PhysiotherapyReferralsAtomPermissions.tab.isAllowed(billingOnly),
        isFalse,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.billingColumn.isAllowed(
          billingOnly,
        ),
        isTrue,
      );
      expect(canViewPhysiotherapyBilling(billingOnly), isTrue);
      expect(canViewPhysiotherapyReferrals(billingOnly), isFalse);
    });

    test('full ∩ write set presents write atoms', () {
      final AppAccessPolicy writer = _writerPolicy();
      expect(PhysiotherapyReferralsAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(
        PhysiotherapyReferralsAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.acceptReferral.isAllowed(writer),
        isTrue,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.billingColumn.isAllowed(writer),
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
        PhysiotherapyReferralsAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(canViewPhysiotherapyReferrals(noModule), isFalse);
    });

    test('ABAC session still evaluates Referrals when facility is present', () {
      final AppAccessPolicy withFacility = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
        },
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.tab.isAllowed(withFacility),
        isTrue,
      );
      expect(
        canViewPhysiotherapyTab(
          withFacility,
          PhysiotherapyQueueScope.referrals,
        ),
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
          PhysiotherapyReferralsAtomPermissions.catalogEntry,
          RouteAccessCatalog.physiotherapyEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          PhysiotherapyReferralsAtomPermissions.routeEntryUnion,
          physiotherapyWorkspaceRouteUnionRequirement,
        ),
        isTrue,
      );
    });

    test('nested cross-module write is n/a; billing is only nested read ∩', () {
      final AppAccessPolicy reader = _readerPolicy();
      expect(
        PhysiotherapyReferralsAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.billingChip.isAllowed(reader),
        isFalse,
      );
      expect(
        PhysiotherapyReferralsAtomPermissions.billingChip.isAllowed(
          _billingReaderPolicy(),
        ),
        isTrue,
      );
    });

    test('mapping note: matrix ∩ clinical:write via allPermissions', () {
      expect(
        physiotherapyWorkspaceWriteRequirement.allPermissions,
        <AppPermission>[AppPermissions.clinicalWrite],
      );
      expect(physiotherapyWorkspaceWriteRequirement.anyPermissions, isEmpty);
      expect(
        physiotherapyWorkspaceWriteRequirement.activeModules,
        contains(physiotherapyModule),
      );
      expect(
        physiotherapyWorkspaceReadRequirement.anyPermissions.toSet(),
        <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.patientRead,
        },
      );
    });
  });

  group('Physiotherapy Referrals tab UI gates', () {
    testWidgets('read-only: worklist present; Accept referral absent', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );

      expect(find.text('Rita Referral'), findsOneWidget);
      expect(find.byTooltip('Accept referral'), findsNothing);
      expect(find.textContaining('Referrals'), findsWidgets);
      expect(find.byType(AppListTable<TherapyWorkItem>), findsOneWidget);
      expect(
        _table(tester).columnVisibilityStorageKey,
        'physiotherapy_referrals',
      );
      expect(
        _table(tester).columnChoices?.any(
              (AppListTableColumn<TherapyWorkItem> c) => c.id == 'billing',
            ) ??
            false,
        isFalse,
      );
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('writer: Accept referral next-action present', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      expect(find.byTooltip('Accept referral'), findsWidgets);
      expect(find.text('Rita Referral'), findsOneWidget);
      expect(
        _table(tester).columnChoices?.any(
              (AppListTableColumn<TherapyWorkItem> c) => c.id == 'billing',
            ) ??
            false,
        isTrue,
      );
    });

    testWidgets('∪ clinical:read alone shows Referrals tab and list', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(find.textContaining('Referrals'), findsWidgets);
      expect(find.text('Rita Referral'), findsOneWidget);
      expect(find.byTooltip('Accept referral'), findsNothing);
    });

    testWidgets('∪ patient:read alone shows Referrals; write absent', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          roles: const <String>['RECEPTIONIST'],
        ),
      );

      expect(find.textContaining('Referrals'), findsWidgets);
      expect(find.text('Rita Referral'), findsOneWidget);
      expect(find.byTooltip('Accept referral'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('billing-only route entry mounts no Referrals chrome', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byType(AppListTable<TherapyWorkItem>), findsNothing);
      expect(find.text('Rita Referral'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('detail write actions absent for read-only; present for writer', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );
      await tester.tap(find.text('Rita Referral'));
      await _pumpAfterAction(tester);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Update plan'), findsNothing);
      expect(find.text('Add progress note'), findsNothing);
      expect(find.text('Close episode'), findsNothing);
      expect(find.text('Accept referral'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );
      await tester.tap(find.text('Rita Referral'));
      await _pumpAfterAction(tester);

      expect(find.text('Update plan'), findsWidgets);
      expect(find.text('Add progress note'), findsWidgets);
      expect(find.text('Close episode'), findsWidgets);
      // Accept referral is the row next-action, so omitted from detail panel.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Accept referral'),
        ),
        findsNothing,
      );
    });

    testWidgets('billing chip absent without billing:read; present with it', (
      WidgetTester tester,
    ) async {
      final AppLocalizations Function(BuildContext) l10nOf = AppLocalizations.of;

      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
      );
      await tester.tap(find.text('Rita Referral'));
      await _pumpAfterAction(tester);
      final AppLocalizations l10n = l10nOf(
        tester.element(find.byType(AppDialog)),
      );
      expect(
        find.text(l10n.physiotherapyBillingAuthorizationLabel),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _billingReaderPolicy(),
      );
      await tester.tap(find.text('Rita Referral'));
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

    testWidgets('authorized accept referral opens dialog (sync seam)', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
      );

      await tester.tap(find.byTooltip('Accept referral').first);
      await _pumpAfterAction(tester);

      expect(find.byType(ClinicalFreeTextActionDialog), findsOneWidget);
      verify(() => repository.listWorkItems(any())).called(greaterThan(0));
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('empty state remains observable for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        items: const <TherapyWorkItem>[],
      );

      expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
      expect(find.byTooltip('Accept referral'), findsNothing);
    });

    testWidgets('error/retry remains observable for authorized readers', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
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
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _readerPolicy(),
        physicalSize: const Size(390, 844),
      );

      expect(find.text('Rita Referral'), findsOneWidget);
      expect(find.byTooltip('Accept referral'), findsNothing);
      expect(find.textContaining('Referrals'), findsWidgets);
    });

    testWidgets('desktop viewport: writer next-action present', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        physicalSize: const Size(1440, 900),
      );

      expect(find.byTooltip('Accept referral'), findsWidgets);
    });

    testWidgets('light + dark themes keep authorized chrome', (
      WidgetTester tester,
    ) async {
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.light,
      );
      expect(find.byTooltip('Accept referral'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpReferralsTab(
        tester,
        repository: repository,
        accessPolicy: _writerPolicy(),
        themeMode: ThemeMode.dark,
      );
      expect(find.byTooltip('Accept referral'), findsWidgets);
      expect(find.text('Rita Referral'), findsOneWidget);
    });

    testWidgets(
      'subscription strips Referrals tab when physiotherapy inactive',
      (WidgetTester tester) async {
        await _pumpReferralsTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
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
          ),
        );

        expect(find.byType(AppTabStrip), findsNothing);
        expect(find.byType(AppListTable<TherapyWorkItem>), findsNothing);
        expect(find.text('Rita Referral'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );
  });
}
