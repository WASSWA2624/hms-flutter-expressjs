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
  id: 'encounter-waiting-review-1',
  sourceQueue: 'OPD',
  encounterId: 'encounter-waiting-review-1',
  encounterPublicId: 'ENC-WR-1',
  patientDisplayName: 'Waiting Review Tab Patient',
  patientPublicId: 'PAT-WR-1',
  providerDisplayName: 'Dr Review',
  encounterType: 'OUTPATIENT',
  currentLocation: 'Clinic R',
  status: 'OPEN',
  stage: 'WAITING_DOCTOR_REVIEW',
  nextStep: 'DOCTOR_REVIEW',
  opdFlowApiId: 'opd-flow-waiting-review-1',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['DOCTOR'],
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
            ClinicalEncounterBundle(
              entry: entry,
              labOrders: const <ClinicalRelatedRecord>[
                ClinicalRelatedRecord(
                  id: 'lab-1',
                  kind: 'LAB_ORDER',
                  status: 'ORDERED',
                  title: 'CBC',
                ),
              ],
              diagnoses: const <ClinicalRelatedRecord>[
                ClinicalRelatedRecord(
                  id: 'dx-1',
                  kind: 'DIAGNOSIS',
                  status: 'ACTIVE',
                  title: 'Acute fever',
                ),
              ],
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
      OpdFlowDetail(
        summary: OpdFlowSummary(id: 'flow-1', publicId: 'OPD000001'),
      ),
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

Future<void> _pumpWaitingReviewTab(
  WidgetTester tester, {
  required _MockClinicalRepository clinicalRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<ClinicalWorklistEntry> items = const <ClinicalWorklistEntry>[_encounter],
  String initialLocation = '/clinical?section=waiting-review',
  Result<AppPage<ClinicalWorklistEntry>>? listOverride,
  Result<ClinicalReferenceData>? referenceOverride,
  bool failOpdLists = false,
  ClinicalEncounterBundle? bundle,
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

  group('ClinicalWaitingReviewAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        ClinicalWaitingReviewAtomPermissions.tab,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.waitingReviewChip,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.empty,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.loading,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.write,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.requestLab,
        same(clinicalLabOrderWriteRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.nestedLabWrite,
        same(clinicalLabOrderWriteRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.requestRadiology,
        same(clinicalRadiologyOrderWriteRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.prescribe,
        same(clinicalPharmacyOrderWriteRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.requestAdmission,
        same(clinicalAdmissionWriteRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.printSummary,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.dischargeFinancialRead,
        same(clinicalDischargeFinancialReadRequirement),
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.routeEntry,
        same(clinicalWorkspaceEntryRequirement),
      );
      expect(
        clinicalSectionTabRequirement(ClinicalWorkspaceSection.waitingReview),
        same(clinicalWorkspaceReadRequirement),
      );
    });

    test('∩ denial: missing clinical:read fails tab; write alone fails tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(canViewClinicalWaitingReview(writeOnly), isFalse);
      expect(
        ClinicalWaitingReviewAtomPermissions.write.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
    });

    test('∪ allowance: lab:write satisfies nested lab order write', () {
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
        ClinicalWaitingReviewAtomPermissions.requestLab.isAllowed(labWriter),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.nestedLabWrite.isAllowed(
          labWriter,
        ),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.addNote.isAllowed(labWriter),
        isFalse,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.requestRadiology.isAllowed(
          labWriter,
        ),
        isFalse,
      );
    });

    test('∪ write: system:admin satisfies encounter write (source gate)', () {
      final AppAccessPolicy admin = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.write.isAllowed(admin),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.addNote.isAllowed(admin),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.tab.isAllowed(admin),
        isFalse,
      );
      expect(canViewClinicalWaitingReview(admin), isFalse);
    });

    test('∪ allowance: pharmacy:write / operations:write nested writes', () {
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
        ClinicalWaitingReviewAtomPermissions.prescribe.isAllowed(
          pharmacyWriter,
        ),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.addNote.isAllowed(pharmacyWriter),
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
        ClinicalWaitingReviewAtomPermissions.requestAdmission.isAllowed(
          opsWriter,
        ),
        isTrue,
      );
    });

    test('discharge financial read ∩ billing:read + billing-payments', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.dischargeFinancialRead.isAllowed(
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
        ClinicalWaitingReviewAtomPermissions.dischargeFinancialRead.isAllowed(
          withBilling,
        ),
        isTrue,
      );
    });

    test(
      'subscription strip: encounters-vitals required for Waiting review tab',
      () {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
          modules: const <AppModuleEntitlement>[],
        );
        expect(
          ClinicalWaitingReviewAtomPermissions.tab.isAllowed(noModule),
          isFalse,
        );
        expect(canViewClinicalWaitingReview(noModule), isFalse);
      },
    );
  });

  testWidgets(
    'read-only: Waiting review list visible; mutation atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(ClinicalWaitingReviewAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ClinicalWaitingReviewAtomPermissions.write.isAllowed(reader),
        isFalse,
      );

      await _pumpWaitingReviewTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: reader,
      );

      expect(find.text('Waiting Review Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Waiting review'), findsWidgets);
      // Disposition next-action is write-gated; readers get Review encounter.
      expect(find.text('Disposition'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Waiting Review Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Request lab'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Request admission'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byTooltip('Edit order'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: encounter mutations and nested order ∪ mount on Waiting review',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(canViewClinicalWaitingReview(writer), isTrue);
      expect(
        ClinicalWaitingReviewAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.requestLab.isAllowed(writer),
        isTrue,
      );

      await _pumpWaitingReviewTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: writer,
      );

      expect(find.text('Waiting Review Tab Patient'), findsOneWidget);
      expect(find.text('Waiting review'), findsWidgets);
      // WAITING_DOCTOR_REVIEW + OPD flow → write-gated disposition next action.
      expect(find.text('Disposition'), findsWidgets);

      await tester.tap(find.text('Waiting Review Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Add clinical note'), findsWidgets);
      expect(find.text('Request lab'), findsWidgets);
      expect(find.text('Request radiology'), findsWidgets);
      expect(find.text('Prescribe'), findsWidgets);
      expect(find.text('Request admission'), findsWidgets);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.byTooltip('Edit order'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: clinical:write alone without clinical:read omits Waiting review chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpWaitingReviewTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Waiting Review Tab Patient'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: encounters-vitals missing omits Waiting review chrome',
    (WidgetTester tester) async {
      await _pumpWaitingReviewTab(
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
      expect(find.text('Waiting Review Tab Patient'), findsNothing);
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
        ClinicalWaitingReviewAtomPermissions.requestLab.isAllowed(labOnly),
        isTrue,
      );
      expect(
        ClinicalWaitingReviewAtomPermissions.addNote.isAllowed(labOnly),
        isFalse,
      );

      await _pumpWaitingReviewTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: labOnly,
      );

      await tester.tap(find.text('Waiting Review Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request lab'), findsWidgets);
      expect(find.byTooltip('Edit order'), findsWidgets);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Request radiology'), findsNothing);
      expect(find.text('Request admission'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module: radiology/pharmacy/admission absent without those rights',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpWaitingReviewTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: reader,
      );

      await tester.tap(find.text('Waiting Review Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request radiology'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Request admission'), findsNothing);
      expect(find.byTooltip('Edit order'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized Waiting review chrome', (
    WidgetTester tester,
  ) async {
    await _pumpWaitingReviewTab(
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

  testWidgets('desktop viewport keeps authorized Waiting review row readable', (
    WidgetTester tester,
  ) async {
    await _pumpWaitingReviewTab(
      tester,
      clinicalRepository: clinicalRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
    );

    expect(find.text('Waiting Review Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Next action'), findsWidgets);
  });

  testWidgets('dark theme: authorized Waiting review chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpWaitingReviewTab(
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

    expect(find.text('Waiting Review Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets('light theme: authorized Waiting review chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpWaitingReviewTab(
      tester,
      clinicalRepository: clinicalRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
    );

    expect(find.text('Waiting Review Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets(
    'empty authorized Waiting review worklist still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpWaitingReviewTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        items: const <ClinicalWorklistEntry>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Waiting Review Tab Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Waiting review',
    (WidgetTester tester) async {
      await _pumpWaitingReviewTab(
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
    'authorized Add clinical note opens dialog (sync path) from Waiting review',
    (WidgetTester tester) async {
      await _pumpWaitingReviewTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Waiting Review Tab Patient'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add clinical note').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      // Detail remains mounted after opening write dialog (sync path ready).
      expect(find.text('Waiting Review Tab Patient'), findsWidgets);
      verify(() => clinicalRepository.loadEncounterBundle(any())).called(
        greaterThan(0),
      );
    },
  );
}
