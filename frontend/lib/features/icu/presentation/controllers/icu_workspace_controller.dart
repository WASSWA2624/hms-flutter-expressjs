import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final icuWorkspaceControllerProvider =
    AsyncNotifierProvider<IcuWorkspaceController, Result<IcuWorkspaceState>>(
      IcuWorkspaceController.new,
    );

final class IcuWorkspaceController
    extends AsyncNotifier<Result<IcuWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 8);

  IcuRepository get _repository => ref.read(icuRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<IcuWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.icu,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<IcuWorkspaceState> result = await _loadInitialState();
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
    final IcuWorkspaceState? current = _currentState;
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

  Future<AppFailure?> applyScope(IcuBoardScope scope) async {
    final IcuWorkspaceState? current = _currentState;
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
    final IcuWorkspaceState? current = _currentState;
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

  Future<AppFailure?> selectPatient(IcuPatientSummary summary) async {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<IcuPatientDetail> result = await _repository.loadIcuDetail(
      summary,
    );
    return result.when(
      success: (IcuPatientDetail detail) {
        final IcuWorkspaceState? latest = _currentState;
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
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> recordObservation({
    required String observation,
    DateTime? observedAt,
  }) {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.recordObservation(
        detail: detail,
        observation: observation,
        observedAt: observedAt,
      ),
    );
  }

  Future<AppFailure?> recordVitals(IcuVitalsInput input) {
    return _mutateSelected(
      (IcuPatientDetail detail) =>
          _repository.recordVitals(detail: detail, input: input),
    );
  }

  Future<AppFailure?> addCriticalAlert({
    required String severity,
    required String message,
  }) {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.addCriticalAlert(
        detail: detail,
        severity: severity,
        message: message,
      ),
    );
  }

  Future<AppFailure?> acknowledgeLatestAlert() {
    final IcuCriticalAlert? alert = _currentState?.selectedDetail?.latestAlert;
    if (alert == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected(
      (IcuPatientDetail detail) =>
          _repository.acknowledgeAlert(detail: detail, alertId: alert.id),
    );
  }

  Future<AppFailure?> addRoundNote({required String notes, DateTime? roundAt}) {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.addRoundNote(
        detail: detail,
        notes: notes,
        roundAt: roundAt,
      ),
    );
  }

  Future<AppFailure?> requestTransfer({
    required String toWardId,
    String? fromWardId,
  }) {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.requestTransfer(
        detail: detail,
        toWardId: toWardId,
        fromWardId: fromWardId,
      ),
    );
  }

  Future<AppFailure?> markDischargeReady({
    required String summary,
    DateTime? dischargedAt,
  }) {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.markDischargeReady(
        detail: detail,
        summary: summary,
        dischargedAt: dischargedAt,
      ),
    );
  }

  Future<AppFailure?> transferOut() {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.transferOut(detail: detail),
      refreshBoardAfter: true,
    );
  }

  Future<Result<IcuWorkspaceState>> _loadInitialState() async {
    const IcuBoardQuery query = IcuBoardQuery();
    final Result<AppPage<IcuPatientSummary>> boardResult = await _repository
        .listIcuBoard(query);
    final AppPage<IcuPatientSummary>? board = _successOrNull(boardResult);
    if (board == null) {
      return Result<IcuWorkspaceState>.failure(_failureOrNull(boardResult)!);
    }

    final IcuReferenceData referenceData = await _referenceData();
    return Result<IcuWorkspaceState>.success(
      IcuWorkspaceState(
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
    final IcuWorkspaceState? current = _currentState;
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
        final IcuReferenceData referenceData = await _referenceData();
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(referenceData: referenceData));
        }
      }

      final IcuPatientDetail? selected = _currentState?.selectedDetail;
      if (selected != null) {
        await selectPatient(selected.summary);
      }

      return null;
    } finally {
      final IcuWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(
          latest.copyWith(isRefreshingBoard: false, isRefreshingDetail: false),
        );
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshBoard({required bool showLoading}) async {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<IcuPatientSummary>> result = await _repository
        .listIcuBoard(current.query);
    return result.when(
      success: (AppPage<IcuPatientSummary> page) {
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              board: page,
              selectedDetail: _selectedAfterBoardRefresh(
                page,
                latest.selectedDetail,
              ),
              isRefreshingBoard: false,
              clearSelectedDetail:
                  latest.selectedDetail != null &&
                  _selectedAfterBoardRefresh(page, latest.selectedDetail) ==
                      null,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingBoard: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<IcuReferenceData> _referenceData() async {
    final Result<IcuReferenceData> result = await _repository
        .loadReferenceData();
    return result.when(
      success: (IcuReferenceData data) => data,
      failure: (_) => const IcuReferenceData(),
    );
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<IcuPatientDetail>> Function(IcuPatientDetail detail) action, {
    bool refreshBoardAfter = false,
  }) async {
    final IcuWorkspaceState? current = _currentState;
    final IcuPatientDetail? detail = current?.selectedDetail;
    if (current == null || detail == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<IcuPatientDetail> result = await action(detail);
    return result.when(
      success: (IcuPatientDetail updated) async {
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedDetail: updated,
              board: _replaceSummary(latest.board, updated.summary),
              isSaving: false,
            ),
          );
        }
        if (refreshBoardAfter) {
          unawaited(_refreshBoard(showLoading: false));
        }
        return null;
      },
      failure: (AppFailure failure) {
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  IcuPatientDetail? _selectedAfterBoardRefresh(
    AppPage<IcuPatientSummary> page,
    IcuPatientDetail? selected,
  ) {
    if (selected == null) {
      return null;
    }

    for (final IcuPatientSummary item in page.items) {
      if (_isSameAdmission(item, selected.summary)) {
        return selected.copyWith(summary: item);
      }
    }

    return selected;
  }

  AppPage<IcuPatientSummary> _replaceSummary(
    AppPage<IcuPatientSummary> page,
    IcuPatientSummary summary,
  ) {
    var replaced = false;
    final List<IcuPatientSummary> items = <IcuPatientSummary>[];
    for (final IcuPatientSummary item in page.items) {
      if (_isSameAdmission(item, summary)) {
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

    return AppPage<IcuPatientSummary>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount == null || replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameAdmission(IcuPatientSummary left, IcuPatientSummary right) {
    return left.admissionId == right.admissionId ||
        left.id == right.id ||
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

  IcuWorkspaceState? get _currentState {
    final Result<IcuWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<IcuWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(IcuWorkspaceState nextState) {
    state = AsyncData<Result<IcuWorkspaceState>>(
      Result<IcuWorkspaceState>.success(nextState),
    );
  }
}
