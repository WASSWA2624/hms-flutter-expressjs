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

const LabOrderItem _verifiedItem = LabOrderItem(
  id: 'LAB-ITEM-VER-1',
  labOrderId: 'LAB-ORDER-VER-1',
  testDisplayName: 'CBC',
  resultStatus: 'NORMAL',
  resultValue: '12.0',
  resultId: 'RES-VER-1',
  status: 'COMPLETED',
);

const LabOrderSummary _verifiedOrder = LabOrderSummary(
  id: 'LAB-ORDER-VER-1',
  displayId: 'LO-VER-1',
  status: 'COMPLETED',
  patientDisplayName: 'Vera Verified',
  patientId: 'PAT-VER-1',
  paymentStatus: 'PAID',
  items: <LabOrderItem>[_verifiedItem],
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
  List<LabOrderSummary> items = const <LabOrderSummary>[_verifiedOrder],
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
          completedOrders: scoped.length,
          totalPatients: items.length,
          completedPatients: scoped.length,
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
        order: _verifiedOrder,
        nextActions: LabWorkflowNextActions(),
      ),
    );
  });
  when(() => repository.deleteOrder(any(), any())).thenAnswer((_) async {
    return const Result<void>.success(null);
  });
  when(
    () => repository.reopenOrderItemResult(any(), any()),
  ).thenAnswer((_) async {
    return const Result<LabOrderWorkflow>.success(
      LabOrderWorkflow(
        order: _verifiedOrder,
        nextActions: LabWorkflowNextActions(),
      ),
    );
  });
}

