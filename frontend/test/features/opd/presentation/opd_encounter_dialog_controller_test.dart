import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_encounter_dialog_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdFlowQuery());
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

    test('submitPatientEncounter updates an existing active encounter', () async {
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
    });

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

    test('closeEncounter success returns persisted detail', () async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      when(() => opdRepository.closeEncounter(any(), any())).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.success(detail),
      );

      final ProviderContainer container = _testContainer(
        opdRepository: opdRepository,
      );
      addTearDown(container.dispose);

      final Result<OpdFlowDetail> result = await container
          .read(opdEncounterDialogControllerProvider)
          .closeEncounter('ENC000001', <String, Object?>{
            'disposition': 'HOME',
          });

      expect(result.isSuccess, isTrue);
      result.when(
        success: (OpdFlowDetail value) {
          expect(value.summary.publicId, 'ENC000001');
        },
        failure: (_) => fail('expected success'),
      );
    });

    test('listProviderSchedules and listAppointments delegate to repository', () async {
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
    });
  });
}

ProviderContainer _testContainer({required _MockOpdRepository opdRepository}) {
  final _MockPatientRepository patientRepository = _MockPatientRepository();
  final InsuranceCatalogRepository insuranceCatalogRepository =
      InsuranceCatalogRepository(apiClient: _MockApiClient());
  return ProviderContainer(
    overrides: [
      opdRepositoryProvider.overrideWithValue(opdRepository),
      patientRepositoryProvider.overrideWithValue(patientRepository),
      insuranceCatalogRepositoryProvider.overrideWithValue(
        insuranceCatalogRepository,
      ),
    ],
  );
}
