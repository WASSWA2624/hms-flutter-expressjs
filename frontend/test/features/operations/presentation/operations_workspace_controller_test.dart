import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/operations/data/repositories/operations_repository_impl.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/domain/repositories/operations_repository.dart';
import 'package:hosspi_hms/features/operations/presentation/controllers/operations_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockOperationsRepository extends Mock implements OperationsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OperationsWorkItemQuery());
    registerFallbackValue(const OperationsAssetQuery());
    registerFallbackValue(const OperationsServiceLogQuery());
    registerFallbackValue(
      const OperationsServiceLogDraft(assetId: 'AS-001', notes: 'Done'),
    );
  });

  group('OperationsWorkspaceController', () {
    test('loads request queue and assets without selecting a detail', () async {
      final _MockOperationsRepository repository = _MockOperationsRepository();
      const OperationsWorkItem request = OperationsWorkItem(
        id: 'MR-001',
        assetId: 'AS-001',
        assetLabel: 'Generator',
        status: 'OPEN',
        metadata: OperationsRequestMetadata(
          priority: 'High',
          issue: 'Generator alarm',
        ),
      );
      const OperationsAsset asset = OperationsAsset(
        id: 'AS-001',
        name: 'Generator',
        status: 'OPEN',
      );

      _stubInitialLoad(
        repository,
        requests: <OperationsWorkItem>[request],
        assets: <OperationsAsset>[asset],
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [operationsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final Result<OperationsWorkspaceState> result = await container.read(
        operationsWorkspaceControllerProvider.future,
      );

      final OperationsWorkspaceState state = result.when(
        success: (OperationsWorkspaceState value) => value,
        failure: (AppFailure failure) => fail(failure.code),
      );
      expect(state.workItems.items.single.id, 'MR-001');
      expect(state.assets.items.single.id, 'AS-001');
      expect(state.serviceLogs.items, isEmpty);
      expect(state.selectedItem, isNull);
      verify(
        () => repository.listRequests(any()),
      ).called(greaterThanOrEqualTo(1));
      verify(
        () => repository.listAssets(any()),
      ).called(greaterThanOrEqualTo(1));
      verifyNever(() => repository.listServiceLogs(any()));
    });

    test('selectItem loads detail and asset service logs', () async {
      final _MockOperationsRepository repository = _MockOperationsRepository();
      const OperationsWorkItem request = OperationsWorkItem(
        id: 'MR-001',
        displayId: 'MR-001',
        assetId: 'AS-001',
        assetLabel: 'Generator',
        status: 'OPEN',
        metadata: OperationsRequestMetadata(
          priority: 'High',
          issue: 'Generator alarm',
        ),
      );
      const OperationsServiceLog log = OperationsServiceLog(
        id: 'SL-001',
        assetId: 'AS-001',
        notes: 'Monthly service',
      );

      _stubInitialLoad(
        repository,
        requests: <OperationsWorkItem>[request],
        assets: <OperationsAsset>[
          const OperationsAsset(
            id: 'AS-001',
            name: 'Generator',
            status: 'OPEN',
          ),
        ],
        serviceLogs: <OperationsServiceLog>[log],
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [operationsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(operationsWorkspaceControllerProvider.future);

      final AppFailure? failure = await container
          .read(operationsWorkspaceControllerProvider.notifier)
          .selectItem(request);

      final OperationsWorkspaceState state = container
          .read(operationsWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (OperationsWorkspaceState value) => value,
            failure: (AppFailure failure) => fail(failure.code),
          );
      expect(failure, isNull);
      expect(state.selectedItem?.id, 'MR-001');
      expect(state.selectedItem?.assetId, 'AS-001');
      expect(state.serviceLogs.items.single.id, 'SL-001');
      verify(() => repository.getRequest(any())).called(1);
      verify(() => repository.listServiceLogs(any())).called(1);
    });

    test('adds service logs without reloading the whole workspace', () async {
      final _MockOperationsRepository repository = _MockOperationsRepository();
      const OperationsWorkItem request = OperationsWorkItem(
        id: 'MR-001',
        displayId: 'MR-001',
        assetId: 'AS-001',
        status: 'IN_PROGRESS',
        metadata: OperationsRequestMetadata(issue: 'Pump repair'),
      );
      const OperationsServiceLog createdLog = OperationsServiceLog(
        id: 'SL-002',
        assetId: 'AS-001',
        notes: 'Pump seal replaced',
      );

      _stubInitialLoad(repository, requests: <OperationsWorkItem>[request]);
      when(() => repository.addServiceLog(any())).thenAnswer(
        (_) async => const Result<OperationsServiceLog>.success(createdLog),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [operationsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(operationsWorkspaceControllerProvider.future);
      await container
          .read(operationsWorkspaceControllerProvider.notifier)
          .selectItem(request);
      clearInteractions(repository);

      final AppFailure? failure = await container
          .read(operationsWorkspaceControllerProvider.notifier)
          .addServiceLog(
            const OperationsServiceLogDraft(
              assetId: 'AS-001',
              notes: 'Pump seal replaced',
            ),
          );

      final OperationsWorkspaceState state = container
          .read(operationsWorkspaceControllerProvider)
          .requireValue
          .when(
            success: (OperationsWorkspaceState value) => value,
            failure: (AppFailure failure) => fail(failure.code),
          );
      expect(failure, isNull);
      expect(
        state.serviceLogs.items.any(
          (OperationsServiceLog l) => l.id == 'SL-002',
        ),
        isTrue,
      );
      verify(() => repository.addServiceLog(any())).called(1);
      verifyNever(() => repository.getRequest(any()));
    });
  });
}

void _stubInitialLoad(
  _MockOperationsRepository repository, {
  List<OperationsWorkItem> requests = const <OperationsWorkItem>[],
  List<OperationsAsset> assets = const <OperationsAsset>[],
  List<OperationsServiceLog> serviceLogs = const <OperationsServiceLog>[],
}) {
  when(() => repository.listRequests(any())).thenAnswer(
    (invocation) async => Result<AppPage<OperationsWorkItem>>.success(
      AppPage<OperationsWorkItem>(
        items: requests,
        request:
            (invocation.positionalArguments.single as OperationsWorkItemQuery)
                .pageRequest,
        totalItemCount: requests.length,
      ),
    ),
  );
  when(() => repository.listAssets(any())).thenAnswer(
    (invocation) async => Result<AppPage<OperationsAsset>>.success(
      AppPage<OperationsAsset>(
        items: assets,
        request: (invocation.positionalArguments.single as OperationsAssetQuery)
            .pageRequest,
        totalItemCount: assets.length,
      ),
    ),
  );
  when(() => repository.listServiceLogs(any())).thenAnswer(
    (invocation) async => Result<AppPage<OperationsServiceLog>>.success(
      AppPage<OperationsServiceLog>(
        items: serviceLogs,
        request:
            (invocation.positionalArguments.single as OperationsServiceLogQuery)
                .pageRequest,
        totalItemCount: serviceLogs.length,
      ),
    ),
  );
  when(() => repository.getRequest(any())).thenAnswer(
    (_) async => Result<OperationsWorkItem>.success(
      requests.firstOrNull ??
          const OperationsWorkItem(
            id: 'MR-001',
            metadata: OperationsRequestMetadata(),
          ),
    ),
  );
}
