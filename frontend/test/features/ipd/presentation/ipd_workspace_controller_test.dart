import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

IpdAdmissionSummary _summary({
  String id = 'adm-1',
  String stage = 'ADMITTED_PENDING_BED',
}) {
  return IpdAdmissionSummary(
    id: id,
    displayId: 'ADM-1',
    patientId: 'pat-1',
    patientDisplayName: 'Jane Doe',
    stage: stage,
    admissionStatus: 'ADMITTED',
  );
}

IpdBedBoardEntry _bed({String id = 'bed-1', String status = 'AVAILABLE'}) {
  return IpdBedBoardEntry(id: id, label: 'Bed 1', status: status);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  ProviderContainer buildContainer(
    _MockIpdRepository repo, {
    List<IpdAdmissionSummary> admissions = const <IpdAdmissionSummary>[],
    List<IpdBedBoardEntry> beds = const <IpdBedBoardEntry>[],
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
      overrides: [ipdRepositoryProvider.overrideWithValue(repo)],
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
}
