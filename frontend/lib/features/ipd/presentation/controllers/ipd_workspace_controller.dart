import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final ipdWorkspaceControllerProvider =
    AsyncNotifierProvider<IpdWorkspaceController, Result<IpdWorkspaceState>>(
      IpdWorkspaceController.new,
    );

final class IpdWorkspaceController
    extends AsyncNotifier<Result<IpdWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 8);

  IpdRepository get _repository => ref.read(ipdRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<IpdWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    final Result<IpdWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshReferenceData: true);
  }

  Future<AppFailure?> applySearch(String search) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: search.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> applyScope(IpdQueueScope scope) async {
    final IpdWorkspaceState? current = _currentState;
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

  Future<AppFailure?> applyWard(String? wardId) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          wardId: wardId,
          clearWard: wardId == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final IpdWorkspaceState? current = _currentState;
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

  Future<AppFailure?> selectAdmission(IpdAdmissionSummary admission) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<IpdAdmissionDetail> result = await _repository.getAdmission(
      admission.apiId,
    );
    return result.when(
      success: (IpdAdmissionDetail detail) {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedAdmission: detail,
              admissions: _replaceAdmission(latest.admissions, detail.summary),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  void clearSelection() {
    final IpdWorkspaceState? current = _currentState;
    if (current != null) {
      _emit(current.copyWith(clearSelectedAdmission: true));
    }
  }

  Future<AppFailure?> assignBed(IpdAdmissionSummary admission, String bedId) {
    return _mutateAdmission(
      admission,
      () => _repository.assignBed(admission.apiId, <String, Object?>{
        'bed_id': bedId,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
      }),
      refreshReferenceData: true,
    );
  }

  Future<AppFailure?> releaseBed(IpdAdmissionSummary admission) {
    return _mutateAdmission(
      admission,
      () => _repository.releaseBed(admission.apiId, <String, Object?>{
        'released_at': DateTime.now().toUtc().toIso8601String(),
      }),
      refreshReferenceData: true,
    );
  }

  Future<AppFailure?> rejectAdmission(
    IpdAdmissionSummary admission,
    String reason,
  ) {
    return _mutateAdmission(
      admission,
      () => _repository.rejectAdmission(admission.apiId, <String, Object?>{
        'reason': reason,
      }),
    );
  }

  Future<AppFailure?> requestTransfer({
    required IpdAdmissionSummary admission,
    String? fromWardId,
    required String toWardId,
  }) {
    return _mutateAdmission(
      admission,
      () => _repository.requestTransfer(admission.apiId, <String, Object?>{
        'from_ward_id': fromWardId,
        'to_ward_id': toWardId,
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<AppFailure?> updateTransfer({
    required IpdAdmissionSummary admission,
    required String action,
    String? transferRequestId,
    String? toBedId,
  }) {
    return _mutateAdmission(
      admission,
      () => _repository.updateTransfer(admission.apiId, <String, Object?>{
        'transfer_request_id': transferRequestId,
        'action': action,
        'to_bed_id': toBedId,
      }),
      refreshReferenceData: action == 'COMPLETE',
    );
  }

  Future<AppFailure?> addWardRound(
    IpdAdmissionSummary admission,
    String notes,
  ) {
    return _mutateAdmission(
      admission,
      () => _repository.addWardRound(admission.apiId, <String, Object?>{
        'round_at': DateTime.now().toUtc().toIso8601String(),
        'notes': notes,
      }),
    );
  }

  Future<AppFailure?> addNursingNote(
    IpdAdmissionSummary admission,
    String note,
  ) {
    return _mutateAdmission(
      admission,
      () => _repository.addNursingNote(admission.apiId, <String, Object?>{
        'note': note,
      }),
    );
  }

  Future<AppFailure?> addMedicationAdministration(
    IpdAdmissionSummary admission,
    Map<String, Object?> payload,
  ) {
    return _mutateAdmission(
      admission,
      () => _repository.addMedicationAdministration(admission.apiId, payload),
    );
  }

  Future<AppFailure?> planDischarge(
    IpdAdmissionSummary admission,
    String summary,
  ) {
    return _mutateAdmission(
      admission,
      () => _repository.planDischarge(admission.apiId, <String, Object?>{
        'summary': summary,
      }),
    );
  }

  Future<AppFailure?> finalizeDischarge(
    IpdAdmissionSummary admission,
    String summary,
  ) {
    return _mutateAdmission(
      admission,
      () => _repository.finalizeDischarge(admission.apiId, <String, Object?>{
        'summary': summary,
        'discharged_at': DateTime.now().toUtc().toIso8601String(),
      }),
      refreshReferenceData: true,
    );
  }

  Future<Result<IpdWorkspaceState>> _loadInitialState() async {
    const IpdAdmissionQuery query = IpdAdmissionQuery();
    final Result<AppPage<IpdAdmissionSummary>> admissionsResult =
        await _repository.listAdmissions(query);
    final AppPage<IpdAdmissionSummary>? admissions = _successOrNull(
      admissionsResult,
    );
    if (admissions == null) {
      return Result<IpdWorkspaceState>.failure(
        _failureOrNull(admissionsResult)!,
      );
    }

    final IpdReferenceData referenceData = await _referenceData();
    return Result<IpdWorkspaceState>.success(
      IpdWorkspaceState(
        query: query,
        admissions: admissions,
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
    final IpdWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingDetail: current.selectedAdmission != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? failure = await _refreshWorklist(
        showLoading: showLoading,
      );
      if (failure != null) {
        return failure;
      }

      if (refreshReferenceData) {
        final IpdReferenceData referenceData = await _referenceData();
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(referenceData: referenceData));
        }
      }

      final IpdAdmissionSummary? selected =
          _currentState?.selectedAdmission?.summary;
      if (selected != null) {
        await selectAdmission(selected);
      }

      return null;
    } finally {
      final IpdWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshWorklist({required bool showLoading}) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<IpdAdmissionSummary>> result = await _repository
        .listAdmissions(current.query);
    return result.when(
      success: (AppPage<IpdAdmissionSummary> page) {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              admissions: page,
              isRefreshing: showLoading ? false : latest.isRefreshing,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<IpdReferenceData> _referenceData() async {
    final results = await Future.wait(<Future<Object>>[
      _repository.listWards(),
      _repository.listBeds(status: 'AVAILABLE'),
    ]);

    final Result<List<IpdWardOption>> wardsResult =
        results[0] as Result<List<IpdWardOption>>;
    final Result<List<IpdBedOption>> bedsResult =
        results[1] as Result<List<IpdBedOption>>;

    return IpdReferenceData(
      wards: wardsResult.when(
        success: (List<IpdWardOption> value) => value,
        failure: (_) => const <IpdWardOption>[],
      ),
      availableBeds: bedsResult.when(
        success: (List<IpdBedOption> value) => value,
        failure: (_) => const <IpdBedOption>[],
      ),
    );
  }

  Future<AppFailure?> _mutateAdmission(
    IpdAdmissionSummary admission,
    Future<Result<IpdAdmissionDetail>> Function() action, {
    bool refreshReferenceData = false,
  }) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<IpdAdmissionDetail> result = await action();
    return result.when(
      success: (IpdAdmissionDetail detail) async {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedAdmission: detail,
              admissions: _replaceAdmission(latest.admissions, detail.summary),
              isSaving: false,
            ),
          );
        }
        if (refreshReferenceData) {
          final IpdReferenceData referenceData = await _referenceData();
          final IpdWorkspaceState? refreshed = _currentState;
          if (refreshed != null) {
            _emit(refreshed.copyWith(referenceData: referenceData));
          }
        }
        unawaited(_refreshWorklist(showLoading: false));
        return null;
      },
      failure: (AppFailure failure) {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  AppPage<IpdAdmissionSummary> _replaceAdmission(
    AppPage<IpdAdmissionSummary> page,
    IpdAdmissionSummary admission,
  ) {
    var replaced = false;
    final List<IpdAdmissionSummary> items = <IpdAdmissionSummary>[];
    for (final IpdAdmissionSummary item in page.items) {
      if (item.id == admission.id) {
        if (!replaced) {
          items.add(admission);
          replaced = true;
        }
      } else {
        items.add(item);
      }
    }

    if (!replaced) {
      items.insert(0, admission);
    }

    return AppPage<IpdAdmissionSummary>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
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

  IpdWorkspaceState? get _currentState {
    final Result<IpdWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<IpdWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(IpdWorkspaceState nextState) {
    state = AsyncData<Result<IpdWorkspaceState>>(
      Result<IpdWorkspaceState>.success(nextState),
    );
  }
}
