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
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_active_work_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

const Patient _admittedPatient = Patient(
  id: 'patient-adm-1',
  publicId: 'PAT-ADM-1',
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  firstName: 'Ada',
  lastName: 'Admitted',
  gender: 'FEMALE',
  primaryPhone: '+256700000001',
  primaryIdentifierType: 'MRN',
  primaryIdentifierValue: 'MRN-ADM-1',
  currentVisit: PatientVisitContext(
    kind: 'admission',
    publicId: 'ADM-1',
    status: 'ADMITTED_IN_BED',
    title: 'Ward A / Bed 1',
  ),
);

const Patient _incompleteAdmitted = Patient(
  id: 'patient-adm-inc',
  publicId: 'PAT-ADM-INC',
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  firstName: 'Ina',
  lastName: 'Incomplete',
  requiresCompletion: true,
  currentVisit: PatientVisitContext(
    kind: 'admission',
    publicId: 'ADM-INC',
    status: 'ADMITTED',
    title: 'Ward B',
  ),
);

const PatientDetail _admittedDetailWithWork = PatientDetail(
  patient: _admittedPatient,
  workspace: PatientWorkspaceSnapshot(
    admissions: <PatientSummaryRecord>[
      PatientSummaryRecord(
        id: 'adm-1',
        kind: 'admission',
        status: 'ADMITTED_IN_BED',
        title: 'Ward A / Bed 1',
      ),
    ],
  ),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: patientRegistryModule, licenseStatus: 'ACTIVE'),
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
      AppPermissions.billingRead,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: patientRegistryModule, licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(
        code: 'inpatient-bed-management',
        licenseStatus: 'ACTIVE',
      ),
      AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(
        code: 'radiology-workflows',
        licenseStatus: 'ACTIVE',
      ),
      AppModuleEntitlement(code: 'theatre-anesthesia', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'physiotherapy', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(
        code: 'reporting-analytics',
        licenseStatus: 'ACTIVE',
      ),
    ],
    roles: const <String>['DOCTOR', 'RECEPTIONIST'],
  );
}