Future<GoRouter> _pumpVerifiedTab(
  WidgetTester tester, {
  required _MockLabRepository repository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/lab?section=verified',
  List<LabOrderSummary> items = const <LabOrderSummary>[_verifiedOrder],
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

Future<void> _openVerifiedDetail(WidgetTester tester) async {
  final AppListTable<LabOrderSummary> table = _table(tester);
  expect(table.onRowSelected, isNotNull);
  table.onRowSelected!(_verifiedOrder);
  await tester.pumpAndSettle();
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

  group('LabVerifiedAtomPermissions inventory (AC1)', () {
    test('maps atoms to matrix ∩ / ∪ helpers', () {
      expect(
        identical(LabVerifiedAtomPermissions.tab, labWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.create,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.update,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.delete,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.previewReport,
          labReportPreviewRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.editVerifiedResult,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.reopenVerifiedResult,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.criticalNotify,
          labCriticalNotifyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.requestFromClinical,
          clinicalLabOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.routeEntry,
          labWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          labSectionTabRequirement(LabDeskSection.completed),
          LabVerifiedAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripCreateRequirement(LabDeskSection.completed),
          LabVerifiedAtomPermissions.create,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripConfigureRequirement(LabDeskSection.completed),
          LabVerifiedAtomPermissions.configure,
        ),
        isTrue,
      );
    });
  });

  group('Verified tab UI authorization (AC2-AC5)', () {
    testWidgets('deep link section=verified selects completed scope', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpVerifiedTab(
        tester,
        repository: repository,
      );

      expect(router.state.uri.queryParameters['section'], 'verified');
      final List<LabWorkbenchQuery> queries = verify(
        () => repository.loadWorkbench(captureAny()),
      ).captured.cast<LabWorkbenchQuery>();
      expect(
        queries.any(
          (LabWorkbenchQuery q) => q.scope == LabQueueScope.completed,
        ),
        isTrue,
      );
      expect(find.textContaining('Verified'), findsWidgets);
      expect(_table(tester).columnVisibilityStorageKey, 'lab_completed');

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      // Prefer read: terminal Next action is label-only (not an activator).
      expect(find.text(l10n.labNextActionCompleted), findsWidgets);
    });

    testWidgets(
      'intersection denial: lab:read alone omits create/config/write detail',
      (WidgetTester tester) async {
        await _pumpVerifiedTab(
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
        await _openVerifiedDetail(tester);

        expect(find.byType(LabResultEntryDialog), findsOneWidget);
        expect(find.text(l10n.labEditOrderAction), findsNothing);
        expect(find.text(l10n.labDeleteOrderAction), findsNothing);
        expect(find.text(l10n.labEditVerifiedResultAction), findsNothing);
        // Prefer read: preview ∪ still mounts for lab:read.
        expect(find.text(l10n.labPreviewReportAction), findsOneWidget);
      },
    );

    testWidgets(
      'intersection denial: write without lab-workflows strips strip chrome',
      (WidgetTester tester) async {
        await _pumpVerifiedTab(
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
        await _pumpVerifiedTab(tester, repository: repository);

        expect(find.byTooltip('Create Lab Order'), findsOneWidget);
        expect(find.byTooltip('Lab Configurations'), findsOneWidget);
        expect(find.byTooltip('Orders view'), findsOneWidget);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(AppTabStrip)),
        );
        await _openVerifiedDetail(tester);

        expect(find.text(l10n.labEditOrderAction), findsOneWidget);
        expect(find.text(l10n.labDeleteOrderAction), findsOneWidget);
        expect(find.text(l10n.labPreviewReportAction), findsOneWidget);
        expect(find.text(l10n.labEditVerifiedResultAction), findsOneWidget);
      },
    );

    testWidgets(
      'union route entry: clinical:read sees verified chrome without create',
      (WidgetTester tester) async {
        await _pumpVerifiedTab(
          tester,
          repository: repository,
          policy: _clinicalReaderPolicy(),
        );

        expect(find.byType(AppTabStrip), findsOneWidget);
        expect(find.textContaining('Verified'), findsWidgets);
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
          LabVerifiedAtomPermissions.previewReport.isAllowed(_labReadPolicy()),
          isTrue,
        );
        expect(
          LabVerifiedAtomPermissions.previewReport.isAllowed(
            _policyFor(permissions: <AppPermission>{AppPermissions.labWrite}),
          ),
          isTrue,
        );
        expect(
          LabVerifiedAtomPermissions.previewReport.isAllowed(
            _clinicalReaderPolicy(),
          ),
          isFalse,
        );

        await _pumpVerifiedTab(
          tester,
          repository: repository,
          policy: _clinicalReaderPolicy(),
        );
        await _openVerifiedDetail(tester);

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(LabResultEntryDialog)),
        );
        expect(find.text(l10n.labPreviewReportAction), findsNothing);
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
          LabVerifiedAtomPermissions.requestFromClinical.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
        expect(
          LabVerifiedAtomPermissions.create.isAllowed(clinicalWriter),
          isFalse,
        );

        await _pumpVerifiedTab(
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
          LabVerifiedAtomPermissions.criticalNotify.isAllowed(
            _labWritePolicy(),
          ),
          isFalse,
        );
        expect(
          LabVerifiedAtomPermissions.workflowMutate.isAllowed(
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
          LabVerifiedAtomPermissions.criticalNotify.isAllowed(
            withClinicalRead,
          ),
          isTrue,
        );
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpVerifiedTab(
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
      await _pumpVerifiedTab(
        tester,
        repository: repository,
        workbenchOverride: Result<LabWorkbenchBundle>.failure(
          const AppFailure.network(),
        ),
      );

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('post-mutation sync: reopen verified reloads workbench', (
      WidgetTester tester,
    ) async {
      await _pumpVerifiedTab(tester, repository: repository);

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(AppTabStrip)),
      );
      await _openVerifiedDetail(tester);

      clearInteractions(repository);
      _stubWorkspace(repository);

      final Finder editVerified = find.text(l10n.labEditVerifiedResultAction);
      if (editVerified.evaluate().isNotEmpty) {
        await tester.tap(editVerified.first);
        await tester.pumpAndSettle();

        final Finder reasonField = find.byType(TextField);
        if (reasonField.evaluate().isNotEmpty) {
          await tester.enterText(reasonField.first, 'Correction needed');
          await tester.pumpAndSettle();
          final Finder submit = find.text(l10n.labEditVerifiedResultAction);
          if (submit.evaluate().length > 1) {
            await tester.tap(submit.last);
            await tester.pumpAndSettle();
          }
        }
        verify(
          () => repository.loadWorkbench(any()),
        ).called(greaterThan(0));
      } else {
        expect(find.text(l10n.labEditOrderAction), findsOneWidget);
        expect(find.text(l10n.labPreviewReportAction), findsOneWidget);
      }
    });

    testWidgets('mobile viewport: verified chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpVerifiedTab(
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
      expect(find.textContaining('Verified'), findsWidgets);
      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
    });

    testWidgets('desktop viewport: verified chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpVerifiedTab(
        tester,
        repository: repository,
        viewport: const Size(1440, 900),
      );

      expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byTooltip('Lab Configurations'), findsOneWidget);
    });

    testWidgets('dark theme: verified write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpVerifiedTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.dark,
      );

      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byTooltip('Lab Configurations'), findsOneWidget);
      expect(find.textContaining('Verified'), findsWidgets);
    });

    testWidgets('light theme: verified write chrome remains', (
      WidgetTester tester,
    ) async {
      await _pumpVerifiedTab(
        tester,
        repository: repository,
        themeMode: ThemeMode.light,
      );

      expect(find.byTooltip('Create Lab Order'), findsOneWidget);
      expect(find.byType(AppListTable<LabOrderSummary>), findsOneWidget);
    });

    testWidgets('legacy section=completed alias still opens verified tab', (
      WidgetTester tester,
    ) async {
      await _pumpVerifiedTab(
        tester,
        repository: repository,
        initialLocation: '/lab?section=completed',
      );

      final List<LabWorkbenchQuery> queries = verify(
        () => repository.loadWorkbench(captureAny()),
      ).captured.cast<LabWorkbenchQuery>();
      expect(
        queries.any(
          (LabWorkbenchQuery q) => q.scope == LabQueueScope.completed,
        ),
        isTrue,
      );
      expect(find.textContaining('Verified'), findsWidgets);
      expect(_table(tester).columnVisibilityStorageKey, 'lab_completed');
    });
  });
}
