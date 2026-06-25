import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/features/radiology/presentation/controllers/radiology_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockRadiologyRepository extends Mock implements RadiologyRepository {}

const RadiologyOrder _order = RadiologyOrder(
  id: 'RO-001',
  displayId: 'RAD-001',
  status: 'ORDERED',
  patientDisplayName: 'Jane Doe',
  modality: 'XRAY',
);

const RadiologySummary _summary = RadiologySummary(
  totalOrders: 1,
  orderedQueue: 1,
);

RadiologyWorkbench _workbench({RadiologyOrder order = _order}) {
  return RadiologyWorkbench(
    summary: _summary,
    orders: AppPage<RadiologyOrder>(
      items: <RadiologyOrder>[order],
      request: const AppPageRequest(),
      totalItemCount: 1,
    ),
  );
}

RadiologyWorkflow _workflow({String status = 'ORDERED'}) {
  return RadiologyWorkflow(
    order: RadiologyOrder(
      id: _order.id,
      displayId: _order.displayId,
      status: status,
      patientDisplayName: _order.patientDisplayName,
      modality: _order.modality,
    ),
    nextActions: const RadiologyNextActions(
      canStart: true,
      canComplete: true,
      canCancel: true,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const RadiologyWorkspaceQuery());
    registerFallbackValue(<String, Object?>{});
  });

  void stubInitialLoad(_MockRadiologyRepository repository) {
    when(
      () => repository.getReferenceData(
        search: any(named: 'search'),
        patientId: any(named: 'patientId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => const Result<RadiologyReferenceData>.success(
        RadiologyReferenceData(),
      ),
    );
    when(
      () => repository.getWorkbench(any()),
    ).thenAnswer((_) async => Result<RadiologyWorkbench>.success(_workbench()));
    when(
      () => repository.listRadiologyCatalogTests(
        search: any(named: 'search'),
        includeStandardCatalog: any(named: 'includeStandardCatalog'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<RadiologyCatalogTest>>.success(
        <RadiologyCatalogTest>[],
      ),
    );
    when(
      () => repository.listEquipmentRecords(search: any(named: 'search')),
    ).thenAnswer(
      (_) async => const Result<List<RadiologyEquipmentRecord>>.success(
        <RadiologyEquipmentRecord>[],
      ),
    );
    when(
      () => repository.getWorkflow(any()),
    ).thenAnswer((_) async => Result<RadiologyWorkflow>.success(_workflow()));
  }

  ProviderContainer buildContainer(_MockRadiologyRepository repository) {
    final ProviderContainer container = ProviderContainer(
      overrides: [radiologyRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'build loads the workbench and selects the first order workflow',
    () async {
      final _MockRadiologyRepository repository = _MockRadiologyRepository();
      stubInitialLoad(repository);
      final ProviderContainer container = buildContainer(repository);

      final Result<RadiologyWorkspaceState> result = await container.read(
        radiologyWorkspaceControllerProvider.future,
      );

      final RadiologyWorkspaceState state =
          (result as ResultSuccess<RadiologyWorkspaceState>).value;
      expect(state.orders.items.single.id, 'RO-001');
      expect(state.summary.totalOrders, 1);
      expect(state.selectedWorkflow?.order.displayId, 'RAD-001');
      verify(
        () => repository.getWorkflow('RAD-001'),
      ).called(greaterThanOrEqualTo(1));
    },
  );

  test('applyStage re-queries the workbench with the selected stage', () async {
    final _MockRadiologyRepository repository = _MockRadiologyRepository();
    stubInitialLoad(repository);
    final ProviderContainer container = buildContainer(repository);

    await container.read(radiologyWorkspaceControllerProvider.future);
    final RadiologyWorkspaceController controller = container.read(
      radiologyWorkspaceControllerProvider.notifier,
    );

    final AppFailure? failure = await controller.applyStage('ORDERED');
    expect(failure, isNull);

    final List<Object?> captured = verify(
      () => repository.getWorkbench(captureAny()),
    ).captured;
    final RadiologyWorkspaceQuery lastQuery =
        captured.last as RadiologyWorkspaceQuery;
    expect(lastQuery.stage, 'ORDERED');
  });

  test(
    'completeOrder mutates the selected order through the repository',
    () async {
      final _MockRadiologyRepository repository = _MockRadiologyRepository();
      stubInitialLoad(repository);
      when(() => repository.completeOrder(any(), any())).thenAnswer(
        (_) async =>
            Result<RadiologyWorkflow>.success(_workflow(status: 'COMPLETED')),
      );
      final ProviderContainer container = buildContainer(repository);

      await container.read(radiologyWorkspaceControllerProvider.future);
      final RadiologyWorkspaceController controller = container.read(
        radiologyWorkspaceControllerProvider.notifier,
      );

      final AppFailure? failure = await controller.completeOrder(
        <String, Object?>{'notes': 'done'},
      );
      expect(failure, isNull);

      final List<Object?> captured = verify(
        () => repository.completeOrder(captureAny(), any()),
      ).captured;
      expect(captured.single, 'RAD-001');

      final RadiologyWorkspaceState state =
          (container.read(radiologyWorkspaceControllerProvider).value!
                  as ResultSuccess<RadiologyWorkspaceState>)
              .value;
      expect(state.selectedWorkflow?.order.normalizedStatus, 'COMPLETED');
    },
  );

  test(
    'createRadiologyTest submits payload and refreshes the catalog',
    () async {
      final _MockRadiologyRepository repository = _MockRadiologyRepository();
      stubInitialLoad(repository);
      when(() => repository.createRadiologyCatalogTest(any())).thenAnswer(
        (_) async => const Result<RadiologyCatalogTest>.success(
          RadiologyCatalogTest(id: 'RT-1', name: 'Chest X-ray'),
        ),
      );
      final ProviderContainer container = buildContainer(repository);

      await container.read(radiologyWorkspaceControllerProvider.future);
      final RadiologyWorkspaceController controller = container.read(
        radiologyWorkspaceControllerProvider.notifier,
      );

      final AppFailure? failure = await controller.createRadiologyTest(
        <String, Object?>{'name': 'Chest X-ray', 'modality': 'XRAY'},
      );
      expect(failure, isNull);

      final List<Object?> captured = verify(
        () => repository.createRadiologyCatalogTest(captureAny()),
      ).captured;
      final Map<String, Object?> payload =
          captured.single as Map<String, Object?>;
      expect(payload['name'], 'Chest X-ray');
      verify(
        () => repository.listRadiologyCatalogTests(
          search: any(named: 'search'),
          includeStandardCatalog: any(named: 'includeStandardCatalog'),
        ),
      ).called(greaterThanOrEqualTo(2));
    },
  );
}
