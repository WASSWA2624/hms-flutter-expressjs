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

const RadiologyOrder _allOrder = RadiologyOrder(
  id: 'RO-ALL-1',
  displayId: 'RAD-ALL-1',
  status: 'ORDERED',
  patientDisplayName: 'Ann All',
  patientId: 'PAT-ALL-1',
  modality: 'XRAY',
  testDisplayName: 'Chest X-ray',
  billingGateBlocked: true,
);

const RadiologySummary _summary = RadiologySummary(
  totalOrders: 1,
  orderedQueue: 1,
  actionablePatients: 1,
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
    nextActions: const RadiologyNextActions(
      canAssign: true,
      canStart: true,
      canCancel: true,
      billingGateBlocked: true,
    ),
  );
}

void _stubWorkspace(
  _MockRadiologyRepository repository, {
  List<RadiologyOrder> items = const <RadiologyOrder>[_allOrder],
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
      workflowOverride ?? _workflowFor(_allOrder),
    );
  });
  when(() => repository.cancelOrder(any(), any())).thenAnswer((_) async {
    return Result<RadiologyWorkflow>.success(
      RadiologyWorkflow(
        order: const RadiologyOrder(
          id: 'RO-ALL-1',
          displayId: 'RAD-ALL-1',
          status: 'CANCELLED',
          patientDisplayName: 'Ann All',
          patientId: 'PAT-ALL-1',
          modality: 'XRAY',
          testDisplayName: 'Chest X-ray',
        ),
        nextActions: const RadiologyNextActions(),
      ),
    );
  });
}

AppListTable<RadiologyOrder> _table(WidgetTester tester) {
  return tester.widget<AppListTable<RadiologyOrder>>(
    find.byType(AppListTable<RadiologyOrder>),
  );
}