void _stubRegistry(
  _MockPatientRepository repository, {
  Patient patient = _admittedPatient,
  PatientDetail? detail,
  List<Patient> items = const <Patient>[_admittedPatient],
  Result<AppPage<Patient>>? listOverride,
  Result<PatientRegistryOverview>? overviewOverride,
}) {
  when(() => repository.loadOverview()).thenAnswer((_) async {
    return overviewOverride ??
        Result<PatientRegistryOverview>.success(
          PatientRegistryOverview(
            totalPatients: items.length,
            activePatients: items.length,
            activeAdmissions: items.length,
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
    if (query.section == PatientRegistrySection.admitted ||
        query.hasActiveAdmission == true) {
      scoped = items
          .where(
            (Patient p) =>
                p.currentVisit?.kind == 'admission' || p.requiresCompletion,
          )
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

Future<GoRouter> _pumpAdmittedTab(
  WidgetTester tester, {
  required _MockPatientRepository patientRepository,
  required _MockOpdRepository opdRepository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/patients?section=admitted',
  Patient patient = _admittedPatient,
  List<Patient> items = const <Patient>[_admittedPatient],
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

  group('PatientAdmittedAtomPermissions reuse (AC1, AC4)', () {
    test('atom map reuses shared *Requirement helpers', () {
      expect(
        identical(
          PatientAdmittedAtomPermissions.tab,
          patientRegistryReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAdmittedAtomPermissions.create,
          patientRegistryWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAdmittedAtomPermissions.delete,
          patientRegistryDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAdmittedAtomPermissions.startOpd,
          opdEncounterPermissionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAdmittedAtomPermissions.nestedRead,
          patientAdmittedNestedReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAdmittedAtomPermissions.financialStatus,
          patientAdmittedFinancialStatusRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAdmittedAtomPermissions.routeEntry,
          patientRegistryEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientAdmittedAtomPermissions.catalogEntry,
          RouteAccessCatalog.patientsEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          patientRegistrySectionTabRequirement(PatientRegistrySection.admitted),
          PatientAdmittedAtomPermissions.tab,
        ),
        isTrue,
      );
    });

    test('intersection denial: patient:read alone fails write/delete/nested', () {
      final AppAccessPolicy readOnly = _readPolicy();
      expect(PatientAdmittedAtomPermissions.tab.isAllowed(readOnly), isTrue);
      expect(
        PatientAdmittedAtomPermissions.register.isAllowed(readOnly),
        isFalse,
      );
      expect(PatientAdmittedAtomPermissions.edit.isAllowed(readOnly), isFalse);
      expect(
        PatientAdmittedAtomPermissions.delete.isAllowed(readOnly),
        isFalse,
      );
      expect(
        PatientAdmittedAtomPermissions.nextActionComplete.isAllowed(readOnly),
        isFalse,
      );
      expect(
        PatientAdmittedAtomPermissions.nestedRead.isAllowed(readOnly),
        isFalse,
      );
      expect(
        PatientAdmittedAtomPermissions.visitColumn.isAllowed(readOnly),
        isFalse,
      );
      expect(
        PatientAdmittedAtomPermissions.financialStatus.isAllowed(readOnly),
        isFalse,
      );
    });

    test('full ∩ write set allows create/update; delete needs patient:delete', () {
      final AppAccessPolicy write = _readWritePolicy();
      expect(PatientAdmittedAtomPermissions.register.isAllowed(write), isTrue);
      expect(PatientAdmittedAtomPermissions.edit.isAllowed(write), isTrue);
      expect(PatientAdmittedAtomPermissions.delete.isAllowed(write), isFalse);

      final AppAccessPolicy crud = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
          AppPermissions.patientDelete,
        },
      );
      expect(PatientAdmittedAtomPermissions.delete.isAllowed(crud), isTrue);
    });

    test(
      'union allowance: nested read ∪ clinical:read | billing:read (matrix)',
      () {
        final AppAccessPolicy clinicalOnly = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          PatientAdmittedAtomPermissions.nestedRead.isAllowed(clinicalOnly),
          isTrue,
        );
        expect(
          PatientAdmittedAtomPermissions.visitColumn.isAllowed(clinicalOnly),
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
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          PatientAdmittedAtomPermissions.nestedRead.isAllowed(billingOnly),
          isTrue,
        );
        expect(
          PatientAdmittedAtomPermissions.financialStatus.isAllowed(billingOnly),
          isTrue,
        );

        final AppAccessPolicy neither = _readPolicy();
        expect(
          PatientAdmittedAtomPermissions.nestedRead.isAllowed(neither),
          isFalse,
        );
      },
    );

    test(
      'union allowance: view-active OPD ∪ clinical|billing (source Quick Action)',
      () {
        final AppAccessPolicy clinicalOnly = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          PatientAdmittedAtomPermissions.viewActiveOpd.isAllowed(clinicalOnly),
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
        PatientAdmittedAtomPermissions.entry.isAllowed(noModule),
        isFalse,
      );
      expect(canEnterPatientRegistry(noModule), isFalse);
    });

    test(
      'subscription/ABAC strip: patient:read without patient-registry denies tab',
      () {
        final AppAccessPolicy noModule = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          modules: const <AppModuleEntitlement>[],
        );
        expect(PatientAdmittedAtomPermissions.tab.isAllowed(noModule), isFalse);
        expect(canViewPatientAdmittedTab(noModule), isFalse);
        expect(patientRegistryAllowedSections(noModule), isEmpty);
      },
    );

    test('ABAC: missing facility context still allows tab when not required', () {
      // Admitted tab read does not set requiresFacilityContext; facility ABAC
      // is enforced by backend + session hydration, not this atom.
      final AppAccessPolicy noFacility = _policy(
        permissions: <AppPermission>{AppPermissions.patientRead},
        facilityId: null,
      );
      expect(PatientAdmittedAtomPermissions.tab.isAllowed(noFacility), isTrue);
      expect(canViewPatientAdmittedTab(noFacility), isTrue);
    });

    test('canViewPatientAdmittedTab mirrors tab atom', () {
      expect(canViewPatientAdmittedTab(_readPolicy()), isTrue);
      expect(canViewPatientAdmittedTab(_fullCrudPolicy()), isTrue);
    });

    test(
      'nested cross-module write: admit needs clinical write ∩ IPD module',
      () {
        final AppAccessPolicy clinicalNoIpd = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(
          PatientAdmittedAtomPermissions.requestAdmission
              .isAllowed(clinicalNoIpd),
          isFalse,
        );
        expect(
          PatientAdmittedAtomPermissions.discharge.isAllowed(clinicalNoIpd),
          isFalse,
        );

        final AppAccessPolicy withIpd = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.clinicalWrite,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          PatientAdmittedAtomPermissions.requestAdmission.isAllowed(withIpd),
          isTrue,
        );
      },
    );

    test('Active Work continue maps admission kind to shared requirement', () {
      expect(
        identical(
          patientActiveWorkContinueRequirement(PatientActiveWorkKind.admission),
          PatientAdmittedAtomPermissions.activeWorkContinueAdmission,
        ),
        isTrue,
      );
    });

    test('filter strips clinical Active Work without nested read', () {
      const List<PatientActiveWorkItem> items = <PatientActiveWorkItem>[
        PatientActiveWorkItem(
          id: 'appt-1',
          kind: PatientActiveWorkKind.appointment,
          status: 'OPEN',
          title: 'Follow-up',
        ),
        PatientActiveWorkItem(
          id: 'adm-1',
          kind: PatientActiveWorkKind.admission,
          status: 'ADMITTED_IN_BED',
          title: 'Ward A',
        ),
      ];

      final List<PatientActiveWorkItem> filtered =
          filterPatientActiveWorkForAdmittedNestedRead(items, _readPolicy());
      expect(filtered, hasLength(1));
      expect(filtered.single.kind, PatientActiveWorkKind.appointment);

      final List<PatientActiveWorkItem> kept =
          filterPatientActiveWorkForAdmittedNestedRead(
            items,
            _policy(
              permissions: <AppPermission>{
                AppPermissions.patientRead,
                AppPermissions.clinicalRead,
              },
              modules: const <AppModuleEntitlement>[
                AppModuleEntitlement(
                  code: patientRegistryModule,
                  licenseStatus: 'ACTIVE',
                ),
                AppModuleEntitlement(
                  code: 'encounters-vitals',
                  licenseStatus: 'ACTIVE',
                ),
              ],
            ),
          );
      expect(kept, hasLength(2));
    });

    test('catalog entry uses patients:read; AppRoutes/matrix use patient:read', () {
      expect(
        PatientAdmittedAtomPermissions.catalogEntry.allPermissions,
        contains(AppPermissions.patientsRead),
      );
      expect(
        PatientAdmittedAtomPermissions.entry.allPermissions,
        contains(AppPermissions.patientRead),
      );
    });
  });

  group('Admitted tab UI authorization (AC2-AC5)', () {
    late _MockPatientRepository patientRepository;
    late _MockOpdRepository opdRepository;

    setUp(() {
      patientRepository = _MockPatientRepository();
      opdRepository = _MockOpdRepository();
    });

    testWidgets('deep link section=admitted selects Admitted strip', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpAdmittedTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );

      expect(router.state.uri.queryParameters['section'], 'admitted');
      expect(find.textContaining('Admitted'), findsWidgets);
      expect(find.byType(AppTabStrip), findsOneWidget);
    });

    testWidgets(
      'intersection denial: patient:read alone omits Register/Edit/Visit',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readPolicy(),
          patient: _incompleteAdmitted,
          items: const <Patient>[_incompleteAdmitted],
        );

        expect(find.byTooltip('Register patient'), findsNothing);
        expect(find.text('Duplicate review'), findsNothing);
        expect(find.text('Visit'), findsNothing);
        expect(find.text('Ward B'), findsNothing);
        expect(find.text('Ina Incomplete'), findsWidgets);

        await tester.tap(find.text('Ina Incomplete').first);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.text('Inpatient admission'), findsNothing);
      },
    );

    testWidgets(
      'union allowance: clinical:read mounts Visit column on Admitted',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.clinicalRead,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: patientRegistryModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(find.text('Visit'), findsOneWidget);
        expect(find.textContaining('Ward A'), findsWidgets);
        expect(find.byTooltip('Register patient'), findsNothing);
      },
    );

    testWidgets(
      'union allowance: billing:read mounts Visit; financial filter allowed',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.billingRead,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: patientRegistryModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(find.text('Visit'), findsOneWidget);

        final Finder filtersButton = find.text('Filters');
        expect(filtersButton, findsWidgets);
        await tester.tap(filtersButton.first);
        await tester.pumpAndSettle();

        expect(find.text('Outstanding balance'), findsOneWidget);
        expect(find.text('Active admission'), findsOneWidget);
      },
    );

    testWidgets(
      'nested denial: patient:read alone omits outstanding-balance filter',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readPolicy(),
        );

        final Finder filtersButton = find.text('Filters');
        expect(filtersButton, findsWidgets);
        await tester.tap(filtersButton.first);
        await tester.pumpAndSettle();

        expect(find.text('Outstanding balance'), findsNothing);
        expect(find.text('Active admission'), findsNothing);
      },
    );

    testWidgets(
      'full ∩ write presents Register; delete absent without patient:delete',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readWritePolicy(),
        );

        expect(find.byTooltip('Register patient'), findsOneWidget);

        await tester.tap(find.text('Ada Admitted').first);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module: admission Active Work absent without nested read',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readWritePolicy(),
          detail: _admittedDetailWithWork,
        );

        await tester.tap(find.text('Ada Admitted').first);
        await tester.pumpAndSettle();

        expect(find.text('Active work'), findsNothing);
        expect(find.text('Inpatient admission'), findsNothing);
      },
    );

    testWidgets(
      'nested cross-module: admission Active Work present with clinical:read',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: patientRegistryModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'inpatient-bed-management',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
          detail: _admittedDetailWithWork,
        );

        await tester.tap(find.text('Ada Admitted').first);
        await tester.pumpAndSettle();

        expect(find.text('Active work'), findsOneWidget);
        expect(find.text('Inpatient admission'), findsWidgets);
      },
    );

    testWidgets(
      'nested cross-module: lab/admit chips absent without modules',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.clinicalWrite,
              AppPermissions.clinicalRead,
              AppPermissions.reportsRead,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: patientRegistryModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'scheduling-queue',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'reporting-analytics',
                licenseStatus: 'ACTIVE',
              ),
            ],
            roles: const <String>['DOCTOR', 'RECEPTIONIST'],
          ),
        );

        await tester.tap(find.text('Ada Admitted').first);
        await tester.pumpAndSettle();

        expect(find.text('Request lab'), findsNothing);
        expect(find.text('Request admission'), findsNothing);
        expect(find.text('Patient report'), findsOneWidget);
      },
    );

    testWidgets(
      'authorized full set shows Register, Edit, Delete, nested chips',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
        );

        expect(find.byTooltip('Register patient'), findsOneWidget);
        expect(find.text('Visit'), findsOneWidget);
        expect(find.textContaining('Admitted In Bed'), findsWidgets);

        await tester.tap(find.text('Ada Admitted').first);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
        expect(find.text('Schedule appointment'), findsOneWidget);
        expect(find.text('Request lab'), findsOneWidget);
        expect(find.text('Patient report'), findsOneWidget);
        // Admitted visit → discharge planning (not request admission) when no
        // Active Work admission row (source clinical write + IPD module).
        expect(find.text('Request admission'), findsNothing);
        expect(find.text('Discharge planning'), findsOneWidget);
      },
    );

    testWidgets(
      'admission status badge absent without nested ∪ clinical|billing read',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readPolicy(),
        );

        expect(find.textContaining('Admitted In Bed'), findsNothing);
        expect(find.text('Visit'), findsNothing);
        expect(find.text('Active'), findsWidgets);
      },
    );

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpAdmittedTab(
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
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance()
                ..clear(),
            ),
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
                  section: PatientRegistrySection.admitted,
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

    testWidgets('post-mutation sync: updatePatient opens edit from detail', (
      WidgetTester tester,
    ) async {
      when(
        () => patientRepository.updatePatient(any(), any()),
      ).thenAnswer((_) async {
        return const Result<Patient>.success(_admittedPatient);
      });

      await _pumpAdmittedTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        policy: _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.patientWrite,
            AppPermissions.clinicalRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      await tester.tap(find.text('Ada Admitted').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT PATIENT'), findsOneWidget);
    });

    testWidgets('mobile viewport keeps Admitted chrome without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpAdmittedTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        viewport: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop viewport keeps Admitted chrome without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpAdmittedTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        viewport: const Size(1440, 900),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byType(AppListTable<Patient>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'defaults five data columns; Admitted count tone is info; Settings lists choices',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.clinicalRead,
            },
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: patientRegistryModule,
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
          overviewOverride: const Result<PatientRegistryOverview>.success(
            PatientRegistryOverview(
              totalPatients: 9,
              activePatients: 4,
              activeAdmissions: 3,
            ),
          ),
        );

        final AppTabStrip strip = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        final AppTabItem admitted = strip.tabs.firstWhere(
          (AppTabItem item) => item.id == 'admitted',
        );
        expect(admitted.count, 3);
        expect(admitted.countTone, AppTabCountTone.info);

        expect(find.text('Patient name'), findsWidgets);
        expect(find.text('Phone'), findsWidgets);
        expect(find.text('Visit'), findsWidgets);
        expect(find.text('Status'), findsWidgets);
        expect(find.text('Next action'), findsWidgets);
        expect(find.text('Alerts'), findsNothing);

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('TABLE SETTINGS'), findsOneWidget);
        expect(find.text('Alerts'), findsOneWidget);
        expect(find.text('Patient no.'), findsOneWidget);
        expect(find.text('Age'), findsOneWidget);
        expect(find.text('Gender'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Visit column omitted without ∪ clinical|billing nested read',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readWritePolicy(),
        );

        expect(find.text('Visit'), findsNothing);

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('TABLE SETTINGS'), findsOneWidget);
        expect(find.text('Visit'), findsNothing);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Advanced filters footer is Clear filters → Apply filters → Close',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readWritePolicy(),
        );

        await tester.tap(find.byTooltip('Filters'));
        await tester.pumpAndSettle();
        expect(find.text('ADVANCED FILTERS'), findsOneWidget);
        expect(find.text('Clear filters'), findsOneWidget);
        expect(find.text('Apply filters'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('ADVANCED FILTERS'), findsNothing);
      },
    );

    testWidgets(
      'active Admitted badge uses filtered total; All sibling stays overview',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readWritePolicy(),
          overviewOverride: const Result<PatientRegistryOverview>.success(
            PatientRegistryOverview(
              totalPatients: 9,
              activePatients: 4,
              activeAdmissions: 3,
            ),
          ),
        );

        final AppTabStrip initial = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        expect(
          initial.tabs
              .firstWhere((AppTabItem t) => t.id == 'admitted')
              .count,
          3,
        );

        when(() => patientRepository.listPatients(any())).thenAnswer((
          Invocation invocation,
        ) async {
          final PatientListQuery query =
              invocation.positionalArguments.single as PatientListQuery;
          final bool narrowed = query.search.trim().isNotEmpty;
          return Result<AppPage<Patient>>.success(
            AppPage<Patient>(
              items: narrowed
                  ? const <Patient>[_admittedPatient]
                  : const <Patient>[_admittedPatient, _incompleteAdmitted],
              request: query.pageRequest,
              totalItemCount: narrowed ? 1 : 3,
            ),
          );
        });

        await tester.enterText(find.byType(TextField).first, 'Adm');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        final AppTabStrip filtered = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        expect(
          filtered.tabs
              .firstWhere((AppTabItem t) => t.id == 'admitted')
              .count,
          1,
        );
        expect(
          filtered.tabs.firstWhere((AppTabItem t) => t.id == 'all').count,
          9,
        );
      },
    );

    testWidgets(
      'Export/Print omit without evidence:export; present when granted',
      (WidgetTester tester) async {
        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _readWritePolicy(),
        );
        expect(find.byTooltip('Export'), findsNothing);
        expect(find.byTooltip('Print'), findsNothing);

        await _pumpAdmittedTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.evidenceExport,
            },
          ),
        );
        expect(find.byTooltip('Export'), findsOneWidget);
        expect(find.byTooltip('Print'), findsOneWidget);
      },
    );

    testWidgets('light and dark themes render Admitted strip', (
      WidgetTester tester,
    ) async {
      await _pumpAdmittedTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        themeMode: ThemeMode.light,
      );
      expect(find.byType(AppTabStrip), findsOneWidget);

      await _pumpAdmittedTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        themeMode: ThemeMode.dark,
      );
      expect(find.byType(AppTabStrip), findsOneWidget);
    });
  });
}
