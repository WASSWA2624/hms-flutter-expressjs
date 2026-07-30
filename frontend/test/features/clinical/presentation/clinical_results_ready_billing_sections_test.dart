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
import 'package:hosspi_hms/features/clinical/presentation/clinical_results_ready_billing_inventory.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

final ClinicalWorklistEntry _resultsReadyEncounter = ClinicalWorklistEntry(
  id: 'encounter-rr-1',
  sourceQueue: 'OPD',
  encounterId: 'encounter-rr-1',
  encounterPublicId: 'ENC-RR-1',
  patientId: 'patient-rr-1',
  patientPublicId: 'PAT-RR-1',
  patientDisplayName: 'Results Ready Patient',
  providerDisplayName: 'Dr Results',
  encounterType: 'OUTPATIENT',
  currentLocation: 'Clinic A',
  status: 'IN_CONSULTATION',
  stage: 'IN_CONSULTATION',
  resultsReady: true,
  updatedAt: DateTime.now(),
);

const ClinicalEncounterBundle _resultsReadyBundle = ClinicalEncounterBundle(
  entry: ClinicalWorklistEntry(
    id: 'encounter-rr-1',
    sourceQueue: 'OPD',
    encounterId: 'encounter-rr-1',
    encounterPublicId: 'ENC-RR-1',
    patientId: 'patient-rr-1',
    patientPublicId: 'PAT-RR-1',
    patientDisplayName: 'Results Ready Patient',
    providerDisplayName: 'Dr Results',
    encounterType: 'OUTPATIENT',
    currentLocation: 'Clinic A',
    status: 'IN_CONSULTATION',
    stage: 'IN_CONSULTATION',
    resultsReady: true,
  ),
  labOrders: <ClinicalRelatedRecord>[
    ClinicalRelatedRecord(
      id: 'lab-1',
      kind: 'lab_order',
      title: 'CBC',
      status: 'RESULTED',
    ),
  ],
  radiologyOrders: <ClinicalRelatedRecord>[
    ClinicalRelatedRecord(
      id: 'rad-1',
      kind: 'radiology_order',
      title: 'Chest X-Ray',
      status: 'REPORTED',
    ),
  ],
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

void _stubClinical(_MockClinicalRepository repository) {
  when(() => repository.listEncounters(any())).thenAnswer((invocation) async {
    return Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: <ClinicalWorklistEntry>[_resultsReadyEncounter],
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: 1,
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
        const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
  );
  when(() => repository.loadEncounterBundle(any())).thenAnswer((invocation) {
    final ClinicalWorklistEntry entry =
        invocation.positionalArguments.single as ClinicalWorklistEntry;
    return Future<Result<ClinicalEncounterBundle>>.value(
      Result<ClinicalEncounterBundle>.success(
        ClinicalEncounterBundle(
          entry: entry.copyWith(resultsReady: true),
          labOrders: _resultsReadyBundle.labOrders,
          radiologyOrders: _resultsReadyBundle.radiologyOrders,
        ),
      ),
    );
  });
}

void _stubOpd(_MockOpdRepository repository) {
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
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

Future<void> _pumpResultsReadyTab(
  WidgetTester tester, {
  required _MockClinicalRepository clinicalRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockOpdRepository opdRepository = _MockOpdRepository();
  final _MockIpdRepository ipdRepository = _MockIpdRepository();
  _stubClinical(clinicalRepository);
  _stubOpd(opdRepository);
  _stubIpd(ipdRepository);

  tester.view.physicalSize = physicalSize;
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
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockClinicalRepository clinicalRepository;

  setUpAll(() {
    registerFallbackValue(const ClinicalWorklistQuery());
    registerFallbackValue(_resultsReadyEncounter);
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    clinicalRepository = _MockClinicalRepository();
  });

  group('Results ready financial inventory (AC1)', () {
    test('every atom is classified billable or explicit not-billable', () {
      expect(ClinicalResultsReadyBillingInventory.all, isNotEmpty);
      for (final ClinicalResultsReadyFinancialAtom atom
          in ClinicalResultsReadyBillingInventory.all) {
        if (atom.financialClass ==
                ClinicalResultsReadyFinancialClass.notRequired ||
            atom.financialClass ==
                ClinicalResultsReadyFinancialClass.notBilled ||
            atom.financialClass == ClinicalResultsReadyFinancialClass.noCharge) {
          expect(
            atom.auditCode,
            isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
            reason: atom.id,
          );
        } else if (atom.mounted) {
          expect(atom.billingPath, isNotNull, reason: atom.id);
        }
      }
      expect(
        ClinicalResultsReadyBillingInventory.allBillableMountedUseSharedBilling,
        isTrue,
      );
      expect(clinicalResultsReadyBillingScopeNote, contains('clinical-request-billing'));
    });

    test('lab/radiology/pharmacy/procedure are create-charge via Billing', () {
      expect(
        ClinicalResultsReadyBillingInventory.requestLab.financialClass,
        ClinicalResultsReadyFinancialClass.createCharge,
      );
      expect(
        ClinicalResultsReadyBillingInventory.requestRadiology.financialClass,
        ClinicalResultsReadyFinancialClass.createCharge,
      );
      expect(
        ClinicalResultsReadyBillingInventory.prescribe.financialClass,
        ClinicalResultsReadyFinancialClass.createCharge,
      );
      expect(
        ClinicalResultsReadyBillingInventory.recordProcedure.financialClass,
        ClinicalResultsReadyFinancialClass.createCharge,
      );
      expect(
        ClinicalResultsReadyBillingInventory.collectPayment.mounted,
        isFalse,
      );
    });
  });

  group('Results ready billing posting / no-bypass (AC2–AC4)', () {
    test('requestLab posts billing payload to createLabOrder', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      final _MockIpdRepository ipdRepository = _MockIpdRepository();
      _stubClinical(clinicalRepository);
      _stubOpd(opdRepository);
      _stubIpd(ipdRepository);
      when(
        () => clinicalRepository.createLabOrder(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));
      when(
        () => clinicalRepository.createClinicalTermFavorite(any()),
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
                AppPermissions.labWrite,
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
      await controller.selectEntry(_resultsReadyEncounter);

      final ClinicalRequestBillingSubmit billing =
          buildPendingClinicalRequestBillingSubmit(
            options: const <ClinicalCatalogOption>[
              ClinicalCatalogOption(
                id: 'lab-cbc',
                publicId: 'lab-cbc',
                name: 'CBC',
                unitPrice: 40,
                currency: 'USD',
              ),
            ],
            catalogType: 'LAB_TEST',
          );

      final AppFailure? failure = await controller.requestLab(
        labTestIds: const <String>['lab-cbc'],
        labPanelIds: const <String>[],
        billing: billing,
      );
      expect(failure, isNull);

      final Map<String, Object?> payload =
          verify(
                () => clinicalRepository.createLabOrder(captureAny()),
              ).captured.single
              as Map<String, Object?>;
      expect(payload['billing'], isA<Map<String, Object?>>());
      final Map<String, Object?> posted =
          payload['billing']! as Map<String, Object?>;
      expect(posted['payment_status'], 'PENDING');
      expect(posted['total_amount'], 40);
    });

    test('requestRadiology embeds billing in request_details', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      final _MockIpdRepository ipdRepository = _MockIpdRepository();
      _stubClinical(clinicalRepository);
      _stubOpd(opdRepository);
      _stubIpd(ipdRepository);
      when(
        () => clinicalRepository.createRadiologyOrder(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));
      when(
        () => clinicalRepository.createClinicalTermFavorite(any()),
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
                AppPermissions.radiologyWrite,
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
      await controller.selectEntry(_resultsReadyEncounter);

      final ClinicalRequestBillingSubmit billing =
          buildPendingClinicalRequestBillingSubmit(
            options: const <ClinicalCatalogOption>[
              ClinicalCatalogOption(
                id: 'rad-cxr',
                publicId: 'rad-cxr',
                name: 'Chest X-Ray',
                unitPrice: 55,
                currency: 'USD',
              ),
            ],
            catalogType: 'RADIOLOGY_TEST',
          );

      final AppFailure? failure = await controller.requestRadiology(
        requests: const <ClinicalRadiologyRequest>[
          ClinicalRadiologyRequest(radiologyTestId: 'rad-cxr'),
        ],
        billing: billing,
      );
      expect(failure, isNull);

      final Map<String, Object?> payload =
          verify(
                () => clinicalRepository.createRadiologyOrder(captureAny()),
              ).captured.single
              as Map<String, Object?>;
      final List<Object?> tests =
          payload['requested_tests']! as List<Object?>;
      final Map<String, Object?> first = tests.first! as Map<String, Object?>;
      final Map<String, Object?> details =
          first['request_details']! as Map<String, Object?>;
      expect(details['billing'], isA<Map<String, Object?>>());
      final Map<String, Object?> posted =
          details['billing']! as Map<String, Object?>;
      expect(posted['payment_status'], 'PENDING');
    });

    test('addProcedures auto-attaches pending billing when omitted', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      final _MockIpdRepository ipdRepository = _MockIpdRepository();
      _stubClinical(clinicalRepository);
      _stubOpd(opdRepository);
      _stubIpd(ipdRepository);
      when(
        () => clinicalRepository.createProcedure(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));
      when(
        () => clinicalRepository.createClinicalTermFavorite(any()),
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
      await controller.selectEntry(_resultsReadyEncounter);

      final AppFailure? failure = await controller.addProcedures(
        procedures: const <ClinicalCatalogOption>[
          ClinicalCatalogOption(
            id: 'proc-1',
            publicId: 'proc-1',
            code: '99213',
            name: 'Office visit',
            unitPrice: 80,
            currency: 'USD',
          ),
        ],
      );
      expect(failure, isNull);

      final Map<String, Object?> payload =
          verify(
                () => clinicalRepository.createProcedure(captureAny()),
              ).captured.single
              as Map<String, Object?>;
      expect(payload['billing'], isA<Map<String, Object?>>());
      final Map<String, Object?> posted =
          payload['billing']! as Map<String, Object?>;
      expect(posted['payment_status'], 'PENDING');
      expect(posted['total_amount'], 80);
    });

    test('pending billing payload is idempotent on replay shape', () {
      final ClinicalRequestBillingSubmit billing =
          buildPendingClinicalRequestBillingSubmit(
            options: const <ClinicalCatalogOption>[
              ClinicalCatalogOption(
                id: 'lab-1',
                name: 'Glucose',
                unitPrice: 12,
                currency: 'USD',
              ),
            ],
            catalogType: 'LAB_TEST',
          );
      expect(billing.toPayloadMap(), billing.toPayloadMap());
    });

    testWidgets(
      'unauthorized user has no Receive payment / Adjust on Results ready',
      (WidgetTester tester) async {
        await _pumpResultsReadyTab(
          tester,
          clinicalRepository: clinicalRepository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
        );

        await tester.tap(find.text('Results Ready Patient'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Adjust balance'), findsNothing);
        expect(find.textContaining('Write off'), findsNothing);
        expect(find.text('Request lab'), findsNothing);
      },
    );

    testWidgets(
      'clinical write without billing:write still opens order actions (no cashier)',
      (WidgetTester tester) async {
        await _pumpResultsReadyTab(
          tester,
          clinicalRepository: clinicalRepository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.labWrite,
              AppPermissions.radiologyWrite,
            },
          ),
        );

        await tester.tap(find.text('Results Ready Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Request lab'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
      },
    );
  });

  group('Results ready flat sections (AC5)', () {
    testWidgets('desktop light: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpResultsReadyTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.labWrite,
            AppPermissions.radiologyWrite,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.light,
      );

      expectFlatTitledSectionLayout(tester);
      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('mobile dark: flat sections on detail', (
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
        themeMode: ThemeMode.dark,
      );

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();
      expectFlatTitledSectionLayout(tester);
    });

    testWidgets('procedure dialog keeps flat section layout', (
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

      await tester.tap(find.text('Results Ready Patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request procedure').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.textContaining('Review billing'), findsOneWidget);
      expectFlatTitledSectionLayout(tester);
    });
  });
}
