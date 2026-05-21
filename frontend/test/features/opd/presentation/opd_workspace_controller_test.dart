import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
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

    test('disposeFlow sends route context for triage decisions', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        providerUserId: 'DOC000001',
        stage: 'WAITING_DOCTOR_ASSIGNMENT',
        triageLevel: 'LEVEL_2',
      );
      const OpdFlowDetail detail = OpdFlowDetail(summary: flow);
      Map<String, Object?>? submittedPayload;

      _stubInitialLoad(
        repository,
        flows: <OpdFlowSummary>[flow],
        triageQueue: <OpdFlowSummary>[flow],
      );
      when(() => repository.routeTriage(any(), any())).thenAnswer((
        invocation,
      ) async {
        submittedPayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
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
      clearInteractions(repository);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .disposeFlow(
            flow,
            'CONSULTATION',
            'Priority review',
            providerUserId: 'DOC000001',
            triageLevel: 'LEVEL_2',
            emergency: true,
          );

      expect(failure, isNull);
      expect(submittedPayload, containsPair('route_to', 'CONSULTATION'));
      expect(submittedPayload, containsPair('provider_user_id', 'DOC000001'));
      expect(submittedPayload, containsPair('triage_level', 'LEVEL_2'));
      expect(submittedPayload, containsPair('emergency', true));
      expect(submittedPayload, containsPair('notes', 'Priority review'));
      verify(() => repository.listAppointments(any())).called(1);
      verify(() => repository.listVisitQueues(any())).called(1);
      verify(() => repository.listOpdFlows(any())).called(1);
      verify(() => repository.listTriageQueue(any())).called(1);
    });

    test('recordVitals uses the canonical OPD flow endpoint', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        stage: 'WAITING_VITALS',
      );
      const OpdFlowDetail detail = OpdFlowDetail(
        summary: OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          stage: 'WAITING_DOCTOR_ASSIGNMENT',
        ),
      );
      Map<String, Object?>? submittedPayload;

      _stubInitialLoad(repository, flows: <OpdFlowSummary>[flow]);
      when(
        () => repository.getOpdFlow(any()),
      ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));
      when(() => repository.recordVitals(any(), any())).thenAnswer((
        Invocation invocation,
      ) async {
        submittedPayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(detail);
      });

      final ProviderContainer container = ProviderContainer(
        overrides: [opdRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);
      clearInteractions(repository);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .recordVitals(flow, <String, Object?>{
            'vitals': <Map<String, Object?>>[
              <String, Object?>{'vital_type': 'TEMPERATURE', 'value': '37'},
            ],
          });

      expect(failure, isNull);
      expect(submittedPayload, containsPair('vitals', isA<List<Object?>>()));
      verify(() => repository.recordVitals('ENC000001', any())).called(1);
      verifyNever(() => repository.recordTriageVitals(any(), any()));
    });

    test('updateVitals sends an audit-safe update payload', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        stage: 'WAITING_DISPOSITION',
      );
      const OpdFlowDetail detail = OpdFlowDetail(summary: flow);
      Map<String, Object?>? submittedPayload;

      _stubInitialLoad(repository, flows: <OpdFlowSummary>[flow]);
      when(
        () => repository.getOpdFlow(any()),
      ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));
      when(() => repository.recordVitals(any(), any())).thenAnswer((
        Invocation invocation,
      ) async {
        submittedPayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(detail);
      });

      final ProviderContainer container = ProviderContainer(
        overrides: [opdRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);
      clearInteractions(repository);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .updateVitals(detail, <Map<String, Object?>>[
            <String, Object?>{'vital_type': 'TEMPERATURE', 'value': '37.2'},
          ]);

      expect(failure, isNull);
      expect(submittedPayload, containsPair('update_existing', true));
      verify(() => repository.recordVitals('ENC000001', any())).called(1);
      verifyNever(() => repository.updateVitals(detail, any()));
    });

    test('correctStage uses the canonical OPD correction endpoint', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        stage: 'WAITING_DOCTOR_REVIEW',
      );
      const OpdFlowDetail corrected = OpdFlowDetail(
        summary: OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          stage: 'WAITING_DISPOSITION',
        ),
      );
      Map<String, Object?>? submittedPayload;

      _stubInitialLoad(repository, flows: <OpdFlowSummary>[flow]);
      when(
        () => repository.getOpdFlow(any()),
      ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(corrected));
      when(() => repository.correctStage(any(), any())).thenAnswer((
        Invocation invocation,
      ) async {
        submittedPayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(corrected);
      });

      final ProviderContainer container = ProviderContainer(
        overrides: [opdRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);
      clearInteractions(repository);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .correctStage(flow, 'WAITING_DISPOSITION', 'Ready for discharge');

      expect(failure, isNull);
      expect(submittedPayload, containsPair('stage_to', 'WAITING_DISPOSITION'));
      expect(submittedPayload, containsPair('reason', 'Ready for discharge'));
      verify(() => repository.correctStage('ENC000001', any())).called(1);
      verifyNever(() => repository.correctTriageStage(any(), any()));
    });

    test(
      'updateLabOrder sends requested tests and refreshes encounter detail',
      () async {
        final _MockOpdRepository repository = _MockOpdRepository();
        const OpdFlowSummary flow = OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          stage: 'LAB_REQUESTED',
        );
        const OpdFlowDetail detail = OpdFlowDetail(
          summary: flow,
          labOrders: <OpdRelatedRecord>[
            OpdRelatedRecord(id: 'lab-order-1', kind: 'lab_order'),
          ],
        );
        Map<String, Object?>? submittedPayload;

        _stubInitialLoad(repository, flows: <OpdFlowSummary>[flow]);
        when(() => repository.updateLabOrder(any(), any())).thenAnswer((
          Invocation invocation,
        ) async {
          submittedPayload =
              invocation.positionalArguments[1] as Map<String, Object?>;
          return const Result<void>.success(null);
        });
        when(
          () => repository.getOpdFlow(any()),
        ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));

        final ProviderContainer container = ProviderContainer(
          overrides: [opdRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);
        clearInteractions(repository);

        final AppFailure? failure = await container
            .read(opdWorkspaceControllerProvider.notifier)
            .updateLabOrder(
              flow: flow,
              labOrderId: 'lab-order-1',
              labTestIds: <String>['lab-test-1'],
              labPanelIds: <String>['lab-panel-1'],
            );

        expect(failure, isNull);
        expect(
          submittedPayload?['requested_tests'],
          equals(<Map<String, Object?>>[
            <String, Object?>{'lab_test_id': 'lab-test-1'},
          ]),
        );
        expect(
          submittedPayload?['requested_panels'],
          equals(<Map<String, Object?>>[
            <String, Object?>{'lab_panel_id': 'lab-panel-1'},
          ]),
        );
        verify(() => repository.updateLabOrder('lab-order-1', any())).called(1);
        verify(() => repository.getOpdFlow('ENC000001')).called(1);
      },
    );
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
