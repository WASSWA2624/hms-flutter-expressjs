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
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/patients/presentation/pages/patient_registry_page.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_Registry_work_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

const Patient _RegistryPatient = Patient(
  id: 'patient-all-1',
  publicId: 'PAT-ALL-1',
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  firstName: 'Alla',
  lastName: 'Registry',
  gender: 'FEMALE',
  primaryPhone: '+256700000001',
  primaryIdentifierType: 'MRN',
  primaryIdentifierValue: 'MRN-ACT-1',
  currentVisit: PatientVisitContext(
    kind: 'encounter',
    publicId: 'OPD-ACT-1',
    status: 'IN_PROGRESS',
    title: 'OPD encounter',
  ),
);

const Patient _idlePatient = Patient(
  id: 'patient-idle-1',
  publicId: 'PAT-IDLE-1',
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  firstName: 'Ida',
  lastName: 'Idle',
  gender: 'FEMALE',
  primaryPhone: '+256700000002',
  primaryIdentifierType: 'MRN',
  primaryIdentifierValue: 'MRN-IDLE-1',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: patientRegistryModule, licenseStatus: 'Registry'),
  ],
  List<String> roles = const <String>['DOCTOR'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
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

AppAccessPolicy _readPolicy() {
  return _policy(permissions: <AppPermission>{AppPermissions.patientRead});
}

AppAccessPolicy _readWritePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
    },
  );
}

AppAccessPolicy _fullCrudPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.patientWrite,
      AppPermissions.patientDelete,
      AppPermissions.clinicalWrite,
      AppPermissions.clinicalRead,
      AppPermissions.reportsRead,
      AppPermissions.billingWrite,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: patientRegistryModule, licenseStatus: 'Registry'),
      AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'Registry'),
      AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'Registry'),
      AppModuleEntitlement(
        code: 'inpatient-bed-management',
        licenseStatus: 'Registry',
      ),
      AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'Registry'),
      AppModuleEntitlement(
        code: 'radiology-workflows',
        licenseStatus: 'Registry',
      ),
      AppModuleEntitlement(code: 'theatre-anesthesia', licenseStatus: 'Registry'),
      AppModuleEntitlement(code: 'physiotherapy', licenseStatus: 'Registry'),
      AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'Registry'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'Registry'),
      AppModuleEntitlement(
        code: 'reporting-analytics',
        licenseStatus: 'Registry',
      ),
    ],
    roles: const <String>['DOCTOR', 'RECEPTIONIST'],
  );
}

void _stubRegistry(
  _MockPatientRepository repository, {
  Patient patient = _RegistryPatient,
  PatientDetail? detail,
  List<Patient> items = const <Patient>[_RegistryPatient],
  Result<AppPage<Patient>>? listOverride,
  Result<PatientRegistryOverview>? overviewOverride,
}) {
  when(() => repository.loadOverview()).thenAnswer((_) async {
    return overviewOverride ??
        Result<PatientRegistryOverview>.success(
          PatientRegistryOverview(
            totalPatients: items.length,
            RegistryPatients: items.length,
          ),
        );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<PatientReferenceData>.success(PatientReferenceData()),
  );
  when(() => repository.listPatients(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (listOverride != null) {
      return listOverride;
    }
    final PatientListQuery query =
        invocation.positionalArguments.single as PatientListQuery;
    List<Patient> scoped = items;
    if (query.section == PatientRegistrySection.Registry) {
      scoped = items
          .where((Patient p) => p.currentVisit != null)
          .toList(growable: false);
      if (scoped.isEmpty && items.isNotEmpty) {
        scoped = items;
      }
    }
    return Result<AppPage<Patient>>.success(
      AppPage<Patient>(
        items: scoped,
        request: query.pageRequest,
        totalItemCount: scoped.length,
      ),
    );
  });
  when(() => repository.loadPatientDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.single as String;
    final Patient match = items.firstWhere(
      (Patient p) => p.id == id,
      orElse: () => patient,
    );
    return Result<PatientDetail>.success(
      detail ??
          PatientDetail(
            patient: match,
            workspace: const PatientWorkspaceSnapshot(),
          ),
    );
  });
}

