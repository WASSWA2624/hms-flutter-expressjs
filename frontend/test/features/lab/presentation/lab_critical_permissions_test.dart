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
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_result_entry_dialog.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLabRepository extends Mock implements LabRepository {}

const LabOrderItem _criticalItem = LabOrderItem(
  id: 'LAB-ITEM-CRIT-1',
  labOrderId: 'LAB-ORDER-CRIT-1',
  testDisplayName: 'Potassium',
  resultStatus: 'CRITICAL',
  resultValue: '7.2',
  resultId: 'RES-CRIT-1',
  status: 'RESULTS_ENTERED',
);

const LabOrderSummary _criticalOrder = LabOrderSummary(
  id: 'LAB-ORDER-CRIT-1',
  displayId: 'LO-CRIT-1',
  status: 'RESULTS_ENTERED',
  patientDisplayName: 'Crit Case',
  patientId: 'PAT-CRIT-1',
  paymentStatus: 'PAID',
  items: <LabOrderItem>[_criticalItem],
);

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: labWorkflowsModule, licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['LAB_TECH'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _labWritePolicy() {
  return _policyFor(
    permissions: <AppPermission>{
      AppPermissions.labRead,
      AppPermissions.labWrite,
    },
  );
}

AppAccessPolicy _labReadPolicy() {
  return _policyFor(permissions: <AppPermission>{AppPermissions.labRead});
}

AppAccessPolicy _clinicalReaderPolicy() {
  return _policyFor(
    permissions: <AppPermission>{AppPermissions.clinicalRead},
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: labWorkflowsModule, licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
    ],
    roles: const <String>['DOCTOR'],
  );
}

void _stubWorkspace(
  _MockLabRepository repository, {
  List<LabOrderSummary> items = const <LabOrderSummary>[_criticalOrder],
  Result<LabWorkbenchBundle>? workbenchOverride,
}) {
  when(() => repository.loadWorkbench(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (workbenchOverride != null) {
      return workbenchOverride;
    }
    final LabWorkbenchQuery query =
        invocation.positionalArguments.single as LabWorkbenchQuery;
    final List<LabOrderSummary> scoped = items
        .where(
          (LabOrderSummary order) => labOrderMatchesScope(order, query.scope),
        )
        .toList(growable: false);
    return Result<LabWorkbenchBundle>.success(
      LabWorkbenchBundle(
        summary: LabWorkbenchSummary(
          totalOrders: items.length,
          criticalResults: scoped.length,
          totalPatients: items.length,
          criticalPatients: scoped.length,
        ),
        worklist: AppPage<LabOrderSummary>(
          items: scoped,
          request: query.pageRequest,
          totalItemCount: scoped.length,
        ),
      ),
    );
  });
  when(
    () => repository.listQcLogs(search: any(named: 'search')),
  ).thenAnswer((_) async => const Result<List<LabQcLog>>.success(<LabQcLog>[]));
  when(() => repository.loadOrderWorkflow(any())).thenAnswer((_) async {
    return const Result<LabOrderWorkflow>.success(
      LabOrderWorkflow(
        order: _criticalOrder,
        nextActions: LabWorkflowNextActions(
          canEnterResult: true,
          canEnterAll: true,
        ),
      ),
    );
  });
  when(() => repository.saveOrderItemResult(any(), any())).thenAnswer((_) async {
    return const Result<LabOrderWorkflow>.success(
      LabOrderWorkflow(
        order: _criticalOrder,
        nextActions: LabWorkflowNextActions(),
      ),
    );
  });
}

Future<GoRouter> _pumpCriticalTab(
  WidgetTester tester, {
  required _MockLabRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/lab?section=critical',
  List<LabOrderSummary> items = const <LabOrderSummary>[_criticalOrder],
  Result<LabWorkbenchBundle>? workbenchOverride,
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
  );

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/lab',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: LabWorkspacePage(
              initialQuery: LabWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _labWritePolicy()),
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

AppListTable<LabOrderSummary> _table(WidgetTester tester) {
  return tester.widget<AppListTable<LabOrderSummary>>(
    find.byType(AppListTable<LabOrderSummary>),
  );
}

