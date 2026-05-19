import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/emergency/data/repositories/emergency_repository_impl.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final emergencyWorkspaceControllerProvider =
    AsyncNotifierProvider<
      EmergencyWorkspaceController,
      Result<EmergencyWorkspaceState>
    >(EmergencyWorkspaceController.new);

final class EmergencyWorkspaceController
    extends AsyncNotifier<Result<EmergencyWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 8);

  EmergencyRepository get _repository => ref.read(emergencyRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<EmergencyWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.emergencyWorkspace,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<EmergencyWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshReferenceData: true);
  }

  Future<AppFailure?> applySearch(String search) async {
    final EmergencyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: search.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshingBoard: true,
        clearLastFailure: true,
      ),
    );
    return _refreshBoard(showLoading: true);
  }

  Future<AppFailure?> applyScope(EmergencyBoardScope scope) async {
    final EmergencyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          scope: scope,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshingBoard: true,
        clearLastFailure: true,
      ),
    );
    return _refreshBoard(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final EmergencyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(pageRequest: request),
        isRefreshingBoard: true,
        clearLastFailure: true,
      ),
    );
    return _refreshBoard(showLoading: true);
  }

  Future<AppFailure?> selectCase(EmergencyCaseSummary summary) async {
    final EmergencyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<EmergencyCaseDetail> result = await _repository
        .loadEmergencyDetail(summary);
    return result.when(
      success: (EmergencyCaseDetail detail) {
        final EmergencyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedDetail: detail,
              board: _replaceSummary(latest.board, detail.summary),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final EmergencyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> createQuickArrival(EmergencyQuickArrivalInput input) {
    final policy = ref.read(appAccessPolicyProvider);
    final EmergencyQuickArrivalInput scopedInput = input.copyWith(
      tenantId: input.tenantId ?? policy.tenantId,
      facilityId: input.facilityId ?? policy.facilityId,
    );

    return _mutate(
      () => _repository.createQuickArrival(scopedInput),
      selectUpdated: true,
    );
  }

  Future<AppFailure?> updatePriority(String severity) {
    return _mutateSelected(
      (EmergencyCaseDetail detail) =>
          _repository.updateCasePriority(detail: detail, severity: severity),
    );
  }

  Future<AppFailure?> recordTriage({
    required String triageLevel,
    String? notes,
  }) {
    return _mutateSelected(
      (EmergencyCaseDetail detail) => _repository.recordTriage(
        detail: detail,
        triageLevel: triageLevel,
        notes: notes,
      ),
    );
  }

  Future<AppFailure?> markResponse({required String notes}) {
    return _mutateSelected(
      (EmergencyCaseDetail detail) =>
          _repository.markResponse(detail: detail, notes: notes),
    );
  }

  Future<AppFailure?> dispatchAmbulance({
    required String ambulanceId,
    String status = 'DISPATCHED',
  }) {
    return _mutateSelected(
      (EmergencyCaseDetail detail) => _repository.dispatchAmbulance(
        detail: detail,
        ambulanceId: ambulanceId,
        status: status,
      ),
      refreshReferenceDataAfter: true,
    );
  }

  Future<AppFailure?> updateLatestDispatchStatus(String status) {
    final EmergencyAmbulanceDispatch? dispatch =
        _currentState?.selectedDetail?.latestDispatch;
    if (dispatch == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected(
      (EmergencyCaseDetail detail) => _repository.updateDispatchStatus(
        detail: detail,
        dispatchId: dispatch.id,
        status: status,
      ),
      refreshReferenceDataAfter: true,
    );
  }

  Future<AppFailure?> startAmbulanceTrip({String? ambulanceId}) {
    final EmergencyCaseDetail? selected = _currentState?.selectedDetail;
    final String? resolvedAmbulanceId =
        ambulanceId ??
        selected?.latestDispatch?.ambulanceId ??
        selected?.latestTrip?.ambulanceId;
    if ((resolvedAmbulanceId ?? '').trim().isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected(
      (EmergencyCaseDetail detail) => _repository.startAmbulanceTrip(
        detail: detail,
        ambulanceId: resolvedAmbulanceId!.trim(),
      ),
      refreshReferenceDataAfter: true,
    );
  }

  Future<AppFailure?> completeTrip() {
    final EmergencyAmbulanceTrip? trip =
        _currentState?.selectedDetail?.activeTrip;
    if (trip == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected(
      (EmergencyCaseDetail detail) =>
          _repository.completeAmbulanceTrip(detail: detail, tripId: trip.id),
      refreshReferenceDataAfter: true,
    );
  }

  Future<AppFailure?> handoff({
    required String destination,
    String? notes,
    bool closeCase = true,
  }) {
    return _mutateSelected(
      (EmergencyCaseDetail detail) => _repository.recordHandoff(
        detail: detail,
        destination: destination,
        notes: notes,
        closeCase: closeCase,
      ),
      refreshBoardAfter: true,
    );
  }

  Future<Result<EmergencyWorkspaceState>> _loadInitialState() async {
    const EmergencyBoardQuery query = EmergencyBoardQuery();
    final Result<AppPage<EmergencyCaseSummary>> boardResult = await _repository
        .listEmergencyBoard(query);
    final AppPage<EmergencyCaseSummary>? board = _successOrNull(boardResult);
    if (board == null) {
      return Result<EmergencyWorkspaceState>.failure(
        _failureOrNull(boardResult)!,
      );
    }

    final EmergencyReferenceData referenceData = await _referenceData();
    return Result<EmergencyWorkspaceState>.success(
      EmergencyWorkspaceState(
        query: query,
        board: board,
        referenceData: referenceData,
      ),
    );
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshReferenceData = false,
  }) async {
    final EmergencyWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshingBoard: true,
          isRefreshingDetail: current.selectedDetail != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? failure = await _refreshBoard(showLoading: showLoading);
      if (failure != null) {
        return failure;
      }

      if (refreshReferenceData) {
        final EmergencyReferenceData referenceData = await _referenceData();
        final EmergencyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(referenceData: referenceData));
        }
      }

      final EmergencyCaseDetail? selected = _currentState?.selectedDetail;
      if (selected != null) {
        await selectCase(selected.summary);
      }

      return null;
    } finally {
      final EmergencyWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(
          latest.copyWith(isRefreshingBoard: false, isRefreshingDetail: false),
        );
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshBoard({required bool showLoading}) async {
    final EmergencyWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<EmergencyCaseSummary>> result = await _repository
        .listEmergencyBoard(current.query);
    return result.when(
      success: (AppPage<EmergencyCaseSummary> page) {
        final EmergencyWorkspaceState? latest = _currentState;
        if (latest != null) {
          final EmergencyCaseDetail? selected = _selectedAfterBoardRefresh(
            page,
            latest.selectedDetail,
          );
          _emit(
            latest.copyWith(
              board: page,
              selectedDetail: selected,
              isRefreshingBoard: false,
              clearSelectedDetail:
                  latest.selectedDetail != null && selected == null,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final EmergencyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingBoard: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<EmergencyReferenceData> _referenceData() async {
    final Result<EmergencyReferenceData> result = await _repository
        .loadReferenceData();
    return result.when(
      success: (EmergencyReferenceData data) => data,
      failure: (_) => const EmergencyReferenceData(),
    );
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<EmergencyCaseDetail>> Function(EmergencyCaseDetail detail)
    action, {
    bool refreshBoardAfter = false,
    bool refreshReferenceDataAfter = false,
  }) async {
    final EmergencyWorkspaceState? current = _currentState;
    final EmergencyCaseDetail? detail = current?.selectedDetail;
    if (current == null || detail == null) {
      return AppFailure.validation();
    }

    return _mutate(
      () => action(detail),
      refreshBoardAfter: refreshBoardAfter,
      refreshReferenceDataAfter: refreshReferenceDataAfter,
    );
  }

  Future<AppFailure?> _mutate(
    Future<Result<EmergencyCaseDetail>> Function() action, {
    bool selectUpdated = false,
    bool refreshBoardAfter = false,
    bool refreshReferenceDataAfter = false,
  }) async {
    final EmergencyWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<EmergencyCaseDetail> result = await action();
    return result.when(
      success: (EmergencyCaseDetail updated) async {
        final EmergencyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedDetail: selectUpdated
                  ? updated
                  : latest.selectedDetail == null
                  ? null
                  : updated,
              board: _replaceSummary(latest.board, updated.summary),
              isSaving: false,
            ),
          );
        }
        if (refreshReferenceDataAfter) {
          unawaited(_refreshReferenceData());
        }
        if (refreshBoardAfter) {
          unawaited(_refreshBoard(showLoading: false));
        }
        return null;
      },
      failure: (AppFailure failure) {
        final EmergencyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<void> _refreshReferenceData() async {
    final EmergencyReferenceData referenceData = await _referenceData();
    final EmergencyWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(latest.copyWith(referenceData: referenceData));
    }
  }

  EmergencyCaseDetail? _selectedAfterBoardRefresh(
    AppPage<EmergencyCaseSummary> page,
    EmergencyCaseDetail? selected,
  ) {
    if (selected == null) {
      return null;
    }

    for (final EmergencyCaseSummary item in page.items) {
      if (_isSameCase(item, selected.summary)) {
        return selected.copyWith(summary: item);
      }
    }

    return selected;
  }

  AppPage<EmergencyCaseSummary> _replaceSummary(
    AppPage<EmergencyCaseSummary> page,
    EmergencyCaseSummary summary,
  ) {
    var replaced = false;
    final List<EmergencyCaseSummary> items = <EmergencyCaseSummary>[];
    for (final EmergencyCaseSummary item in page.items) {
      if (_isSameCase(item, summary)) {
        if (!replaced) {
          items.add(summary);
          replaced = true;
        }
      } else {
        items.add(item);
      }
    }

    if (!replaced) {
      items.insert(0, summary);
    }

    return AppPage<EmergencyCaseSummary>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount == null || replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameCase(EmergencyCaseSummary left, EmergencyCaseSummary right) {
    return left.id == right.id ||
        (left.displayId != null && left.displayId == right.displayId);
  }

  T? _successOrNull<T>(Result<T> result) {
    return result.when(success: (T value) => value, failure: (_) => null);
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  EmergencyWorkspaceState? get _currentState {
    final Result<EmergencyWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<EmergencyWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(EmergencyWorkspaceState nextState) {
    state = AsyncData<Result<EmergencyWorkspaceState>>(
      Result<EmergencyWorkspaceState>.success(nextState),
    );
  }
}
