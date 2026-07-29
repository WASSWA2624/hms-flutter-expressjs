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
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _noBedPatient = IcuPatientSummary(
  id: 'ADM-ALL-1',
  admissionId: 'ADM-ALL-1',
  displayId: 'ADM-ALL1',
  patientDisplayName: 'All Tab Patient',
  icuStatus: 'ACTIVE',
  hasActiveBed: false,
  encounterId: 'ENC-ALL-1',
);

const IcuPatientSummary _endedPatient = IcuPatientSummary(
  id: 'ADM-ALL-2',
  admissionId: 'ADM-ALL-2',
  displayId: 'ADM-ALL2',
  patientDisplayName: 'Ended All Patient',
  icuStatus: 'ENDED',
  admissionStatus: 'DISCHARGED',
  hasActiveBed: true,
  encounterId: 'ENC-ALL-2',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsEmergency = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.emergencyRead ||
        permission == AppPermissions.emergencyWrite,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'icu-critical-care',
          licenseStatus: 'ACTIVE',
        ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        if (needsEmergency)
          const AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
        if (needsOperations)
          const AppModuleEntitlement(
            code: 'facilities-maintenance',
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

void _stubBoard(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> board = const <IcuPatientSummary>[_noBedPatient],
  Result<AppPage<IcuPatientSummary>>? listOverride,
  IcuPatientDetail? detailOverride,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    List<IcuPatientSummary> items = board;
    if (query.search.trim().isNotEmpty) {
      final String needle = query.search.trim().toLowerCase();
      items = items
          .where((IcuPatientSummary item) => item.matchesSearch(needle))
          .toList(growable: false);
    }
    return Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(() => repository.loadBedBoard()).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(
      IcuBedBoard(wards: <IcuBedWard>[], beds: <IcuBed>[]),
    ),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detailOverride != null) {
      return Result<IcuPatientDetail>.success(detailOverride);
    }
    final IcuPatientSummary summary =
        invocation.positionalArguments.single as IcuPatientSummary;
    return Result<IcuPatientDetail>.success(
      IcuPatientDetail(
        summary: summary,
        activeStay: summary.isEndedIcu
            ? null
            : const IcuStaySummary(id: 'stay-all-1'),
      ),
    );
  });
  when(
    () => repository.assignBed(
      detail: any(named: 'detail'),
      bedId: any(named: 'bedId'),
    ),
  ).thenAnswer((Invocation invocation) async {
    final IcuPatientDetail detail =
        invocation.namedArguments[#detail] as IcuPatientDetail;
    return Result<IcuPatientDetail>.success(
      detail.copyWith(
        summary: detail.summary.copyWith(hasActiveBed: true),
      ),
    );
  });
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary>? items,
  Result<AppPage<IcuPatientSummary>>? listOverride,
  IcuPatientDetail? detailOverride,
  String initialLocation = '/icu?section=all',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(
    repository,
    board: items ?? <IcuPatientSummary>[_noBedPatient],
    listOverride: listOverride,
    detailOverride: detailOverride,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/icu',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IcuWorkspacePage(
              initialQuery: IcuBoardQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('IPD'));
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Billing'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        icuRepositoryProvider.overrideWithValue(repository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
        ),
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
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
    );
    registerFallbackValue(
      const IcuPatientDetail(
        summary: IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
      ),
    );
  });

  setUp(() {
    repository = _MockIcuRepository();
  });

  group('IcuAllAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(IcuAllAtomPermissions.tab, same(icuWorkspaceReadRequirement));
      expect(IcuAllAtomPermissions.search, same(icuWorkspaceReadRequirement));
      expect(IcuAllAtomPermissions.filters, same(icuWorkspaceReadRequirement));
      expect(IcuAllAtomPermissions.settings, same(icuWorkspaceReadRequirement));
      expect(IcuAllAtomPermissions.empty, same(icuWorkspaceReadRequirement));
      expect(IcuAllAtomPermissions.loading, same(icuWorkspaceReadRequirement));
      expect(IcuAllAtomPermissions.retry, same(icuWorkspaceReadRequirement));
      expect(
        IcuAllAtomPermissions.printSummary,
        same(icuWorkspaceReadRequirement),
      );
      expect(IcuAllAtomPermissions.rowSelect, same(icuWorkspaceReadRequirement));
      expect(IcuAllAtomPermissions.detail, same(icuWorkspaceReadRequirement));
      expect(IcuAllAtomPermissions.write, same(icuWorkspaceWriteRequirement));
      expect(IcuAllAtomPermissions.create, same(icuWorkspaceWriteRequirement));
      expect(IcuAllAtomPermissions.update, same(icuWorkspaceWriteRequirement));
      // Matrix ∩ clinical:write alone; source keeps ∪ clinical|emergency write.
      expect(
        IcuAllAtomPermissions.write,
        same(IcuWorkspaceWriteRequirement.writeRequirement),
      );
      expect(IcuAllAtomPermissions.delete, same(icuWorkspaceDeleteRequirement));
      expect(
        IcuAllAtomPermissions.nextActionAssignBed,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuAllAtomPermissions.nextActionOpenIpd,
        same(icuNavigationRequirement),
      );
      expect(
        IcuAllAtomPermissions.navigation,
        same(icuNavigationRequirement),
      );
      expect(
        IcuAllAtomPermissions.routeEntry,
        same(icuWorkspaceEntryRequirement),
      );
      expect(
        IcuAllAtomPermissions.routeEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        IcuAllAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        IcuAllAtomPermissions.panelDeepLink,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuBoardTabRequirement(IcuWorkspaceSection.all),
        same(IcuAllAtomPermissions.tab),
      );
      expect(
        icuWriteRequirementForSection(IcuWorkspaceSection.all),
        same(IcuAllAtomPermissions.write),
      );
      expect(
        icuDetailReadRequirement(IcuWorkspaceSection.all),
        same(IcuAllAtomPermissions.detail),
      );
      expect(icuRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('∩ denial: clinical:read alone strips All write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canViewIcuAll(reader), isTrue);
      expect(IcuAllAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(IcuAllAtomPermissions.write.isAllowed(reader), isFalse);
      expect(IcuAllAtomPermissions.create.isAllowed(reader), isFalse);
      expect(IcuAllAtomPermissions.update.isAllowed(reader), isFalse);
      expect(IcuAllAtomPermissions.delete.isAllowed(reader), isFalse);
      expect(
        IcuAllAtomPermissions.nextActionAssignBed.isAllowed(reader),
        isFalse,
      );
      expect(IcuAllAtomPermissions.endStay.isAllowed(reader), isFalse);
      expect(IcuAllAtomPermissions.validation.isAllowed(reader), isFalse);
      expect(canWriteIcu(reader), isFalse);
      // All keeps next-action column for navigate kinds (Open IPD).
      expect(
        icuBoardShowsNextActionColumn(reader, IcuWorkspaceSection.all),
        isTrue,
      );
    });

    test('∪ allowance: clinical:read alone shows All tab; write alone fails tab',
        () {
      final AppAccessPolicy clinicalReader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canViewIcuAll(clinicalReader), isTrue);
      expect(IcuAllAtomPermissions.tab.isAllowed(clinicalReader), isTrue);
      expect(IcuAllAtomPermissions.write.isAllowed(clinicalReader), isFalse);

      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(canViewIcuAll(emergencyReader), isTrue);
      expect(IcuAllAtomPermissions.write.isAllowed(emergencyReader), isFalse);

      // Write without clinical|emergency read fails All tab (∪ read gate).
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(canViewIcuAll(writeOnly), isFalse);
      expect(IcuAllAtomPermissions.write.isAllowed(writeOnly), isTrue);
      expect(
        IcuAllAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
    });

    test('full write ∪: clinical:write or emergency:write grants mutations', () {
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(IcuAllAtomPermissions.write.isAllowed(clinicalWriter), isTrue);
      expect(
        IcuAllAtomPermissions.nextActionAssignBed.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(canWriteIcu(clinicalWriter), isTrue);

      final AppAccessPolicy emergencyWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      // Source keeps ∪ emergency:write (matrix ∩ clinical:write alone).
      expect(IcuAllAtomPermissions.write.isAllowed(emergencyWriter), isTrue);
      expect(IcuAllAtomPermissions.create.isAllowed(emergencyWriter), isTrue);
    });

    test('∪ allowance: route entry accepts operations:read; All tab still ∪ read',
        () {
      final AppAccessPolicy opsReadOnly = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(IcuAllAtomPermissions.routeEntry.isAllowed(opsReadOnly), isTrue);
      expect(
        IcuAllAtomPermissions.routeEntryUnion.isAllowed(opsReadOnly),
        isTrue,
      );
      expect(IcuAllAtomPermissions.catalogEntry.isAllowed(opsReadOnly), isTrue);
      // All tab content requires clinical:read | emergency:read.
      expect(IcuAllAtomPermissions.tab.isAllowed(opsReadOnly), isFalse);
      expect(canViewIcuAll(opsReadOnly), isFalse);
      expect(icuAllowedBoardSections(opsReadOnly), isEmpty);
    });

    test('subscription strip: icu-critical-care required for All tab', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(IcuAllAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewIcuAll(noModule), isFalse);
      expect(IcuAllAtomPermissions.write.isAllowed(noModule), isFalse);
      expect(icuAllowedBoardSections(noModule), isEmpty);
    });

    test('nested cross-module matrix rows are n/a (aliases keep ICU gates)', () {
      expect(
        IcuAllAtomPermissions.nestedRead,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuAllAtomPermissions.nestedWrite,
        same(icuWorkspaceWriteRequirement),
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuAllAtomPermissions.nestedWrite.isAllowed(reader), isFalse);
      expect(IcuAllAtomPermissions.nestedRead.isAllowed(reader), isTrue);
    });

    test('next-action write kinds map to source write ∪; navigate stay open', () {
      expect(
        icuBoardNextActionKind(_noBedPatient, IcuWorkspaceSection.all),
        IcuNextActionKind.assignBed,
      );
      expect(
        icuBoardNextActionKind(_endedPatient, IcuWorkspaceSection.all),
        IcuNextActionKind.openIpd,
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.assignBed),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.openIpd),
        same(icuNavigationRequirement),
      );
      expect(
        icuFocusedPanelRequirement(IcuDetailPanel.vitals),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuAllAtomPermissions.panelDeepLink,
        same(icuWorkspaceWriteRequirement),
      );
    });
  });

  testWidgets(
    'read-only: All list visible; mutation atoms absent (∪ read / ∩ write denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuAllAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(IcuAllAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('All Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('All ICU'), findsWidgets);
      expect(find.byType(AppSearchBar), findsOneWidget);
      expect(find.text('Assign ICU bed'), findsNothing);
      expect(find.text('Start ICU stay'), findsNothing);
      expect(find.byTooltip('Refresh'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('All Tab Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Assign ICU bed'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Observation'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Critical alert'), findsNothing);
      expect(find.widgetWithText(AppButton, 'End ICU stay'), findsNothing);
      expect(find.textContaining('Print'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∪: Assign bed next-action and detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(IcuAllAtomPermissions.write.isAllowed(writer), isTrue);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('All Tab Patient'), findsOneWidget);
      expect(find.text('Assign ICU bed'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('All Tab Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppButton, 'Observation'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'Critical alert'), findsWidgets);
      expect(find.widgetWithText(AppButton, 'End ICU stay'), findsWidgets);
      // Assign bed omitted from detail when it is the row next-action.
      expect(
        find.descendant(
          of: find.byType(AppQuickActions),
          matching: find.text('Assign ICU bed'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    '∪ write: emergency:write alone enables All mutations without clinical:write',
    (WidgetTester tester) async {
      final AppAccessPolicy emergencyWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.emergencyWrite,
        },
      );
      // Source keeps clinical|emergency write ∪ (matrix ∩ clinical:write alone).
      expect(IcuAllAtomPermissions.write.isAllowed(emergencyWriter), isTrue);
      expect(IcuAllAtomPermissions.create.isAllowed(emergencyWriter), isTrue);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: emergencyWriter,
      );

      expect(find.text('Assign ICU bed'), findsWidgets);
    },
  );

  testWidgets(
    '∪ emergency:read alone shows All tab without write next-actions',
    (WidgetTester tester) async {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: emergencyReader,
      );

      expect(find.text('All Tab Patient'), findsOneWidget);
      expect(find.textContaining('All ICU'), findsWidgets);
      expect(find.text('Assign ICU bed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'operations:read alone collapses strip (no board read)',
    (WidgetTester tester) async {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: opsReader,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byType(AppListTable<IcuPatientSummary>), findsNothing);
      expect(find.text('All Tab Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip collapses All chrome without icu-critical-care',
    (WidgetTester tester) async {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('All Tab Patient'), findsNothing);
      expect(find.text('Assign ICU bed'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'navigation next-action Open IPD remains for read-only on ended row',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        items: <IcuPatientSummary>[_endedPatient],
      );

      expect(find.text('Ended All Patient'), findsOneWidget);
      expect(find.textContaining('Open in IPD'), findsWidgets);
    },
  );

  testWidgets(
    'post-mutation sync: Assign bed patches selected stay via write ∪',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(IcuAllAtomPermissions.assignBed.isAllowed(writer), isTrue);

      final IcuPatientSummary afterAssign = _noBedPatient.copyWith(
        hasActiveBed: true,
      );

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      when(() => repository.listIcuBoard(any())).thenAnswer((
        Invocation invocation,
      ) async {
        final IcuBoardQuery query =
            invocation.positionalArguments.single as IcuBoardQuery;
        return Result<AppPage<IcuPatientSummary>>.success(
          AppPage<IcuPatientSummary>(
            items: <IcuPatientSummary>[afterAssign],
            request: query.pageRequest,
            totalItemCount: 1,
          ),
        );
      });
      when(() => repository.loadIcuDetail(any())).thenAnswer((_) async {
        return Result<IcuPatientDetail>.success(
          IcuPatientDetail(
            summary: afterAssign,
            activeStay: const IcuStaySummary(id: 'stay-all-1'),
          ),
        );
      });

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final IcuWorkspaceController controller = container.read(
        icuWorkspaceControllerProvider.notifier,
      );
      final AppFailure? selectFailure = await controller.selectPatient(
        _noBedPatient,
      );
      expect(selectFailure, isNull);

      final AppFailure? mutateFailure = await controller.assignBed('bed-9');
      expect(mutateFailure, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verify(
        () => repository.assignBed(
          detail: any(named: 'detail'),
          bedId: 'bed-9',
        ),
      ).called(1);

      final IcuWorkspaceState? state = container
          .read(icuWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (IcuWorkspaceState value) => value,
            failure: (_) => null,
          );
      expect(state?.selectedDetail?.summary.hasActiveBed, isTrue);
      expect(
        state?.board.items.any(
          (IcuPatientSummary item) => item.hasActiveBed,
        ),
        isTrue,
      );
    },
  );

  testWidgets('empty state remains for authorized All reader', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      listOverride: Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: const <IcuPatientSummary>[],
          request: const AppPageRequest(),
          totalItemCount: 0,
        ),
      ),
    );

    expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
    expect(find.byType(AppSearchBar), findsOneWidget);
    expect(find.text('Assign ICU bed'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('error / retry remains for authorized All reader', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      listOverride: const Result<AppPage<IcuPatientSummary>>.failure(
        AppFailure.network(),
      ),
    );

    expect(find.textContaining('Try again'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('mobile viewport: All list + write next-action for writer', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(390, 844),
    );

    expect(find.textContaining('All Tab Patient'), findsWidgets);
    expect(find.text('Assign ICU bed'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('dark theme: All read chrome mounts without mutation atoms', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.emergencyRead},
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      themeMode: ThemeMode.dark,
    );

    expect(find.text('All Tab Patient'), findsOneWidget);
    expect(find.text('Assign ICU bed'), findsNothing);
    expect(
      Theme.of(tester.element(find.text('All Tab Patient'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('desktop + light: write ∪ mounts Assign bed on All', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Assign ICU bed'), findsWidgets);
    expect(find.text('All Tab Patient'), findsOneWidget);
  });

  testWidgets('integration: All tab selected via section=all deep link', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpAllTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      initialLocation: '/icu?section=all',
    );

    final List<IcuBoardQuery> scopes = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(
      scopes.any((IcuBoardQuery q) => q.scope == IcuBoardScope.all),
      isTrue,
    );
  });
}