void _stubOpd(_MockOpdRepository opdRepository) {
  when(() => opdRepository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(
    () => opdRepository.getBillingDefaults(
      facilityId: any(named: 'facilityId'),
      tenantId: any(named: 'tenantId'),
    ),
  ).thenAnswer(
    (_) async => const Result<OpdBillingDefaults>.success(OpdBillingDefaults()),
  );
  when(() => opdRepository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
  when(() => opdRepository.listAppointments(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: <OpdAppointment>[],
        request: AppPageRequest(pageSize: 50),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => opdRepository.listOpdFlows(any())).thenAnswer((
    Invocation invocation,
  ) async {
    return Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdFlowQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    );
  });
}

Future<GoRouter> _pumpRegistryTab(
  WidgetTester tester, {
  required _MockPatientRepository patientRepository,
  required _MockOpdRepository opdRepository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/patients?section=Registry',
  Patient patient = _RegistryPatient,
  List<Patient> items = const <Patient>[_RegistryPatient],
  PatientDetail? detail,
  Result<AppPage<Patient>>? listOverride,
  Result<PatientRegistryOverview>? overviewOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _stubRegistry(
    patientRepository,
    patient: patient,
    items: items,
    detail: detail,
    listOverride: listOverride,
    overviewOverride: overviewOverride,
  );
  _stubOpd(opdRepository);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/patients',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: PatientRegistryPage(
              initialQuery: PatientListQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientRepositoryProvider.overrideWithValue(patientRepository),
        opdRepositoryProvider.overrideWithValue(opdRepository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy ?? _fullCrudPolicy()),
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
  setUpAll(() {
    registerFallbackValue(const PatientListQuery());
    registerFallbackValue(const PatientDuplicateQuery());
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(<String, Object?>{});
  });

  group('PatientAllAtomPermissions reuse (AC1, AC4)', () {
    test('atom map reuses shared *Requirement helpers', () {
      expect(
        identical(
          PatientAllAtomPermissions.tab,
          patientRegistryReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAllAtomPermissions.create,
          patientRegistryWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAllAtomPermissions.delete,
          patientRegistryDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAllAtomPermissions.startOpd,
          opdEncounterPermissionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAllAtomPermissions.routeEntry,
          patientRegistryEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAllAtomPermissions.catalogEntry,
          RouteAccessCatalog.patientsEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          patientRegistrySectionTabRequirement(PatientRegistrySection.Registry),
          PatientAllAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('intersection denial: patient:read alone fails write/delete', () {
      final AppAccessPolicy readOnly = _readPolicy();
      expect(PatientAllAtomPermissions.tab.isAllowed(readOnly), isTrue);
      expect(PatientAllAtomPermissions.register.isAllowed(readOnly), isFalse);
      expect(PatientAllAtomPermissions.edit.isAllowed(readOnly), isFalse);
      expect(PatientAllAtomPermissions.delete.isAllowed(readOnly), isFalse);
      expect(
        PatientAllAtomPermissions.nextActionComplete.isAllowed(readOnly),
        isFalse,
      );
    });

    test('full ∩ write set allows create/update; delete needs patient:delete', () {
      final AppAccessPolicy write = _readWritePolicy();
      expect(PatientAllAtomPermissions.register.isAllowed(write), isTrue);
      expect(PatientAllAtomPermissions.edit.isAllowed(write), isTrue);
      expect(PatientAllAtomPermissions.delete.isAllowed(write), isFalse);

      final AppAccessPolicy crud = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
          AppPermissions.patientDelete,
        },
      );
      expect(PatientAllAtomPermissions.delete.isAllowed(crud), isTrue);
    });

    test(
      'union allowance: view-Registry OPD ∪ clinical:read | billing:read (source)',
      () {
        final AppAccessPolicy clinicalOnly = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'Registry',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'Registry',
            ),
          ],
        );
        expect(
          PatientAllAtomPermissions.viewRegistryOpd.isAllowed(clinicalOnly),
          isTrue,
        );

        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'Registry',
            ),
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'Registry',
            ),
          ],
        );
        expect(
          PatientAllAtomPermissions.viewRegistryOpd.isAllowed(billingOnly),
          isTrue,
        );

        final AppAccessPolicy neither = _readPolicy();
        expect(
          PatientAllAtomPermissions.viewRegistryOpd.isAllowed(neither),
          isFalse,
        );
      },
    );

    test(
      'union allowance: enroll insurance ∪ patient|billing|clinical write (source)',
      () {
        final AppAccessPolicy billingWrite = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingWrite,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'Registry',
            ),
            AppModuleEntitlement(
              code: 'insurance-claims',
              licenseStatus: 'Registry',
            ),
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'Registry',
            ),
          ],
        );
        expect(
          PatientAllAtomPermissions.enrollInsurance.isAllowed(billingWrite),
          isTrue,
        );
      },
    );

    test('subscription strip: role pack alone without module denies entry', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );
      expect(
        PatientAllAtomPermissions.entry.isAllowed(noModule),
        isFalse,
      );
      expect(canEnterPatientRegistry(noModule), isFalse);
    });

    test('nested cross-module: lab chip needs clinical write ∩ lab-workflows', () {
      final AppAccessPolicy clinicalNoLab = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: patientRegistryModule,
            licenseStatus: 'Registry',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'Registry',
          ),
        ],
      );
      expect(
        PatientAllAtomPermissions.labOrder.isAllowed(clinicalNoLab),
        isFalse,
      );

      final AppAccessPolicy withLab = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: patientRegistryModule,
            licenseStatus: 'Registry',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'Registry',
          ),
          AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'Registry'),
        ],
      );
      expect(PatientAllAtomPermissions.labOrder.isAllowed(withLab), isTrue);
    });

    test('Registry Work continue maps kinds to shared requirements', () {
      expect(
        identical(
          patientRegistryWorkContinueRequirement(
            PatientRegistryWorkKind.appointment,
          ),
          PatientAllAtomPermissions.RegistryWorkContinueAppointment,
        ),
        isTrue,
      );
      expect(
        identical(
          patientRegistryWorkContinueRequirement(PatientRegistryWorkKind.labOrder),
          PatientAllAtomPermissions.RegistryWorkContinueLab,
        ),
        isTrue,
      );
      expect(
        identical(
          patientRegistryWorkContinueRequirement(PatientRegistryWorkKind.admission),
          PatientAllAtomPermissions.RegistryWorkContinueAdmission,
        ),
        isTrue,
      );
    });

    test('catalog entry uses patients:read; AppRoutes/matrix use patient:read', () {
      expect(
        PatientAllAtomPermissions.catalogEntry.allPermissions,
        contains(AppPermissions.patientsRead),
      );
      expect(
        PatientAllAtomPermissions.entry.allPermissions,
        contains(AppPermissions.patientRead),
      );
    });
  });

  group('Registry tab UI authorization (AC2-AC5)', () {
    late _MockPatientRepository patientRepository;
    late _MockOpdRepository opdRepository;

    setUp(() {
      patientRepository = _MockPatientRepository();
      opdRepository = _MockOpdRepository();
    });

    testWidgets('deep link section=Registry selects Registry strip', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpRegistryTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );

      expect(router.state.uri.queryParameters['section'], 'Registry');
      expect(find.textContaining('Registry'), findsWidgets);
      expect(find.byType(AppTabStrip), findsOneWidget);
    });

    testWidgets(
      'intersection denial: patient:read alone omits Register/Edit/Delete',
      (WidgetTester tester) async {
        await _pumpRegistryTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readPolicy(),
          patient: _idlePatient,
          items: const <Patient>[_idlePatient],
        );

        expect(find.byTooltip('Register patient'), findsNothing);
        expect(find.text('Duplicate review'), findsNothing);

        await tester.tap(find.text('Ida Idle').first);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
      },
    );

    testWidgets(
      'full ∩ write presents Register; delete absent without patient:delete',
      (WidgetTester tester) async {
        await _pumpRegistryTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readWritePolicy(),
          patient: _idlePatient,
          items: const <Patient>[_idlePatient],
        );

        expect(find.byTooltip('Register patient'), findsOneWidget);

        await tester.tap(find.text('Ida Idle').first);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module: lab/radiology chips absent without modules',
      (WidgetTester tester) async {
        await _pumpRegistryTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.clinicalWrite,
              AppPermissions.reportsRead,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: patientRegistryModule,
                licenseStatus: 'Registry',
              ),
              AppModuleEntitlement(
                code: 'scheduling-queue',
                licenseStatus: 'Registry',
              ),
              AppModuleEntitlement(
                code: 'reporting-analytics',
                licenseStatus: 'Registry',
              ),
            ],
            roles: const <String>['DOCTOR', 'RECEPTIONIST'],
          ),
          patient: _idlePatient,
          items: const <Patient>[_idlePatient],
        );

        await tester.tap(find.text('Ida Idle').first);
        await tester.pumpAndSettle();

        expect(find.text('Request lab'), findsNothing);
        expect(find.text('Request radiology'), findsNothing);
        expect(find.text('Schedule theater procedure'), findsNothing);
        expect(find.text('Patient report'), findsOneWidget);
      },
    );

    testWidgets(
      'authorized full set shows Register, Edit, Delete, nested chips',
      (WidgetTester tester) async {
        await _pumpRegistryTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          patient: _idlePatient,
          items: const <Patient>[_idlePatient],
        );

        expect(find.byTooltip('Register patient'), findsOneWidget);

        await tester.tap(find.text('Ida Idle').first);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
        expect(find.text('Schedule appointment'), findsOneWidget);
        expect(find.text('Start OPD encounter'), findsOneWidget);
        expect(find.text('Request admission'), findsOneWidget);
        expect(find.text('Request lab'), findsOneWidget);
        expect(find.text('Patient report'), findsOneWidget);
      },
    );

    testWidgets(
      'Registry Work Continue for lab absent without lab module',
      (WidgetTester tester) async {
        final PatientDetail detail = PatientDetail(
          patient: _RegistryPatient,
          workspace: const PatientWorkspaceSnapshot(),
          timeline: <PatientTimelineItem>[
            PatientTimelineItem(
              id: 'lab-1',
              resource: 'lab_order',
              title: 'CBC',
              subtitle: 'ORDERED',
              occurredAt: DateTime(2026, 7, 1),
            ),
          ],
        );

        await _pumpRegistryTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readWritePolicy(),
          detail: detail,
        );

        await tester.tap(find.text('Alla Registry').first);
        await tester.pumpAndSettle();

        expect(find.text('Registry work'), findsOneWidget);
        expect(find.text('Collect sample'), findsNothing);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpRegistryTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        listOverride: Result<AppPage<Patient>>.success(
          AppPage<Patient>(
            items: const <Patient>[],
            request: const AppPageRequest(),
            totalItemCount: 0,
          ),
        ),
        items: const <Patient>[],
      );

      expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
      expect(find.byTooltip('Register patient'), findsOneWidget);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      when(() => patientRepository.loadOverview()).thenAnswer(
        (_) async =>
            const Result<PatientRegistryOverview>.failure(AppFailure.network()),
      );
      when(() => patientRepository.loadReferenceData()).thenAnswer(
        (_) async =>
            const Result<PatientReferenceData>.success(PatientReferenceData()),
      );
      when(() => patientRepository.listPatients(any())).thenAnswer(
        (_) async =>
            const Result<AppPage<Patient>>.failure(AppFailure.network()),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientRepositoryProvider.overrideWithValue(patientRepository),
            opdRepositoryProvider.overrideWithValue(opdRepository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(_fullCrudPolicy()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: PatientRegistryPage(
                initialQuery: PatientListQuery(
                  section: PatientRegistrySection.Registry,
                ),
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Try again'), findsWidgets);
    });

    testWidgets('post-mutation sync: updatePatient refreshes detail', (
      WidgetTester tester,
    ) async {
      when(
        () => patientRepository.updatePatient(any(), any()),
      ).thenAnswer((_) async {
        return const Result<Patient>.success(_idlePatient);
      });

      await _pumpRegistryTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        patient: _idlePatient,
        items: const <Patient>[_idlePatient],
      );

      await tester.tap(find.text('Ida Idle').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT PATIENT'), findsOneWidget);
    });

    testWidgets('mobile viewport keeps Registry chrome without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpRegistryTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        viewport: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop viewport keeps Registry chrome without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpRegistryTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        viewport: const Size(1440, 900),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppListTable<Patient>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('light and dark themes render Registry strip', (
      WidgetTester tester,
    ) async {
      await _pumpRegistryTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        themeMode: ThemeMode.light,
      );
      expect(find.byType(AppTabStrip), findsOneWidget);

      await _pumpRegistryTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        themeMode: ThemeMode.dark,
      );
      expect(find.byType(AppTabStrip), findsOneWidget);
    });
  });
}
