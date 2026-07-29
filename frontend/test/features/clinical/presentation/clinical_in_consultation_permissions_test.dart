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
  id: 'encounter-consult-1',
  sourceQueue: 'OPD',
  encounterId: 'encounter-consult-1',
  encounterPublicId: 'ENC-CONSULT-1',
  patientDisplayName: 'Consult Tab Patient',
  patientPublicId: 'PAT-CONSULT-1',
  providerDisplayName: 'Dr Consult',
  encounterType: 'OUTPATIENT',
  currentLocation: 'Clinic B',
  status: 'OPEN',
  stage: 'IN_CONSULTATION',
  opdFlowApiId: 'opd-flow-consult-1',
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
                  title: 'Hypertension',
                ),
              ],
            ),
      ),
    );
  });
}

void _stubOpd(
  _MockOpdRepository repository, {
  Result<AppPage<OpdFlowSummary>>? listOverride,
}) {
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (invocation) async =>
        listOverride ??
        Result<AppPage<OpdFlowSummary>>.success(
          AppPage<OpdFlowSummary>(
            items: const <OpdFlowSummary>[],
            request: (invocation.positionalArguments.single as OpdFlowQuery)
                .pageRequest,
            totalItemCount: 0,
          ),
        ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (invocation) async =>
        listOverride ??
        Result<AppPage<OpdFlowSummary>>.success(
          AppPage<OpdFlowSummary>(
            items: const <OpdFlowSummary>[],
            request:
                (invocation.positionalArguments.single as OpdTriageQueueQuery)
                    .pageRequest,
            totalItemCount: 0,
          ),
        ),
  );
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

Future<void> _pumpInConsultationTab(
  WidgetTester tester, {
  required _MockClinicalRepository clinicalRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<ClinicalWorklistEntry> items = const <ClinicalWorklistEntry>[_encounter],
  String initialLocation = '/clinical?section=in-consultation',
  Result<AppPage<ClinicalWorklistEntry>>? listOverride,
  Result<ClinicalReferenceData>? referenceOverride,
  Result<AppPage<OpdFlowSummary>>? opdListOverride,
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
  );
  _stubOpd(opdRepository, listOverride: opdListOverride);
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

  group('ClinicalInConsultationAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        ClinicalInConsultationAtomPermissions.tab,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.empty,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.loading,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.write,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.requestLab,
        same(clinicalLabOrderWriteRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.requestRadiology,
        same(clinicalRadiologyOrderWriteRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.prescribe,
        same(clinicalPharmacyOrderWriteRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.requestAdmission,
        same(clinicalAdmissionWriteRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.dischargeFinancialRead,
        same(clinicalDischargeFinancialReadRequirement),
      );
      expect(
        ClinicalInConsultationAtomPermissions.routeEntry,
        same(clinicalWorkspaceEntryRequirement),
      );
      expect(
        clinicalSectionTabRequirement(ClinicalWorkspaceSection.inConsultation),
        same(clinicalWorkspaceReadRequirement),
      );
    });

    test('∩ denial: missing clinical:read fails tab; write alone fails tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(canViewClinicalInConsultation(writeOnly), isFalse);
      expect(
        ClinicalInConsultationAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        ClinicalInConsultationAtomPermissions.write.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        ClinicalInConsultationAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );

      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canViewClinicalInConsultation(reader), isTrue);
      expect(
        ClinicalInConsultationAtomPermissions.write.isAllowed(reader),
        isFalse,
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
        ClinicalInConsultationAtomPermissions.requestLab.isAllowed(labWriter),
        isTrue,
      );
      expect(
        ClinicalInConsultationAtomPermissions.addNote.isAllowed(labWriter),
        isFalse,
      );
      expect(
        ClinicalInConsultationAtomPermissions.requestRadiology.isAllowed(
          labWriter,
        ),
        isFalse,
      );
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
        ClinicalInConsultationAtomPermissions.prescribe.isAllowed(
          pharmacyWriter,
        ),
        isTrue,
      );
      expect(
        ClinicalInConsultationAtomPermissions.addNote.isAllowed(pharmacyWriter),
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
        ClinicalInConsultationAtomPermissions.requestAdmission.isAllowed(
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
        ClinicalInConsultationAtomPermissions.dischargeFinancialRead.isAllowed(
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
        ClinicalInConsultationAtomPermissions.dischargeFinancialRead.isAllowed(
          withBilling,
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    'read-only: In consultation list visible; mutation atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(ClinicalInConsultationAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ClinicalInConsultationAtomPermissions.write.isAllowed(reader),
        isFalse,
      );

      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: reader,
      );

      expect(find.text('Consult Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('In consultation'), findsWidgets);

      await tester.tap(find.text('Consult Tab Patient'));
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
    'full write ∩: encounter mutations and nested order ∪ mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        ClinicalInConsultationAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        ClinicalInConsultationAtomPermissions.requestLab.isAllowed(writer),
        isTrue,
      );

      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: writer,
      );

      expect(find.text('Consult Tab Patient'), findsOneWidget);

      await tester.tap(find.text('Consult Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Add clinical note'), findsWidgets);
      expect(find.text('Request lab'), findsWidgets);
      expect(find.text('Request radiology'), findsWidgets);
      expect(find.text('Prescribe'), findsWidgets);
      expect(find.text('Request admission'), findsWidgets);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: clinical:write alone without clinical:read omits chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(
        ClinicalInConsultationAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        ClinicalInConsultationAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Consult Tab Patient'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: encounters-vitals missing omits In consultation chrome',
    (WidgetTester tester) async {
      await _pumpInConsultationTab(
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
      expect(find.text('Consult Tab Patient'), findsNothing);
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
        ClinicalInConsultationAtomPermissions.requestLab.isAllowed(labOnly),
        isTrue,
      );
      expect(
        ClinicalInConsultationAtomPermissions.addNote.isAllowed(labOnly),
        isFalse,
      );

      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: labOnly,
      );

      await tester.tap(find.text('Consult Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request lab'), findsWidgets);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module: radiology/pharmacy absent without those rights',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );

      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: reader,
      );

      await tester.tap(find.text('Consult Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request radiology'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Request admission'), findsNothing);
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
        ClinicalInConsultationAtomPermissions.requestAdmission.isAllowed(
          opsOnly,
        ),
        isTrue,
      );
      expect(
        ClinicalInConsultationAtomPermissions.addNote.isAllowed(opsOnly),
        isFalse,
      );

      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: opsOnly,
      );

      await tester.tap(find.text('Consult Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request admission'), findsWidgets);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module ∪: radiology:write shows Request radiology',
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
        ClinicalInConsultationAtomPermissions.requestRadiology.isAllowed(
          radiologyOnly,
        ),
        isTrue,
      );

      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: radiologyOnly,
      );

      await tester.tap(find.text('Consult Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request radiology'), findsWidgets);
      expect(find.text('Request lab'), findsNothing);
      expect(find.text('Add clinical note'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized In consultation chrome', (
    WidgetTester tester,
  ) async {
    await _pumpInConsultationTab(
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

  testWidgets('desktop viewport keeps authorized In consultation row readable', (
    WidgetTester tester,
  ) async {
    await _pumpInConsultationTab(
      tester,
      clinicalRepository: clinicalRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Consult Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Next action'), findsWidgets);
  });

  testWidgets('dark theme: authorized In consultation chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpInConsultationTab(
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

    expect(find.text('Consult Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets('light theme: authorized In consultation chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpInConsultationTab(
      tester,
      clinicalRepository: clinicalRepository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('Consult Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets(
    'empty authorized In consultation worklist still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        items: const <ClinicalWorklistEntry>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Consult Tab Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on In consultation',
    (WidgetTester tester) async {
      const Result<AppPage<ClinicalWorklistEntry>> encounterFailure =
          Result<AppPage<ClinicalWorklistEntry>>.failure(AppFailure.network());
      const Result<AppPage<OpdFlowSummary>> opdFailure =
          Result<AppPage<OpdFlowSummary>>.failure(AppFailure.network());

      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        listOverride: encounterFailure,
        opdListOverride: opdFailure,
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Add clinical note opens dialog (sync path)',
    (WidgetTester tester) async {
      await _pumpInConsultationTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Consult Tab Patient'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add clinical note').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
    },
  );
}
