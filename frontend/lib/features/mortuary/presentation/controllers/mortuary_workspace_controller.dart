import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/mortuary/data/repositories/mortuary_repository_impl.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/domain/repositories/mortuary_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final mortuaryWorkspaceControllerProvider =
    AsyncNotifierProvider<
      MortuaryWorkspaceController,
      Result<MortuaryWorkspaceState>
    >(MortuaryWorkspaceController.new);

final class MortuaryWorkspaceController
    extends AsyncNotifier<Result<MortuaryWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 20);

  MortuaryRepository get _repository => ref.read(mortuaryRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<MortuaryWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.mortuary,
      onRefresh: (_) => _syncVisibleData(),
    );
    final Result<MortuaryWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true);
  }

  Future<AppFailure?> applySearch(String value) async {
    final MortuaryWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: value.trim(),
          pageRequest: current.query.pageRequest.first(),
          clearId: true,
          clearAction: true,
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace(showLoading: true);
  }

  Future<AppFailure?> switchPanel(String panel) async {
    final MortuaryWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final String resource =
        mortuaryDefaultResourceByPanel[panel] ?? mortuaryResourceCases;
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          panel: panel,
          resource: resource,
          pageRequest: current.query.pageRequest.first(),
          clearQueue: true,
          clearStatus: true,
          clearIdentificationStatus: true,
          clearId: true,
          clearAction: true,
        ),
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace(showLoading: true);
  }

  Future<AppFailure?> applyQueue(String? queue) async {
    final MortuaryWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final String? panel = queue == null ? null : _queuePanelById[queue];
    final String? resource = queue == null ? null : _queueResourceById[queue];
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          panel: panel,
          resource: resource,
          queue: queue,
          pageRequest: current.query.pageRequest.first(),
          clearQueue: queue == null,
          clearId: true,
          clearAction: true,
        ),
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace(showLoading: true);
  }

  Future<AppFailure?> applyFilters({
    String? panel,
    String? resource,
    String? queue,
    String? status,
    String? identificationStatus,
    String? facilityId,
    String? storageUnitId,
    String? storageSlotId,
    String? datePreset,
  }) async {
    final MortuaryWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final String effectivePanel = panel ?? current.query.panel;
    final String effectiveResource =
        resource ??
        _queueResourceById[queue] ??
        current.query.resource.ifNotEmpty ??
        mortuaryDefaultResourceByPanel[effectivePanel] ??
        mortuaryResourceCases;
    final String? effectivePanelForQueue = queue == null
        ? effectivePanel
        : _queuePanelById[queue] ?? effectivePanel;

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          panel: effectivePanelForQueue,
          resource: effectiveResource,
          queue: queue,
          status: status,
          identificationStatus: identificationStatus,
          facilityId: facilityId,
          storageUnitId: storageUnitId,
          storageSlotId: storageSlotId,
          datePreset: datePreset,
          pageRequest: current.query.pageRequest.first(),
          clearQueue: queue == null,
          clearStatus: status == null,
          clearIdentificationStatus: identificationStatus == null,
          clearFacilityId: facilityId == null,
          clearStorageUnitId: storageUnitId == null,
          clearStorageSlotId: storageSlotId == null,
          clearDatePreset: datePreset == null,
          clearId: true,
          clearAction: true,
        ),
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace(showLoading: true);
  }

  Future<AppFailure?> clearFilters() async {
    final MortuaryWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: MortuaryWorkspaceQuery(
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearSelectedItem: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorkspace(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final MortuaryWorkspaceState? current = _currentState;
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
    return _refreshWorkspace(showLoading: true);
  }

  Future<AppFailure?> selectItem(MortuaryWorkspaceItem item) async {
    final MortuaryWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<MortuaryWorkspaceItem> result = await _repository.getItem(
      resource: item.resource,
      id: item.effectiveDisplayId,
      baseQuery: current.query,
    );

    return result.when(
      success: (MortuaryWorkspaceItem detail) {
        final MortuaryWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedItem: detail,
              items: _replaceItem(latest.items, detail),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final MortuaryWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<Result<MortuaryWorkspaceState>> _loadInitialState() async {
    const MortuaryWorkspaceQuery query = MortuaryWorkspaceQuery();
    final Result<MortuaryWorkspacePayload> result = await _repository
        .getWorkspace(query);

    return result.when(
      success: (MortuaryWorkspacePayload payload) async {
        MortuaryWorkspaceItem? selected;
        if (payload.items.items.isNotEmpty) {
          final MortuaryWorkspaceItem first = payload.items.items.first;
          final Result<MortuaryWorkspaceItem> detailResult = await _repository
              .getItem(
                resource: first.resource,
                id: first.effectiveDisplayId,
                baseQuery: payload.filters ?? query,
              );
          selected = detailResult.when(
            success: (MortuaryWorkspaceItem detail) => detail,
            failure: (_) => first,
          );
        }

        return Result<MortuaryWorkspaceState>.success(
          _stateFromPayload(payload, query).copyWith(
            items: selected == null
                ? payload.items
                : _replaceItem(payload.items, selected),
            selectedItem: selected,
          ),
        );
      },
      failure: (AppFailure failure) =>
          Result<MortuaryWorkspaceState>.failure(failure),
    );
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  Future<AppFailure?> _syncVisibleData({bool showLoading = false}) async {
    final MortuaryWorkspaceState? current = _currentState;
    if (current == null || _isSyncing) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingDetail: current.selectedItem != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? failure = await _refreshWorkspace(
        showLoading: showLoading,
      );
      if (failure != null) {
        return failure;
      }

      final MortuaryWorkspaceItem? selected = _currentState?.selectedItem;
      if (selected != null) {
        final Result<MortuaryWorkspaceItem> detailResult = await _repository
            .getItem(
              resource: selected.resource,
              id: selected.effectiveDisplayId,
              baseQuery: _currentState?.query ?? current.query,
            );
        detailResult.when(
          success: (MortuaryWorkspaceItem detail) {
            final MortuaryWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(
                latest.copyWith(
                  selectedItem: detail,
                  items: _replaceItem(latest.items, detail),
                ),
              );
            }
          },
          failure: (_) {},
        );
      }
      return null;
    } finally {
      final MortuaryWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshWorkspace({required bool showLoading}) async {
    final MortuaryWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<MortuaryWorkspacePayload> result = await _repository
        .getWorkspace(current.query);
    return result.when(
      success: (MortuaryWorkspacePayload payload) {
        final MortuaryWorkspaceState? latest = _currentState;
        if (latest != null) {
          final MortuaryWorkspaceState next = _stateFromPayload(
            payload,
            latest.query,
          );
          _emit(
            latest.copyWith(
              items: next.items,
              lookups: next.lookups,
              summary: next.summary,
              queues: next.queues,
              panels: next.panels,
              spotlight: next.spotlight,
              query: next.query,
              lastUpdatedAt: next.lastUpdatedAt,
              isRefreshing: false,
              selectedItem: _selectedAfterRefresh(
                next.items,
                latest.selectedItem,
              ),
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final MortuaryWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  MortuaryWorkspaceState _stateFromPayload(
    MortuaryWorkspacePayload payload,
    MortuaryWorkspaceQuery fallbackQuery,
  ) {
    return MortuaryWorkspaceState(
      items: payload.items,
      query: (payload.filters ?? fallbackQuery).copyWith(
        pageRequest: fallbackQuery.pageRequest,
      ),
      lookups: payload.lookups,
      summary: payload.summary,
      queues: payload.queues,
      panels: payload.panels,
      spotlight: payload.spotlight,
      lastUpdatedAt: payload.lastUpdatedAt,
    );
  }

  MortuaryWorkspaceItem? _selectedAfterRefresh(
    AppPage<MortuaryWorkspaceItem> page,
    MortuaryWorkspaceItem? selected,
  ) {
    if (selected == null) {
      return page.items.isEmpty ? null : page.items.first;
    }
    for (final MortuaryWorkspaceItem item in page.items) {
      if (_isSameItem(item, selected)) {
        return selected;
      }
    }
    return selected;
  }

  AppPage<MortuaryWorkspaceItem> _replaceItem(
    AppPage<MortuaryWorkspaceItem> page,
    MortuaryWorkspaceItem replacement,
  ) {
    var replaced = false;
    final List<MortuaryWorkspaceItem> items = page.items
        .map((MortuaryWorkspaceItem item) {
          if (_isSameItem(item, replacement)) {
            replaced = true;
            return replacement;
          }
          return item;
        })
        .toList(growable: true);

    if (!replaced) {
      items.insert(0, replacement);
    }

    return AppPage<MortuaryWorkspaceItem>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameItem(MortuaryWorkspaceItem left, MortuaryWorkspaceItem right) {
    return left.resource == right.resource &&
        (left.id == right.id ||
            left.displayId != null && left.displayId == right.displayId);
  }

  MortuaryWorkspaceState? get _currentState {
    final Result<MortuaryWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<MortuaryWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(MortuaryWorkspaceState nextState) {
    state = AsyncData<Result<MortuaryWorkspaceState>>(
      Result<MortuaryWorkspaceState>.success(nextState),
    );
  }
}

const Map<String, String> _queuePanelById = <String, String>{
  mortuaryQueueIdentificationPending: mortuaryPanelIntake,
  mortuaryQueueStorageExceptions: mortuaryPanelStorage,
  mortuaryQueueReleaseReady: mortuaryPanelRelease,
  mortuaryQueueUnsettledBilling: mortuaryPanelRelease,
  mortuaryQueuePostMortemPending: mortuaryPanelReporting,
};

const Map<String, String> _queueResourceById = <String, String>{
  mortuaryQueueIdentificationPending: mortuaryResourceCases,
  mortuaryQueueStorageExceptions: mortuaryResourceStorageAssignments,
  mortuaryQueueReleaseReady: mortuaryResourceReleaseAuthorisations,
  mortuaryQueueUnsettledBilling: mortuaryResourceBillableEvents,
  mortuaryQueuePostMortemPending: mortuaryResourcePostMortemRequests,
};

extension _NullableStringX on String? {
  String? get ifNotEmpty {
    final String? normalized = this?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
