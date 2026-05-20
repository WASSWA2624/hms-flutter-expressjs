import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/housekeeping/data/repositories/housekeeping_repository_impl.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/domain/repositories/housekeeping_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final housekeepingWorkspaceControllerProvider =
    AsyncNotifierProvider<
      HousekeepingWorkspaceController,
      Result<HousekeepingWorkspaceState>
    >(HousekeepingWorkspaceController.new);

final class HousekeepingWorkspaceController
    extends AsyncNotifier<Result<HousekeepingWorkspaceState>> {
  HousekeepingRepository get _repository =>
      ref.read(housekeepingRepositoryProvider);

  @override
  Future<Result<HousekeepingWorkspaceState>> build() async {
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.housekeeping,
      onRefresh: (_) => _syncFromRealtime(),
    );
    const HousekeepingWorkspaceQuery query = HousekeepingWorkspaceQuery();
    final Result<HousekeepingWorkspaceLoad> loadResult = await _repository
        .getWorkspace(query);

    return loadResult.when(
      success: (HousekeepingWorkspaceLoad load) {
        return Result<HousekeepingWorkspaceState>.success(
          HousekeepingWorkspaceState(
            query: query,
            overview: load.overview,
            items: load.items,
            selectedItem: load.items.items.firstOrNull,
          ),
        );
      },
      failure: (AppFailure failure) {
        return Result<HousekeepingWorkspaceState>.failure(failure);
      },
    );
  }

  Future<void> _syncFromRealtime() async {
    await refresh();
  }

  Future<AppFailure?> refresh() async {
    final HousekeepingWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }
    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    return _refreshWorkspace(preferredSelectedId: current.selectedItem?.id);
  }

  Future<AppFailure?> applySearch(String value) async {
    final HousekeepingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: value.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace();
  }

  Future<AppFailure?> applyResource(HousekeepingResource resource) async {
    final HousekeepingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          resource: resource,
          queue: _queueForResource(resource, current.query.queue),
          pageRequest: current.query.pageRequest.first(),
          clearStatus: true,
          clearAssignee: resource != HousekeepingResource.tasks,
        ),
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace();
  }

  Future<AppFailure?> applyFilters({
    HousekeepingResource? resource,
    String? status,
    String? facilityId,
    String? roomId,
    String? assigneeId,
    HousekeepingQueue? queue,
    HousekeepingDatePreset? datePreset,
  }) async {
    final HousekeepingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    final HousekeepingResource requestedResource =
        resource ?? current.query.resource;
    final HousekeepingQueue resolvedQueue = _queueForResource(
      requestedResource,
      queue ?? current.query.queue,
    );
    final HousekeepingResource resolvedResource = _resourceForQueue(
      resolvedQueue,
      requestedResource,
    );

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          resource: resolvedResource,
          queue: resolvedQueue,
          status: status,
          facilityId: facilityId,
          roomId: roomId,
          assigneeId: assigneeId,
          datePreset: datePreset,
          pageRequest: current.query.pageRequest.first(),
          clearStatus: status == null,
          clearFacility: facilityId == null,
          clearRoom: roomId == null,
          clearAssignee: assigneeId == null,
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace(preferredSelectedId: current.selectedItem?.id);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final HousekeepingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(pageRequest: request),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace(preferredSelectedId: current.selectedItem?.id);
  }

  void selectItem(HousekeepingWorkItem item) {
    final HousekeepingWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(current.copyWith(selectedItem: item, clearLastFailure: true));
  }

  Future<AppFailure?> createTask(HousekeepingTaskDraft draft) {
    return _submitAction(
      () => _repository.createTask(draft),
      resourceAfterSuccess: HousekeepingResource.tasks,
    );
  }

  Future<AppFailure?> createSchedule(HousekeepingScheduleDraft draft) {
    return _submitAction(
      () => _repository.createSchedule(draft),
      resourceAfterSuccess: HousekeepingResource.schedules,
    );
  }

  Future<AppFailure?> createMaintenanceRequest(
    HousekeepingMaintenanceRequestDraft draft,
  ) {
    return _submitAction(
      () => _repository.createMaintenanceRequest(draft),
      resourceAfterSuccess: HousekeepingResource.maintenanceRequests,
    );
  }

  Future<AppFailure?> assignTask(
    HousekeepingWorkItem item, {
    required String? assigneeId,
  }) {
    if (!item.isTask) {
      return Future<AppFailure?>.value(_invalidItemFailure('task_id'));
    }
    return _submitAction(
      () => _repository.updateTask(item.id, <String, Object?>{
        'assigned_to_staff_id': assigneeId,
      }),
      preferredSelectedId: item.id,
    );
  }

  Future<AppFailure?> startTask(HousekeepingWorkItem item) {
    if (!item.isTask) {
      return Future<AppFailure?>.value(_invalidItemFailure('task_id'));
    }
    return _submitAction(
      () => _repository.updateTask(item.id, const <String, Object?>{
        'status': 'IN_PROGRESS',
        'completed_at': null,
      }),
      preferredSelectedId: item.id,
    );
  }

  Future<AppFailure?> completeTask(HousekeepingWorkItem item) {
    if (!item.isTask) {
      return Future<AppFailure?>.value(_invalidItemFailure('task_id'));
    }
    return _submitAction(
      () => _repository.updateTask(item.id, <String, Object?>{
        'status': 'COMPLETED',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }),
      preferredSelectedId: item.id,
    );
  }

  Future<AppFailure?> cancelTask(HousekeepingWorkItem item) {
    if (!item.isTask) {
      return Future<AppFailure?>.value(_invalidItemFailure('task_id'));
    }
    return _submitAction(
      () => _repository.updateTask(item.id, const <String, Object?>{
        'status': 'CANCELLED',
      }),
      preferredSelectedId: item.id,
    );
  }

  Future<AppFailure?> triageMaintenanceRequest(
    HousekeepingWorkItem item,
    HousekeepingMaintenanceTriageDraft draft,
  ) {
    if (!item.isMaintenanceRequest) {
      return Future<AppFailure?>.value(
        _invalidItemFailure('maintenance_request_id'),
      );
    }
    return _submitAction(
      () => _repository.triageMaintenanceRequest(item.id, draft),
      preferredSelectedId: item.id,
    );
  }

  Future<AppFailure?> completeMaintenanceRequest(HousekeepingWorkItem item) {
    if (!item.isMaintenanceRequest) {
      return Future<AppFailure?>.value(
        _invalidItemFailure('maintenance_request_id'),
      );
    }
    return _submitAction(
      () => _repository.updateMaintenanceRequest(item.id, <String, Object?>{
        'status': 'COMPLETED',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }),
      preferredSelectedId: item.id,
    );
  }

  Future<AppFailure?> cancelMaintenanceRequest(HousekeepingWorkItem item) {
    if (!item.isMaintenanceRequest) {
      return Future<AppFailure?>.value(
        _invalidItemFailure('maintenance_request_id'),
      );
    }
    return _submitAction(
      () => _repository.updateMaintenanceRequest(
        item.id,
        const <String, Object?>{'status': 'CANCELLED'},
      ),
      preferredSelectedId: item.id,
    );
  }

  Future<AppFailure?> _submitAction(
    Future<Result<void>> Function() submit, {
    HousekeepingResource? resourceAfterSuccess,
    String? preferredSelectedId,
  }) async {
    final HousekeepingWorkspaceState? current = _currentState;
    if (current == null) {
      return _invalidItemFailure('workspace');
    }

    HousekeepingWorkspaceQuery nextQuery = current.query;
    if (resourceAfterSuccess != null &&
        resourceAfterSuccess != current.query.resource) {
      nextQuery = current.query.copyWith(
        resource: resourceAfterSuccess,
        queue: _queueForResource(resourceAfterSuccess, current.query.queue),
        pageRequest: current.query.pageRequest.first(),
        clearStatus: true,
        clearAssignee: resourceAfterSuccess != HousekeepingResource.tasks,
      );
    }

    _emit(
      current.copyWith(
        query: nextQuery,
        isSaving: true,
        clearLastFailure: true,
        clearSelectedItem: resourceAfterSuccess != null,
      ),
    );
    final Result<void> result = await submit();
    return result.when<Future<AppFailure?>>(
      success: (_) async {
        return _refreshWorkspace(
          preferredSelectedId: preferredSelectedId ?? current.selectedItem?.id,
        );
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshWorkspace({String? preferredSelectedId}) async {
    final HousekeepingWorkspaceState current = _currentState!;
    final Result<HousekeepingWorkspaceLoad> loadResult = await _repository
        .getWorkspace(current.query);
    return loadResult.when<Future<AppFailure?>>(
      success: (HousekeepingWorkspaceLoad load) async {
        final HousekeepingWorkItem? selected = _selectAfterRefresh(
          load.items.items,
          preferredSelectedId,
        );
        _emit(
          _currentState!.copyWith(
            overview: load.overview,
            items: load.items,
            selectedItem: selected,
            isRefreshing: false,
            isSaving: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) async {
        _emit(
          _currentState!.copyWith(
            isRefreshing: false,
            isSaving: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  HousekeepingWorkItem? _selectAfterRefresh(
    List<HousekeepingWorkItem> items,
    String? preferredSelectedId,
  ) {
    if (preferredSelectedId != null) {
      for (final HousekeepingWorkItem item in items) {
        if (item.id == preferredSelectedId) {
          return item;
        }
      }
    }
    return items.firstOrNull;
  }

  HousekeepingWorkspaceState? get _currentState {
    final Result<HousekeepingWorkspaceState>? currentResult =
        state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<HousekeepingWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(HousekeepingWorkspaceState nextState) {
    state = AsyncData<Result<HousekeepingWorkspaceState>>(
      Result<HousekeepingWorkspaceState>.success(nextState),
    );
  }

  AppFailure _invalidItemFailure(String field) {
    return AppFailure.validation(validationFields: <String>{field});
  }
}

HousekeepingQueue _queueForResource(
  HousekeepingResource resource,
  HousekeepingQueue currentQueue,
) {
  return switch (resource) {
    HousekeepingResource.tasks =>
      currentQueue.isRequestQueue ? HousekeepingQueue.all : currentQueue,
    HousekeepingResource.schedules => HousekeepingQueue.all,
    HousekeepingResource.maintenanceRequests =>
      currentQueue.isTaskQueue ? HousekeepingQueue.all : currentQueue,
  };
}

HousekeepingResource _resourceForQueue(
  HousekeepingQueue queue,
  HousekeepingResource currentResource,
) {
  if (queue.isTaskQueue) {
    return HousekeepingResource.tasks;
  }
  if (queue.isRequestQueue) {
    return HousekeepingResource.maintenanceRequests;
  }
  return currentResource;
}
