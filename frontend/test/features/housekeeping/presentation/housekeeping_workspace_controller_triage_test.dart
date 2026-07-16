import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/housekeeping/data/repositories/housekeeping_repository_impl.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/domain/repositories/housekeeping_repository.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHousekeepingRepository extends Mock
    implements HousekeepingRepository {}

const HousekeepingWorkItem _openRequest = HousekeepingWorkItem(
  id: 'MR-001',
  displayId: 'MR-001',
  resource: HousekeepingResource.maintenanceRequests,
  title: 'Fix leaking tap',
  status: 'OPEN',
  facilityLabel: 'Main Campus',
  assetLabel: 'Tap-12',
  roomLabel: 'Room 3A',
);

const HousekeepingWorkItem _triagedRequest = HousekeepingWorkItem(
  id: 'MR-001',
  displayId: 'MR-001',
  resource: HousekeepingResource.maintenanceRequests,
  title: 'Tap-12',
  subtitle: '[TRIAGE] triage_summary=Leak confirmed',
  status: 'IN_PROGRESS',
  facilityLabel: 'Main Campus',
  assetLabel: 'Tap-12',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const HousekeepingWorkspaceQuery());
    registerFallbackValue(
      const HousekeepingMaintenanceTriageDraft(status: 'IN_PROGRESS'),
    );
  });

  test('triageMaintenanceRequest patches worklist and selected detail', () async {
    final _MockHousekeepingRepository repository = _MockHousekeepingRepository();
    _stubWorkspace(repository, items: <HousekeepingWorkItem>[_openRequest]);
    when(
      () => repository.triageMaintenanceRequest(any(), any()),
    ).thenAnswer(
      (_) async => const Result<HousekeepingWorkItem>.success(_triagedRequest),
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        housekeepingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(housekeepingWorkspaceControllerProvider.future);
    clearInteractions(repository);
    final HousekeepingWorkspaceController controller = container.read(
      housekeepingWorkspaceControllerProvider.notifier,
    );
    controller.selectItem(_openRequest);

    final AppFailure? failure = await controller.triageMaintenanceRequest(
      _openRequest,
      const HousekeepingMaintenanceTriageDraft(
        status: 'IN_PROGRESS',
        summary: 'Leak confirmed',
        slaHours: 24,
      ),
    );

    expect(failure, isNull);
    final HousekeepingWorkspaceState state = _readState(container);
    expect(state.isSaving, isFalse);
    expect(state.selectedItem?.status, 'IN_PROGRESS');
    expect(state.selectedItem?.subtitle, contains('Leak confirmed'));
    expect(state.selectedItem?.roomLabel, 'Room 3A');
    expect(state.items.items.single.status, 'IN_PROGRESS');
    verify(() => repository.triageMaintenanceRequest('MR-001', any())).called(1);
    verifyNever(() => repository.getWorkspace(any()));
  });

  test('triageMaintenanceRequest failure patches nothing', () async {
    final _MockHousekeepingRepository repository = _MockHousekeepingRepository();
    _stubWorkspace(repository, items: <HousekeepingWorkItem>[_openRequest]);
    when(() => repository.triageMaintenanceRequest(any(), any())).thenAnswer(
      (_) async => const Result<HousekeepingWorkItem>.failure(
        AppFailure.network(),
      ),
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        housekeepingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(housekeepingWorkspaceControllerProvider.future);
    final HousekeepingWorkspaceController controller = container.read(
      housekeepingWorkspaceControllerProvider.notifier,
    );
    controller.selectItem(_openRequest);

    final AppFailure? failure = await controller.triageMaintenanceRequest(
      _openRequest,
      const HousekeepingMaintenanceTriageDraft(status: 'IN_PROGRESS'),
    );

    expect(failure, isNotNull);
    final HousekeepingWorkspaceState state = _readState(container);
    expect(state.isSaving, isFalse);
    expect(state.selectedItem?.status, 'OPEN');
    expect(state.items.items.single.status, 'OPEN');
    verify(() => repository.getWorkspace(any())).called(1);
  });
}

void _stubWorkspace(
  _MockHousekeepingRepository repository, {
  required List<HousekeepingWorkItem> items,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final HousekeepingWorkspaceQuery query =
        invocation.positionalArguments.single as HousekeepingWorkspaceQuery;
    return Result<HousekeepingWorkspaceLoad>.success(
      HousekeepingWorkspaceLoad(
        overview: const HousekeepingWorkspaceOverview(),
        items: AppPage<HousekeepingWorkItem>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
}

HousekeepingWorkspaceState _readState(ProviderContainer container) {
  final Result<HousekeepingWorkspaceState> result = container
      .read(housekeepingWorkspaceControllerProvider)
      .requireValue;
  return result.when(
    success: (HousekeepingWorkspaceState value) => value,
    failure: (AppFailure failure) => fail(failure.code),
  );
}
