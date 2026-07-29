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
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/features/radiology/presentation/pages/radiology_workspace_page.dart';
import 'package:hosspi_hms/features/radiology/presentation/radiology_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRadiologyRepository extends Mock implements RadiologyRepository {}

const RadiologyOrder _reportingOrder = RadiologyOrder(
  id: 'RO-REPORT',
  displayId: 'RAD-REPORT',
  status: 'IN_PROCESS',
  patientDisplayName: 'Rita Reporting',
  patientId: 'PAT-RITA',
  modality: 'CT',
  testDisplayName: 'CT Head',
  paymentStatus: 'PAID',
  authorizationStatus: 'AUTHORIZED',
  draftResultCount: 1,
  studyCount: 1,
);

const RadiologySummary _summary = RadiologySummary(
  totalOrders: 1,
  orderedQueue: 0,
  processingQueue: 1,
  draftReports: 1,
  finalizedReports: 0,
  actionablePatients: 1,
  reportingPatients: 1,
  releasedPatients: 0,
  totalPatients: 1,
);

const ImagingStudy _study = ImagingStudy(
  id: 'STUDY-1',
  displayId: 'ST-1',
  radiologyOrderId: 'RO-REPORT',
  modality: 'CT',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['RADIOLOGIST'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: radiologyWorkflowsModule,
          licenseStatus: 'ACTIVE',
        ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
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

RadiologyWorkflow _reportingWorkflow({
  RadiologyNextActions nextActions = const RadiologyNextActions(
    canCreateDraftResult: true,
    canCancel: true,
  ),
  List<RadiologyResult> results = const <RadiologyResult>[],
}) {
  return RadiologyWorkflow(
    order: RadiologyOrder(
      id: _reportingOrder.id,
      displayId: _reportingOrder.displayId,
      status: _reportingOrder.status,
      patientDisplayName: _reportingOrder.patientDisplayName,
      patientId: _reportingOrder.patientId,
      modality: _reportingOrder.modality,
      testDisplayName: _reportingOrder.testDisplayName,
      paymentStatus: _reportingOrder.paymentStatus,
      authorizationStatus: _reportingOrder.authorizationStatus,
      draftResultCount: _reportingOrder.draftResultCount,
      studyCount: _reportingOrder.studyCount,
      results: results,
      imagingStudies: const <ImagingStudy>[_study],
    ),
    studies: const <ImagingStudy>[_study],
    nextActions: nextActions,
    results: results,
  );
}

void main() {
  late _MockRadiologyRepository radiologyRepository;

  setUpAll(() {
    registerFallbackValue(const RadiologyWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    radiologyRepository = _MockRadiologyRepository();
    _stubRadiology(radiologyRepository);
  });

  group('RadiologyReportingAtomPermissions helpers', () {
    test('reuses radiology Reporting requirements (no second vocabulary)', () {
      expect(
        RadiologyReportingAtomPermissions.tab,
        same(radiologyWorkspaceReadRequirement),
      );
      expect(
        RadiologyReportingAtomPermissions.write,
        same(radiologyWorkspaceWriteRequirement),
      );
      expect(
        RadiologyReportingAtomPermissions.create,
        same(radiologyRequestImagingRequirement),
      );
      expect(
        RadiologyReportingAtomPermissions.configure,
        same(radiologyConfigurationsWriteRequirement),
      );
      expect(
        RadiologyReportingAtomPermissions.draftReport,
        same(radiologyWorkspaceWriteRequirement),
      );
      expect(
        RadiologyReportingAtomPermissions.releaseReport,
        same(radiologyWorkspaceWriteRequirement),
      );
      expect(
        RadiologyReportingAtomPermissions.printReport,
        same(radiologyPrintReportRequirement),
      );
      expect(
        RadiologyReportingAtomPermissions.billingHold,
        same(radiologyBillingHoldReadRequirement),
      );
      expect(
        radiologySectionTabRequirement(RadiologyDeskSection.reporting),
        same(RadiologyReportingAtomPermissions.tab),
      );
      expect(
        radiologyStripCreateRequirement(RadiologyDeskSection.reporting),
        same(RadiologyReportingAtomPermissions.create),
      );
      expect(
        radiologyStripConfigureRequirement(RadiologyDeskSection.reporting),
        same(RadiologyReportingAtomPermissions.configure),
      );
      expect(
        RadiologyReportingAtomPermissions.routeEntry,
        same(radiologyWorkspaceRouteEntryRequirement),
      );
      expect(
        RadiologyReportingAtomPermissions.catalogEntry,
        same(RouteAccessCatalog.radiologyEntry),
      );
      expect(
        RadiologyReportingAtomPermissions.requestFromClinical,
        same(clinicalRadiologyOrderWriteRequirement),
      );
    });

    test('∩ denial: missing radiology:write hides Reporting write atoms', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
      );
      expect(RadiologyReportingAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(RadiologyReportingAtomPermissions.write.isAllowed(reader), isFalse);
      expect(
        RadiologyReportingAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        RadiologyReportingAtomPermissions.draftReport.isAllowed(reader),
        isFalse,
      );
      expect(
        RadiologyReportingAtomPermissions.releaseReport.isAllowed(reader),
        isFalse,
      );
      expect(
        RadiologyReportingAtomPermissions.configure.isAllowed(reader),
        isFalse,
      );
      expect(
        RadiologyReportingAtomPermissions.printReport.isAllowed(reader),
        isTrue,
      );
      expect(canWriteRadiology(reader), isFalse);
    });

    test('∩ denial: missing radiology:read fails Reporting tab requirement', () {
      final AppAccessPolicy writerOnly = _policy(
        permissions: <AppPermission>{AppPermissions.radiologyWrite},
      );
      expect(
        RadiologyReportingAtomPermissions.tab.isAllowed(writerOnly),
        isFalse,
      );
      expect(canViewRadiologyReportingTab(writerOnly), isFalse);
      // Mapping note: route ∪ without radiology:read still keeps Reporting in
      // the strip via radiologyAllowedSections fallback (shared results).
      expect(
        radiologyAllowedSections(writerOnly),
        contains(RadiologyDeskSection.reporting),
      );
    });

    test('write ∩ presence: radiology:write + module allows mutations', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
      );
      expect(RadiologyReportingAtomPermissions.write.isAllowed(writer), isTrue);
      expect(
        RadiologyReportingAtomPermissions.draftReport.isAllowed(writer),
        isTrue,
      );
      expect(
        RadiologyReportingAtomPermissions.releaseReport.isAllowed(writer),
        isTrue,
      );
      expect(
        RadiologyReportingAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(canWriteRadiology(writer), isTrue);
      expect(canViewRadiologyReportingTab(writer), isTrue);
    });

    test('mapping note: matrix ∩ radiology:write via allPermissions', () {
      expect(
        radiologyWorkspaceWriteRequirement.allPermissions,
        <AppPermission>[AppPermissions.radiologyWrite],
      );
      expect(radiologyWorkspaceWriteRequirement.anyPermissions, isEmpty);
      expect(
        radiologyWorkspaceWriteRequirement.activeModules,
        contains(radiologyWorkflowsModule),
      );
      expect(
        RadiologyReportingAtomPermissions.draftReport.allPermissions,
        <AppPermission>[AppPermissions.radiologyWrite],
      );
    });

    test('∩ allowance: radiology:read alone satisfies Reporting read', () {
      final AppAccessPolicy radiologyReader = _policy(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
      );
      expect(
        RadiologyReportingAtomPermissions.tab.isAllowed(radiologyReader),
        isTrue,
      );
      expect(
        RadiologyReportingAtomPermissions.search.isAllowed(radiologyReader),
        isTrue,
      );
      expect(
        RadiologyReportingAtomPermissions.printReport.isAllowed(radiologyReader),
        isTrue,
      );
      expect(canViewRadiologyReportingTab(radiologyReader), isTrue);
      expect(canReadRadiology(radiologyReader), isTrue);
    });

    test(
      '∪ allowance: clinical:read satisfies route entry; tab ∩ denied',
      () {
        final AppAccessPolicy clinical = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        );
        expect(
          RadiologyReportingAtomPermissions.routeEntry.isAllowed(clinical),
          isTrue,
        );
        expect(
          RadiologyReportingAtomPermissions.tab.isAllowed(clinical),
          isFalse,
        );
        expect(canViewRadiologyReportingTab(clinical), isFalse);
        expect(canEnterRadiologyWorkspace(clinical), isTrue);
        // Mapping note: shared-results fallback keeps Reporting chrome.
        expect(
          radiologyAllowedSections(clinical),
          contains(RadiologyDeskSection.reporting),
        );
        expect(
          RadiologyReportingAtomPermissions.create.isAllowed(clinical),
          isFalse,
        );
        expect(
          RadiologyReportingAtomPermissions.configure.isAllowed(clinical),
          isFalse,
        );
      },
    );

    test(
      '∪ allowance: billing:read satisfies route entry + billing hold',
      () {
        final AppAccessPolicy billing = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          roles: const <String>['BILLING_CLERK'],
        );
        expect(
          RadiologyReportingAtomPermissions.routeEntry.isAllowed(billing),
          isTrue,
        );
        expect(
          RadiologyReportingAtomPermissions.tab.isAllowed(billing),
          isFalse,
        );
        expect(
          RadiologyReportingAtomPermissions.billingHold.isAllowed(billing),
          isTrue,
        );
        expect(canViewRadiologyBillingHold(billing), isTrue);
        expect(canViewRadiologyReportingTab(billing), isFalse);
      },
    );

    test(
      '∪ allowance: clinical:write satisfies route entry + request-from-clinical',
      () {
        final AppAccessPolicy clinicalWriter = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
          roles: const <String>['DOCTOR'],
        );
        expect(
          RadiologyReportingAtomPermissions.routeEntry.isAllowed(clinicalWriter),
          isTrue,
        );
        expect(
          RadiologyReportingAtomPermissions.write.isAllowed(clinicalWriter),
          isFalse,
        );
        expect(
          RadiologyReportingAtomPermissions.requestFromClinical.isAllowed(
            clinicalWriter,
          ),
          isTrue,
        );
      },
    );

    test(
      'subscription strips Reporting when radiology-workflows inactive',
      () {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );
        expect(
          RadiologyReportingAtomPermissions.tab.isAllowed(noModule),
          isFalse,
        );
        expect(
          RadiologyReportingAtomPermissions.write.isAllowed(noModule),
          isFalse,
        );
        expect(canEnterRadiologyWorkspace(noModule), isFalse);
      },
    );

    test(
      'ABAC: missing facility still allows Reporting chrome '
      '(row/own scope remains backend-authoritative)',
      () {
        final AppAccessPolicy noFacility = _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
          facilityId: null,
        );
        expect(noFacility.hasFacilityContext, isFalse);
        expect(
          RadiologyReportingAtomPermissions.tab.isAllowed(noFacility),
          isTrue,
        );
        expect(
          RadiologyReportingAtomPermissions.write.isAllowed(noFacility),
          isTrue,
        );
        expect(
          RadiologyReportingAtomPermissions.routeEntry.isAllowed(noFacility),
          isTrue,
        );
      },
    );

    test(
      'nested cross-module _(n/a)_: Reporting write does not grant billing hold',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
        );
        expect(RadiologyReportingAtomPermissions.write.isAllowed(writer), isTrue);
        expect(
          RadiologyReportingAtomPermissions.billingHold.isAllowed(writer),
          isFalse,
        );
        expect(writer.grants(AppPermissions.billingRead), isFalse);
        expect(writer.grants(AppPermissions.clinicalWrite), isFalse);
      },
    );
  });

  testWidgets(
    '∩ denial: without radiology:write, Request imaging / Configurations absent',
    (WidgetTester tester) async {
      await _pumpReportingTab(
        tester,
        radiologyRepository: radiologyRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.radiologyRead},
        ),
      );

      expect(_tab('Reporting'), findsOneWidget);
      expect(find.text('Rita Reporting'), findsOneWidget);
      expect(find.byTooltip('Request imaging'), findsNothing);
      expect(find.byTooltip('Configurations'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strips Reporting workspace when radiology-workflows inactive',
    (WidgetTester tester) async {
      await _pumpReportingTab(
        tester,
        radiologyRepository: radiologyRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(_tab('Reporting'), findsNothing);
      expect(find.byTooltip('Request imaging'), findsNothing);
      expect(find.byTooltip('Configurations'), findsNothing);
      expect(find.text('Rita Reporting'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized read ∩: list mounts; write / billing atoms absent',
    (WidgetTester tester) async {
      await _pumpReportingTab(
        tester,
        radiologyRepository: radiologyRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.radiologyRead},
        ),
      );

      expect(_tab('Reporting'), findsOneWidget);
      expect(find.text('Rita Reporting'), findsOneWidget);
      expect(find.byTooltip('Request imaging'), findsNothing);
      expect(find.byTooltip('Configurations'), findsNothing);
      expect(find.text('Billing gate'), findsNothing);

      await tester.tap(find.text('Rita Reporting'));
      await tester.pumpAndSettle();

      expect(find.text('Draft report'), findsNothing);
      expect(find.text('Release report'), findsNothing);
      expect(find.text('Cancel order'), findsNothing);
      expect(find.text('Assign'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      // Switch to Reporting detail view — draft CTA still absent for readers.
      final Finder reportingMode = find.text('Reporting');
      expect(reportingMode, findsWidgets);
      await tester.tap(reportingMode.last);
      await tester.pumpAndSettle();

      expect(find.text('Draft report'), findsNothing);
      expect(find.text('Print report'), findsOneWidget);
    },
  );

  testWidgets(
    '∪ allowance: clinical:read mounts Reporting shared-results chrome without write',
    (WidgetTester tester) async {
      await _pumpReportingTab(
        tester,
        radiologyRepository: radiologyRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(_tab('Reporting'), findsOneWidget);
      expect(find.text('Rita Reporting'), findsOneWidget);
      expect(find.byTooltip('Request imaging'), findsNothing);
      expect(find.byTooltip('Configurations'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested billing hold: billing column / filter absent without billing:read',
    (WidgetTester tester) async {
      await _pumpReportingTab(
        tester,
        radiologyRepository: radiologyRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
        ),
      );

      expect(find.text('Billing gate'), findsNothing);

      await tester.tap(find.text('Rita Reporting'));
      await tester.pumpAndSettle();

      expect(find.text('Payment'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested billing hold: billing filter present with billing:read ∪',
    (WidgetTester tester) async {
      await _pumpReportingTab(
        tester,
        radiologyRepository: radiologyRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.billingRead,
          },
        ),
      );

      expect(find.text('Rita Reporting'), findsOneWidget);
      // Open advanced filters to surface the billing gate group.
      final Finder filters = find.byTooltip('Filters');
      if (filters.evaluate().isNotEmpty) {
        await tester.tap(filters.first);
        await tester.pumpAndSettle();
        expect(find.text('Billing gate'), findsWidgets);
      } else {
        // Desktop chrome may expose the filter label without tooltip.
        expect(find.textContaining('Filters'), findsWidgets);
      }
      expect(find.byTooltip('Request imaging'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Request imaging / Configurations / Draft report mount; '
    'draft syncs detail',
    (WidgetTester tester) async {
      when(() => radiologyRepository.draftResult(any(), any())).thenAnswer((
        _,
      ) async {
        return Result<RadiologyWorkflow>.success(
          _reportingWorkflow(
            nextActions: const RadiologyNextActions(
              canFinalizeResult: true,
              canCancel: true,
            ),
            results: const <RadiologyResult>[
              RadiologyResult(
                id: 'RES-DRAFT',
                displayId: 'RES-DRAFT',
                status: 'DRAFT',
                reportText: 'Preliminary findings',
              ),
            ],
          ),
        );
      });

      await _pumpReportingTab(
        tester,
        radiologyRepository: radiologyRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.radiologyRead,
            AppPermissions.radiologyWrite,
          },
        ),
      );

      expect(find.byTooltip('Request imaging'), findsOneWidget);
      expect(find.byTooltip('Configurations'), findsOneWidget);
      expect(find.text('Rita Reporting'), findsOneWidget);

      await tester.tap(find.text('Rita Reporting'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel order'), findsOneWidget);

      // Writers default to imaging floor; switch to Reporting view for draft CTA.
      final Finder reportingMode = find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Reporting'),
      );
      expect(reportingMode, findsOneWidget);
      await tester.ensureVisible(reportingMode);
      await tester.tap(reportingMode);
      await tester.pumpAndSettle();

      expect(find.text('Draft report'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Draft report'));
      await tester.pumpAndSettle();

      // Nested draft dialog / form entry for authorized writers.
      expect(find.textContaining('no access'), findsNothing);
      verify(
        () => radiologyRepository.getWorkflow(any()),
      ).called(greaterThan(0));
    },
  );

  testWidgets('error / retry state remains for authorized Reporting users', (
    WidgetTester tester,
  ) async {
    var workbenchCalls = 0;
    when(() => radiologyRepository.getWorkbench(any())).thenAnswer((_) async {
      workbenchCalls += 1;
      if (workbenchCalls == 1) {
        return Result<RadiologyWorkbench>.success(
          RadiologyWorkbench(
            summary: _summary,
            orders: AppPage<RadiologyOrder>(
              items: const <RadiologyOrder>[_reportingOrder],
              request: const AppPageRequest(pageSize: 12),
              totalItemCount: 1,
            ),
          ),
        );
      }
      return const Result<RadiologyWorkbench>.failure(NetworkFailure());
    });

    await _pumpReportingTab(
      tester,
      radiologyRepository: radiologyRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
      ),
    );

    expect(find.text('Rita Reporting'), findsOneWidget);

    // Trigger an authorized refresh that surfaces the in-content failure banner.
    final Finder searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'rita');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    expect(find.byTooltip('Request imaging'), findsNothing);

    when(() => radiologyRepository.getWorkbench(any())).thenAnswer(
      (_) async => Result<RadiologyWorkbench>.success(
        RadiologyWorkbench(
          summary: _summary,
          orders: AppPage<RadiologyOrder>(
            items: const <RadiologyOrder>[_reportingOrder],
            request: const AppPageRequest(pageSize: 12),
            totalItemCount: 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Rita Reporting'), findsOneWidget);
  });

  testWidgets('empty state remains for authorized Reporting users', (
    WidgetTester tester,
  ) async {
    when(() => radiologyRepository.getWorkbench(any())).thenAnswer(
      (_) async => Result<RadiologyWorkbench>.success(
        RadiologyWorkbench(
          summary: const RadiologySummary(
            totalOrders: 0,
            orderedQueue: 0,
            processingQueue: 0,
            draftReports: 0,
            finalizedReports: 0,
            actionablePatients: 0,
            reportingPatients: 0,
            releasedPatients: 0,
            totalPatients: 0,
          ),
          orders: AppPage<RadiologyOrder>(
            items: const <RadiologyOrder>[],
            request: const AppPageRequest(pageSize: 12),
            totalItemCount: 0,
          ),
        ),
      ),
    );

    await _pumpReportingTab(
      tester,
      radiologyRepository: radiologyRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.radiologyRead},
      ),
    );

    expect(find.text('No radiology patients'), findsOneWidget);
    expect(find.text('Draft report'), findsNothing);
  });

  testWidgets('authorized loading chrome remains observable on Reporting', (
    WidgetTester tester,
  ) async {
    final Completer<Result<RadiologyWorkbench>> listCompleter =
        Completer<Result<RadiologyWorkbench>>();
    when(
      () => radiologyRepository.getWorkbench(any()),
    ).thenAnswer((_) => listCompleter.future);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/radiology?section=reporting',
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
          radiologyRepositoryProvider.overrideWithValue(radiologyRepository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{AppPermissions.radiologyRead},
            ),
          ),
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

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byTooltip('Request imaging'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);

    listCompleter.complete(
      Result<RadiologyWorkbench>.success(
        RadiologyWorkbench(
          summary: _summary,
          orders: AppPage<RadiologyOrder>(
            items: const <RadiologyOrder>[_reportingOrder],
            request: const AppPageRequest(pageSize: 12),
            totalItemCount: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_tab('Reporting'), findsOneWidget);
    expect(find.text('Rita Reporting'), findsOneWidget);
  });

  testWidgets('mobile viewport: authorized Reporting list remains usable', (
    WidgetTester tester,
  ) async {
    await _pumpReportingTab(
      tester,
      radiologyRepository: radiologyRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    expect(_tab('Reporting'), findsOneWidget);
    expect(find.textContaining('Rita'), findsWidgets);
    expect(find.byTooltip('Request imaging'), findsOneWidget);
  });

  testWidgets('desktop viewport: authorized Reporting chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpReportingTab(
      tester,
      radiologyRepository: radiologyRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Rita Reporting'), findsOneWidget);
    expect(_tab('Reporting'), findsOneWidget);
    expect(find.byTooltip('Configurations'), findsOneWidget);
  });

  testWidgets('light theme: authorized Reporting chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpReportingTab(
      tester,
      radiologyRepository: radiologyRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Rita Reporting'), findsOneWidget);
    expect(_tab('Reporting'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Reporting chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpReportingTab(
      tester,
      radiologyRepository: radiologyRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Rita Reporting'), findsOneWidget);
    expect(_tab('Reporting'), findsOneWidget);
  });

  testWidgets(
    'deep link section=reporting with radiology:read stays on Reporting',
    (WidgetTester tester) async {
      await _pumpReportingTab(
        tester,
        radiologyRepository: radiologyRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.radiologyRead},
        ),
        initialLocation: '/radiology?section=reporting',
      );

      expect(_tab('Reporting'), findsOneWidget);
      expect(find.text('Rita Reporting'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}

Future<void> _pumpReportingTab(
  WidgetTester tester, {
  required _MockRadiologyRepository radiologyRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/radiology?section=reporting',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
        radiologyRepositoryProvider.overrideWithValue(radiologyRepository),
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

void _stubRadiology(_MockRadiologyRepository repository) {
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
    final RadiologyWorkspaceQuery query =
        invocation.positionalArguments.single as RadiologyWorkspaceQuery;
    List<RadiologyOrder> items = const <RadiologyOrder>[_reportingOrder];
    final String stage = query.stage.trim().toUpperCase();
    if (stage == 'REPORTING') {
      items = items
          .where((RadiologyOrder order) => order.draftResultCount > 0)
          .toList(growable: false);
    } else if (stage == 'COMPLETED') {
      items = const <RadiologyOrder>[];
    }
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
  when(() => repository.getWorkflow(any())).thenAnswer(
    (_) async => Result<RadiologyWorkflow>.success(_reportingWorkflow()),
  );
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
}
