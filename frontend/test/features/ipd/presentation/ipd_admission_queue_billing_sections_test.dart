import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_admission_queue_billing_inventory.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_start_admission_dialog.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

const IpdAdmissionSummary _pending = IpdAdmissionSummary(
  id: 'adm-queue-bill',
  displayId: 'ADM-QB1',
  patientId: 'pat-queue-bill',
  patientDisplayName: 'Queue Billing Patient',
  stage: 'ADMISSION_REQUESTED',
  admissionStatus: 'REQUESTED',
  nextStep: 'APPROVE_ADMISSION',
  encounterId: 'enc-queue-bill',
);

const IpdReferenceData _referenceData = IpdReferenceData(
  wards: <IpdWardOption>[
    IpdWardOption(id: 'ward-a', name: 'Ward A', wardType: 'GENERAL'),
  ],
  availableBeds: <IpdBedOption>[
    IpdBedOption(
      id: 'bed-1',
      label: 'Bed 1',
      status: 'AVAILABLE',
      wardId: 'ward-a',
      wardName: 'Ward A',
      roomId: 'room-1',
      roomName: 'Room 1',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
  );
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['DOCTOR'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements:
          modules ??
          <AppModuleEntitlement>[
            const AppModuleEntitlement(
              code: 'inpatient-bed-management',
              licenseStatus: 'ACTIVE',
            ),
            if (needsClinical)
              const AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            if (needsOperations)
              const AppModuleEntitlement(
                code: 'facilities-maintenance',
                licenseStatus: 'ACTIVE',
              ),
            if (needsBilling)
              const AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubIpd(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    return Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[_pending],
        request: query.pageRequest,
        totalItemCount: 1,
      ),
    );
  });
  when(() => repository.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(
      <IpdWardOption>[
        IpdWardOption(id: 'ward-a', name: 'Ward A', wardType: 'GENERAL'),
      ],
    ),
  );
  when(
    () => repository.listBeds(
      search: any(named: 'search'),
      status: any(named: 'status'),
      wardId: any(named: 'wardId'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedOption>>.success(
      <IpdBedOption>[
        IpdBedOption(
          id: 'bed-1',
          label: 'Bed 1',
          status: 'AVAILABLE',
          wardId: 'ward-a',
          wardName: 'Ward A',
          roomId: 'room-1',
          roomName: 'Room 1',
        ),
      ],
    ),
  );
  when(
    () => repository.listBedBoard(
      wardId: any(named: 'wardId'),
      status: any(named: 'status'),
      statusAny: any(named: 'statusAny'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<List<IpdBedBoardEntry>>.success(<IpdBedBoardEntry>[]),
  );
  when(() => repository.getAdmission(any())).thenAnswer(
    (_) async => Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(summary: _pending),
    ),
  );
}

Future<void> _pumpAdmissionQueue(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubIpd(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/ipd?section=admission-queue',
    routes: <RouteBase>[
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IpdWorkspacePage(
              initialQuery: IpdAdmissionQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('Billing workspace')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ipdRepositoryProvider.overrideWithValue(repository),
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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(
      const PatientListQuery(pageRequest: AppPageRequest(pageSize: 12)),
    );
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('Admission Queue billing inventory (AC1)', () {
    test('every atom is classified billable or explicit not-billable', () {
      expect(IpdAdmissionQueueBillingInventory.all, isNotEmpty);
      for (final IpdAdmissionQueueFinancialAtom atom
          in IpdAdmissionQueueBillingInventory.all) {
        final bool billable =
            atom.financialClass ==
                IpdAdmissionQueueFinancialClass.createCharge ||
            atom.financialClass == IpdAdmissionQueueFinancialClass.settle ||
            atom.financialClass == IpdAdmissionQueueFinancialClass.adjust ||
            atom.financialClass == IpdAdmissionQueueFinancialClass.reverse ||
            atom.financialClass == IpdAdmissionQueueFinancialClass.defer;
        if (billable && atom.mounted) {
          expect(
            atom.billingPath,
            isNotNull,
            reason: '${atom.id} must declare billingPath',
          );
        }
        if (!billable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} must declare NOT_* audit code',
          );
        }
      }
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      for (final IpdAdmissionQueueFinancialAtom atom
          in IpdAdmissionQueueBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('clinical-request'),
            contains('admission'),
            contains('ward-round'),
            contains('icu'),
            contains('discharge'),
          ),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(IpdAdmissionQueueBillingInventory.collectPayment.mounted, isFalse);
      expect(IpdAdmissionQueueBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        IpdAdmissionQueueBillingInventory.forbidsInlineCashier(
          IpdAdmissionQueueFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('start admission atom wires persistAdmissionBilling path', () {
      expect(
        IpdAdmissionQueueBillingInventory.startAdmission.billingPath,
        contains('persistAdmissionBilling'),
      );
      expect(
        IpdAdmissionQueueBillingInventory.startAdmission.financialClass,
        IpdAdmissionQueueFinancialClass.createCharge,
      );
    });
  });

  group('Admission Queue billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized queue has no collect/adjust; Start admission mounts',
      (WidgetTester tester) async {
        await _pumpAdmissionQueue(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.operationsWrite,
            },
          ),
        );

        expect(find.textContaining('Admission Queue'), findsWidgets);
        expect(find.textContaining('Start admission'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing panel absent without billing:read on start dialog',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        final _MockPatientRepository patients = _MockPatientRepository();
        when(() => patients.listPatients(any())).thenAnswer(
          (Invocation invocation) async => Result<AppPage<Patient>>.success(
            AppPage<Patient>(
              items: const <Patient>[],
              request:
                  (invocation.positionalArguments.single as PatientListQuery)
                      .pageRequest,
              totalItemCount: 0,
            ),
          ),
        );
        _stubIpd(repository);

        final AppAccessPolicy policy = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.operationsWrite,
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ipdRepositoryProvider.overrideWithValue(repository),
              patientRepositoryProvider.overrideWithValue(patients),
              sharedPreferencesProvider.overrideWithValue(preferences),
              initialSessionStateProvider.overrideWithValue(
                const SessionState.ready(),
              ),
              appAccessPolicyProvider.overrideWithValue(policy),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: IpdStartAdmissionDialog(referenceData: _referenceData),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(IpdStartAdmissionDialog), findsOneWidget);
        expect(find.byType(ClinicalRequestBillingPanel), findsNothing);
        expect(find.text('Admission fee'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing panel mounts with billing:read; flat sections on dialog',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        final _MockPatientRepository patients = _MockPatientRepository();
        when(() => patients.listPatients(any())).thenAnswer(
          (Invocation invocation) async => Result<AppPage<Patient>>.success(
            AppPage<Patient>(
              items: const <Patient>[],
              request:
                  (invocation.positionalArguments.single as PatientListQuery)
                      .pageRequest,
              totalItemCount: 0,
            ),
          ),
        );
        _stubIpd(repository);

        final AppAccessPolicy policy = _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.operationsWrite,
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ipdRepositoryProvider.overrideWithValue(repository),
              patientRepositoryProvider.overrideWithValue(patients),
              sharedPreferencesProvider.overrideWithValue(preferences),
              initialSessionStateProvider.overrideWithValue(
                const SessionState.ready(),
              ),
              appAccessPolicyProvider.overrideWithValue(policy),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: IpdStartAdmissionDialog(referenceData: _referenceData),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ClinicalRequestBillingPanel), findsOneWidget);
        expect(find.text('Admission fee'), findsOneWidget);
        expect(find.text('Admission deposit'), findsOneWidget);
        expect(find.text('Bed / day'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    test('unauthorized users cannot collect/adjust (inventory gates)', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IpdAdmissionQueueBillingInventory.collectPayment.requirement.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );
      expect(
        IpdAdmissionQueueBillingInventory.adjustRefund.requirement.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );
      expect(
        IpdAdmissionQueueAtomPermissions.billingPanel.isAllowed(clinicalOnly),
        isFalse,
      );
    });
  });

  group('Admission Queue flat sections (AC5)', () {
    testWidgets('desktop light: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpAdmissionQueue(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );
      expectFlatSections(tester);

      await tester.tap(find.text('Queue Billing Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile dark: flat sections', (WidgetTester tester) async {
      await _pumpAdmissionQueue(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );
      expectFlatSections(tester);
    });
  });
}
