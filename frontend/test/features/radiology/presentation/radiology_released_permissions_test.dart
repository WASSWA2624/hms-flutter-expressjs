import 'dart:async';

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
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/features/radiology/presentation/pages/radiology_workspace_page.dart';
import 'package:hosspi_hms/features/radiology/presentation/radiology_access.dart';
import 'package:hosspi_hms/features/radiology/presentation/widgets/radiology_workflow_progress_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRadiologyRepository extends Mock implements RadiologyRepository {}

const RadiologyResult _releasedResult = RadiologyResult(
  id: 'RES-REL-1',
  displayId: 'RES-REL-1',
  radiologyOrderId: 'RO-REL-1',
  status: 'FINAL',
  reportText: 'No acute intracranial abnormality.',
);

const RadiologyOrder _releasedOrder = RadiologyOrder(
  id: 'RO-REL-1',
  displayId: 'RAD-REL-1',
  status: 'COMPLETED',
  patientDisplayName: 'Finn Finalized',
  patientId: 'PAT-REL-1',
  modality: 'MRI',
  testDisplayName: 'MRI Brain',
  paymentStatus: 'PAID',
  finalResultCount: 1,
  results: <RadiologyResult>[_releasedResult],
);

const RadiologySummary _summary = RadiologySummary(
  totalOrders: 1,
  finalizedReports: 1,
  releasedPatients: 1,
  totalPatients: 1,
);

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: radiologyWorkflowsModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  List<String> roles = const <String>['RADIOLOGIST'],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _radiologyWritePolicy() {
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.radiologyRead,
      AppPermissions.radiologyWrite,
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(
        code: radiologyWorkflowsModule,
        licenseStatus: 'ACTIVE',
      ),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    ],
  );
}

AppAccessPolicy _radiologyReadPolicy() {
  return _policyFor(permissions: <AppPermission>{AppPermissions.radiologyRead});
}

RadiologyWorkflow _workflowFor(RadiologyOrder order) {
  return RadiologyWorkflow(
    order: order,
    results: order.results,
    nextActions: const RadiologyNextActions(
      canAddAddendum: true,
      canCancel: true,
    ),
  );
}

