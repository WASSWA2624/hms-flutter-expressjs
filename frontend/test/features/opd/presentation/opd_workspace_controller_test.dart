import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
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
      when(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        submittedPayload =
            invocation.positionalArguments.single as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(detail);
      });
      when(
        () => repository.getOpdFlow(any()),
      ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));

      final ProviderContainer container = _testContainer(repository);
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

    test(
      'assignAppointmentToQueue patches the persisted queue entry',
      () async {
        final _MockOpdRepository repository = _MockOpdRepository();
        const OpdAppointment appointment = OpdAppointment(
          id: 'appointment-internal',
          publicId: 'APT000001',
          tenantId: 'TEN000001',
          facilityId: 'FAC000001',
          patientId: 'PAT000001',
          providerUserId: 'USR000001',
          status: 'SCHEDULED',
        );
        const OpdQueueEntry queued = OpdQueueEntry(
          id: 'queue-internal',
          publicId: 'QUE000001',
          tenantId: 'TEN000001',
          facilityId: 'FAC000001',
          patientId: 'PAT000001',
          appointmentId: 'APT000001',
          providerUserId: 'USR000001',
          status: 'CONFIRMED',
        );
        Map<String, Object?>? submittedPayload;
        _stubInitialLoad(
          repository,
          appointments: <OpdAppointment>[appointment],
        );
        when(
          () => repository.createVisitQueue(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((Invocation invocation) async {
          submittedPayload =
              invocation.positionalArguments.single as Map<String, Object?>;
          return const Result<OpdQueueEntry>.success(queued);
        });

        final ProviderContainer container = _testContainer(repository);
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);

        final AppFailure? failure = await container
            .read(opdWorkspaceControllerProvider.notifier)
            .assignAppointmentToQueue(appointment);

        expect(failure, isNull);
        expect(_workspaceState(container).queueEntries.items, <OpdQueueEntry>[
          queued,
        ]);
        expect(submittedPayload, containsPair('tenant_id', 'TEN000001'));
        expect(submittedPayload, containsPair('facility_id', 'FAC000001'));
        expect(submittedPayload, containsPair('patient_id', 'PAT000001'));
        expect(submittedPayload, containsPair('appointment_id', 'APT000001'));
        expect(submittedPayload, containsPair('provider_user_id', 'USR000001'));
      },
    );

    test('rescheduleAppointment patches only the persisted response', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      final DateTime originalStart = DateTime.utc(2026, 7, 20, 8);
      final DateTime updatedStart = DateTime.utc(2026, 7, 21, 10);
      final DateTime updatedEnd = DateTime.utc(2026, 7, 21, 10, 30);
      final OpdAppointment appointment = OpdAppointment(
        id: 'appointment-internal',
        publicId: 'APT000001',
        status: 'SCHEDULED',
        scheduledStart: originalStart,
      );
      final OpdAppointment updated = appointment.copyWith(
        scheduledStart: updatedStart,
        scheduledEnd: updatedEnd,
      );
      Map<String, Object?>? submittedPayload;
      _stubInitialLoad(repository, appointments: <OpdAppointment>[appointment]);
      when(() => repository.updateAppointment(any(), any())).thenAnswer((
        Invocation invocation,
      ) async {
        submittedPayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return Result<OpdAppointment>.success(updated);
      });

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .rescheduleAppointment(appointment, updatedStart, updatedEnd);

      expect(failure, isNull);
      expect(
        _workspaceState(container).appointments.items.single.scheduledStart,
        updatedStart,
      );
      expect(
        submittedPayload,
        containsPair('scheduled_start', updatedStart.toIso8601String()),
      );
      expect(
        submittedPayload,
        containsPair('scheduled_end', updatedEnd.toIso8601String()),
      );
      verify(() => repository.updateAppointment('APT000001', any())).called(1);
    });

    test('rescheduleAppointment failure leaves the schedule unpatched', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      final DateTime originalStart = DateTime.utc(2026, 7, 20, 8);
      final DateTime updatedStart = DateTime.utc(2026, 7, 21, 10);
      final DateTime updatedEnd = DateTime.utc(2026, 7, 21, 10, 30);
      final OpdAppointment appointment = OpdAppointment(
        id: 'appointment-internal',
        publicId: 'APT000001',
        status: 'SCHEDULED',
        scheduledStart: originalStart,
      );
      _stubInitialLoad(repository, appointments: <OpdAppointment>[appointment]);
      when(() => repository.updateAppointment(any(), any())).thenAnswer(
        (_) async => Result<OpdAppointment>.failure(AppFailure.network()),
      );

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .rescheduleAppointment(appointment, updatedStart, updatedEnd);

      expect(failure, isA<AppFailure>());
      expect(
        _workspaceState(container).appointments.items.single.scheduledStart,
        originalStart,
      );
    });

    test('cancelAppointment patches the returned terminal row', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdAppointment appointment = OpdAppointment(
        id: 'appointment-internal',
        publicId: 'APT000001',
        status: 'SCHEDULED',
      );
      const OpdAppointment cancelled = OpdAppointment(
        id: 'appointment-internal',
        publicId: 'APT000001',
        status: 'CANCELLED',
      );
      _stubInitialLoad(repository, appointments: <OpdAppointment>[appointment]);
      when(() => repository.cancelAppointment(any(), any())).thenAnswer(
        (_) async => const Result<OpdAppointment>.success(cancelled),
      );

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .cancelAppointment(appointment, 'Patient request');

      expect(failure, isNull);
      expect(
        _workspaceState(container).appointments.items.single.status,
        'CANCELLED',
      );
      verify(
        () => repository.cancelAppointment('APT000001', 'Patient request'),
      ).called(1);
    });

    test('cancelAppointment sends null for blank cancellation reasons', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdAppointment appointment = OpdAppointment(
        id: 'appointment-internal',
        publicId: 'APT000001',
        status: 'SCHEDULED',
      );
      const OpdAppointment cancelled = OpdAppointment(
        id: 'appointment-internal',
        publicId: 'APT000001',
        status: 'CANCELLED',
      );
      _stubInitialLoad(repository, appointments: <OpdAppointment>[appointment]);
      when(() => repository.cancelAppointment(any(), any())).thenAnswer(
        (_) async => const Result<OpdAppointment>.success(cancelled),
      );

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .cancelAppointment(appointment, '   ');

      expect(failure, isNull);
      verify(() => repository.cancelAppointment('APT000001', null)).called(1);
    });

    test('failed appointment mutation leaves the row unchanged', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdAppointment appointment = OpdAppointment(
        id: 'appointment-internal',
        publicId: 'APT000001',
        status: 'SCHEDULED',
      );
      _stubInitialLoad(repository, appointments: <OpdAppointment>[appointment]);
      when(() => repository.cancelAppointment(any(), any())).thenAnswer(
        (_) async => const Result<OpdAppointment>.failure(AppFailure.network()),
      );

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .cancelAppointment(appointment, 'Patient request');

      expect(failure, isNotNull);
      expect(
        _workspaceState(container).appointments.items.single,
        same(appointment),
      );
    });

    test('submitOpdEncounter patches the persisted flow immediately', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdAppointment appointment = OpdAppointment(
        id: 'appointment-1',
        publicId: 'APT000001',
        status: 'SCHEDULED',
      );
      const OpdQueueEntry queueEntry = OpdQueueEntry(
        id: 'queue-1',
        publicId: 'QUE000001',
        status: 'WAITING',
      );
      const OpdFlowDetail detail = OpdFlowDetail(
        summary: OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          patientId: 'PAT000001',
          status: 'OPEN',
          stage: 'WAITING_VITALS',
          appointmentId: 'APT000001',
          visitQueueId: 'QUE000001',
        ),
      );
      _stubInitialLoad(
        repository,
        appointments: const <OpdAppointment>[appointment],
        queueEntries: const <OpdQueueEntry>[queueEntry],
      );
      when(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final Result<OpdFlowDetail> result = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .submitOpdEncounter(<String, Object?>{
            'patient_id': 'PAT000001',
            'arrival_mode': 'WALK_IN',
          });

      expect(result.isSuccess, isTrue);
      expect(_workspaceState(container).flows.items, contains(detail.summary));
      expect(
        _workspaceState(container).triageQueue.items,
        contains(detail.summary),
      );
      expect(_workspaceState(container).selectedFlow, detail);
      expect(
        _workspaceState(container).appointments.items.single.status,
        'IN_PROGRESS',
      );
      expect(
        _workspaceState(container).queueEntries.items.single.status,
        'IN_PROGRESS',
      );
    });

    test('submitOpdEncounter failure patches nothing', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdFlowSummary existing = OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        status: 'OPEN',
        stage: 'WAITING_VITALS',
      );
      _stubInitialLoad(
        repository,
        flows: const <OpdFlowSummary>[existing],
        triageQueue: const <OpdFlowSummary>[existing],
      );
      when(
        () => repository.updateActiveEncounter(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
      );

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);
      final OpdWorkspaceState before = _workspaceState(container);

      final Result<OpdFlowDetail> result = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .submitOpdEncounter(<String, Object?>{
            'existing_encounter_id': 'ENC000001',
            'patient_id': 'PAT000001',
          });

      expect(result.isFailure, isTrue);
      expect(_workspaceState(container).flows, same(before.flows));
      expect(_workspaceState(container).triageQueue, same(before.triageQueue));
      expect(_workspaceState(container).selectedFlow, isNull);
    });

    test('closeOpdEncounter removes a persisted terminal flow', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdAppointment appointment = OpdAppointment(
        id: 'appointment-1',
        publicId: 'APT000001',
        status: 'IN_PROGRESS',
      );
      const OpdQueueEntry queueEntry = OpdQueueEntry(
        id: 'queue-1',
        publicId: 'QUE000001',
        status: 'IN_PROGRESS',
      );
      const OpdFlowSummary active = OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        status: 'OPEN',
        stage: 'WAITING_VITALS',
      );
      const OpdFlowDetail closed = OpdFlowDetail(
        summary: OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          status: 'CLOSED',
          stage: 'DISCHARGED',
          appointmentId: 'APT000001',
          visitQueueId: 'QUE000001',
        ),
      );
      _stubInitialLoad(
        repository,
        appointments: const <OpdAppointment>[appointment],
        queueEntries: const <OpdQueueEntry>[queueEntry],
        flows: const <OpdFlowSummary>[active],
        triageQueue: const <OpdFlowSummary>[active],
      );
      when(
        () => repository.closeEncounter(any(), any()),
      ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(closed));

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final Result<OpdFlowDetail> result = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .closeOpdEncounter('ENC000001', const <String, Object?>{});

      expect(result.isSuccess, isTrue);
      expect(_workspaceState(container).flows.items, isEmpty);
      expect(_workspaceState(container).triageQueue.items, isEmpty);
      expect(_workspaceState(container).selectedFlow, isNull);
      expect(
        _workspaceState(container).appointments.items.single.status,
        'COMPLETED',
      );
      expect(
        _workspaceState(container).queueEntries.items.single.status,
        'COMPLETED',
      );
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

      final ProviderContainer container = _testContainer(repository);
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

      final ProviderContainer container = _testContainer(repository);
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

      final ProviderContainer container = _testContainer(repository);
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

      final ProviderContainer container = _testContainer(repository);
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
      'resolveFlowById returns a loaded flow without a network call',
      () async {
        final _MockOpdRepository repository = _MockOpdRepository();
        const OpdFlowSummary flow = OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          stage: 'WAITING_DOCTOR_REVIEW',
        );

        _stubInitialLoad(repository, flows: <OpdFlowSummary>[flow]);

        final ProviderContainer container = _testContainer(repository);
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);
        clearInteractions(repository);

        final OpdFlowSummary? resolved = await container
            .read(opdWorkspaceControllerProvider.notifier)
            .resolveFlowById('ENC000001');

        expect(resolved?.apiId, 'ENC000001');
        verifyNever(() => repository.getOpdFlow(any()));
      },
    );

    test(
      'resolveFlowById fetches the detail when not already loaded',
      () async {
        final _MockOpdRepository repository = _MockOpdRepository();
        const OpdFlowDetail detail = OpdFlowDetail(
          summary: OpdFlowSummary(
            id: 'encounter-9',
            publicId: 'ENC000009',
            stage: 'WAITING_VITALS',
          ),
        );

        _stubInitialLoad(repository);
        when(
          () => repository.getOpdFlow(any()),
        ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(detail));

        final ProviderContainer container = _testContainer(repository);
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);
        clearInteractions(repository);

        final OpdFlowSummary? resolved = await container
            .read(opdWorkspaceControllerProvider.notifier)
            .resolveFlowById('ENC000009');

        expect(resolved?.apiId, 'ENC000009');
        verify(() => repository.getOpdFlow('ENC000009')).called(1);
      },
    );

    test(
      'resolveFlowById returns null when the encounter cannot be found',
      () async {
        final _MockOpdRepository repository = _MockOpdRepository();

        _stubInitialLoad(repository);
        when(() => repository.getOpdFlow(any())).thenAnswer(
          (_) async =>
              const Result<OpdFlowDetail>.failure(AppFailure.notFound()),
        );

        final ProviderContainer container = _testContainer(repository);
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);

        final OpdFlowSummary? resolved = await container
            .read(opdWorkspaceControllerProvider.notifier)
            .resolveFlowById('UNKNOWN');

        expect(resolved, isNull);
      },
    );

    test('completeDisposition admits via the disposition endpoint', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdFlowSummary flow = OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        providerUserId: 'DOC000001',
        stage: 'WAITING_DISPOSITION',
      );
      const OpdFlowDetail admitted = OpdFlowDetail(
        summary: OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          stage: 'WAITING_DISPOSITION',
          displayCode: 'ADMISSION_PENDING',
        ),
        admissions: <OpdRelatedRecord>[
          OpdRelatedRecord(
            id: 'ADM000001',
            kind: 'admission',
            status: 'ADMITTED',
          ),
        ],
      );
      Map<String, Object?>? submittedPayload;

      _stubInitialLoad(repository, flows: <OpdFlowSummary>[flow]);
      when(() => repository.disposition(any(), any())).thenAnswer((
        Invocation invocation,
      ) async {
        submittedPayload =
            invocation.positionalArguments[1] as Map<String, Object?>;
        return const Result<OpdFlowDetail>.success(admitted);
      });
      when(
        () => repository.getOpdFlow(any()),
      ).thenAnswer((_) async => const Result<OpdFlowDetail>.success(admitted));

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);
      clearInteractions(repository);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .completeDisposition(flow, <String, Object?>{
            'decision': 'ADMIT',
            'notes': 'Needs inpatient care',
          });

      expect(failure, isNull);
      expect(submittedPayload, containsPair('decision', 'ADMIT'));
      verify(() => repository.disposition('ENC000001', any())).called(1);
      verifyNever(() => repository.doctorReview(any(), any()));
    });

    test(
      'completeDisposition runs doctor review before disposition when waiting',
      () async {
        final _MockOpdRepository repository = _MockOpdRepository();
        const OpdFlowSummary flow = OpdFlowSummary(
          id: 'encounter-1',
          publicId: 'ENC000001',
          providerUserId: 'DOC000001',
          stage: 'WAITING_DOCTOR_REVIEW',
        );
        const OpdFlowDetail reviewed = OpdFlowDetail(
          summary: OpdFlowSummary(
            id: 'encounter-1',
            publicId: 'ENC000001',
            stage: 'WAITING_DISPOSITION',
          ),
        );
        const OpdFlowDetail discharged = OpdFlowDetail(
          summary: OpdFlowSummary(
            id: 'encounter-1',
            publicId: 'ENC000001',
            stage: 'DISCHARGED',
            status: 'COMPLETED',
          ),
        );
        Map<String, Object?>? reviewPayload;
        Map<String, Object?>? dispositionPayload;

        _stubInitialLoad(repository, flows: <OpdFlowSummary>[flow]);
        when(() => repository.doctorReview(any(), any())).thenAnswer((
          Invocation invocation,
        ) async {
          reviewPayload =
              invocation.positionalArguments[1] as Map<String, Object?>;
          return const Result<OpdFlowDetail>.success(reviewed);
        });
        when(() => repository.disposition(any(), any())).thenAnswer((
          Invocation invocation,
        ) async {
          dispositionPayload =
              invocation.positionalArguments[1] as Map<String, Object?>;
          return const Result<OpdFlowDetail>.success(discharged);
        });
        when(() => repository.getOpdFlow(any())).thenAnswer(
          (_) async => const Result<OpdFlowDetail>.success(discharged),
        );

        final ProviderContainer container = _testContainer(repository);
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);
        clearInteractions(repository);

        final AppFailure? failure = await container
            .read(opdWorkspaceControllerProvider.notifier)
            .completeDisposition(flow, <String, Object?>{
              'decision': 'DISCHARGE',
              'notes': 'Home care advice given',
            });

        expect(failure, isNull);
        expect(reviewPayload, containsPair('note', 'DISCHARGE - Home care advice given'));
        expect(dispositionPayload, containsPair('decision', 'DISCHARGE'));
        verify(() => repository.doctorReview('ENC000001', any())).called(1);
        verify(() => repository.disposition('ENC000001', any())).called(1);
      },
    );

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

        final ProviderContainer container = _testContainer(repository);
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

    test(
      'moveQueueEntry patches the persisted queue response immediately',
      () async {
        final _MockOpdRepository repository = _MockOpdRepository();
        const OpdQueueEntry queued = OpdQueueEntry(
          id: 'queue-internal',
          publicId: 'QUE000001',
          status: 'SCHEDULED',
        );
        const OpdQueueEntry moved = OpdQueueEntry(
          id: 'queue-internal',
          publicId: 'QUE000001',
          providerUserId: 'USR000002',
          status: 'CONFIRMED',
        );
        _stubInitialLoad(repository, queueEntries: <OpdQueueEntry>[queued]);
        when(
          () => repository.updateVisitQueue(
            any(),
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => const Result<OpdQueueEntry>.success(moved));

        final ProviderContainer container = _testContainer(repository);
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);

        final AppFailure? failure = await container
            .read(opdWorkspaceControllerProvider.notifier)
            .moveQueueEntry(queued, <String, Object?>{
              'status': 'CONFIRMED',
              'provider_user_id': 'USR000002',
            });

        expect(failure, isNull);
        final OpdWorkspaceState state = _workspaceState(container);
        expect(state.queueEntries.items.single.status, 'CONFIRMED');
        expect(state.queueEntries.items.single.providerUserId, 'USR000002');
        verify(
          () => repository.updateVisitQueue('QUE000001', <String, Object?>{
            'status': 'CONFIRMED',
            'provider_user_id': 'USR000002',
          }, idempotencyKey: any(named: 'idempotencyKey')),
        ).called(1);
      },
    );

    test('prioritizeQueueEntry preserves the queue workflow status', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdQueueEntry queued = OpdQueueEntry(
        id: 'queue-internal',
        publicId: 'QUE000001',
        status: 'IN_PROGRESS',
      );
      _stubInitialLoad(repository, queueEntries: <OpdQueueEntry>[queued]);
      when(
        () => repository.prioritizeVisitQueue(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => const Result<OpdQueueEntry>.success(queued));

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .prioritizeQueueEntry(queued, 'Urgent');

      expect(failure, isNull);
      expect(
        _workspaceState(container).queueEntries.items.single.status,
        'IN_PROGRESS',
      );
      verify(
        () => repository.prioritizeVisitQueue('QUE000001', <String, Object?>{
          'reason': 'Urgent',
        }, idempotencyKey: any(named: 'idempotencyKey')),
      ).called(1);
    });

    test('failed queue mutation leaves the queue row unchanged', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdQueueEntry queued = OpdQueueEntry(
        id: 'queue-internal',
        publicId: 'QUE000001',
        status: 'SCHEDULED',
      );
      _stubInitialLoad(repository, queueEntries: <OpdQueueEntry>[queued]);
      when(
        () => repository.prioritizeVisitQueue(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const Result<OpdQueueEntry>.failure(AppFailure.network()),
      );

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .prioritizeQueueEntry(queued, 'Urgent');

      expect(failure, isNotNull);
      expect(
        _workspaceState(container).queueEntries.items.single,
        same(queued),
      );
    });

    test('provider options load through controller state once', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      _stubInitialLoad(repository);
      when(() => repository.listProviders()).thenAnswer(
        (_) async =>
            const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[
              OpdProviderOption(id: 'USR000001', displayName: 'Dr Queue'),
            ]),
      );

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);
      final OpdWorkspaceController controller = container.read(
        opdWorkspaceControllerProvider.notifier,
      );

      expect(await controller.ensureQueueProviderOptionsLoaded(), isNull);
      expect(await controller.ensureQueueProviderOptionsLoaded(), isNull);

      expect(
        _workspaceState(container).queueProviderOptions.single.id,
        'USR000001',
      );
      verify(() => repository.listProviders()).called(1);
    });

    test(
      'startOpdFromQueue patches the queue row to IN_PROGRESS on success',
      () async {
        final _MockOpdRepository repository = _MockOpdRepository();
        const OpdQueueEntry queued = OpdQueueEntry(
          id: 'queue-internal',
          publicId: 'QUE000001',
          providerUserId: 'USR000001',
          status: 'CONFIRMED',
        );
        const OpdFlowDetail detail = OpdFlowDetail(
          summary: OpdFlowSummary(
            id: 'encounter-1',
            publicId: 'ENC000001',
            patientId: 'PAT000001',
            providerUserId: 'USR000001',
            status: 'OPEN',
            stage: 'WAITING_VITALS',
            visitQueueId: 'QUE000001',
          ),
        );
        Map<String, Object?>? submittedPayload;
        _stubInitialLoad(repository, queueEntries: <OpdQueueEntry>[queued]);
        when(
          () => repository.startOpdFlow(
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((Invocation invocation) async {
          submittedPayload =
              invocation.positionalArguments.single as Map<String, Object?>;
          return const Result<OpdFlowDetail>.success(detail);
        });

        final ProviderContainer container = _testContainer(repository);
        addTearDown(container.dispose);
        await container.read(opdWorkspaceControllerProvider.future);

        final AppFailure? failure = await container
            .read(opdWorkspaceControllerProvider.notifier)
            .startOpdFromQueue(queued);

        expect(failure, isNull);
        expect(submittedPayload, containsPair('arrival_mode', 'WALK_IN'));
        expect(submittedPayload, containsPair('visit_queue_id', 'QUE000001'));
        expect(submittedPayload, containsPair('provider_user_id', 'USR000001'));
        expect(submittedPayload, containsPair('reuse_open_encounter', true));
        expect(
          _workspaceState(container).queueEntries.items.single.status,
          'IN_PROGRESS',
        );
        expect(
          _workspaceState(container).flows.items,
          contains(detail.summary),
        );
      },
    );

    test('failed startOpdFromQueue leaves the queue row unchanged', () async {
      final _MockOpdRepository repository = _MockOpdRepository();
      const OpdQueueEntry queued = OpdQueueEntry(
        id: 'queue-internal',
        publicId: 'QUE000001',
        status: 'CONFIRMED',
      );
      _stubInitialLoad(repository, queueEntries: <OpdQueueEntry>[queued]);
      when(
        () => repository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
      );

      final ProviderContainer container = _testContainer(repository);
      addTearDown(container.dispose);
      await container.read(opdWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(opdWorkspaceControllerProvider.notifier)
          .startOpdFromQueue(queued);

      expect(failure, isNotNull);
      expect(
        _workspaceState(container).queueEntries.items.single,
        same(queued),
      );
    });
  });
}

OpdWorkspaceState _workspaceState(ProviderContainer container) {
  final Result<OpdWorkspaceState> result = container
      .read(opdWorkspaceControllerProvider)
      .requireValue;
  return result.when(
    success: (OpdWorkspaceState value) => value,
    failure: (AppFailure failure) => throw StateError(failure.toString()),
  );
}

ProviderContainer _testContainer(_MockOpdRepository repository) {
  return ProviderContainer(
    overrides: [
      initialSessionStateProvider.overrideWithValue(const SessionState.ready()),
      opdRepositoryProvider.overrideWithValue(repository),
    ],
  );
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
