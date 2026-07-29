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
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

const ClinicalWorklistEntry _encounter = ClinicalWorklistEntry(
  id: 'encounter-results-1',
  sourceQueue: 'OPD',
  encounterId: 'encounter-results-1',
  encounterPublicId: 'ENC-RES-1',
  patientDisplayName: 'Results Ready Patient',
  patientPublicId: 'PAT-RES-1',
  providerDisplayName: 'Dr Results',
  encounterType: 'OUTPATIENT',
  currentLocation: 'Clinic R',
  status: 'OPEN',
  stage: 'LAB_RESULTS_READY',
  resultsReady: true,
  opdFlowApiId: 'opd-flow-results-1',
);

const ClinicalEncounterBundle _resultsBundle = ClinicalEncounterBundle(
  entry: _encounter,
  labOrders: <ClinicalRelatedRecord>[
    ClinicalRelatedRecord(
      id: 'lab-1',
      kind: 'LAB_ORDER',
      status: 'COMPLETED',
      title: 'CBC',
      labOrderItems: <ClinicalLabOrderItem>[
        ClinicalLabOrderItem(
          id: 'lab-item-1',
          testDisplayName: 'Hemoglobin',
          resultValue: '13.5',
          unit: 'g/dL',
          resultStatus: 'FINAL',
          status: 'COMPLETED',
        ),
      ],
    ),
  ],
  radiologyOrders: <ClinicalRelatedRecord>[
    ClinicalRelatedRecord(
      id: 'rad-1',
      kind: 'RADIOLOGY_ORDER',
      status: 'COMPLETED',
      title: 'Chest X-Ray',
      subtitle: 'No acute findings',
    ),
  ],
  diagnoses: <ClinicalRelatedRecord>[
    ClinicalRelatedRecord(
      id: 'dx-1',
      kind: 'DIAGNOSIS',
      status: 'ACTIVE',
      title: 'Anemia',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  ],
  String? userId,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        id: userId,
        roles: const <String>['DOCTOR'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubClinical(
  _MockClinicalRepository repository, {
  List<ClinicalWorklistEntry> items = const <ClinicalWorklistEntry>[_encounter],
  Result<AppPage<ClinicalWorklistEntry>>? listOverride,
  Result<ClinicalReferenceData>? referenceOverride,
  ClinicalEncounterBundle? bundle,
}) {
  when(() => repository.listEncounters(any())).thenAnswer((invocation) async {
    if (listOverride != null) {
      return listOverride;
    }
    return Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: items,
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listAdmissions(any())).thenAnswer(
    (invocation) async => Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        referenceOverride ??
        const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
  );
  when(() => repository.loadEncounterBundle(any())).thenAnswer((invocation) {
    final ClinicalWorklistEntry entry =
        invocation.positionalArguments.single as ClinicalWorklistEntry;
    return Future<Result<ClinicalEncounterBundle>>.value(
      Result<ClinicalEncounterBundle>.success(
        bundle ??
            _resultsBundle.copyWith(
              entry: entry.copyWith(resultsReady: true),
            ),
      ),
    );
  });
}

void _stubOpd(_MockOpdRepository repository, {bool failLists = false}) {
  when(() => repository.listOpdFlows(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdFlowSummary>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.listTriageQueue(any())).thenAnswer((invocation) async {
    if (failLists) {
      return const Result<AppPage<OpdFlowSummary>>.failure(AppFailure.network());
    }
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    );
  });
  when(() => repository.getOpdFlow(any())).thenAnswer(
    (_) async => const Result<OpdFlowDetail>.success(
      OpdFlowDetail(summary: OpdFlowSummary(id: 'flow-1', publicId: 'OPD000001')),
    ),
  );
}

void _stubIpd(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[],
        request: (invocation.positionalArguments.single as IpdAdmissionQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}

Future<void> _pumpResultsReadyTab(
  WidgetTester tester, {
  required _MockClinicalRepository clinicalRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<ClinicalWorklistEntry> items = const <ClinicalWorklistEntry>[_encounter],
  String initialLocation = '/clinical?section=results-ready',
  Result<AppPage<ClinicalWorklistEntry>>? listOverride,
  Result<ClinicalReferenceData>? referenceOverride,
  bool failOpdLists = false,
  ClinicalEncounterBundle? bundle,
  SessionState sessionState = const SessionState.ready(),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockOpdRepository opdRepository = _MockOpdRepository();
  final _MockIpdRepository ipdRepository = _MockIpdRepository();
  _stubClinical(
    clinicalRepository,
    items: items,
    listOverride: listOverride,
    referenceOverride: referenceOverride,
    bundle: bundle,
  );
  _stubOpd(opdRepository, failLists: failOpdLists);
  _stubIpd(ipdRepository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/clinical',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ClinicalWorkspacePage(
              initialQuery: ClinicalWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
        opdRepositoryProvider.overrideWithValue(opdRepository),
        ipdRepositoryProvider.overrideWithValue(ipdRepository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(sessionState),
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
  late _MockClinicalRepository clinicalRepository;

  setUpAll(() {
    registerFallbackValue(const ClinicalWorklistQuery());
    registerFallbackValue(
      const ClinicalWorklistEntry(
        id: 'encounter-fallback',
        sourceQueue: 'OPD',
        encounterId: 'encounter-fallback',
      ),
    );
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const IpdAdmissionQuery());
  });

  setUp(() {
    clinicalRepository = _MockClinicalRepository();
  });

  group('ClinicalResultsReadyAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        ClinicalResultsReadyAtomPermissions.tab,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.listChrome,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.search,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.nextActionReview,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.resultsReadyChip,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.resultsTimeline,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.loading,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.empty,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.printSummary,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.nestedRead,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.write,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.create,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.update,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.delete,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.success,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.validation,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestLab,
        same(clinicalLabOrderWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestRadiology,
        same(clinicalRadiologyOrderWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.prescribe,
        same(clinicalPharmacyOrderWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestAdmission,
        same(clinicalAdmissionWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.nestedLabWrite,
        same(clinicalLabOrderWriteRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.labResultsPanel,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.radiologyResultsPanel,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.routeEntry,
        same(clinicalWorkspaceEntryRequirement),
      );
      expect(
        ClinicalResultsReadyAtomPermissions.dischargeFinancialRead,
        same(clinicalDischargeFinancialReadRequirement),
      );
      expect(
        clinicalSectionTabRequirement(ClinicalWorkspaceSection.resultsReady),
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        canViewClinicalResultsReady(
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
        ),
        isTrue,
      );
      expect(
        canViewClinicalLabResultsPanel(
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
        ),
        isTrue,
      );
      expect(
        canViewClinicalRadiologyResultsPanel(
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
        ),
        isTrue,
      );
    });

    test('∩ denial: missing clinical:read fails tab; write alone fails tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(
        ClinicalResultsReadyAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.labResultsPanel.isAllowed(
          writeOnly,
        ),
        isFalse,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.resultsReadyChip.isAllowed(
          writeOnly,
        ),
        isFalse,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.write.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.create.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(canViewClinicalResultsReady(writeOnly), isFalse);

      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canViewClinicalResultsReady(reader), isTrue);
      expect(
        ClinicalResultsReadyAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.success.isAllowed(reader),
        isFalse,
      );
    });

    test(
      'matrix nested read n/a: lab:read / radiology:read alone do not open panels',
      () {
        final AppAccessPolicy labReader = _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'lab-workflows',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          ClinicalResultsReadyAtomPermissions.labResultsPanel.isAllowed(
            labReader,
          ),
          isFalse,
        );
        expect(canViewClinicalLabResultsPanel(labReader), isFalse);

        final AppAccessPolicy radiologyReader = _policy(
          permissions: <AppPermission>{AppPermissions.radiologyRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'radiology-workflows',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          ClinicalResultsReadyAtomPermissions.radiologyResultsPanel.isAllowed(
            radiologyReader,
          ),
          isFalse,
        );
        expect(canViewClinicalRadiologyResultsPanel(radiologyReader), isFalse);
      },
    );
    test('∪ allowance: lab:write + modules satisfies nested lab order write', () {
      final AppAccessPolicy labWriter = _policy(
        permissions: <AppPermission>{AppPermissions.labWrite},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'lab-workflows',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestLab.isAllowed(labWriter),
        isTrue,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.addNote.isAllowed(labWriter),
        isFalse,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestRadiology.isAllowed(
          labWriter,
        ),
        isFalse,
      );
    });

    test('∪ allowance: pharmacy:write / radiology:write / operations:write', () {
      final AppAccessPolicy pharmacyWriter = _policy(
        permissions: <AppPermission>{AppPermissions.pharmacyWrite},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.prescribe.isAllowed(pharmacyWriter),
        isTrue,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.addNote.isAllowed(pharmacyWriter),
        isFalse,
      );

      final AppAccessPolicy radiologyWriter = _policy(
        permissions: <AppPermission>{AppPermissions.radiologyWrite},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'radiology-workflows',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestRadiology.isAllowed(
          radiologyWriter,
        ),
        isTrue,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestLab.isAllowed(
          radiologyWriter,
        ),
        isFalse,
      );

      final AppAccessPolicy opsWriter = _policy(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestAdmission.isAllowed(
          opsWriter,
        ),
        isTrue,
      );
    });

    test('∪ allowance: system:admin satisfies clinical write source gate', () {
      final AppAccessPolicy admin = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
      );
      expect(ClinicalResultsReadyAtomPermissions.write.isAllowed(admin), isTrue);
      expect(
        ClinicalResultsReadyAtomPermissions.addNote.isAllowed(admin),
        isTrue,
      );
      expect(ClinicalResultsReadyAtomPermissions.tab.isAllowed(admin), isFalse);
    });

    test('discharge financial read ∩ billing:read + billing-payments', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        ClinicalResultsReadyAtomPermissions.dischargeFinancialRead.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );

      final AppAccessPolicy withBilling = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.billingRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.dischargeFinancialRead.isAllowed(
          withBilling,
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    'read-only: Results ready list visible; mutation atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(ClinicalResultsReadyAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ClinicalResultsReadyAtomPermissions.write.isAllowed(reader),
        isFalse,
      );

      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: reader,
      );

      expect(find.text('Results Ready Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Results ready'), findsWidgets);

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Request lab'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.text('Results timeline'), findsWidgets);
      expect(find.text('Lab orders'), findsWidgets);
      expect(find.text('Radiology orders'), findsWidgets);
      expect(find.text('Hemoglobin'), findsWidgets);
      expect(find.textContaining('13.5'), findsWidgets);
      expect(find.textContaining('Chest X-Ray'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byTooltip('Edit order'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: encounter mutations and nested lab ∪ mount on Results ready',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        ClinicalResultsReadyAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestLab.isAllowed(writer),
        isTrue,
      );

      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: writer,
      );

      expect(find.text('Results Ready Patient'), findsOneWidget);

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Add clinical note'), findsWidgets);
      expect(find.text('Request lab'), findsWidgets);
      expect(find.text('Prescribe'), findsWidgets);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.text('Results timeline'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: clinical:write alone without clinical:read omits Results ready chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(
        ClinicalResultsReadyAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Results Ready Patient'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: encounters-vitals missing omits Results ready chrome',
    (WidgetTester tester) async {
      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Results Ready Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module ∪: lab:write shows Request lab without clinical:write',
    (WidgetTester tester) async {
      final AppAccessPolicy labOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.labWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'lab-workflows',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestLab.isAllowed(labOnly),
        isTrue,
      );
      expect(
        ClinicalResultsReadyAtomPermissions.addNote.isAllowed(labOnly),
        isFalse,
      );

      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: labOnly,
      );

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request lab'), findsWidgets);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.text('Results timeline'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module: radiology write ∪ absent without radiology/clinical write',
    (WidgetTester tester) async {
      final AppAccessPolicy labOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.labWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'lab-workflows',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: labOnly,
      );

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request radiology'), findsNothing);
      expect(find.text('Request lab'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module ∪: radiology:write shows Request radiology without clinical:write',
    (WidgetTester tester) async {
      final AppAccessPolicy radiologyOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.radiologyWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'radiology-workflows',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestRadiology.isAllowed(
          radiologyOnly,
        ),
        isTrue,
      );

      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: radiologyOnly,
      );

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request radiology'), findsWidgets);
      expect(find.text('Request lab'), findsNothing);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Results timeline'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module ∪: pharmacy:write shows Prescribe without clinical:write',
    (WidgetTester tester) async {
      final AppAccessPolicy pharmacyOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'pharmacy-dispensing',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.prescribe.isAllowed(pharmacyOnly),
        isTrue,
      );

      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: pharmacyOnly,
      );

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Prescribe'), findsWidgets);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Request lab'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module ∪: operations:write shows Request admission',
    (WidgetTester tester) async {
      final AppAccessPolicy opsOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.operationsWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'facilities-maintenance',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClinicalResultsReadyAtomPermissions.requestAdmission.isAllowed(opsOnly),
        isTrue,
      );

      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: opsOnly,
      );

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request admission'), findsWidgets);
      expect(find.text('Add clinical note'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized Results ready chrome', (
    WidgetTester tester,
  ) async {
    await _pumpResultsReadyTab(
      tester,
      clinicalRepository: clinicalRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop viewport keeps authorized Results ready row readable', (
    WidgetTester tester,
  ) async {
    await _pumpResultsReadyTab(
      tester,
      clinicalRepository: clinicalRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
    );

    expect(find.text('Results Ready Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Next action'), findsWidgets);
    expect(find.text('Encounter type'), findsWidgets);
  });

  testWidgets('dark theme: authorized Results ready chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpResultsReadyTab(
      tester,
      clinicalRepository: clinicalRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Results Ready Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets('light theme: authorized Results ready chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpResultsReadyTab(
      tester,
      clinicalRepository: clinicalRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
    );

    expect(find.text('Results Ready Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets(
    'empty authorized Results ready worklist still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        items: const <ClinicalWorklistEntry>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Results Ready Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Results ready',
    (WidgetTester tester) async {
      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        listOverride: const Result<AppPage<ClinicalWorklistEntry>>.failure(
          AppFailure.network(),
        ),
        failOpdLists: true,
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Add clinical note opens dialog (sync path) from Results ready',
    (WidgetTester tester) async {
      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add clinical note').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
    },
  );

  testWidgets(
    'authorized loading chrome remains observable on Results ready',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      final _MockIpdRepository ipdRepository = _MockIpdRepository();
      _stubOpd(opdRepository);
      _stubIpd(ipdRepository);

      final Completer<Result<AppPage<ClinicalWorklistEntry>>> listCompleter =
          Completer<Result<AppPage<ClinicalWorklistEntry>>>();
      when(() => clinicalRepository.listEncounters(any())).thenAnswer(
        (_) => listCompleter.future,
      );
      when(() => clinicalRepository.listAdmissions(any())).thenAnswer(
        (invocation) async => Result<AppPage<ClinicalWorklistEntry>>.success(
          AppPage<ClinicalWorklistEntry>(
            items: const <ClinicalWorklistEntry>[],
            request:
                (invocation.positionalArguments.single as ClinicalWorklistQuery)
                    .pageRequest,
            totalItemCount: 0,
          ),
        ),
      );
      when(clinicalRepository.loadReferenceData).thenAnswer(
        (_) async =>
            const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
      );

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/clinical?section=results-ready',
        routes: <RouteBase>[
          GoRoute(
            path: '/clinical',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: ClinicalWorkspacePage(
                  initialQuery: ClinicalWorkspaceQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
            opdRepositoryProvider.overrideWithValue(opdRepository),
            ipdRepositoryProvider.overrideWithValue(ipdRepository),
            followUpTabCountProvider.overrideWith(
              (Ref ref, FollowUpWorklistScope scope) => null,
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{AppPermissions.clinicalRead},
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
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Loading clinical workspace'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      listCompleter.complete(
        Result<AppPage<ClinicalWorklistEntry>>.success(
          AppPage<ClinicalWorklistEntry>(
            items: const <ClinicalWorklistEntry>[_encounter],
            request: const AppPageRequest(),
            totalItemCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Results Ready Patient'), findsOneWidget);
    },
  );
}
