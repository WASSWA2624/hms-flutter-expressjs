import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  group('OpdWorkspaceController', () {
    test('checkInAppointment starts an appointment-backed OPD flow', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdAppointment appointment = OpdAppointment(
        id: 'appointment-1',
        publicId: 'APT000001',
        facilityId: 'FAC000001',
        patientId: 'PAT000001',
        providerUserId: 'DOC000001',
        status: 'SCHEDULED',
      );
      const OpdFlowDetail detail = OpdFlowDetail(
        summary: OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          facilityId: 'FAC000001',
          patientId: 'PAT000001',
          providerUserId: 'DOC000001',
          encounterType: 'OPD',
          status: 'OPEN',
          stage: 'WAITING_VITALS',
          appointmentId: 'appointment-1',
        ),
        consultationPaymentRequired: true,
      );
      Map<String, Object?>? submittedPayload;

      _stubInitialLoad(repository, appointments: <OpdAppointment>[appointment]);
      when(() => repository.startOpdFlow(any())).thenAnswer((invocation) async {
        submittedPayload =
            invocation.positionalArguments.single as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(detail);
      });
      when(
        () => repository.getOpdFlow(any()),
      ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));

      final ProviderContainer container = ProviderContainer(
        overrides: [opdRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .checkInAppointment(appointment);

      expect(failure, isNull);
      expect(
        submittedPayload,
        containsPair('arrival_mode', 'ONLINE_APPOINTMENT'),
      );
      expect(submittedPayload, containsPair('appointment_id', 'APT000001'));
      expect(submittedPayload, containsPair('facility_id', 'FAC000001'));
      expect(submittedPayload, containsPair('provider_user_id', 'DOC000001'));
      expect(
        DateTime.tryParse(submittedPayload?['queued_at'] as String),
        isNotNull,
      );
      verifyNever(() => repository.updateAppointment(any(), any()));
    });
  });
}

void _stubInitialLoad(
  _MockOpdRepository repository, {
  List<OpdAppointment> appointments = const <OpdAppointment>[],
  List<OpdQueueEntry> queueEntries = const <OpdQueueEntry>[],
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[],
  List<OpdFlowSummary> triageQueue = const <OpdFlowSummary>[],
}) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: appointments,
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: appointments.length,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: queueEntries,
        request: (invocation.positionalArguments.single as OpdQueueQuery)
            .pageRequest,
        totalItemCount: queueEntries.length,
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: flows,
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: flows.length,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: triageQueue,
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: triageQueue.length,
      ),
    ),
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
