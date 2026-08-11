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

const Patient _balancePatient = Patient(
  id: 'patient-bal-1',
  publicId: 'PAT-BAL-1',
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  firstName: 'Bea',
  lastName: 'Balance',
  gender: 'FEMALE',
  primaryPhone: '+256700000010',
  primaryIdentifierType: 'MRN',
  primaryIdentifierValue: 'MRN-BAL-1',
  currentVisit: PatientVisitContext(
    kind: 'invoice',
    publicId: 'INV-BAL-1',
    status: 'UNPAID',
    title: 'Outstanding balance',
  ),
);

const Patient _incompletePatient = Patient(
  id: 'patient-inc-1',
  publicId: 'PAT-INC-1',
  tenantId: 'tenant-1',
  facilityId: 'facility-1',
  firstName: 'Ina',
  lastName: 'Incomplete',
  requiresCompletion: true,
  currentVisit: PatientVisitContext(
    kind: 'invoice',
    publicId: 'INV-INC-1',
    status: 'UNPAID',
    title: 'Outstanding balance',
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
    AppModuleEntitlement(code: patientRegistryModule, licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
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

AppAccessPolicy _tabReadPolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.billingRead,
    },
  );
}

AppAccessPolicy _tabReadWritePolicy() {
  return _policy(
    permissions: <AppPermission>{
      AppPermissions.patientRead,
      AppPermissions.billingRead,
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
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
      AppPermissions.clinicalWrite,
      AppPermissions.clinicalRead,
      AppPermissions.reportsRead,
    },
    modules: const <AppModuleEntitlement>[
      AppModuleEntitlement(code: patientRegistryModule, licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(
        code: 'inpatient-bed-management',
        licenseStatus: 'ACTIVE',
      ),
      AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(
        code: 'radiology-workflows',
        licenseStatus: 'ACTIVE',
      ),
      AppModuleEntitlement(code: 'theatre-anesthesia', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'physiotherapy', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
      AppModuleEntitlement(
        code: 'reporting-analytics',
        licenseStatus: 'ACTIVE',
      ),
    ],
    roles: const <String>['DOCTOR', 'RECEPTIONIST', 'BILLING'],
  );
}

void _stubRegistry(
  _MockPatientRepository repository, {
  Patient patient = _balancePatient,
  PatientDetail? detail,
  List<Patient> items = const <Patient>[_balancePatient],
  Result<AppPage<Patient>>? listOverride,
  Result<PatientRegistryOverview>? overviewOverride,
}) {
  when(() => repository.loadOverview()).thenAnswer((_) async {
    return overviewOverride ??
        Result<PatientRegistryOverview>.success(
          PatientRegistryOverview(
            totalPatients: items.length,
            unpaidInvoices: items.length,
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
    if (query.section == PatientRegistrySection.balanceDue ||
        query.hasOutstandingBalance == true) {
      scoped = items;
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

Future<GoRouter> _pumpBalanceDueTab(
  WidgetTester tester, {
  required _MockPatientRepository patientRepository,
  required _MockOpdRepository opdRepository,
  AppAccessPolicy? policy,
  Size viewport = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/patients?section=balance-due',
  Patient patient = _balancePatient,
  List<Patient> items = const <Patient>[_balancePatient],
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

  group('PatientBalanceDueAtomPermissions reuse (AC1, AC4)', () {
    test('atom map reuses shared *Requirement helpers', () {
      expect(
        identical(
          PatientBalanceDueAtomPermissions.tab,
          patientBalanceDueReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientBalanceDueAtomPermissions.create,
          patientRegistryWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientBalanceDueAtomPermissions.delete,
          patientRegistryDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientBalanceDueAtomPermissions.nestedWrite,
          patientBalanceDueBillingWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientBalanceDueAtomPermissions.billingWorkbench,
          patientBillingWorkbenchRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientBalanceDueAtomPermissions.startOpd,
          opdEncounterPermissionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientBalanceDueAtomPermissions.routeEntry,
          patientRegistryEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          PatientBalanceDueAtomPermissions.catalogEntry,
          RouteAccessCatalog.patientsEntry,
        ),
        isTrue,
      );
      expect(
        identical(
          patientRegistrySectionTabRequirement(
            PatientRegistrySection.balanceDue,
          ),
          PatientBalanceDueAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          patientRegistryRegisterAtom(PatientRegistrySection.balanceDue),
          PatientBalanceDueAtomPermissions.register,
        ),
        isTrue,
      );
    });

    test(
      'intersection denial: patient:read alone fails Balance due tab read',
      () {
        final AppAccessPolicy patientOnly = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          PatientBalanceDueAtomPermissions.tab.isAllowed(patientOnly),
          isFalse,
        );
        expect(canViewPatientBalanceDueTab(patientOnly), isFalse);
        expect(
          PatientBalanceDueAtomPermissions.register.isAllowed(patientOnly),
          isFalse,
        );
      },
    );

    test(
      'intersection denial: billing:read alone fails Balance due tab read',
      () {
        final AppAccessPolicy billingOnly = _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        );
        expect(
          PatientBalanceDueAtomPermissions.tab.isAllowed(billingOnly),
          isFalse,
        );
      },
    );

    test('full ∩ read set allows tab; write/delete need their keys', () {
      final AppAccessPolicy tabRead = _tabReadPolicy();
      expect(PatientBalanceDueAtomPermissions.tab.isAllowed(tabRead), isTrue);
      expect(
        PatientBalanceDueAtomPermissions.register.isAllowed(tabRead),
        isFalse,
      );
      expect(
        PatientBalanceDueAtomPermissions.delete.isAllowed(tabRead),
        isFalse,
      );

      final AppAccessPolicy write = _tabReadWritePolicy();
      expect(PatientBalanceDueAtomPermissions.register.isAllowed(write), isTrue);
      expect(PatientBalanceDueAtomPermissions.delete.isAllowed(write), isFalse);

      final AppAccessPolicy crud = _policy(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.billingRead,
          AppPermissions.patientWrite,
          AppPermissions.patientDelete,
        },
      );
      expect(PatientBalanceDueAtomPermissions.delete.isAllowed(crud), isTrue);
    });

    test(
      'union allowance: view-active OPD ∪ clinical:read | billing:read (source)',
      () {
        final AppAccessPolicy clinicalOnly = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
            AppPermissions.clinicalRead,
          },
        );
        expect(
          PatientBalanceDueAtomPermissions.viewActiveOpd.isAllowed(
            clinicalOnly,
          ),
          isTrue,
        );

        // Tab read ∩ already includes billing:read, which alone satisfies ∪.
        final AppAccessPolicy tabRead = _tabReadPolicy();
        expect(
          PatientBalanceDueAtomPermissions.viewActiveOpd.isAllowed(tabRead),
          isTrue,
        );

        final AppAccessPolicy noClinicalOrBilling = _policy(
          permissions: <AppPermission>{AppPermissions.patientRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          PatientBalanceDueAtomPermissions.viewActiveOpd.isAllowed(
            noClinicalOrBilling,
          ),
          isFalse,
        );
      },
    );

    test(
      'union allowance: enroll insurance ∪ billing:write (source; not matrix ∩)',
      () {
        final AppAccessPolicy billingWrite = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
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
            AppModuleEntitlement(
              code: 'insurance-claims',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          PatientBalanceDueAtomPermissions.enrollInsurance.isAllowed(
            billingWrite,
          ),
          isTrue,
        );
      },
    );

    test(
      'nested write ∩ billing:write: workbench denied without billing:write',
      () {
        final AppAccessPolicy readOnly = _tabReadPolicy();
        expect(
          PatientBalanceDueAtomPermissions.nestedWrite.isAllowed(readOnly),
          isFalse,
        );
        expect(
          PatientBalanceDueAtomPermissions.billingWorkbench.isAllowed(readOnly),
          isFalse,
        );

        final AppAccessPolicy withWrite = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        );
        expect(
          PatientBalanceDueAtomPermissions.nestedWrite.isAllowed(withWrite),
          isTrue,
        );
      },
    );

    test(
      'subscription strip: role pack alone without billing-payments denies tab',
      () {
        final AppAccessPolicy noBillingModule = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: patientRegistryModule,
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        expect(
          PatientBalanceDueAtomPermissions.tab.isAllowed(noBillingModule),
          isFalse,
        );
        expect(
          PatientBalanceDueAtomPermissions.entry.isAllowed(
            _policy(
              permissions: <AppPermission>{AppPermissions.patientRead},
              modules: const <AppModuleEntitlement>[],
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'nested cross-module: lab chip needs clinical write ∩ lab-workflows',
      () {
        final AppAccessPolicy clinicalNoLab = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
            AppPermissions.clinicalWrite,
          },
        );
        expect(
          PatientBalanceDueAtomPermissions.labOrder.isAllowed(clinicalNoLab),
          isFalse,
        );

        final AppAccessPolicy withLab = _policy(
          permissions: <AppPermission>{
            AppPermissions.patientRead,
            AppPermissions.billingRead,
            AppPermissions.clinicalWrite,
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
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
          ],
        );
        expect(
          PatientBalanceDueAtomPermissions.labOrder.isAllowed(withLab),
          isTrue,
        );
      },
    );

    test('Active Work continue maps kinds to shared requirements', () {
      expect(
        identical(
          patientActiveWorkContinueRequirement(
            PatientActiveWorkKind.appointment,
          ),
          PatientBalanceDueAtomPermissions.activeWorkContinueAppointment,
        ),
        isTrue,
      );
      expect(
        identical(
          patientActiveWorkContinueRequirement(PatientActiveWorkKind.labOrder),
          PatientBalanceDueAtomPermissions.activeWorkContinueLab,
        ),
        isTrue,
      );
    });

    test('catalog entry uses patients:read; AppRoutes/matrix use patient:read', () {
      expect(
        PatientBalanceDueAtomPermissions.catalogEntry.allPermissions,
        contains(AppPermissions.patientsRead),
      );
      expect(
        PatientBalanceDueAtomPermissions.entry.allPermissions,
        contains(AppPermissions.patientRead),
      );
    });
  });

  group('Balance due tab UI authorization (AC2-AC5)', () {
    late _MockPatientRepository patientRepository;
    late _MockOpdRepository opdRepository;

    setUp(() {
      patientRepository = _MockPatientRepository();
      opdRepository = _MockOpdRepository();
    });

    testWidgets('deep link section=balance-due selects Balance due strip', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpBalanceDueTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );

      expect(router.state.uri.queryParameters['section'], 'balance-due');
      expect(find.textContaining('Balance due'), findsWidgets);
      expect(find.byType(AppTabStrip), findsOneWidget);
    });

    testWidgets(
      'intersection denial: patient:read alone omits Balance due tab',
      (WidgetTester tester) async {
        final GoRouter router = await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{AppPermissions.patientRead},
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: patientRegistryModule,
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(find.textContaining('Balance due'), findsNothing);
        expect(
          router.state.uri.queryParameters['section'],
          isNot('balance-due'),
        );
      },
    );

    testWidgets(
      'intersection denial: tab read alone omits Register/Edit/Delete',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _tabReadPolicy(),
          patient: _incompletePatient,
          items: const <Patient>[_incompletePatient],
          overviewOverride: Result<PatientRegistryOverview>.success(
            PatientRegistryOverview(
              totalPatients: 1,
              unpaidInvoices: 1,
              duplicates: <PatientDuplicateCandidate>[
                PatientDuplicateCandidate(
                  reviewId: 'dup-1',
                  confidenceScore: 90,
                  classification: 'LIKELY',
                  primaryPatient: _incompletePatient,
                  secondaryPatient: _idlePatient,
                ),
              ],
            ),
          ),
        );

        expect(find.byTooltip('Register patient'), findsNothing);
        expect(find.text('Duplicate review'), findsNothing);
        expect(find.text('Ina Incomplete'), findsWidgets);
        // Incomplete next-action button must not mount for read-only users.
        expect(
          find.descendant(
            of: find.byType(GestureDetector),
            matching: find.text('Complete record'),
          ),
          findsNothing,
        );

        await tester.tap(find.text('Ina Incomplete').first);
        await tester.pumpAndSettle();

        expect(find.text('Edit'), findsNothing);
        expect(find.text('Delete'), findsNothing);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.text('Billing details'), findsOneWidget);
        expect(find.text('Open billing'), findsNothing);
      },
    );

    testWidgets(
      'full ∩ write presents Register; delete absent without patient:delete',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _tabReadWritePolicy(),
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
      'nested cross-module: lab chips absent; billing workbench needs write',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.billingRead,
              AppPermissions.patientWrite,
              AppPermissions.clinicalWrite,
              AppPermissions.reportsRead,
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
              AppModuleEntitlement(
                code: 'scheduling-queue',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'reporting-analytics',
                licenseStatus: 'ACTIVE',
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
        expect(find.text('Billing details'), findsOneWidget);
        expect(find.text('Open billing'), findsNothing);
        expect(find.text('Enroll insurance'), findsNothing);
      },
    );

    testWidgets(
      'nested write ∩ billing:write: Open billing present for writers',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.billingRead,
              AppPermissions.patientWrite,
              AppPermissions.billingWrite,
            },
            roles: const <String>['DOCTOR', 'BILLING'],
          ),
          patient: _idlePatient,
          items: const <Patient>[_idlePatient],
        );

        await tester.tap(find.text('Ida Idle').first);
        await tester.pumpAndSettle();

        expect(find.text('Billing details'), findsOneWidget);
        expect(find.text('Open billing'), findsOneWidget);
      },
    );

    testWidgets(
      'billing-role reader: Open billing present; clinical chips absent',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            },
            roles: const <String>['BILLING'],
          ),
          patient: _idlePatient,
          items: const <Patient>[_idlePatient],
        );

        await tester.tap(find.text('Ida Idle').first);
        await tester.pumpAndSettle();

        expect(find.text('Billing details'), findsOneWidget);
        expect(find.text('Open billing'), findsOneWidget);
        expect(find.text('Schedule appointment'), findsNothing);
        expect(find.text('Start OPD encounter'), findsNothing);
        expect(find.text('Request lab'), findsNothing);
      },
    );

    testWidgets(
      'union allowance UI: Continue OPD via tab billing:read leg',
      (WidgetTester tester) async {
        final Patient withOpdVisit = _idlePatient.copyWith(
          currentVisit: const PatientVisitContext(
            kind: 'encounter',
            publicId: 'OPD-BAL-1',
            status: 'IN_PROGRESS',
            title: 'OPD encounter',
          ),
        );
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _tabReadPolicy(),
          patient: withOpdVisit,
          items: <Patient>[withOpdVisit],
        );

        await tester.tap(find.text('Ida Idle').first);
        await tester.pumpAndSettle();

        expect(find.text('Continue OPD flow'), findsOneWidget);
        expect(find.text('Start OPD encounter'), findsNothing);
        expect(find.text('Request lab'), findsNothing);
      },
    );

    testWidgets(
      'authorized full set shows Register, Edit, Delete, nested chips',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
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
        expect(find.text('Enroll insurance'), findsOneWidget);
        expect(find.text('Billing details'), findsOneWidget);
        expect(find.text('Open billing'), findsOneWidget);
      },
    );

    testWidgets('Active Work Continue for lab absent without lab module', (
      WidgetTester tester,
    ) async {
      final PatientDetail detail = PatientDetail(
        patient: _balancePatient,
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

      await _pumpBalanceDueTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        policy: _tabReadWritePolicy(),
        detail: detail,
      );

      await tester.tap(find.text('Bea Balance').first);
      await tester.pumpAndSettle();

      expect(find.text('Active work'), findsOneWidget);
      expect(find.text('Collect sample'), findsNothing);
    });

    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpBalanceDueTab(
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
                  section: PatientRegistrySection.balanceDue,
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

    testWidgets('post-mutation sync: updatePatient opens edit form', (
      WidgetTester tester,
    ) async {
      when(
        () => patientRepository.updatePatient(any(), any()),
      ).thenAnswer((_) async {
        return const Result<Patient>.success(_idlePatient);
      });

      await _pumpBalanceDueTab(
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

    testWidgets('mobile viewport keeps Balance due chrome without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpBalanceDueTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        viewport: const Size(390, 844),
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop viewport keeps Balance due chrome without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpBalanceDueTab(
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
      'defaults five data columns; Balance due count tone is warning; Settings lists choices',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _tabReadWritePolicy(),
          overviewOverride: const Result<PatientRegistryOverview>.success(
            PatientRegistryOverview(
              totalPatients: 12,
              activePatients: 5,
              unpaidInvoices: 4,
            ),
          ),
        );

        final AppTabStrip strip = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        final AppTabItem balanceDue = strip.tabs.firstWhere(
          (AppTabItem item) => item.id == 'balanceDue',
        );
        expect(balanceDue.count, 4);
        expect(balanceDue.countTone, AppTabCountTone.warning);

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
      'Advanced filters footer is Clear filters → Apply filters → Close',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _tabReadWritePolicy(),
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
      'active Balance due badge uses filtered total; All sibling stays overview',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _tabReadWritePolicy(),
          overviewOverride: const Result<PatientRegistryOverview>.success(
            PatientRegistryOverview(
              totalPatients: 12,
              activePatients: 5,
              unpaidInvoices: 4,
            ),
          ),
        );

        final AppTabStrip initial = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        expect(
          initial.tabs
              .firstWhere((AppTabItem t) => t.id == 'balanceDue')
              .count,
          4,
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
                  ? const <Patient>[_balancePatient]
                  : const <Patient>[_balancePatient, _incompletePatient],
              request: query.pageRequest,
              totalItemCount: narrowed ? 1 : 4,
            ),
          );
        });

        await tester.enterText(find.byType(TextField).first, 'Bea');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        final AppTabStrip filtered = tester.widget<AppTabStrip>(
          find.byType(AppTabStrip),
        );
        expect(
          filtered.tabs
              .firstWhere((AppTabItem t) => t.id == 'balanceDue')
              .count,
          1,
        );
        expect(
          filtered.tabs.firstWhere((AppTabItem t) => t.id == 'all').count,
          12,
        );
      },
    );

    testWidgets(
      'Export/Print omit without evidence:export; present when granted',
      (WidgetTester tester) async {
        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _tabReadWritePolicy(),
        );
        expect(find.byTooltip('Export'), findsNothing);
        expect(find.byTooltip('Print'), findsNothing);

        await _pumpBalanceDueTab(
          tester,
          patientRepository: patientRepository,
          opdRepository: opdRepository,
          policy: _policy(
            permissions: <AppPermission>{
              AppPermissions.patientRead,
              AppPermissions.billingRead,
              AppPermissions.patientWrite,
              AppPermissions.evidenceExport,
            },
          ),
        );
        expect(find.byTooltip('Export'), findsOneWidget);
        expect(find.byTooltip('Print'), findsOneWidget);
      },
    );

    testWidgets('light and dark themes render Balance due strip', (
      WidgetTester tester,
    ) async {
      await _pumpBalanceDueTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        themeMode: ThemeMode.light,
      );
      expect(find.byType(AppTabStrip), findsOneWidget);

      await _pumpBalanceDueTab(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        themeMode: ThemeMode.dark,
      );
      expect(find.byType(AppTabStrip), findsOneWidget);
    });
  });
}
