import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/rooms_beds/data/repositories/rooms_beds_repository_impl.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/repositories/rooms_beds_repository.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockRoomsBedsRepository extends Mock implements RoomsBedsRepository {}

IpdAdmissionSummary _summary({
  String id = 'adm-1',
  String stage = 'ADMITTED_PENDING_BED',
  String admissionStatus = 'ADMITTED',
}) {
  return IpdAdmissionSummary(
    id: id,
    displayId: 'ADM-1',
    patientId: 'pat-1',
    patientDisplayName: 'Jane Doe',
    stage: stage,
    admissionStatus: admissionStatus,
  );
}

IpdBedBoardEntry _bed({String id = 'bed-1', String status = 'AVAILABLE'}) {
  return IpdBedBoardEntry(id: id, label: 'Bed 1', status: status);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(
      const PatientListQuery(pageRequest: AppPageRequest(pageSize: 12)),
    );
  });

  ProviderContainer buildContainer(
    _MockIpdRepository repo, {
    List<IpdAdmissionSummary> admissions = const <IpdAdmissionSummary>[],
    List<IpdBedBoardEntry> beds = const <IpdBedBoardEntry>[],
    PatientRepository? patientRepository,
  }) {
    when(() => repo.listAdmissions(any())).thenAnswer(
      (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: admissions,
          request: (invocation.positionalArguments.single as IpdAdmissionQuery)
              .pageRequest,
          totalItemCount: admissions.length,
        ),
      ),
    );
    when(() => repo.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
    when(() => repo.getAdmission(any())).thenAnswer(
      (Invocation invocation) async {
        final String id = invocation.positionalArguments.single as String;
        IpdAdmissionSummary? matched;
        for (final IpdAdmissionSummary item in admissions) {
          if (item.id == id) {
            matched = item;
            break;
          }
        }
        final IpdAdmissionSummary summary =
            matched ??
            (admissions.isNotEmpty ? admissions.first : _summary(id: id));
        return Result<IpdAdmissionDetail>.success(
          IpdAdmissionDetail(summary: summary),
        );
      },
    );
    when(() => repo.listWards(search: any(named: 'search'))).thenAnswer(
      (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[]),
    );
    when(
      () => repo.listBeds(
        search: any(named: 'search'),
        status: any(named: 'status'),
        wardId: any(named: 'wardId'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[]),
    );
    when(
      () => repo.listBedBoard(
        wardId: any(named: 'wardId'),
        status: any(named: 'status'),
        statusAny: any(named: 'statusAny'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => Result<List<IpdBedBoardEntry>>.success(beds));

    final ProviderContainer container = ProviderContainer(
      overrides: [
        ipdRepositoryProvider.overrideWithValue(repo),
        if (patientRepository != null)
          patientRepositoryProvider.overrideWithValue(patientRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  IpdWorkspaceState? readState(ProviderContainer container) {
    return container
        .read(ipdWorkspaceControllerProvider)
        .asData
        ?.value
        .when(success: (IpdWorkspaceState s) => s, failure: (_) => null);
  }

  test('loadBedBoard populates bed board state', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      repo,
      beds: <IpdBedBoardEntry>[
        _bed(),
        _bed(id: 'bed-2', status: 'OCCUPIED'),
      ],
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.loadBedBoard();
    expect(failure, isNull);

    final IpdWorkspaceState? state = readState(container);
    expect(state, isNotNull);
    expect(state!.bedBoard, hasLength(2));
    expect(state.bedBoardLoaded, isTrue);
    verify(
      () => repo.listBedBoard(
        wardId: any(named: 'wardId'),
        status: any(named: 'status'),
        statusAny: any(named: 'statusAny'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });

  test(
    'applyBedBoardWard reloads the bed board with the ward filter',
    () async {
      final _MockIpdRepository repo = _MockIpdRepository();
      final ProviderContainer container = buildContainer(repo);

      await container.read(ipdWorkspaceControllerProvider.future);
      final IpdWorkspaceController controller = container.read(
        ipdWorkspaceControllerProvider.notifier,
      );

      await controller.applyBedBoardWard('WRD-9');

      final IpdWorkspaceState? state = readState(container);
      expect(state!.bedBoardWardId, 'WRD-9');
      verify(
        () => repo.listBedBoard(
          wardId: 'WRD-9',
          status: any(named: 'status'),
          statusAny: any(named: 'statusAny'),
          limit: any(named: 'limit'),
        ),
      ).called(1);
    },
  );

  test('updateBedStatus calls repository and reloads the board', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      repo,
      beds: <IpdBedBoardEntry>[_bed()],
    );
    when(
      () => repo.updateBedStatus(
        bedId: any(named: 'bedId'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => const Result<void>.success(null));

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );
    await controller.loadBedBoard();

    final failure = await controller.updateBedStatus(_bed(), 'RESERVED');
    expect(failure, isNull);
    verify(
      () => repo.updateBedStatus(bedId: 'bed-1', status: 'RESERVED'),
    ).called(1);
  });

  test('startAdmission selects the created admission', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final ProviderContainer container = buildContainer(repo);
    when(() => repo.startAdmission(any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(summary: _summary()),
      ),
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.startAdmission(<String, Object?>{
      'patient_id': 'pat-1',
    });
    expect(failure, isNull);

    final IpdWorkspaceState? state = readState(container);
    expect(state!.selectedAdmission, isNotNull);
    expect(state.selectedAdmission!.summary.id, 'adm-1');
    verify(() => repo.startAdmission(any())).called(1);
  });

  test(
    'startAdmission with bed patches admission and reconciles rooms/beds',
    () async {
      final _MockIpdRepository repo = _MockIpdRepository();
      final _MockRoomsBedsRepository roomsBeds = _MockRoomsBedsRepository();
      _stubRoomsBedsWorkspace(roomsBeds);
      when(() => repo.startAdmission(any())).thenAnswer(
        (_) async => Result<IpdAdmissionDetail>.success(
          IpdAdmissionDetail(
            summary: _summary(
              stage: 'ADMITTED_IN_BED',
            ).copyWith(hasActiveBed: true, bedId: 'bed-1'),
          ),
        ),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          ipdRepositoryProvider.overrideWithValue(repo),
          roomsBedsRepositoryProvider.overrideWithValue(roomsBeds),
        ],
      );
      addTearDown(container.dispose);

      // Ensure IPD load stubs are registered on this repo instance.
      when(() => repo.listAdmissions(any())).thenAnswer(
        (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
          AppPage<IpdAdmissionSummary>(
            items: const <IpdAdmissionSummary>[],
            request:
                (invocation.positionalArguments.single as IpdAdmissionQuery)
                    .pageRequest,
            totalItemCount: 0,
          ),
        ),
      );
      when(() => repo.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
      when(() => repo.listWards(search: any(named: 'search'))).thenAnswer(
        (_) async =>
            const Result<List<IpdWardOption>>.success(<IpdWardOption>[]),
      );
      when(
        () => repo.listBeds(
          search: any(named: 'search'),
          status: any(named: 'status'),
          wardId: any(named: 'wardId'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[]),
      );
      when(
        () => repo.listBedBoard(
          wardId: any(named: 'wardId'),
          status: any(named: 'status'),
          statusAny: any(named: 'statusAny'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async =>
            const Result<List<IpdBedBoardEntry>>.success(<IpdBedBoardEntry>[]),
      );

      await container.read(ipdWorkspaceControllerProvider.future);
      await container.read(roomsBedsWorkspaceControllerProvider.future);

      clearInteractions(roomsBeds);

      final IpdWorkspaceController controller = container.read(
        ipdWorkspaceControllerProvider.notifier,
      );
      final AppFailure? failure = await controller.startAdmission(
        <String, Object?>{
          'patient_id': 'pat-1',
          'bed_id': 'bed-1',
        },
      );
      expect(failure, isNull);

      final IpdWorkspaceState? state = readState(container);
      expect(state!.selectedAdmission?.summary.hasActiveBed, isTrue);
      expect(state.selectedAdmission?.summary.bedId, 'bed-1');

      // Allow unawaited rooms/beds reconcile to run.
      await Future<void>.delayed(Duration.zero);
      verify(
        () => roomsBeds.loadSetup(facilityId: any(named: 'facilityId')),
      ).called(greaterThanOrEqualTo(1));
    },
  );

  test('startAdmission failure patches nothing', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final ProviderContainer container = buildContainer(repo);
    when(() => repo.startAdmission(any())).thenAnswer(
      (_) async => const Result<IpdAdmissionDetail>.failure(
        AppFailure.network(),
      ),
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final AppFailure? failure = await controller.startAdmission(
      <String, Object?>{'patient_id': 'pat-1'},
    );
    expect(failure, isNotNull);

    final IpdWorkspaceState? state = readState(container);
    expect(state!.selectedAdmission, isNull);
    expect(state.admissions.items, isEmpty);
    expect(state.isSaving, isFalse);
    expect(state.lastFailure, isNotNull);
  });

  test('searchPatients delegates to the patient repository', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final _MockPatientRepository patients = _MockPatientRepository();
    final ProviderContainer container = buildContainer(
      repo,
      patientRepository: patients,
    );
    when(() => patients.listPatients(any())).thenAnswer(
      (Invocation invocation) async => Result<AppPage<Patient>>.success(
        AppPage<Patient>(
          items: const <Patient>[
            Patient(id: 'pat-1', displayName: 'Ada Active'),
          ],
          request: (invocation.positionalArguments.single as PatientListQuery)
              .pageRequest,
          totalItemCount: 1,
        ),
      ),
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final Result<AppPage<Patient>> result = await controller.searchPatients(
      const PatientListQuery(
        search: 'Ada',
        pageRequest: AppPageRequest(pageSize: 12),
      ),
    );

    expect(
      result.when(success: (AppPage<Patient> page) => page.items.single.id, failure: (_) => null),
      'pat-1',
    );
    verify(() => patients.listPatients(any())).called(1);
  });

  test('approveAdmission refreshes admission detail', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final ProviderContainer container = buildContainer(
      repo,
      admissions: <IpdAdmissionSummary>[_summary(stage: 'ADMISSION_REQUESTED')],
    );
    when(() => repo.approveAdmission(any(), any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(summary: _summary()),
      ),
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.approveAdmission(
      _summary(stage: 'ADMISSION_REQUESTED'),
    );
    expect(failure, isNull);
    verify(() => repo.approveAdmission('adm-1', any())).called(1);
  });

  test('releaseBed patches admission and refreshes reference data', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final IpdAdmissionSummary occupied = _summary(
      stage: 'DISCHARGE_PLANNED',
    ).copyWith(hasActiveBed: true);
    final IpdAdmissionSummary released = occupied.copyWith(
      hasActiveBed: false,
      stage: 'DISCHARGE_PLANNED',
    );
    final ProviderContainer container = buildContainer(
      repo,
      admissions: <IpdAdmissionSummary>[occupied],
    );
    when(() => repo.releaseBed(any(), any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(summary: released),
      ),
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    clearInteractions(repo);
    when(() => repo.listAdmissions(any())).thenAnswer(
      (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: <IpdAdmissionSummary>[released],
          request:
              (invocation.positionalArguments.single as IpdAdmissionQuery)
                  .pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
    when(() => repo.getSummaryCounts()).thenAnswer((_) async => const Result<IpdFlowAggregateCounts>.success(IpdFlowAggregateCounts.empty));
    when(() => repo.listWards(search: any(named: 'search'))).thenAnswer(
      (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[]),
    );
    when(
      () => repo.listBeds(
        search: any(named: 'search'),
        status: any(named: 'status'),
        wardId: any(named: 'wardId'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[]),
    );
    when(() => repo.releaseBed(any(), any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(summary: released),
      ),
    );

    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.releaseBed(occupied);
    expect(failure, isNull);

    final IpdWorkspaceState? state = readState(container);
    expect(state, isNotNull);
    expect(state!.selectedAdmission?.summary.hasActiveBed, isFalse);
    expect(state.admissions.items.single.hasActiveBed, isFalse);
    verify(() => repo.releaseBed('adm-1', any())).called(1);
    verify(() => repo.listWards(search: any(named: 'search'))).called(1);
    verify(
      () => repo.listBeds(
        search: any(named: 'search'),
        status: any(named: 'status'),
        wardId: any(named: 'wardId'),
      ),
    ).called(1);
  });

  test('releaseBed failure patches nothing', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final IpdAdmissionSummary occupied = _summary(
      stage: 'DISCHARGE_PLANNED',
    ).copyWith(hasActiveBed: true);
    final ProviderContainer container = buildContainer(
      repo,
      admissions: <IpdAdmissionSummary>[occupied],
    );
    when(() => repo.releaseBed(any(), any())).thenAnswer(
      (_) async => Result<IpdAdmissionDetail>.failure(AppFailure.network()),
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.releaseBed(occupied);
    expect(failure, isNotNull);

    final IpdWorkspaceState? state = readState(container);
    expect(state!.selectedAdmission, isNull);
    expect(state.admissions.items.single.hasActiveBed, isTrue);
    expect(state.isSaving, isFalse);
    expect(state.lastFailure, isNotNull);
  });

  test('requestTransfer patches admission detail and transfer queue stage',
      () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final IpdAdmissionSummary admitted = _summary(stage: 'ADMITTED_IN_BED');
    final IpdAdmissionSummary transferred = IpdAdmissionSummary(
      id: admitted.id,
      displayId: admitted.displayId,
      patientId: admitted.patientId,
      patientDisplayName: admitted.patientDisplayName,
      stage: 'TRANSFER_REQUESTED',
      transferStatus: 'REQUESTED',
      admissionStatus: admitted.admissionStatus,
      openTransferRequestId: 'tr-1',
    );
    Map<String, Object?>? payload;
    final ProviderContainer container = buildContainer(
      repo,
      admissions: <IpdAdmissionSummary>[admitted],
    );
    when(() => repo.requestTransfer(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      payload = invocation.positionalArguments[1] as Map<String, Object?>;
      final IpdAdmissionDetail detail = IpdAdmissionDetail(
        summary: transferred,
        openTransferRequest: const IpdTransferRequest(
          id: 'tr-1',
          status: 'REQUESTED',
        ),
      );
      when(() => repo.listAdmissions(any())).thenAnswer(
        (Invocation listInvocation) async =>
            Result<AppPage<IpdAdmissionSummary>>.success(
              AppPage<IpdAdmissionSummary>(
                items: <IpdAdmissionSummary>[transferred],
                request:
                    (listInvocation.positionalArguments.single
                            as IpdAdmissionQuery)
                        .pageRequest,
                totalItemCount: 1,
              ),
            ),
      );
      when(() => repo.getSummaryCounts()).thenAnswer(
        (_) async => const Result<IpdFlowAggregateCounts>.success(
          IpdFlowAggregateCounts(transferPending: 1),
        ),
      );
      when(() => repo.getAdmission(any())).thenAnswer(
        (_) async => Result<IpdAdmissionDetail>.success(detail),
      );
      return Result<IpdAdmissionDetail>.success(detail);
    });

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.requestTransfer(
      admission: admitted,
      fromWardId: 'ward-a',
      toWardId: 'ward-b',
    );
    expect(failure, isNull);
    expect(payload?['from_ward_id'], 'ward-a');
    expect(payload?['to_ward_id'], 'ward-b');
    expect(payload?['requested_at'], isA<String>());

    await Future<void>.delayed(Duration.zero);

    final IpdWorkspaceState? state = readState(container);
    expect(state!.selectedAdmission?.summary.stage, 'TRANSFER_REQUESTED');
    expect(state.selectedAdmission?.openTransferRequest?.id, 'tr-1');
    expect(state.admissions.items.first.stage, 'TRANSFER_REQUESTED');
    expect(state.transferPendingCount, 1);
    verify(() => repo.requestTransfer('adm-1', any())).called(1);
  });

  test('requestTransfer failure patches nothing', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final IpdAdmissionSummary admitted = _summary(stage: 'ADMITTED_IN_BED');
    final ProviderContainer container = buildContainer(
      repo,
      admissions: <IpdAdmissionSummary>[admitted],
    );
    when(() => repo.requestTransfer(any(), any())).thenAnswer(
      (_) async => const Result<IpdAdmissionDetail>.failure(
        AppFailure.network(),
      ),
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.requestTransfer(
      admission: admitted,
      fromWardId: 'ward-a',
      toWardId: 'ward-b',
    );
    expect(failure, isNotNull);

    final IpdWorkspaceState? state = readState(container);
    expect(state!.selectedAdmission, isNull);
    expect(state.admissions.items.first.stage, 'ADMITTED_IN_BED');
    expect(state.transferPendingCount, 0);
  });

  test('updateTransfer patches admission transfer status', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final IpdAdmissionSummary requested = IpdAdmissionSummary(
      id: 'adm-1',
      displayId: 'ADM-1',
      patientId: 'pat-1',
      patientDisplayName: 'Jane Doe',
      stage: 'TRANSFER_REQUESTED',
      transferStatus: 'REQUESTED',
      admissionStatus: 'ADMITTED',
      openTransferRequestId: 'tr-1',
    );
    final IpdAdmissionSummary approved = IpdAdmissionSummary(
      id: 'adm-1',
      displayId: 'ADM-1',
      patientId: 'pat-1',
      patientDisplayName: 'Jane Doe',
      stage: 'TRANSFER_REQUESTED',
      transferStatus: 'APPROVED',
      admissionStatus: 'ADMITTED',
      openTransferRequestId: 'tr-1',
    );
    Map<String, Object?>? payload;
    final ProviderContainer container = buildContainer(
      repo,
      admissions: <IpdAdmissionSummary>[requested],
    );
    when(() => repo.updateTransfer(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      payload = invocation.positionalArguments[1] as Map<String, Object?>;
      final IpdAdmissionDetail detail = IpdAdmissionDetail(
        summary: approved,
        openTransferRequest: const IpdTransferRequest(
          id: 'tr-1',
          status: 'APPROVED',
        ),
      );
      when(() => repo.listAdmissions(any())).thenAnswer(
        (Invocation listInvocation) async =>
            Result<AppPage<IpdAdmissionSummary>>.success(
              AppPage<IpdAdmissionSummary>(
                items: <IpdAdmissionSummary>[approved],
                request:
                    (listInvocation.positionalArguments.single
                            as IpdAdmissionQuery)
                        .pageRequest,
                totalItemCount: 1,
              ),
            ),
      );
      when(() => repo.getSummaryCounts()).thenAnswer(
        (_) async => const Result<IpdFlowAggregateCounts>.success(
          IpdFlowAggregateCounts(transferPending: 1),
        ),
      );
      when(() => repo.getAdmission(any())).thenAnswer(
        (_) async => Result<IpdAdmissionDetail>.success(detail),
      );
      return Result<IpdAdmissionDetail>.success(detail);
    });

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.updateTransfer(
      admission: requested,
      action: 'APPROVE',
      transferRequestId: 'tr-1',
    );
    expect(failure, isNull);
    expect(payload?['action'], 'APPROVE');
    expect(payload?['transfer_request_id'], 'tr-1');

    await Future<void>.delayed(Duration.zero);

    final IpdWorkspaceState? state = readState(container);
    expect(state!.selectedAdmission?.openTransferRequest?.status, 'APPROVED');
    expect(state.admissions.items.first.transferStatus, 'APPROVED');
    verify(() => repo.updateTransfer('adm-1', any())).called(1);
  });

  test('updateTransfer failure patches nothing', () async {
    final _MockIpdRepository repo = _MockIpdRepository();
    final IpdAdmissionSummary requested = IpdAdmissionSummary(
      id: 'adm-1',
      displayId: 'ADM-1',
      patientId: 'pat-1',
      patientDisplayName: 'Jane Doe',
      stage: 'TRANSFER_REQUESTED',
      transferStatus: 'REQUESTED',
      admissionStatus: 'ADMITTED',
      openTransferRequestId: 'tr-1',
    );
    final ProviderContainer container = buildContainer(
      repo,
      admissions: <IpdAdmissionSummary>[requested],
    );
    when(() => repo.updateTransfer(any(), any())).thenAnswer(
      (_) async => const Result<IpdAdmissionDetail>.failure(
        AppFailure.network(),
      ),
    );

    await container.read(ipdWorkspaceControllerProvider.future);
    final IpdWorkspaceController controller = container.read(
      ipdWorkspaceControllerProvider.notifier,
    );

    final failure = await controller.updateTransfer(
      admission: requested,
      action: 'APPROVE',
      transferRequestId: 'tr-1',
    );
    expect(failure, isNotNull);

    final IpdWorkspaceState? state = readState(container);
    expect(state!.selectedAdmission, isNull);
    expect(state.admissions.items.first.transferStatus, 'REQUESTED');
  });

  test('admissionQueueCount reads authoritative summaryCounts', () {
    final IpdWorkspaceState state = IpdWorkspaceState(
      query: const IpdAdmissionQuery(),
      admissions: AppPage<IpdAdmissionSummary>(
        items: <IpdAdmissionSummary>[
          _summary(stage: 'ADMISSION_REQUESTED'),
          _summary(),
          _summary(stage: 'ADMITTED_IN_BED', id: 'adm-3'),
        ],
        request: const AppPageRequest(),
        totalItemCount: 3,
      ),
      summaryCounts: const IpdFlowAggregateCounts(admissionQueue: 2),
    );

    expect(state.admissionQueueCount, 2);
  });
}

void _stubRoomsBedsWorkspace(_MockRoomsBedsRepository repository) {
  when(
    () => repository.loadSetup(facilityId: any(named: 'facilityId')),
  ).thenAnswer(
    (_) async => Result<FacilitySetupSnapshot>.success(
      const FacilitySetupSnapshot(
        tenant: TenantProfile(id: 'TEN-001', name: 'Tenant'),
        facility: FacilityProfile(
          id: 'FAC-001',
          tenantId: 'TEN-001',
          name: 'Main',
          type: FacilitySetupType.hospital,
        ),
        facilities: <FacilityProfile>[
          FacilityProfile(
            id: 'FAC-001',
            tenantId: 'TEN-001',
            name: 'Main',
            type: FacilitySetupType.hospital,
          ),
        ],
        wards: <WardProfile>[
          WardProfile(
            id: 'WRD-001',
            tenantId: 'TEN-001',
            facilityId: 'FAC-001',
            name: 'General',
            type: WardSetupType.general,
          ),
        ],
        rooms: <RoomProfile>[
          RoomProfile(
            id: 'ROM-001',
            tenantId: 'TEN-001',
            facilityId: 'FAC-001',
            name: 'Room A',
            wardId: 'WRD-001',
          ),
        ],
        beds: <BedProfile>[
          BedProfile(
            id: 'BED-001',
            tenantId: 'TEN-001',
            facilityId: 'FAC-001',
            wardId: 'WRD-001',
            label: 'A1',
            status: BedSetupStatus.available,
            roomId: 'ROM-001',
          ),
        ],
      ),
    ),
  );
  when(() => repository.loadAdmissionContext(any())).thenAnswer(
    (_) async => const Result<BedAdmissionContext>.success(
      BedAdmissionContext(admissionId: 'ADM-001'),
    ),
  );
  when(() => repository.listBedAssignmentsForBed(any())).thenAnswer(
    (_) async => const Result<List<BedAssignmentRecord>>.success(
      <BedAssignmentRecord>[],
    ),
  );
}
