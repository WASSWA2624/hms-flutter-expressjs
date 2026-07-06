import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
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

const RadiologyCatalogTest _platformRadiologyTest = RadiologyCatalogTest(
  id: 'RT-PLATFORM',
  name: 'Chest X-ray',
  code: 'RAD-00001',
  modality: 'XRAY',
);

const RadiologyCatalogTest _offeredRadiologyTest = RadiologyCatalogTest(
  id: 'RT-OFFERED',
  name: 'LFT',
  code: 'RAD-00002',
  modality: 'CT',
  isOfferedAtFacility: true,
);

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
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<RadiologyCatalogTest>>.success(
        <RadiologyCatalogTest>[],
      ),
    );
    when(
      () => repository.listFacilityRadiologyTests(
        tenantId: any(named: 'tenantId'),
        facilityId: any(named: 'facilityId'),
        search: any(named: 'search'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        offeredOnly: any(named: 'offeredOnly'),
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
      overrides: [
        radiologyRepositoryProvider.overrideWithValue(repository),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.unauthenticated(),
        ),
      ],
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
    'upsertRadiologyTestOffering merges the offering into catalogTests immediately',
    () async {
      final _MockRadiologyRepository repository = _MockRadiologyRepository();
      stubInitialLoad(repository);
      const RadiologyCatalogTest enabledTest = RadiologyCatalogTest(
        id: 'RT-1',
        name: 'Chest X-ray',
        code: 'RAD-00001',
        modality: 'XRAY',
        unitPrice: 25000,
        currency: 'UGX',
      );
      when(
        () => repository.upsertFacilityRadiologyTestOffering(
          any(),
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<RadiologyCatalogTest>.success(enabledTest),
      );
      final ProviderContainer container = buildContainer(repository);

      await container.read(radiologyWorkspaceControllerProvider.future);
      final RadiologyWorkspaceController controller = container.read(
        radiologyWorkspaceControllerProvider.notifier,
      );

      final AppFailure? failure = await controller.upsertRadiologyTestOffering(
        'RT-1',
        <String, Object?>{
          'is_active': true,
          'unit_price': 25000,
          'currency': 'UGX',
        },
        scope: const RadiologyCatalogScope(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
        ),
      );
      expect(failure, isNull);

      final RadiologyWorkspaceState state =
          (container.read(radiologyWorkspaceControllerProvider).value!
                  as ResultSuccess<RadiologyWorkspaceState>)
              .value;
      expect(state.catalogTests, hasLength(1));
      expect(state.catalogTests.single.name, 'Chest X-ray');
      expect(state.catalogTests.single.isOfferedAtFacility, isTrue);
      expect(state.isMutating, isFalse);

      verify(
        () => repository.upsertFacilityRadiologyTestOffering(
          'RT-1',
          any(),
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
        ),
      ).called(1);
      verifyNever(
        () => repository.listFacilityRadiologyTests(
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
          search: any(named: 'search'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          offeredOnly: any(named: 'offeredOnly'),
        ),
      );
    },
  );

  test(
    'searchPlatformRadiologyCatalogForOffering loads platform catalog and marks offered items',
    () async {
      final _MockRadiologyRepository repository = _MockRadiologyRepository();
      stubInitialLoad(repository);
      when(
        () => repository.listRadiologyCatalogTests(
          search: any(named: 'search'),
          includeStandardCatalog: any(named: 'includeStandardCatalog'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<RadiologyCatalogTest>>.success(
          <RadiologyCatalogTest>[
            _platformRadiologyTest,
            _offeredRadiologyTest,
          ],
        ),
      );
      when(
        () => repository.listFacilityRadiologyTests(
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
          search: any(named: 'search'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          offeredOnly: true,
        ),
      ).thenAnswer(
        (_) async => const Result<List<RadiologyCatalogTest>>.success(
          <RadiologyCatalogTest>[_offeredRadiologyTest],
        ),
      );

      final ProviderContainer container = buildContainer(repository);
      await container.read(radiologyWorkspaceControllerProvider.future);

      final RadiologyWorkspaceController controller = container.read(
        radiologyWorkspaceControllerProvider.notifier,
      );
      final Result<List<RadiologyCatalogTest>> result = await controller
          .searchPlatformRadiologyCatalogForOffering(
            scope: const RadiologyCatalogScope(
              tenantId: 'TEN0000001',
              facilityId: 'FAC0000001',
            ),
            query: 'Chest',
          );

      expect(result, isA<ResultSuccess<List<RadiologyCatalogTest>>>());
      final List<RadiologyCatalogTest> items =
          (result as ResultSuccess<List<RadiologyCatalogTest>>).value;
      expect(items, hasLength(2));
      expect(items.first.isOfferedAtFacility, isFalse);
      expect(items.last.code, 'RAD-00002');
      expect(items.last.isOfferedAtFacility, isTrue);

      verify(
        () => repository.listRadiologyCatalogTests(
          search: 'Chest',
          limit: any<int>(named: 'limit'),
        ),
      ).called(1);
      verify(
        () => repository.listFacilityRadiologyTests(
          tenantId: 'TEN0000001',
          facilityId: 'FAC0000001',
          offeredOnly: true,
          limit: any<int>(named: 'limit'),
        ),
      ).called(1);
    },
  );

  test(
    'searchPlatformRadiologyCatalogForOffering returns empty list when scope is incomplete',
    () async {
      final _MockRadiologyRepository repository = _MockRadiologyRepository();
      stubInitialLoad(repository);
      final ProviderContainer container = buildContainer(repository);
      await container.read(radiologyWorkspaceControllerProvider.future);

      final RadiologyWorkspaceController controller = container.read(
        radiologyWorkspaceControllerProvider.notifier,
      );
      final Result<List<RadiologyCatalogTest>> result = await controller
          .searchPlatformRadiologyCatalogForOffering(
            scope: const RadiologyCatalogScope(tenantId: 'TEN0000001'),
          );

      expect(result, isA<ResultSuccess<List<RadiologyCatalogTest>>>());
      expect(
        (result as ResultSuccess<List<RadiologyCatalogTest>>).value,
        isEmpty,
      );
      verifyNever(
        () => repository.listRadiologyCatalogTests(
          search: any(named: 'search'),
          limit: any(named: 'limit'),
        ),
      );
    },
  );
}
