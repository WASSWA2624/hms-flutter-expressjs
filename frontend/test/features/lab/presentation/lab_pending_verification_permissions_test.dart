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

const LabOrderItem _pendingItem = LabOrderItem(
  id: 'LAB-ITEM-PV-1',
  labOrderId: 'LAB-ORDER-PV-1',
  testDisplayName: 'Glucose',
  resultKind: 'TEXT',
  resultText: '5.4 mmol/L',
  resultId: 'RES-PV-1',
  status: 'IN_PROCESS',
);

const LabOrderSummary _pendingOrder = LabOrderSummary(
  id: 'LAB-ORDER-PV-1',
  displayId: 'LO-PV-1',
  status: 'IN_PROCESS',
  patientDisplayName: 'Vera Pending',
  patientId: 'PAT-PV-1',
  paymentStatus: 'PAID',
  items: <LabOrderItem>[_pendingItem],
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
  List<LabOrderSummary> items = const <LabOrderSummary>[_pendingOrder],
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
          resultsQueue: scoped.length,
          totalPatients: items.length,
          resultsPatients: scoped.length,
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
        order: _pendingOrder,
        nextActions: LabWorkflowNextActions(
          canVerifyResult: true,
          canVerifyAll: true,
        ),
      ),
    );
  });
  when(() => repository.verifyOrderItem(any(), any())).thenAnswer((_) async {
    return const Result<LabOrderWorkflow>.success(
      LabOrderWorkflow(
        order: _pendingOrder,
        nextActions: LabWorkflowNextActions(),
      ),
    );
  });
}