Future<GoRouter> _pumpAllOrdersTab(
  WidgetTester tester, {
  required _MockRadiologyRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/radiology?section=all',
  List<RadiologyOrder> items = const <RadiologyOrder>[_allOrder],
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

  group('RadiologyAllOrdersAtomPermissions inventory (AC1)', () {
    test('maps atoms to matrix ∩ / ∪ helpers', () {
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.tab,
          radiologyWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.create,
          radiologyRequestImagingRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.create,
          radiologyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.update,
          radiologyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.delete,
          radiologyWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.configure,
          radiologyConfigurationsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.billingHold,
          radiologyBillingHoldReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.billingHold,
          billingReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.requestFromClinical,
          clinicalRadiologyOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.routeEntry,
          radiologyWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          RadiologyAllOrdersAtomPermissions.catalogEntry,
          RouteAccessCatalog.radiologyEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          radiologySectionTabRequirement(RadiologyDeskSection.allOrders),
          RadiologyAllOrdersAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          radiologyStripCreateRequirement(RadiologyDeskSection.allOrders),
          RadiologyAllOrdersAtomPermissions.create,
        ),
        isTrue,
      );
      expect(
        identical(
          radiologyStripConfigureRequirement(RadiologyDeskSection.allOrders),
          RadiologyAllOrdersAtomPermissions.configure,
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

  group('All orders tab UI authorization (AC2-AC5)', () {
    testWidgets('deep link section=all selects All orders board', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpAllOrdersTab(
        tester,
        repository: repository,
      );

      expect(router.state.uri.queryParameters['section'], 'all');
      expect(find.textContaining('All orders'), findsWidgets);
      expect(
        _table(tester).columnVisibilityStorageKey,
        'radiology_allOrders_patients',
      );
    });

    testWidgets(
      'intersection denial: radiology:read alone omits create/config/write',
      (WidgetTester tester) async {
        await _pumpAllOrdersTab(
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
        await tester.tap(find.text(l10n.radiologyNextActionConfirmBilling).first);
        await tester.pumpAndSettle();

        expect(find.byKey(AppDialog.shellKey), findsOneWidget);
        expect(find.text(l10n.radiologyCancelOrderAction), findsNothing);
        expect(find.text(l10n.radiologyAssignAction), findsNothing);
      },
    );

    testWidgets(
      'intersection denial: write without radiology-workflows strips chrome',
      (WidgetTester tester) async {
        await _pumpAllOrdersTab(
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
      'full intersection set mounts create, config, and detail mutate',
      (WidgetTester tester) async {
        await _pumpAllOrdersTab(tester, repository: repository);

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
        await tester.tap(find.text(l10n.radiologyNextActionConfirmBilling).first);
        await tester.pumpAndSettle();

        expect(find.text(l10n.radiologyCancelOrderAction), findsOneWidget);
        expect(
          RadiologyAllOrdersAtomPermissions.billingHold.isAllowed(
            _radiologyWritePolicy(),
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'union route entry: clinical:read sees All chrome without create',
      (WidgetTester tester) async {
        await _pumpAllOrdersTab(
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
        expect(find.textContaining('All orders'), findsWidgets);
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
          RadiologyAllOrdersAtomPermissions.requestFromClinical.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          RadiologyAllOrdersAtomPermissions.create.isAllowed(clinicalWriter),
          isFalse,
        );

        await _pumpAllOrdersTab(
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
        await _pumpAllOrdersTab(
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
          RadiologyAllOrdersAtomPermissions.billingHold.isAllowed(
            _radiologyReadPolicy(),
          ),
          isFalse,
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await tester.tap(find.text(l10n.radiologyNextActionConfirmBilling).first);
        await tester.pumpAndSettle();
        expect(find.text(l10n.radiologyPaymentLabel), findsNothing);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpAllOrdersTab(
        tester,
        repository: repository,
        items: const <RadiologyOrder>[],
      );

      expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byTooltip('Orders view'), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpAllOrdersTab(
        tester,
        repository: repository,
        workbenchOverride: const Result<RadiologyWorkbench>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets(
      'post-mutation sync: start imaging updates selected workflow in place',
      (WidgetTester tester) async {
        when(() => repository.startOrder(any(), any())).thenAnswer((_) async {
          return Result<RadiologyWorkflow>.success(
            RadiologyWorkflow(
              order: const RadiologyOrder(
                id: 'RO-ALL-1',
                displayId: 'RAD-ALL-1',
                status: 'IN_PROCESS',
                patientDisplayName: 'Ann All',
                modality: 'XRAY',
                testDisplayName: 'Chest X-ray',
              ),
              nextActions: const RadiologyNextActions(canCreateStudy: true),
            ),
          );
        });

        await _pumpAllOrdersTab(
          tester,
          repository: repository,
          workflowOverride: RadiologyWorkflow(
            order: _allOrder,
            nextActions: const RadiologyNextActions(
              canStart: true,
              canCancel: true,
              billingGateBlocked: false,
            ),
          ),
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await tester.tap(
          find.text(l10n.radiologyNextActionConfirmBilling).first,
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.radiologyStartImagingAction), findsWidgets);
        await tester.tap(find.text(l10n.radiologyStartImagingAction).first);
        await tester.pumpAndSettle();

        verify(() => repository.startOrder(any(), any())).called(1);
        // Detail stays open with synchronized workflow (Start action cleared).
        expect(find.byKey(AppDialog.shellKey), findsOneWidget);
        expect(find.text(l10n.radiologyStartImagingAction), findsNothing);
      },
    );

    testWidgets('mobile viewport: All orders chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpAllOrdersTab(
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
      expect(find.textContaining('All orders'), findsWidgets);
      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
    });

    testWidgets('desktop viewport: All orders chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpAllOrdersTab(
        tester,
        repository: repository,
        viewport: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<RadiologyOrder>), findsOneWidget);
      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byTooltip('Configurations'), findsOneWidget);
    });

    testWidgets('dark theme: All orders write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpAllOrdersTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byTooltip('Configurations'), findsOneWidget);
      expect(find.textContaining('All orders'), findsWidgets);
    });

    testWidgets('light theme: All orders write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpAllOrdersTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.light,
      );

      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byType(AppListTable<RadiologyOrder>), findsOneWidget);
    });
  });

  group('All orders authorization helpers (AC4)', () {
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
        radiologyAllowedSections(clinicalOnly),
        isNotEmpty,
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
      expect(canViewRadiologyAllOrdersTab(noModule), isFalse);
    });
  });
}
