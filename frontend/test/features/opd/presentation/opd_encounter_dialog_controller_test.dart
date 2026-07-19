import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_encounter_dialog_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  const Patient patient = Patient(
    id: 'patient-internal',
    publicId: 'PAT000001',
    tenantId: 'TEN000001',
    facilityId: 'FAC000001',
    firstName: 'Ada',
    lastName: 'Lovelace',
  );

  const OpdFlowDetail detail = OpdFlowDetail(
    summary: OpdFlowSummary(
      id: 'encounter-1',
      publicId: 'ENC000001',
      facilityId: 'FAC000001',
      patientId: 'PAT000001',
      status: 'OPEN',
      stage: 'WAITING_VITALS',
    ),
  );

  group('OpdEncounterDialogController', () {
    test('submitPatientEncounter starts a new OPD flow', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      Map<String, Object?>? submittedPayload;
      when(
        () => opdRepository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((Invocation invocation) async {
        submittedPayload =
            invocation.positionalArguments.single as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(detail);
      });

      final ProviderContainer container = _testContainer(
        opdRepository: opdRepository,
      );
      addTearDown(container.dispose);

      final Result<OpdFlowDetail> result = await container
          .read(opdEncounterDialogControllerProvider)
          .submitPatientEncounter(patient, <String, Object?>{
            'arrival_mode': 'WALK_IN',
            'patient_id': 'PAT000001',
          });

      expect(result.isSuccess, isTrue);
      expect(submittedPayload, containsPair('arrival_mode', 'WALK_IN'));
      expect(submittedPayload, containsPair('patient_id', 'PAT000001'));
      expect(submittedPayload, containsPair('tenant_id', 'TEN000001'));
      expect(submittedPayload, containsPair('facility_id', 'FAC000001'));
      verifyNever(() => opdRepository.updateActiveEncounter(any(), any()));
    });

    test('submitEncounter starts from appointment-only context', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      Map<String, Object?>? submittedPayload;
      when(
        () => opdRepository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((Invocation invocation) async {
        submittedPayload =
            invocation.positionalArguments.single as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(detail);
      });

      final ProviderContainer container = _testContainer(
        opdRepository: opdRepository,
      );
      addTearDown(container.dispose);

      final Result<OpdFlowDetail> result = await container
          .read(opdEncounterDialogControllerProvider)
          .submitEncounter(<String, Object?>{
            'appointment_id': 'APT000001',
            'arrival_mode': 'ONLINE_APPOINTMENT',
          });

      expect(result.isSuccess, isTrue);
      expect(submittedPayload, containsPair('appointment_id', 'APT000001'));
      expect(
        submittedPayload,
        containsPair('arrival_mode', 'ONLINE_APPOINTMENT'),
      );
      verifyNever(() => opdRepository.updateActiveEncounter(any(), any()));
    });

    test(
      'submitPatientEncounter updates an existing active encounter',
      () async {
        final _MockOpdRepository opdRepository = _MockOpdRepository();
        Map<String, Object?>? submittedPayload;
        when(
          () => opdRepository.updateActiveEncounter(
            any(),
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((Invocation invocation) async {
          submittedPayload =
              invocation.positionalArguments[1] as Map<String, Object?>;
          return const Result<OpdFlowDetail>.success(detail);
        });

        final ProviderContainer container = _testContainer(
          opdRepository: opdRepository,
        );
        addTearDown(container.dispose);

        final Result<OpdFlowDetail> result = await container
            .read(opdEncounterDialogControllerProvider)
            .submitPatientEncounter(patient, <String, Object?>{
              'existing_encounter_id': 'ENC000001',
              'arrival_mode': 'WALK_IN',
            });

        expect(result.isSuccess, isTrue);
        expect(submittedPayload, containsPair('arrival_mode', 'WALK_IN'));
        expect(submittedPayload, isNot(contains('existing_encounter_id')));
        verify(
          () => opdRepository.updateActiveEncounter(
            'ENC000001',
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).called(1);
        verifyNever(
          () => opdRepository.startOpdFlow(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        );
      },
    );

    test('cancelEncounter failure returns failure without success', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      when(() => opdRepository.cancelEncounter(any(), any())).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
      );

      final ProviderContainer container = _testContainer(
        opdRepository: opdRepository,
      );
      addTearDown(container.dispose);

      final Result<OpdFlowDetail> result = await container
          .read(opdEncounterDialogControllerProvider)
          .cancelEncounter('ENC000001', <String, Object?>{
            'reason_code': 'PATIENT_LEFT',
          });

      expect(result.isFailure, isTrue);
      verify(
        () => opdRepository.cancelEncounter('ENC000001', <String, Object?>{
          'reason_code': 'PATIENT_LEFT',
        }),
      ).called(1);
    });

    test(
      'cancelEncounter success returns persisted cancelled detail',
      () async {
        final _MockOpdRepository opdRepository = _MockOpdRepository();
        const OpdFlowDetail cancelled = OpdFlowDetail(
          summary: OpdFlowSummary(
            id: 'encounter-1',
            publicId: 'ENC000001',
            facilityId: 'FAC000001',
            patientId: 'PAT000001',
            status: 'CANCELLED',
            stage: 'CANCELLED',
          ),
        );
        when(() => opdRepository.cancelEncounter(any(), any())).thenAnswer(
          (_) async => const Result<OpdFlowDetail>.success(cancelled),
        );

        final ProviderContainer container = _testContainer(
          opdRepository: opdRepository,
        );
        addTearDown(container.dispose);

        final Result<OpdFlowDetail> result = await container
            .read(opdEncounterDialogControllerProvider)
            .cancelEncounter('ENC000001', <String, Object?>{
              'reason_code': 'DUPLICATE_ENCOUNTER',
              'reason_notes': 'Superseded',
            });

        expect(result.isSuccess, isTrue);
        result.when(
          success: (OpdFlowDetail value) {
            expect(value.summary.publicId, 'ENC000001');
            expect(value.summary.status, 'CANCELLED');
          },
          failure: (_) => fail('expected success'),
        );
        verify(
          () => opdRepository.cancelEncounter('ENC000001', <String, Object?>{
            'reason_code': 'DUPLICATE_ENCOUNTER',
            'reason_notes': 'Superseded',
          }),
        ).called(1);
      },
    );

    test('closeEncounter success returns persisted detail', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      Map<String, Object?>? submittedPayload;
      when(() => opdRepository.closeEncounter(any(), any())).thenAnswer((
        Invocation invocation,
      ) async {
        submittedPayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(detail);
      });

      final ProviderContainer container = _testContainer(
        opdRepository: opdRepository,
      );
      addTearDown(container.dispose);

      final Result<OpdFlowDetail> result = await container
          .read(opdEncounterDialogControllerProvider)
          .closeEncounter('ENC000001', <String, Object?>{
            'reason_notes': 'Consultation completed',
          });

      expect(result.isSuccess, isTrue);
      expect(
        submittedPayload,
        containsPair('reason_notes', 'Consultation completed'),
      );
      verify(
        () => opdRepository.closeEncounter('ENC000001', <String, Object?>{
          'reason_notes': 'Consultation completed',
        }),
      ).called(1);
      result.when(
        success: (OpdFlowDetail value) {
          expect(value.summary.publicId, 'ENC000001');
        },
        failure: (_) => fail('expected success'),
      );
    });

    test('closeEncounter failure patches nothing', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      when(() => opdRepository.closeEncounter(any(), any())).thenAnswer(
        (_) async => Result<OpdFlowDetail>.failure(AppFailure.validation()),
      );

      final ProviderContainer container = _testContainer(
        opdRepository: opdRepository,
      );
      addTearDown(container.dispose);

      final Result<OpdFlowDetail> result = await container
          .read(opdEncounterDialogControllerProvider)
          .closeEncounter('ENC000001', <String, Object?>{
            'reason_notes': 'Incomplete',
          });

      expect(result.isFailure, isTrue);
      verify(
        () => opdRepository.closeEncounter('ENC000001', <String, Object?>{
          'reason_notes': 'Incomplete',
        }),
      ).called(1);
    });

    test(
      'listProviderSchedules and listAppointments delegate to repository',
      () async {
        final _MockOpdRepository opdRepository = _MockOpdRepository();
        const OpdProviderSchedule schedule = OpdProviderSchedule(
          id: 'schedule-1',
          providerUserId: 'USR000001',
        );
        const OpdAppointment appointment = OpdAppointment(
          id: 'appointment-1',
          publicId: 'APT000001',
          status: 'SCHEDULED',
        );
        when(() => opdRepository.listProviderSchedules()).thenAnswer(
          (_) async => const Result<List<OpdProviderSchedule>>.success(
            <OpdProviderSchedule>[schedule],
          ),
        );
        when(() => opdRepository.listAppointments(any())).thenAnswer(
          (_) async => const Result<AppPage<OpdAppointment>>.success(
            AppPage<OpdAppointment>(
              items: <OpdAppointment>[appointment],
              request: AppPageRequest(),
              totalItemCount: 1,
            ),
          ),
        );

        final ProviderContainer container = _testContainer(
          opdRepository: opdRepository,
        );
        addTearDown(container.dispose);
        final OpdEncounterDialogController controller = container.read(
          opdEncounterDialogControllerProvider,
        );

        final Result<List<OpdProviderSchedule>> schedules = await controller
            .listProviderSchedules();
        final Result<AppPage<OpdAppointment>> appointments = await controller
            .listAppointments(const OpdAppointmentQuery(search: 'PAT000001'));

        expect(schedules.isSuccess, isTrue);
        expect(appointments.isSuccess, isTrue);
        schedules.when(
          success: (List<OpdProviderSchedule> value) {
            expect(value.single.id, 'schedule-1');
          },
          failure: (_) => fail('expected schedules success'),
        );
        appointments.when(
          success: (AppPage<OpdAppointment> value) {
            expect(value.items.single.publicId, 'APT000001');
          },
          failure: (_) => fail('expected appointments success'),
        );
      },
    );

    test(
      'loadClinicalReferenceData and searchClinicalTerms delegate',
      () async {
        final _MockOpdRepository opdRepository = _MockOpdRepository();
        final _MockClinicalRepository clinicalRepository =
            _MockClinicalRepository();
        const ClinicalCatalogOption term = ClinicalCatalogOption(
          id: 'TERM000001',
          code: 'J06.9',
          name: 'Upper respiratory infection',
        );
        when(() => clinicalRepository.loadReferenceData()).thenAnswer(
          (_) async => const Result<ClinicalReferenceData>.success(
            ClinicalReferenceData(),
          ),
        );
        when(
          () => clinicalRepository.searchClinicalTerms(
            termType: any(named: 'termType'),
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            source: any(named: 'source'),
            facilityId: any(named: 'facilityId'),
          ),
        ).thenAnswer(
          (_) async => const Result<List<ClinicalCatalogOption>>.success(
            <ClinicalCatalogOption>[term],
          ),
        );

        final ProviderContainer container = _testContainer(
          opdRepository: opdRepository,
          clinicalRepository: clinicalRepository,
        );
        addTearDown(container.dispose);
        final OpdEncounterDialogController controller = container.read(
          opdEncounterDialogControllerProvider,
        );

        final Result<ClinicalReferenceData> reference = await controller
            .loadClinicalReferenceData();
        final Result<List<ClinicalCatalogOption>> terms = await controller
            .searchClinicalTerms(
              termType: 'DIAGNOSIS',
              query: 'uri',
              limit: 20,
            );

        expect(reference.isSuccess, isTrue);
        expect(terms.isSuccess, isTrue);
        terms.when(
          success: (List<ClinicalCatalogOption> value) {
            expect(value.single.code, 'J06.9');
          },
          failure: (_) => fail('expected clinical term search success'),
        );
        verify(() => clinicalRepository.loadReferenceData()).called(1);
        verify(
          () => clinicalRepository.searchClinicalTerms(
            termType: 'DIAGNOSIS',
            query: 'uri',
            limit: 20,
            source: 'ALL',
            facilityId: any(named: 'facilityId'),
          ),
        ).called(1);
      },
    );

    test(
      'resolveConsultationBillingLineItems returns fallback without tenant',
      () async {
        final _MockOpdRepository opdRepository = _MockOpdRepository();
        const ClinicalRequestBillingLineItem fallback =
            ClinicalRequestBillingLineItem(
              id: 'CONSULTATION',
              label: 'Consultation fee',
              unitPrice: 25000,
              catalogType: 'CONSULTATION',
              billingEntity: 'FACILITY',
              currency: 'UGX',
            );

        final ProviderContainer container = _testContainer(
          opdRepository: opdRepository,
        );
        addTearDown(container.dispose);

        final List<ClinicalRequestBillingLineItem> resolved = await container
            .read(opdEncounterDialogControllerProvider)
            .resolveConsultationBillingLineItems(
              catalogFallbackItems: const <ClinicalRequestBillingLineItem>[
                fallback,
              ],
            );

        expect(resolved, hasLength(1));
        expect(resolved.single.id, 'CONSULTATION');
        expect(resolved.single.unitPrice, 25000);
        expect(resolved.single.currency, 'UGX');
      },
    );

    test(
      'submitPatientEncounter patches loaded OPD workspace flows on success',
      () async {
        final _MockOpdRepository opdRepository = _MockOpdRepository();
        _stubWorkspaceInitialLoad(opdRepository);
        when(
          () => opdRepository.startOpdFlow(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));

        final ProviderContainer container = _testContainer(
          opdRepository: opdRepository,
          seedWorkspace: true,
        );
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);

        final Result<OpdFlowDetail> result = await container
            .read(opdEncounterDialogControllerProvider)
            .submitPatientEncounter(patient, <String, Object?>{
              'arrival_mode': 'WALK_IN',
              'patient_id': 'PAT000001',
            });

        expect(result.isSuccess, isTrue);
        final OpdWorkspaceState state = _requireWorkspaceState(container);
        expect(
          state.flows.items.any(
            (OpdFlowSummary flow) => flow.publicId == 'ENC000001',
          ),
          isTrue,
        );
        expect(state.selectedFlow?.summary.publicId, 'ENC000001');
      },
    );

    test(
      'cancelEncounter failure leaves loaded OPD workspace flows unchanged',
      () async {
        final _MockOpdRepository opdRepository = _MockOpdRepository();
        const OpdFlowSummary existing = OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          facilityId: 'FAC000001',
          patientId: 'PAT000001',
          status: 'OPEN',
          stage: 'WAITING_VITALS',
        );
        _stubWorkspaceInitialLoad(
          opdRepository,
          flows: <OpdFlowSummary>[existing],
        );
        when(() => opdRepository.cancelEncounter(any(), any())).thenAnswer(
          (_) async =>
              const Result<OpdFlowDetail>.failure(AppFailure.network()),
        );

        final ProviderContainer container = _testContainer(
          opdRepository: opdRepository,
          seedWorkspace: true,
        );
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);

        final Result<OpdFlowDetail> result = await container
            .read(opdEncounterDialogControllerProvider)
            .cancelEncounter('ENC000001', <String, Object?>{
              'reason_code': 'PATIENT_LEFT',
            });

        expect(result.isFailure, isTrue);
        final OpdWorkspaceState state = _requireWorkspaceState(container);
        expect(state.flows.items, hasLength(1));
        expect(state.flows.items.single.status, 'OPEN');
        expect(state.flows.items.single.stage, 'WAITING_VITALS');
      },
    );

    test(
      'cancelEncounter success patches loaded OPD workspace terminal flow',
      () async {
        final _MockOpdRepository opdRepository = _MockOpdRepository();
        const OpdFlowSummary existing = OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          facilityId: 'FAC000001',
          patientId: 'PAT000001',
          status: 'OPEN',
          stage: 'WAITING_VITALS',
        );
        const OpdFlowDetail cancelled = OpdFlowDetail(
          summary: OpdFlowSummary(
            id: 'encounter-1',
            publicId: 'ENC000001',
            facilityId: 'FAC000001',
            patientId: 'PAT000001',
            status: 'CANCELLED',
            stage: 'CANCELLED',
          ),
        );
        _stubWorkspaceInitialLoad(
          opdRepository,
          flows: <OpdFlowSummary>[existing],
        );
        when(() => opdRepository.cancelEncounter(any(), any())).thenAnswer(
          (_) async => const Result<OpdFlowDetail>.success(cancelled),
        );

        final ProviderContainer container = _testContainer(
          opdRepository: opdRepository,
          seedWorkspace: true,
        );
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);

        final Result<OpdFlowDetail> result = await container
            .read(opdEncounterDialogControllerProvider)
            .cancelEncounter('ENC000001', <String, Object?>{
              'reason_code': 'PATIENT_LEFT',
            });

        expect(result.isSuccess, isTrue);
        final OpdWorkspaceState state = _requireWorkspaceState(container);
        expect(
          state.flows.items.any(
            (OpdFlowSummary flow) => flow.publicId == 'ENC000001',
          ),
          isFalse,
        );
        expect(state.selectedFlow, isNull);
      },
    );
  });
}

