import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/entities/physiotherapy_entities.dart';
import 'package:hosspi_hms/features/physiotherapy/domain/repositories/physiotherapy_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final physiotherapyWorkspaceControllerProvider =
    AsyncNotifierProvider<
      PhysiotherapyWorkspaceController,
      Result<PhysiotherapyWorkspaceState>
    >(PhysiotherapyWorkspaceController.new);

final class PhysiotherapyWorkspaceController
    extends AsyncNotifier<Result<PhysiotherapyWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 10);

  PhysiotherapyRepository get _repository =>
      ref.read(physiotherapyRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<PhysiotherapyWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.physiotherapy,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<PhysiotherapyWorkspaceState> result =
        await _loadInitialState();
    _startSync();
    return result;
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true);
  }

  Future<AppFailure?> applySearch(String value, {bool showLoading = true}) {
    final PhysiotherapyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: value.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: showLoading ? true : current.isRefreshing,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: showLoading);
  }

  Future<AppFailure?> applyScope(PhysiotherapyQueueScope scope) {
    final PhysiotherapyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          scope: scope,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> applyFilters(PhysiotherapyWorklistFilters filters) {
    final PhysiotherapyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          filters: filters,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> applyWorklistFilters({
    required PhysiotherapyQueueScope scope,
    required PhysiotherapyWorklistFilters filters,
    String? search,
  }) {
    final PhysiotherapyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: search?.trim(),
          scope: scope,
          filters: filters,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) {
    final PhysiotherapyWorkspaceState? current = _currentState;
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
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> selectWorkItem(TherapyWorkItem item) async {
    final PhysiotherapyWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<PhysiotherapyDetail> result = await _repository.loadDetail(
      item,
    );
    return result.when(
      success: (PhysiotherapyDetail detail) {
        final PhysiotherapyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedDetail: detail,
              worklist: _replaceItem(latest.worklist, detail.item),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final PhysiotherapyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              isRefreshingDetail: false,
              lastFailure: failure,
            ),
          );
        }
        return failure;
      },
    );
  }

  void clearSelection() {
    final PhysiotherapyWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        clearSelectedDetail: true,
        isRefreshingDetail: false,
        clearLastFailure: true,
      ),
    );
  }

  Future<AppFailure?> acceptReferral(String note) {
    return _mutateSelected(
      (TherapyWorkItem item) =>
          _repository.acceptReferral(item: item, note: note),
    );
  }

  Future<AppFailure?> scheduleSession({
    required DateTime startAt,
    required DateTime endAt,
    String? reason,
  }) {
    final String? providerUserId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.id;
    return _mutateSelected(
      (TherapyWorkItem item) => _repository.scheduleSession(
        item: item,
        startAt: startAt,
        endAt: endAt,
        providerUserId: providerUserId,
        reason: reason,
      ),
    );
  }

  Future<AppFailure?> recordAssessment({
    required String assessment,
    required String goals,
    required String plan,
    String? instructions,
  }) {
    return _mutateSelected(
      (TherapyWorkItem item) => _repository.recordAssessment(
        item: item,
        assessment: assessment,
        goals: goals,
        plan: plan,
        instructions: instructions,
      ),
    );
  }

  Future<AppFailure?> recordSession({
    required String note,
    String? attendanceStatus,
  }) {
    return _mutateSelected(
      (TherapyWorkItem item) => _repository.recordSession(
        item: item,
        note: note,
        attendanceStatus: attendanceStatus,
      ),
    );
  }

  Future<AppFailure?> markAttendance({
    required String status,
    String? note,
  }) {
    return _mutateSelected(
      (TherapyWorkItem item) => _repository.markAttendance(
        item: item,
        status: status,
        note: note,
      ),
    );
  }

  Future<AppFailure?> updatePlan({
    required String plan,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _mutateSelected(
      (TherapyWorkItem item) => _repository.updatePlan(
        item: item,
        plan: plan,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  Future<AppFailure?> addProgressNote(String note) {
    final String? authorUserId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.id;
    if (authorUserId == null || authorUserId.trim().isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected(
      (TherapyWorkItem item) => _repository.addProgressNote(
        item: item,
        authorUserId: authorUserId,
        note: note,
      ),
    );
  }

  Future<AppFailure?> scheduleFollowUp({
    required DateTime scheduledAt,
    String? notes,
  }) {
    return _mutateSelected(
      (TherapyWorkItem item) => _repository.scheduleFollowUp(
        item: item,
        scheduledAt: scheduledAt,
        notes: notes,
      ),
    );
  }

  Future<AppFailure?> closeEpisode(String summary) {
    return _mutateSelected(
      (TherapyWorkItem item) =>
          _repository.closeEpisode(item: item, summary: summary),
    );
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
  }

  Future<Result<PhysiotherapyWorkspaceState>> _loadInitialState() async {
    const PhysiotherapyWorklistQuery query = PhysiotherapyWorklistQuery();
    final Result<AppPage<TherapyWorkItem>> worklistResult = await _repository
        .listWorkItems(query);
    return worklistResult.map(
      (AppPage<TherapyWorkItem> worklist) =>
          PhysiotherapyWorkspaceState(query: query, worklist: worklist),
    );
  }

  Future<AppFailure?> _syncVisibleData({bool showLoading = false}) async {
    if (_isSyncing) {
      return null;
    }
    _isSyncing = true;
    try {
      final PhysiotherapyWorkspaceState? current = _currentState;
      if (current == null) {
        state = const AsyncLoading<Result<PhysiotherapyWorkspaceState>>();
        final Result<PhysiotherapyWorkspaceState> result =
            await _loadInitialState();
        state = AsyncData<Result<PhysiotherapyWorkspaceState>>(result);
        return _failureOrNull(result);
      }
      if (showLoading) {
        _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
      }
      return _refreshWorklist(showLoading: showLoading);
    } finally {
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshWorklist({required bool showLoading}) async {
    final PhysiotherapyWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<TherapyWorkItem>> result = await _repository
        .listWorkItems(current.query);
    return result.when(
      success: (AppPage<TherapyWorkItem> worklist) {
        final PhysiotherapyWorkspaceState? latest = _currentState;
        if (latest != null) {
          final PhysiotherapyDetail? selected = latest.selectedDetail;
          _emit(
            latest.copyWith(
              worklist: worklist,
              selectedDetail: selected == null
                  ? null
                  : selected.copyWith(
                      item: _matchingItem(worklist, selected.item) ??
                          selected.item,
                    ),
              isRefreshing: showLoading ? false : latest.isRefreshing,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final PhysiotherapyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              isRefreshing: showLoading ? false : latest.isRefreshing,
              lastFailure: failure,
            ),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<PhysiotherapyDetail>> Function(TherapyWorkItem item) mutate,
  ) async {
    final PhysiotherapyWorkspaceState? current = _currentState;
    final TherapyWorkItem? item = current?.selectedDetail?.item;
    if (current == null || item == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<PhysiotherapyDetail> result = await mutate(item);
    return result.when(
      success: (PhysiotherapyDetail detail) {
        final PhysiotherapyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedDetail: detail,
              worklist: _replaceItem(latest.worklist, detail.item),
              isSaving: false,
            ),
          );
        }
        unawaited(_refreshWorklist(showLoading: false));
        return null;
      },
      failure: (AppFailure failure) {
        final PhysiotherapyWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  void _startSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  AppPage<TherapyWorkItem> _replaceItem(
    AppPage<TherapyWorkItem> page,
    TherapyWorkItem item,
  ) {
    return AppPage<TherapyWorkItem>(
      items: page.items
          .map((TherapyWorkItem current) => current.id == item.id ? item : current)
          .toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  TherapyWorkItem? _matchingItem(
    AppPage<TherapyWorkItem> page,
    TherapyWorkItem selected,
  ) {
    for (final TherapyWorkItem item in page.items) {
      if (item.id == selected.id) {
        return item;
      }
    }
    return null;
  }

  PhysiotherapyWorkspaceState? get _currentState {
    return state.asData?.value.when(
      success: (PhysiotherapyWorkspaceState value) => value,
      failure: (_) => null,
    );
  }

  void _emit(PhysiotherapyWorkspaceState next) {
    state = AsyncData<Result<PhysiotherapyWorkspaceState>>(
      Result<PhysiotherapyWorkspaceState>.success(next),
    );
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }
}