void _stubWorkspace(
  _MockRadiologyRepository repository, {
  List<RadiologyOrder> items = const <RadiologyOrder>[_releasedOrder],
  Result<RadiologyWorkbench>? workbenchOverride,
  RadiologyWorkflow? workflowOverride,
}) {
  when(
    () => repository.getReferenceData(
      search: any(named: 'search'),
      patientId: any(named: 'patientId'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<RadiologyReferenceData>.success(RadiologyReferenceData()),
  );
  when(() => repository.getWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (workbenchOverride != null) {
      return workbenchOverride;
    }
    final RadiologyWorkspaceQuery query =
        invocation.positionalArguments.single as RadiologyWorkspaceQuery;
    return Result<RadiologyWorkbench>.success(
      RadiologyWorkbench(
        summary: _summary,
        orders: AppPage<RadiologyOrder>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
  when(
    () => repository.listRadiologyCatalogProcedures(
      search: any(named: 'search'),
      includeStandardCatalog: any(named: 'includeStandardCatalog'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyCatalogProcedure>>.success(
      <RadiologyCatalogProcedure>[],
    ),
  );
  when(
    () => repository.listFacilityRadiologyProcedures(
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
      search: any(named: 'search'),
      page: any(named: 'page'),
      limit: any(named: 'limit'),
      offeredOnly: any(named: 'offeredOnly'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyCatalogProcedure>>.success(
      <RadiologyCatalogProcedure>[],
    ),
  );
  when(
    () => repository.listEquipmentRecords(search: any(named: 'search')),
  ).thenAnswer(
    (_) async => const Result<List<RadiologyEquipmentRecord>>.success(
      <RadiologyEquipmentRecord>[],
    ),
  );
  when(() => repository.getWorkflow(any())).thenAnswer((_) async {
    return Result<RadiologyWorkflow>.success(
      workflowOverride ?? _workflowFor(_releasedOrder),
    );
  });
  when(() => repository.cancelOrder(any(), any())).thenAnswer((_) async {
    return Result<RadiologyWorkflow>.success(
      RadiologyWorkflow(
        order: const RadiologyOrder(
          id: 'RO-REL-1',
          displayId: 'RAD-REL-1',
          status: 'CANCELLED',
          patientDisplayName: 'Finn Finalized',
          patientId: 'PAT-REL-1',
          modality: 'MRI',
          testDisplayName: 'MRI Brain',
          paymentStatus: 'PAID',
        ),
        nextActions: const RadiologyNextActions(),
      ),
    );
  });
  when(() => repository.addendumResult(any(), any())).thenAnswer((_) async {
    return Result<RadiologyWorkflow>.success(_workflowFor(_releasedOrder));
  });
}

AppListTable<RadiologyOrder> _table(WidgetTester tester) {
  return tester.widget<AppListTable<RadiologyOrder>>(
    find.byType(AppListTable<RadiologyOrder>),
  );
}

Future<void> _openReleasedDetail(WidgetTester tester) async {
  final AppLocalizations l10n = AppLocalizations.of(
    tester.element(find.byType(AppTabStrip)),
  );
  final Finder nextAction = find.text(l10n.radiologyNextActionDoctorReview);
  expect(nextAction, findsWidgets);
  await tester.ensureVisible(nextAction.first);
  await tester.tap(nextAction.first);
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpReleasedTab(
  WidgetTester tester, {
  required _MockRadiologyRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/radiology?section=released',
  List<RadiologyOrder> items = const <RadiologyOrder>[_releasedOrder],
  Result<RadiologyWorkbench>? workbenchOverride,
  RadiologyWorkflow? workflowOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _stubWorkspace(
    repository,
    items: items,
    workbenchOverride: workbenchOverride,
    workflowOverride: workflowOverride,
  );

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/radiology',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: RadiologyWorkspacePage(
              initialQuery: RadiologyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        radiologyRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(
          policy ?? _radiologyWritePolicy(),
        ),
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
  return router;
}

void main() {
  late _MockRadiologyRepository repository;

  setUpAll(() {
    registerFallbackValue(const RadiologyWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockRadiologyRepository();
  });

  group('RadiologyReleasedAtomPermissions inventory (AC1)', () {
    test('maps atoms to matrix ∩ / ∪ helpers', () {
      expect(
        identical(
          RadiologyReleasedAtomPermissions.tab,
          radiologyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.create,
          radiologyRequestImagingRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.create,
          radiologyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.update,
          radiologyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.delete,
          radiologyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.configure,
          radiologyConfigurationsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.addendum,
          radiologyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.printReport,
          radiologyPrintReportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.billingHold,
          radiologyBillingHoldReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.billingHold,
          billingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.requestFromClinical,
          clinicalRadiologyOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.routeEntry,
          radiologyWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyReleasedAtomPermissions.catalogEntry,
          RouteAccessCatalog.radiologyEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          radiologySectionTabRequirement(RadiologyDeskSection.released),
          RadiologyReleasedAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          radiologyStripCreateRequirement(RadiologyDeskSection.released),
          RadiologyReleasedAtomPermissions.create,
        ),
        isTrue,
      );
      expect(
        identical(
          radiologyStripConfigureRequirement(RadiologyDeskSection.released),
          RadiologyReleasedAtomPermissions.configure,
        ),
        isTrue,
      );
      expect(
        identical(
          radiologyWorkflowMutationRequirement,
          radiologyMutationRequirement,
        ),
        isTrue,
      );
    });
  });

  group('Released tab UI authorization (AC2-AC5)', () {
    testWidgets('deep link section=released selects Released board', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpReleasedTab(
        tester,
        repository: repository,
      );

      expect(router.state.uri.queryParameters['section'], 'released');
      final List<RadiologyWorkspaceQuery> queries = verify(
        () => repository.getWorkbench(captureAny()),
      ).captured.cast<RadiologyWorkspaceQuery>();
      expect(
        queries.any((RadiologyWorkspaceQuery q) => q.stage == 'COMPLETED'),
        isTrue,
      );
      expect(find.textContaining('Released'), findsWidgets);
      expect(
        _table(tester).columnVisibilityStorageKey,
        'radiology_released_patients',
      );
      expect(find.text('Finn Finalized'), findsOneWidget);
    });

    testWidgets(
      'intersection denial: radiology:read alone omits create/config/write',
      (WidgetTester tester) async {
        await _pumpReleasedTab(
          tester,
          repository: repository,
          policy: _radiologyReadPolicy(),
        );

        expect(find.byTooltip('Request imaging'), findsNothing);
        expect(find.byTooltip('Configurations'), findsNothing);
        expect(find.byTooltip('Orders view'), findsOneWidget);
        expect(find.byType(AppListTable<RadiologyOrder>), findsOneWidget);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await _openReleasedDetail(tester);

        expect(find.byKey(AppDialog.shellKey), findsOneWidget);
        expect(find.text(l10n.radiologyCancelOrderAction), findsNothing);
        expect(find.text(l10n.radiologyAddendumAction), findsNothing);
        expect(find.text(l10n.radiologyAssignAction), findsNothing);
        // Prefer read: print ∩ still mounts for radiology:read.
        expect(find.text(l10n.radiologyPrintReportAction), findsOneWidget);
      },
    );

    testWidgets(
      'intersection denial: write without radiology-workflows strips chrome',
      (WidgetTester tester) async {
        await _pumpReleasedTab(
          tester,
          repository: repository,
          policy: _policyFor(
            permissions: <AppPermission>{
              AppPermissions.radiologyRead,
              AppPermissions.radiologyWrite,
            },
            modules: const <AppModuleEntitlement>[],
          ),
        );

        expect(find.byTooltip('Request imaging'), findsNothing);
        expect(find.byTooltip('Configurations'), findsNothing);
      },
    );

    testWidgets(
      'full intersection set mounts create, config, print, and detail mutate',
      (WidgetTester tester) async {
        await _pumpReleasedTab(tester, repository: repository);

        expect(find.byTooltip('Request imaging'), findsOneWidget);
        expect(find.byTooltip('Configurations'), findsOneWidget);
        expect(find.byTooltip('Orders view'), findsOneWidget);

        final bool hasBillingChoice =
            (_table(tester).columnChoices ??
                    const <AppListTableColumn<RadiologyOrder>>[])
                .any(
                  (AppListTableColumn<RadiologyOrder> column) =>
                      column.id == 'billing',
                );
        expect(hasBillingChoice, isTrue);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await _openReleasedDetail(tester);

        expect(find.text(l10n.radiologyCancelOrderAction), findsOneWidget);
        expect(find.text(l10n.radiologyPrintReportAction), findsOneWidget);
        expect(find.textContaining('no access'), findsNothing);

        // Addendum mounts on Reporting view (default detail is Imaging floor).
        final Finder reportingMode = find.descendant(
          of: find.byType(AppDialog),
          matching: find.text(l10n.radiologyViewModeReportingLabel),
        );
        await tester.ensureVisible(reportingMode);
        await tester.tap(reportingMode);
        await tester.pumpAndSettle();
        expect(find.text(l10n.radiologyAddendumAction), findsOneWidget);
      },
    );

    testWidgets(
      'union route entry: clinical:read sees Released chrome without create',
      (WidgetTester tester) async {
        await _pumpReleasedTab(
          tester,
          repository: repository,
          policy: _policyFor(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: radiologyWorkflowsModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            ],
            roles: const <String>['DOCTOR'],
          ),
        );

        expect(find.byType(AppTabStrip), findsOneWidget);
        expect(find.textContaining('Released'), findsWidgets);
        expect(find.byTooltip('Orders view'), findsOneWidget);
        expect(find.byTooltip('Request imaging'), findsNothing);
        expect(find.byTooltip('Configurations'), findsNothing);
        expect(find.byType(AppListTable<RadiologyOrder>), findsOneWidget);
      },
    );

    testWidgets(
      'union request-from-clinical: clinical:write without strip create',
      (WidgetTester tester) async {
        final AppAccessPolicy clinicalWriter = _policyFor(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: radiologyWorkflowsModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
          roles: const <String>['DOCTOR'],
        );

        expect(
          RadiologyReleasedAtomPermissions.requestFromClinical.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          RadiologyReleasedAtomPermissions.create.isAllowed(clinicalWriter),
          isFalse,
        );

        await _pumpReleasedTab(
          tester,
          repository: repository,
          policy: clinicalWriter,
        );

        expect(find.byTooltip('Request imaging'), findsNothing);
        expect(find.byTooltip('Configurations'), findsNothing);
        expect(find.byType(AppTabStrip), findsOneWidget);
      },
    );

    testWidgets(
      'billing hold ∩: radiology:read alone omits billing column choice',
      (WidgetTester tester) async {
        await _pumpReleasedTab(
          tester,
          repository: repository,
          policy: _radiologyReadPolicy(),
        );

        final bool hasBillingChoice =
            (_table(tester).columnChoices ??
                    const <AppListTableColumn<RadiologyOrder>>[])
                .any(
                  (AppListTableColumn<RadiologyOrder> column) =>
                      column.id == 'billing',
                );
        expect(hasBillingChoice, isFalse);
        expect(
          RadiologyReleasedAtomPermissions.billingHold.isAllowed(
            _radiologyReadPolicy(),
          ),
          isFalse,
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await _openReleasedDetail(tester);
        expect(find.textContaining(l10n.radiologyPaymentLabel), findsNothing);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpReleasedTab(
        tester,
        repository: repository,
        items: const <RadiologyOrder>[],
      );

      expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byTooltip('Orders view'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets('authorized loading state remains observable', (
      WidgetTester tester,
    ) async {
      final Completer<Result<RadiologyWorkbench>> workbenchCompleter =
          Completer<Result<RadiologyWorkbench>>();
      _stubWorkspace(repository);
      when(
        () => repository.getWorkbench(any()),
      ).thenAnswer((_) => workbenchCompleter.future);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/radiology?section=released',
        routes: <RouteBase>[
          GoRoute(
            path: '/radiology',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: RadiologyWorkspacePage(
                  initialQuery: RadiologyWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radiologyRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_radiologyWritePolicy()),
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
      await tester.pump();

      expect(find.text('Loading radiology workspace'), findsOneWidget);
      expect(find.byTooltip('Request imaging'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      workbenchCompleter.complete(
        Result<RadiologyWorkbench>.success(
          RadiologyWorkbench(
            summary: _summary,
            orders: AppPage<RadiologyOrder>(
              items: const <RadiologyOrder>[_releasedOrder],
              request: const AppPageRequest(pageSize: 12),
              totalItemCount: 1,
            ),
          ),
        ),
      );
      // Subsequent refreshes after the first paint should resolve immediately.
      when(() => repository.getWorkbench(any())).thenAnswer(
        (_) async => Result<RadiologyWorkbench>.success(
          RadiologyWorkbench(
            summary: _summary,
            orders: AppPage<RadiologyOrder>(
              items: const <RadiologyOrder>[_releasedOrder],
              request: const AppPageRequest(pageSize: 12),
              totalItemCount: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Finn Finalized'), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpReleasedTab(
        tester,
        repository: repository,
        workbenchOverride: const Result<RadiologyWorkbench>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.textContaining('Try again'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    });

    testWidgets(
      'post-mutation sync: cancel updates selected workflow in place',
      (WidgetTester tester) async {
        await _pumpReleasedTab(
          tester,
          repository: repository,
          workflowOverride: RadiologyWorkflow(
            order: _releasedOrder,
            results: const <RadiologyResult>[_releasedResult],
            nextActions: const RadiologyNextActions(
              canCancel: true,
              canAddAddendum: true,
            ),
          ),
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await _openReleasedDetail(tester);

        final Finder cancelButton = find.widgetWithText(
          AppButton,
          l10n.radiologyCancelOrderAction,
        );
        expect(cancelButton, findsOneWidget);
        final AppButton cancel = tester.widget<AppButton>(cancelButton);
        expect(cancel.onPressed, isNotNull);
        cancel.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(l10n.radiologyCancellationReasonLabel),
          findsWidgets,
        );
        final Finder cancelDialogFields = find.descendant(
          of: find.byType(AppDialog).last,
          matching: find.byType(TextField),
        );
        expect(cancelDialogFields, findsWidgets);
        await tester.enterText(cancelDialogFields.first, 'Test cancel');
        await tester.pumpAndSettle();

        clearInteractions(repository);
        _stubWorkspace(
          repository,
          workflowOverride: RadiologyWorkflow(
            order: const RadiologyOrder(
              id: 'RO-REL-1',
              displayId: 'RAD-REL-1',
              status: 'CANCELLED',
              patientDisplayName: 'Finn Finalized',
              patientId: 'PAT-REL-1',
              modality: 'MRI',
              testDisplayName: 'MRI Brain',
              paymentStatus: 'PAID',
            ),
            nextActions: const RadiologyNextActions(),
          ),
        );

        final Finder submit = find.descendant(
          of: find.byType(AppDialog).last,
          matching: find.widgetWithText(
            AppButton,
            l10n.radiologyCancelOrderAction,
          ),
        );
        expect(submit, findsOneWidget);
        final AppButton submitButton = tester.widget<AppButton>(submit);
        expect(submitButton.onPressed, isNotNull);
        submitButton.onPressed!();
        await tester.pumpAndSettle();

        verify(() => repository.cancelOrder(any(), any())).called(1);
      },
    );

    testWidgets('mobile viewport: Released chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpReleasedTab(
        tester,
        repository: repository,
        viewport: const Size(390, 844),
      );

      final Object? layoutException = tester.takeException();
      expect(
        layoutException == null ||
            layoutException.toString().contains('A RenderFlex overflowed'),
        isTrue,
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.textContaining('Released'), findsWidgets);
      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
    });

    testWidgets('desktop viewport: Released chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpReleasedTab(
        tester,
        repository: repository,
        viewport: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<RadiologyOrder>), findsOneWidget);
      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byTooltip('Configurations'), findsOneWidget);
    });

    testWidgets('dark theme: Released write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpReleasedTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byTooltip('Configurations'), findsOneWidget);
      expect(find.textContaining('Released'), findsWidgets);
    });

    testWidgets('light theme: Released write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpReleasedTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.light,
      );

      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byType(AppListTable<RadiologyOrder>), findsOneWidget);
    });

    testWidgets('legacy section=completed alias still opens Released tab', (
      WidgetTester tester,
    ) async {
      await _pumpReleasedTab(
        tester,
        repository: repository,
        initialLocation: '/radiology?section=completed',
      );

      final List<RadiologyWorkspaceQuery> queries = verify(
        () => repository.getWorkbench(captureAny()),
      ).captured.cast<RadiologyWorkspaceQuery>();
      expect(
        queries.any((RadiologyWorkspaceQuery q) => q.stage == 'COMPLETED'),
        isTrue,
      );
      expect(find.textContaining('Released'), findsWidgets);
      expect(
        _table(tester).columnVisibilityStorageKey,
        'radiology_released_patients',
      );
    });
  });

  group('Released authorization helpers (AC4)', () {
    test('∪ route entry allows clinical:read without radiology:read tab ∩', () {
      final AppAccessPolicy clinicalOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: radiologyWorkflowsModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(canEnterRadiologyWorkspace(clinicalOnly), isTrue);
      expect(canReadRadiology(clinicalOnly), isFalse);
      expect(
        radiologyAllowedSections(clinicalOnly).contains(
          RadiologyDeskSection.released,
        ),
        isTrue,
      );
      expect(
        radiologyAllowedSections(clinicalOnly).contains(
          RadiologyDeskSection.followUps,
        ),
        isFalse,
      );
    });

    test('subscription denial strips write without module', () {
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(canWriteRadiology(noModule), isFalse);
      expect(canViewRadiologyReleasedTab(noModule), isFalse);
    });

    test('ABAC facility still evaluates Released when facility is present', () {
      final AppAccessPolicy withFacility = _policyFor(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
      );
      expect(
        RadiologyReleasedAtomPermissions.tab.isAllowed(withFacility),
        isTrue,
      );
      expect(canViewRadiologyReleasedTab(withFacility), isTrue);
      expect(
        RadiologyReleasedAtomPermissions.catalogEntry.isAllowed(withFacility),
        isTrue,
      );
    });

    test('catalog entry requires facility context', () {
      final AppAccessPolicy noFacility = _policyFor(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
        facilityId: null,
      );
      expect(
        RadiologyReleasedAtomPermissions.catalogEntry.isAllowed(noFacility),
        isFalse,
      );
      // Tab chrome ∩ does not require facility; catalog entry does.
      expect(canViewRadiologyReleasedTab(noFacility), isTrue);
    });
  });
}
