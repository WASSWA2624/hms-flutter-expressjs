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
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _criticalPatient = IcuPatientSummary(
  id: 'ADM-CRIT-1',
  admissionId: 'ADM-CRIT-1',
  displayId: 'ADMCRIT1',
  patientDisplayName: 'Critical Tab Patient',
  icuStatus: 'ACTIVE',
  hasCriticalAlert: true,
  criticalSeverity: 'HIGH',
  bedLabel: 'ICU-2',
  encounterId: 'ENC-CRIT-1',
);

const IcuCriticalAlert _latestAlert = IcuCriticalAlert(
  id: 'ALERT-1',
  severity: 'HIGH',
  message: 'Hypotension',
);

const IcuPatientDetail _criticalDetail = IcuPatientDetail(
  summary: _criticalPatient,
  activeStay: IcuStaySummary(id: 'STAY-CRIT-1'),
  alerts: <IcuCriticalAlert>[_latestAlert],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  String? tenantId = 'tenant-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalWrite ||
        permission == AppPermissions.clinicalRead,
  );
  final bool needsEmergency = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.emergencyWrite ||
        permission == AppPermissions.emergencyRead,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsWrite ||
        permission == AppPermissions.operationsRead,
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
        roles: const <String>['NURSE'],
        tenantId: tenantId,
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_criticalPatient],
  IcuPatientDetail? detail,
  Result<AppPage<IcuPatientSummary>>? listOverride,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((invocation) async {
    if (listOverride != null) {
      return listOverride;
    }
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    List<IcuPatientSummary> filtered = items;
    if (query.scope == IcuBoardScope.critical) {
      filtered = items
          .where((IcuPatientSummary item) => item.hasCriticalAlert)
          .toList(growable: false);
    }
    return Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: filtered,
        request: query.pageRequest,
        totalItemCount: filtered.length,
      ),
    );
  });
  when(repository.loadReferenceData).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(repository.loadBedBoard).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(IcuBedBoard()),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer((invocation) async {
    final IcuPatientSummary summary =
        invocation.positionalArguments.single as IcuPatientSummary;
    return Result<IcuPatientDetail>.success(
      detail ??
          IcuPatientDetail(
            summary: summary.id == _criticalPatient.id
                ? _criticalPatient
                : summary,
            activeStay: summary.hasCriticalAlert
                ? const IcuStaySummary(id: 'STAY-CRIT-1')
                : null,
            alerts: summary.hasCriticalAlert
                ? const <IcuCriticalAlert>[_latestAlert]
                : const <IcuCriticalAlert>[],
          ),
    );
  });
  when(() => repository.acknowledgeAlert(
        detail: any(named: 'detail'),
        alertId: any(named: 'alertId'),
      )).thenAnswer((_) async {
    return Result<IcuPatientDetail>.success(
      IcuPatientDetail(
        summary: _criticalPatient.copyWith(hasCriticalAlert: false),
        activeStay: const IcuStaySummary(id: 'STAY-CRIT-1'),
      ),
    );
  });
}