Future<GoRouter> _pumpPendingVerificationTab(
  WidgetTester tester, {
  required _MockLabRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/lab?section=pending-verification',
  List<LabOrderSummary> items = const <LabOrderSummary>[_pendingOrder],
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

  group('LabPendingVerificationAtomPermissions inventory (AC1)', () {
    test('maps atoms to matrix ∩ / ∪ helpers', () {
      expect(
        identical(
          LabPendingVerificationAtomPermissions.tab,
          labWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabPendingVerificationAtomPermissions.create,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabPendingVerificationAtomPermissions.update,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabPendingVerificationAtomPermissions.delete,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabPendingVerificationAtomPermissions.verify,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabPendingVerificationAtomPermissions.previewReport,
          labReportPreviewRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabPendingVerificationAtomPermissions.criticalNotify,
          labCriticalNotifyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabPendingVerificationAtomPermissions.requestFromClinical,
          clinicalLabOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabPendingVerificationAtomPermissions.routeEntry,
          labWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          labSectionTabRequirement(LabDeskSection.verification),
          LabPendingVerificationAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripCreateRequirement(LabDeskSection.verification),
          LabPendingVerificationAtomPermissions.create,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripConfigureRequirement(LabDeskSection.verification),
          LabPendingVerificationAtomPermissions.configure,
        ),
        isTrue,
      );
    });
  });

  group('Pending verification tab UI authorization (AC2-AC5)', () {
    testWidgets(
      'deep link section=pending-verification selects results scope',
      (WidgetTester tester) async {
        final GoRouter router = await _pumpPendingVerificationTab(
          tester,
          repository: repository,
        );

        expect(
          router.state.uri.queryParameters['section'],
          'pending-verification',
        );
        final List<LabWorkbenchQuery> queries = verify(
          () => repository.loadWorkbench(captureAny()),
        ).captured.cast<LabWorkbenchQuery>();
        expect(
          queries.any(
            (LabWorkbenchQuery q) => q.scope == LabQueueScope.results,
          ),
          isTrue,
        );
        expect(find.textContaining('Pending verification'), findsWidgets);
        expect(_table(tester).columnVisibilityStorageKey, 'lab_verification');
        expect(_pendingOrder.verifiableItemCount, greaterThan(0));
      },
    );

    testWidgets(
      'intersection denial: lab:read alone omits create/config/write detail',
      (WidgetTester tester) async {
        await _pumpPendingVerificationTab(
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
        await tester.tap(find.text(l10n.labNextActionVerify).first);
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
        await _pumpPendingVerificationTab(
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
      'full intersection set mounts create, config, and verify chrome',
      (WidgetTester tester) async {
        await _pumpPendingVerificationTab(tester, repository: repository);

        expect(find.byTooltip('Create Lab Order'), findsOneWidget);
        expect(find.byTooltip('Lab Configurations'), findsOneWidget);
        expect(find.byTooltip('Orders view'), findsOneWidget);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await tester.tap(find.text(l10n.labNextActionVerify).first);
        await tester.pumpAndSettle();

        expect(find.text(l10n.labEditOrderAction), findsOneWidget);
        expect(find.text(l10n.labDeleteOrderAction), findsOneWidget);
        expect(find.text(l10n.labWorkflowNextVerifyResults), findsOneWidget);
        expect(find.text(l10n.labPreviewReportAction), findsOneWidget);
      },
    );

    testWidgets(
      'union route entry: clinical:read sees pending chrome without create',
      (WidgetTester tester) async {
        await _pumpPendingVerificationTab(
          tester,
          repository: repository,
          policy: _clinicalReaderPolicy(),
        );

        expect(find.byType(AppTabStrip), findsOneWidget);
        expect(find.textContaining('Pending verification'), findsWidgets);
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
          LabPendingVerificationAtomPermissions.previewReport.isAllowed(
            _labReadPolicy(),
          ),
          isTrue,
        );
        expect(
          LabPendingVerificationAtomPermissions.previewReport.isAllowed(
            _policyFor(permissions: <AppPermission>{AppPermissions.labWrite}),
          ),
          isTrue,
        );
        expect(
          LabPendingVerificationAtomPermissions.previewReport.isAllowed(
            _clinicalReaderPolicy(),
          ),
          isFalse,
        );

        await _pumpPendingVerificationTab(
          tester,
          repository: repository,
          policy: _labReadPolicy(),
        );

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await tester.tap(find.text(l10n.labNextActionVerify).first);
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
          LabPendingVerificationAtomPermissions.requestFromClinical.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          LabPendingVerificationAtomPermissions.create.isAllowed(
            clinicalWriter,
          ),
          isFalse,
        );

        await _pumpPendingVerificationTab(
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
          LabPendingVerificationAtomPermissions.criticalNotify.isAllowed(
            _labWritePolicy(),
          ),
          isFalse,
        );
        expect(
          LabPendingVerificationAtomPermissions.verify.isAllowed(
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
          LabPendingVerificationAtomPermissions.criticalNotify.isAllowed(
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
      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        items: const <LabOrderSummary>[],
      );

      expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byTooltip('Orders view'), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        workbenchOverride: Result<LabWorkbenchBundle>.failure(
          const AppFailure.network(),
        ),
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('post-mutation sync: verify reloads order workflow', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(tester, repository: repository);

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      await tester.tap(find.text(l10n.labNextActionVerify).first);
      await tester.pumpAndSettle();

      clearInteractions(repository);
      _stubWorkspace(repository);

      final Finder verifyFinder = find.text(l10n.labWorkflowNextVerifyResults);
      expect(verifyFinder, findsWidgets);
      await tester.tap(verifyFinder.first);
      await tester.pumpAndSettle();

      verify(() => repository.verifyOrderItem(any(), any())).called(
        greaterThan(0),
      );
      verify(() => repository.loadOrderWorkflow(any())).called(greaterThan(0));
    });

    testWidgets('mobile viewport: pending-verification chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(
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
      expect(find.textContaining('Pending verification'), findsWidgets);
      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
    });

    testWidgets('desktop viewport: pending-verification chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        viewport: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    });

    testWidgets('dark theme: pending-verification write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byTooltip('Lab Configurations'), findsOneWidget);
      expect(find.textContaining('Pending verification'), findsWidgets);
    });

    testWidgets('light theme: pending-verification write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpPendingVerificationTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.light,
      );

      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
    });

    testWidgets(
      'legacy section=verification alias still opens pending tab',
      (WidgetTester tester) async {
        await _pumpPendingVerificationTab(
          tester,
          repository: repository,
          initialLocation: '/lab?section=verification',
        );

        final List<LabWorkbenchQuery> queries = verify(
          () => repository.loadWorkbench(captureAny()),
        ).captured.cast<LabWorkbenchQuery>();
        expect(
          queries.any(
            (LabWorkbenchQuery q) => q.scope == LabQueueScope.results,
          ),
          isTrue,
        );
        expect(find.textContaining('Pending verification'), findsWidgets);
      },
    );
  });
}
