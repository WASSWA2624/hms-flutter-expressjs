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
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
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
  id: 'encounter-all-1',
  sourceQueue: 'OPD',
  encounterId: 'encounter-all-1',
  encounterPublicId: 'ENC-ALL-1',
  patientDisplayName: 'All Tab Patient',
  patientPublicId: 'PAT-ALL-1',
  providerDisplayName: 'Dr All',
  encounterType: 'OUTPATIENT',
  currentLocation: 'Clinic A',
  status: 'OPEN',
  stage: 'WAITING_DOCTOR_REVIEW',
  opdFlowApiId: 'opd-flow-1',
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

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockClinicalRepository clinicalRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<ClinicalWorklistEntry> items = const <ClinicalWorklistEntry>[_encounter],
  String initialLocation = '/clinical?section=all',
  Result<AppPage<ClinicalWorklistEntry>>? listOverride,
  Result<ClinicalReferenceData>? referenceOverride,
  bool failOpdLists = false,
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
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    clinicalRepository = _MockClinicalRepository();
  });

  group('ClinicalAllAtomPermissions helpers', () {
    test('reuses feature *Requirement helpers (no second vocabulary)', () {
      expect(
        ClinicalAllAtomPermissions.tab,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.search,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.empty,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.loading,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.retry,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.printSummary,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.rowSelect,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.nextActionReview,
        same(clinicalWorkspaceReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.write,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.create,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.update,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.delete,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.success,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.validation,
        same(clinicalEncounterWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.requestLab,
        same(clinicalLabOrderWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.nestedLabWrite,
        same(clinicalLabOrderWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.requestRadiology,
        same(clinicalRadiologyOrderWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.prescribe,
        same(clinicalPharmacyOrderWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.requestAdmission,
        same(clinicalAdmissionWriteRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.dischargeFinancialRead,
        same(clinicalDischargeFinancialReadRequirement),
      );
      expect(
        ClinicalAllAtomPermissions.routeEntry,
        same(clinicalWorkspaceEntryRequirement),
      );
      expect(
        clinicalSectionTabRequirement(ClinicalWorkspaceSection.all),
        same(clinicalWorkspaceReadRequirement),
      );
      expect(canViewClinicalAll(_policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      )), isTrue);
    });

    test('∩ denial: missing clinical:read fails tab; write alone fails tab', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(canViewClinicalAll(writeOnly), isFalse);
      expect(ClinicalAllAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(ClinicalAllAtomPermissions.write.isAllowed(writeOnly), isTrue);
      expect(ClinicalAllAtomPermissions.create.isAllowed(writeOnly), isTrue);
      expect(ClinicalAllAtomPermissions.routeEntry.isAllowed(writeOnly), isTrue);

      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(canViewClinicalAll(reader), isTrue);
      expect(ClinicalAllAtomPermissions.write.isAllowed(reader), isFalse);
      expect(ClinicalAllAtomPermissions.success.isAllowed(reader), isFalse);
      expect(ClinicalAllAtomPermissions.validation.isAllowed(reader), isFalse);
    });

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
        ClinicalAllAtomPermissions.requestLab.isAllowed(labWriter),
        isTrue,
      );
      expect(ClinicalAllAtomPermissions.addNote.isAllowed(labWriter), isFalse);
      expect(
        ClinicalAllAtomPermissions.requestRadiology.isAllowed(labWriter),
        isFalse,
      );
    });

    test('∪ allowance: pharmacy / radiology / operations nested writes', () {
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
        ClinicalAllAtomPermissions.prescribe.isAllowed(pharmacyWriter),
        isTrue,
      );
      expect(
        ClinicalAllAtomPermissions.addNote.isAllowed(pharmacyWriter),
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
        ClinicalAllAtomPermissions.requestRadiology.isAllowed(radiologyWriter),
        isTrue,
      );
      expect(
        ClinicalAllAtomPermissions.addNote.isAllowed(radiologyWriter),
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
        ClinicalAllAtomPermissions.requestAdmission.isAllowed(opsWriter),
        isTrue,
      );
    });

    test('∪ allowance: system:admin satisfies clinical write source gate', () {
      final AppAccessPolicy admin = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
      );
      expect(ClinicalAllAtomPermissions.write.isAllowed(admin), isTrue);
      expect(ClinicalAllAtomPermissions.addNote.isAllowed(admin), isTrue);
      expect(ClinicalAllAtomPermissions.tab.isAllowed(admin), isFalse);
    });

    test('discharge financial read ∩ billing:read + billing-payments', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        ClinicalAllAtomPermissions.dischargeFinancialRead.isAllowed(
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
        ClinicalAllAtomPermissions.dischargeFinancialRead.isAllowed(
          withBilling,
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    'read-only: All list visible; mutation atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
      );
      expect(ClinicalAllAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(ClinicalAllAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: reader,
      );

      expect(find.text('All Tab Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('All'), findsWidgets);

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Request lab'), findsNothing);
      expect(find.text('Request radiology'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Request admission'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byTooltip('Edit order'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: encounter mutations and nested lab ∪ mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(ClinicalAllAtomPermissions.write.isAllowed(writer), isTrue);
      expect(ClinicalAllAtomPermissions.requestLab.isAllowed(writer), isTrue);

      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: writer,
      );

      expect(find.text('All Tab Patient'), findsOneWidget);

      await tester.tap(find.text('All Tab Patient'));
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
    'route entry ∪: clinical:write alone without clinical:read omits All chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
      );
      expect(ClinicalAllAtomPermissions.routeEntry.isAllowed(writeOnly), isTrue);
      expect(ClinicalAllAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: writeOnly,
      );

      expect(find.text('All Tab Patient'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: encounters-vitals missing omits All chrome',
    (WidgetTester tester) async {
      await _pumpAllTab(
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
      expect(find.text('All Tab Patient'), findsNothing);
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
      expect(ClinicalAllAtomPermissions.requestLab.isAllowed(labOnly), isTrue);
      expect(ClinicalAllAtomPermissions.addNote.isAllowed(labOnly), isFalse);

      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: labOnly,
      );

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request lab'), findsWidgets);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Prescribe'), findsNothing);
      expect(find.text('Request admission'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
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
        ClinicalAllAtomPermissions.prescribe.isAllowed(pharmacyOnly),
        isTrue,
      );
      expect(ClinicalAllAtomPermissions.addNote.isAllowed(pharmacyOnly), isFalse);

      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: pharmacyOnly,
      );

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Prescribe'), findsWidgets);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Request lab'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
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
        ClinicalAllAtomPermissions.requestAdmission.isAllowed(opsOnly),
        isTrue,
      );
      expect(ClinicalAllAtomPermissions.addNote.isAllowed(opsOnly), isFalse);

      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: opsOnly,
      );

      await tester.tap(find.text('All Tab Patient'));
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
        ClinicalAllAtomPermissions.requestRadiology.isAllowed(radiologyOnly),
        isTrue,
      );
      expect(
        ClinicalAllAtomPermissions.addNote.isAllowed(radiologyOnly),
        isFalse,
      );

      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: radiologyOnly,
      );

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Request radiology'), findsWidgets);
      expect(find.text('Request lab'), findsNothing);
      expect(find.text('Add clinical note'), findsNothing);
      expect(find.text('Print summary'), findsWidgets);
    },
  );

  testWidgets('mobile viewport keeps authorized All chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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

  testWidgets('desktop viewport keeps authorized All row readable', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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

    expect(find.text('All Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Next action'), findsWidgets);
  });

  testWidgets('dark theme: authorized All chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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

    expect(find.text('All Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets('light theme: authorized All chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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

    expect(find.text('All Tab Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });

  testWidgets(
    'empty authorized All worklist still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        items: const <ClinicalWorklistEntry>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('All Tab Patient'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on All',
    (WidgetTester tester) async {
      await _pumpAllTab(
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
    'authorized Add clinical note shows validation for empty submit',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add clinical note').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);

      await tester.tap(find.text('Add clinical note').last);
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsWidgets);
      verifyNever(() => clinicalRepository.createClinicalNote(any()));
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  test(
    'post-mutation sync: deleteDiagnosis reloads All encounter bundle',
    () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      final _MockIpdRepository ipdRepository = _MockIpdRepository();
      _stubClinical(clinicalRepository);
      _stubOpd(opdRepository);
      _stubIpd(ipdRepository);
      when(
        () => clinicalRepository.deleteDiagnosis(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));

      final ProviderContainer container = ProviderContainer(
        overrides: [
          clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
          opdRepositoryProvider.overrideWithValue(opdRepository),
          ipdRepositoryProvider.overrideWithValue(ipdRepository),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.clinicalRead,
                AppPermissions.clinicalWrite,
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(clinicalWorkspaceControllerProvider.future);
      final ClinicalWorkspaceController controller = container.read(
        clinicalWorkspaceControllerProvider.notifier,
      );
      await controller.selectEntry(_encounter);

      clearInteractions(clinicalRepository);
      when(
        () => clinicalRepository.deleteDiagnosis(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));
      when(() => clinicalRepository.loadEncounterBundle(any())).thenAnswer((
        invocation,
      ) {
        final ClinicalWorklistEntry entry =
            invocation.positionalArguments.single as ClinicalWorklistEntry;
        return Future<Result<ClinicalEncounterBundle>>.value(
          Result<ClinicalEncounterBundle>.success(
            ClinicalEncounterBundle(
              entry: entry,
              diagnoses: const <ClinicalRelatedRecord>[],
            ),
          ),
        );
      });

      final AppFailure? failure = await controller.deleteDiagnosis('dx-1');
      expect(failure, isNull);
      verify(() => clinicalRepository.deleteDiagnosis('dx-1')).called(1);
      verify(
        () => clinicalRepository.loadEncounterBundle(any()),
      ).called(greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'write ∪: system:admin mounts Add clinical note with clinical:read',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.systemAdmin,
          },
        ),
      );

      await tester.tap(find.text('All Tab Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Add clinical note'), findsWidgets);
      expect(find.text('Request lab'), findsWidgets);
      expect(find.text('Print summary'), findsWidgets);
    },
  );

  testWidgets(
    'authorized loading chrome remains observable on All',
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
        initialLocation: '/clinical?section=all',
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
      expect(find.text('All Tab Patient'), findsOneWidget);
    },
  );
}