Future<void> _pumpCriticalTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/icu?section=critical',
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_criticalPatient],
  Result<AppPage<IcuPatientSummary>>? listOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, listOverride: listOverride);

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
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        icuRepositoryProvider.overrideWithValue(repository),
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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
    );
    registerFallbackValue(_criticalDetail);
  });

  setUp(() {
    repository = _MockIcuRepository();
  });

  group('IcuCriticalAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        IcuCriticalAtomPermissions.tab,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.alertColumn,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.empty,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.detail,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.printSummary,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.write,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.write,
        same(IcuWorkspaceWriteRequirement.writeRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.nextActionAcknowledge,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.raiseAlert,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.delete,
        same(icuWorkspaceDeleteRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.panelDeepLink,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.routeEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        IcuCriticalAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.icuEntry),
      );
      expect(
        IcuCriticalAtomPermissions.navigation,
        same(icuNavigationRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.navigate,
        same(icuNavigationRequirement),
      );
      expect(
        icuWriteRequirementForSection(IcuWorkspaceSection.critical),
        same(IcuCriticalAtomPermissions.write),
      );
      expect(
        icuDetailReadRequirement(IcuWorkspaceSection.critical),
        same(IcuCriticalAtomPermissions.detail),
      );
      expect(
        icuBoardTabRequirement(IcuWorkspaceSection.critical),
        same(IcuCriticalAtomPermissions.tab),
      );
      expect(icuRouteEntryMatchesAppRoutes(), isTrue);
    });

    test('nested cross-module matrix _(n/a)_: no extra module keys', () {
      expect(
        IcuCriticalAtomPermissions.nestedWrite,
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.nestedRead,
        same(icuWorkspaceReadRequirement),
      );
      expect(
        IcuCriticalAtomPermissions.nestedWrite.anyPermissions.toSet(),
        <AppPermission>{
          AppPermissions.clinicalWrite,
          AppPermissions.emergencyWrite,
        },
      );
    });

    test('∩ denial via missing write: clinical:read alone strips mutations', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(IcuCriticalAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(canViewIcuCritical(reader), isTrue);
      expect(IcuCriticalAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        IcuCriticalAtomPermissions.nextActionAcknowledge.isAllowed(reader),
        isFalse,
      );
      expect(
        IcuCriticalAtomPermissions.validation.isAllowed(reader),
        isFalse,
      );
      expect(icuBoardShowsNextActionColumn(reader, IcuWorkspaceSection.critical),
          isFalse);
    });

    test('source write ∪: clinical:write alone satisfies acknowledge', () {
      // Matrix lists ∩ clinical:write; source keeps ∪ clinical|emergency write.
      final AppAccessPolicy clinicalWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IcuCriticalAtomPermissions.write.isAllowed(clinicalWriter),
        isTrue,
      );
      expect(
        IcuCriticalAtomPermissions.nextActionAcknowledge.isAllowed(
          clinicalWriter,
        ),
        isTrue,
      );

      final AppAccessPolicy emergencyWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.emergencyWrite,
        },
      );
      expect(
        IcuCriticalAtomPermissions.write.isAllowed(emergencyWriter),
        isTrue,
      );
    });

    test('∪ allowance: emergency:read shows Critical tab without clinical:read',
        () {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );
      expect(canViewIcuCritical(emergencyReader), isTrue);
      expect(
        IcuCriticalAtomPermissions.tab.isAllowed(emergencyReader),
        isTrue,
      );
      expect(
        IcuCriticalAtomPermissions.write.isAllowed(emergencyReader),
        isFalse,
      );
    });

    test('∪ allowance: operations:read enters route but not Critical tab', () {
      final AppAccessPolicy opsReader = _policy(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      expect(
        IcuCriticalAtomPermissions.routeEntry.isAllowed(opsReader),
        isTrue,
      );
      expect(canViewIcuCritical(opsReader), isFalse);
      expect(
        icuAllowedBoardSections(opsReader),
        isEmpty,
      );
    });

    test('subscription strip: icu-critical-care required for Critical tab', () {
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
      expect(IcuCriticalAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(canViewIcuCritical(noModule), isFalse);
      expect(IcuCriticalAtomPermissions.write.isAllowed(noModule), isFalse);
    });

    test('next-action requirement maps acknowledge to write ∪', () {
      expect(
        icuNextActionRequirement(IcuNextActionKind.acknowledgeAlert),
        same(icuWorkspaceWriteRequirement),
      );
      expect(
        icuNextActionRequirement(IcuNextActionKind.openIpd),
        same(icuNavigationRequirement),
      );
      expect(
        icuFocusedPanelRequirement(IcuDetailPanel.alerts),
        same(icuWorkspaceWriteRequirement),
      );
    });
  });

  testWidgets(
    'read-only: Critical list visible; Acknowledge / writes absent (∪ read, write denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Critical Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Critical alerts'), findsWidgets);
      expect(find.text('Acknowledge alert'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.textContaining('Next'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Critical Tab Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Acknowledge alert'), findsNothing);
      expect(find.text('Critical alert'), findsNothing);
      expect(find.text('End ICU stay'), findsNothing);
      expect(find.text('Print summary'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∪: Acknowledge next-action + detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Critical Tab Patient'), findsOneWidget);
      expect(find.text('Acknowledge alert'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Critical Tab Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Row next-action Acknowledge omitted from detail Quick Actions.
      expect(find.text('Critical alert'), findsWidgets);
      expect(find.text('Print summary'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    '∪ emergency:read alone shows Critical tab content',
    (WidgetTester tester) async {
      final AppAccessPolicy emergencyReader = _policy(
        permissions: <AppPermission>{AppPermissions.emergencyRead},
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: emergencyReader,
      );

      expect(find.text('Critical Tab Patient'), findsOneWidget);
      expect(find.textContaining('Critical alerts'), findsWidgets);
      expect(find.text('Acknowledge alert'), findsNothing);
    },
  );

  testWidgets(
    'authorized acknowledge syncs board after mutation',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      final Element element = tester.element(find.byType(IcuWorkspacePage));
      final ProviderContainer container = ProviderScope.containerOf(element);
      final IcuWorkspaceController controller = container.read(
        icuWorkspaceControllerProvider.notifier,
      );
      final AppFailure? selectFailure = await controller.selectPatient(
        _criticalPatient,
      );
      expect(selectFailure, isNull);

      final AppFailure? mutateFailure = await controller.acknowledgeLatestAlert();
      expect(mutateFailure, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verify(
        () => repository.acknowledgeAlert(
          detail: any(named: 'detail'),
          alertId: 'ALERT-1',
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
      expect(state?.selectedDetail?.summary.hasCriticalAlert, isFalse);
      expect(
        state?.board.items.any(
          (IcuPatientSummary item) =>
              item.id == _criticalPatient.id && !item.hasCriticalAlert,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'subscription strip collapses Critical chrome without icu-critical-care',
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

      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: noModule,
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Critical Tab Patient'), findsNothing);
      expect(find.text('Acknowledge alert'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized empty state remains observable for readers', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      items: const <IcuPatientSummary>[],
      listOverride: Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: const <IcuPatientSummary>[],
          request: const AppPageRequest(),
          totalItemCount: 0,
        ),
      ),
    );

    expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
    expect(find.text('Acknowledge alert'), findsNothing);
    expect(find.byType(AppSearchBar), findsOneWidget);
  });

  testWidgets('authorized error/retry surface remains observable', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      listOverride: const Result<AppPage<IcuPatientSummary>>.failure(
        AppFailure.network(),
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('integration: Critical tab selected via section=critical', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      initialLocation: '/icu?section=critical',
    );

    final List<IcuBoardQuery> scopes = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(
      scopes.any((IcuBoardQuery q) => q.scope == IcuBoardScope.critical),
      isTrue,
    );
  });

  testWidgets('mobile viewport: Critical read chrome + no write affordance', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy reader = _policy(
      permissions: <AppPermission>{AppPermissions.clinicalRead},
    );

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: reader,
      physicalSize: const Size(390, 844),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Critical'), findsWidgets);
    expect(find.text('Acknowledge alert'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop + dark: Critical write affordances remain for writer', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Critical Tab Patient'), findsOneWidget);
    expect(find.text('Acknowledge alert'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop + light: write ∪ mounts Acknowledge alert', (
    WidgetTester tester,
  ) async {
    final AppAccessPolicy writer = _policy(
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
    );

    await _pumpCriticalTab(
      tester,
      repository: repository,
      accessPolicy: writer,
      physicalSize: const Size(1440, 900),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Acknowledge alert'), findsWidgets);
    expect(find.text('Critical Tab Patient'), findsOneWidget);
  });
}