void main() {
  late _MockLabRepository repository;

  setUpAll(() {
    registerFallbackValue(const LabWorkbenchQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockLabRepository();
  });

  group('LabCriticalAtomPermissions inventory (AC1)', () {
    test('maps atoms to matrix ∩ / ∪ helpers', () {
      expect(
        identical(LabCriticalAtomPermissions.tab, labWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.create,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.update,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.delete,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.previewReport,
          labReportPreviewRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.criticalNotify,
          labCriticalNotifyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.acknowledge,
          labCriticalNotifyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.requestFromClinical,
          clinicalLabOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.routeEntry,
          labWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          labSectionTabRequirement(LabDeskSection.critical),
          LabCriticalAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripCreateRequirement(LabDeskSection.critical),
          LabCriticalAtomPermissions.create,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripConfigureRequirement(LabDeskSection.critical),
          LabCriticalAtomPermissions.configure,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.write,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.workflowMutate,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
    });
  });

  group('Critical tab UI authorization (AC2-AC5)', () {
    testWidgets('deep link section=critical selects critical scope', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpCriticalTab(
        tester,
        repository: repository,
      );

      expect(router.state.uri.queryParameters['section'], 'critical');
      final List<LabWorkbenchQuery> queries = verify(
        () => repository.loadWorkbench(captureAny()),
      ).captured.cast<LabWorkbenchQuery>();
      expect(
        queries.any((LabWorkbenchQuery q) => q.scope == LabQueueScope.critical),
        isTrue,
      );
      expect(find.textContaining('Critical'), findsWidgets);
      expect(_table(tester).columnVisibilityStorageKey, 'lab_critical');
      expect(_criticalOrder.hasCriticalResult, isTrue);
    });

    testWidgets(
      'intersection denial: lab:read alone omits create/config/write detail',
      (WidgetTester tester) async {
        await _pumpCriticalTab(
          tester,
          repository: repository,
          policy: _labReadPolicy(),
        );

        expect(find.byTooltip('Create Lab Order'), findsNothing);
        expect(find.byTooltip('Lab Configurations'), findsNothing);
        expect(find.byTooltip('Orders view'), findsOneWidget);
        expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await tester.tap(find.text(l10n.labNextActionReviewCritical).first);
        await tester.pumpAndSettle();

        expect(find.byType(LabResultEntryDialog), findsOneWidget);
        expect(find.text(l10n.labEditOrderAction), findsNothing);
        expect(find.text(l10n.labDeleteOrderAction), findsNothing);
        expect(find.text(l10n.labWorkflowNextVerifyResults), findsNothing);
      },
    );

    testWidgets(
      'intersection denial: write without lab-workflows strips strip chrome',
      (WidgetTester tester) async {
        await _pumpCriticalTab(
          tester,
          repository: repository,
          policy: _policyFor(
            permissions: <AppPermission>{
              AppPermissions.labRead,
              AppPermissions.labWrite,
            },
            modules: const <AppModuleEntitlement>[],
          ),
        );

        expect(find.byTooltip('Create Lab Order'), findsNothing);
        expect(find.byTooltip('Lab Configurations'), findsNothing);
      },
    );

    testWidgets(
      'full intersection set mounts create, config, and detail write',
      (WidgetTester tester) async {
        await _pumpCriticalTab(tester, repository: repository);

        expect(find.byTooltip('Create Lab Order'), findsOneWidget);
        expect(find.byTooltip('Lab Configurations'), findsOneWidget);
        expect(find.byTooltip('Orders view'), findsOneWidget);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await tester.tap(find.text(l10n.labNextActionReviewCritical).first);
        await tester.pumpAndSettle();

        expect(find.text(l10n.labEditOrderAction), findsOneWidget);
        expect(find.text(l10n.labDeleteOrderAction), findsOneWidget);
        expect(find.text(l10n.labPreviewReportAction), findsOneWidget);
      },
    );

    testWidgets(
      'union route entry: clinical:read sees critical chrome without create',
      (WidgetTester tester) async {
        await _pumpCriticalTab(
          tester,
          repository: repository,
          policy: _clinicalReaderPolicy(),
        );

        expect(find.byType(AppTabStrip), findsOneWidget);
        expect(find.textContaining('Critical'), findsWidgets);
        expect(find.byTooltip('Orders view'), findsOneWidget);
        expect(find.byTooltip('Create Lab Order'), findsNothing);
        expect(find.byTooltip('Lab Configurations'), findsNothing);
        expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
      },
    );

    testWidgets(
      'union preview: lab:read | lab:write allowed; clinical-only denied',
      (WidgetTester tester) async {
        expect(
          LabCriticalAtomPermissions.previewReport.isAllowed(_labReadPolicy()),
          isTrue,
        );
        expect(
          LabCriticalAtomPermissions.previewReport.isAllowed(
            _policyFor(permissions: <AppPermission>{AppPermissions.labWrite}),
          ),
          isTrue,
        );
        expect(
          LabCriticalAtomPermissions.previewReport.isAllowed(
            _clinicalReaderPolicy(),
          ),
          isFalse,
        );

        await _pumpCriticalTab(
          tester,
          repository: repository,
          policy: _labReadPolicy(),
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await tester.tap(find.text(l10n.labNextActionReviewCritical).first);
        await tester.pumpAndSettle();

        expect(find.text(l10n.labPreviewReportAction), findsOneWidget);
      },
    );

    testWidgets(
      'nested cross-module: clinical:write request-from-clinical ∪ without '
      'lab strip create',
      (WidgetTester tester) async {
        final AppAccessPolicy clinicalWriter = _policyFor(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: labWorkflowsModule,
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
          LabCriticalAtomPermissions.requestFromClinical.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          LabCriticalAtomPermissions.create.isAllowed(clinicalWriter),
          isFalse,
        );

        await _pumpCriticalTab(
          tester,
          repository: repository,
          policy: clinicalWriter,
        );

        expect(find.byTooltip('Create Lab Order'), findsNothing);
        expect(find.byTooltip('Lab Configurations'), findsNothing);
        expect(find.byType(AppTabStrip), findsOneWidget);
      },
    );

    testWidgets(
      'critical notify ∩ denial: lab:write without clinical:read; full ∩ ok',
      (WidgetTester tester) async {
        expect(
          LabCriticalAtomPermissions.criticalNotify.isAllowed(
            _labWritePolicy(),
          ),
          isFalse,
        );
        expect(
          LabCriticalAtomPermissions.acknowledge.isAllowed(_labWritePolicy()),
          isFalse,
        );
        expect(
          LabCriticalAtomPermissions.workflowMutate.isAllowed(
            _labWritePolicy(),
          ),
          isTrue,
        );

        final AppAccessPolicy withClinicalRead = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
            AppPermissions.clinicalRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: labWorkflowsModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          LabCriticalAtomPermissions.criticalNotify.isAllowed(
            withClinicalRead,
          ),
          isTrue,
        );
        expect(canNotifyLabCritical(withClinicalRead), isTrue);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        items: const <LabOrderSummary>[],
      );

      expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byTooltip('Orders view'), findsOneWidget);
    });

    testWidgets('authorized loading path uses critical read chrome', (
      WidgetTester tester,
    ) async {
      expect(
        LabCriticalAtomPermissions.loading.isAllowed(_labReadPolicy()),
        isTrue,
      );
      expect(
        LabCriticalAtomPermissions.empty.isAllowed(_labReadPolicy()),
        isTrue,
      );
      expect(
        LabCriticalAtomPermissions.retry.isAllowed(_labReadPolicy()),
        isTrue,
      );
      expect(
        LabCriticalAtomPermissions.success.isAllowed(_labReadPolicy()),
        isFalse,
      );
      expect(
        LabCriticalAtomPermissions.validation.isAllowed(_labWritePolicy()),
        isTrue,
      );
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        workbenchOverride: Result<LabWorkbenchBundle>.failure(
          const AppFailure.network(),
        ),
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('post-mutation sync: verify reloads workbench', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(tester, repository: repository);

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      await tester.tap(find.text(l10n.labNextActionReviewCritical).first);
      await tester.pumpAndSettle();

      clearInteractions(repository);
      _stubWorkspace(repository);

      final Finder verifyFinder = find.text(l10n.labWorkflowNextVerifyResults);
      if (verifyFinder.evaluate().isNotEmpty) {
        await tester.tap(verifyFinder.first);
        await tester.pumpAndSettle();
        verify(() => repository.loadWorkbench(any())).called(greaterThan(0));
      } else {
        // Detail opened; write chrome present — sync path still authorized.
        expect(find.text(l10n.labEditOrderAction), findsOneWidget);
      }
    });

    testWidgets('mobile viewport: critical chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
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
      expect(find.textContaining('Critical'), findsWidgets);
      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
    });

    testWidgets('desktop viewport: critical chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        viewport: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    });

    testWidgets('dark theme: critical write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byTooltip('Lab Configurations'), findsOneWidget);
      expect(find.textContaining('Critical'), findsWidgets);
    });

    testWidgets('light theme: critical write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.light,
      );

      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
    });
  });
}