OpdWorkspaceState _requireWorkspaceState(ProviderContainer container) {
  final AsyncValue<Result<OpdWorkspaceState>> asyncValue = container.read(
    opdWorkspaceControllerProvider,
  );
  final Result<OpdWorkspaceState>? result = asyncValue.asData?.value;
  if (result == null) {
    throw StateError('workspace not loaded');
  }
  return switch (result) {
    ResultSuccess<OpdWorkspaceState>(:final OpdWorkspaceState value) => value,
    ResultFailure<OpdWorkspaceState>() => throw StateError('workspace failed'),
  };
}

ProviderContainer _testContainer({
  required _MockOpdRepository opdRepository,
  _MockClinicalRepository? clinicalRepository,
  bool seedWorkspace = false,
}) {
  final _MockPatientRepository patientRepository = _MockPatientRepository();
  final _MockClinicalRepository effectiveClinical =
      clinicalRepository ?? _MockClinicalRepository();
  final InsuranceCatalogRepository insuranceCatalogRepository =
      InsuranceCatalogRepository(apiClient: _MockApiClient());
  return ProviderContainer(
    overrides: [
      if (seedWorkspace)
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
      opdRepositoryProvider.overrideWithValue(opdRepository),
      patientRepositoryProvider.overrideWithValue(patientRepository),
      clinicalRepositoryProvider.overrideWithValue(effectiveClinical),
      insuranceCatalogRepositoryProvider.overrideWithValue(
        insuranceCatalogRepository,
      ),
    ],
  );
}

void _stubWorkspaceInitialLoad(
  _MockOpdRepository repository, {
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[],
}) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: const <OpdAppointment>[],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: const <OpdQueueEntry>[],
        request: (invocation.positionalArguments.single as OpdQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: flows,
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: flows.length,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async =>
        const Result<OpdFlowAggregateCounts>.success(OpdFlowAggregateCounts()),
  );
  when(
    () => repository.listClinicalAlertThresholds(
      vitalType: any(named: 'vitalType'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
      <OpdClinicalAlertThreshold>[],
    ),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
}
