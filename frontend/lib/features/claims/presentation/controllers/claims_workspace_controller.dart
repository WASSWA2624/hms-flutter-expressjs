import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final claimsWorkspaceControllerProvider =
    AsyncNotifierProvider<
      ClaimsWorkspaceController,
      Result<ClaimsWorkspaceState>
    >(ClaimsWorkspaceController.new);

final class ClaimsWorkspaceController
    extends AsyncNotifier<Result<ClaimsWorkspaceState>> {
  ClaimsRepository get _repository => ref.read(claimsRepositoryProvider);

  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<ClaimsWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.claims,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: _syncFromRealtime,
    );
    return runWorkspaceInitialLoad(ref, () async {
      const ClaimsQueueQuery query = ClaimsQueueQuery();
      final Result<AppPage<ClaimsQueueItem>> queueResult = await _repository
          .listQueue(query);

      return queueResult.when(
        success: (AppPage<ClaimsQueueItem> queue) async {
          final ClaimsReferenceData referenceData = await _repository
              .loadReferenceData()
              .then(
                (Result<ClaimsReferenceData> result) => result.when(
                  success: (ClaimsReferenceData value) => value,
                  failure: (_) => const ClaimsReferenceData(
                    coverageUnavailable: true,
                    invoicesUnavailable: true,
                  ),
                ),
              );
          final ClaimsWorkspaceSummary? summary = await _loadSummary();

          return Result<ClaimsWorkspaceState>.success(
            ClaimsWorkspaceState(
              query: query,
              queue: queue,
              referenceData: referenceData,
              summary: summary,
            ),
          );
        },
        failure: (AppFailure failure) async {
          return Result<ClaimsWorkspaceState>.failure(failure);
        },
      );
    });
  }

  Future<ClaimsWorkspaceSummary?> _loadSummary() {
    return _repository.loadWorkspaceSummary().then(
      (Result<ClaimsWorkspaceSummary> result) => result.when(
        success: (ClaimsWorkspaceSummary value) => value,
        failure: (_) => null,
      ),
    );
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (_isSyncing || (_currentState?.isSaving ?? false)) {
      _pendingRefresh.defer(
        WorkspaceEventRefreshPlan.forMessage(
          message,
          profile: WorkspaceRefreshProfile.fullOnMatch,
        ),
      );
      return;
    }
    final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forMessage(
      message,
      profile: WorkspaceRefreshProfile.fullOnMatch,
    );
    if (plan.isEmpty) {
      return;
    }
    await _syncVisibleData(plan: plan);
  }

  Future<AppFailure?> _syncVisibleData({
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.full,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final ClaimsWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      _pendingRefresh.defer(plan);
      return null;
    }

    final bool refreshList = workspacePlanRefreshesPrimaryList(plan);
    if (!refreshList && !plan.selectedDetail) {
      return null;
    }

    _isSyncing = true;
    try {
      if (refreshList) {
        final AppFailure? failure = await _refreshQueue();
        if (failure != null) {
          return failure;
        }
      }
      if (plan.selectedDetail) {
        final ClaimsQueueDetail? selected = _currentState?.selectedDetail;
        if (selected != null) {
          await selectItem(selected.item);
        }
      }
      return null;
    } finally {
      _isSyncing = false;
      if (_pendingRefresh.refreshPending &&
          !(_currentState?.isSaving ?? false)) {
        final WorkspaceRefreshPlan pendingPlan = _pendingRefresh.takePending();
        if (!pendingPlan.isEmpty) {
          unawaited(_syncVisibleData(plan: pendingPlan));
        }
      }
    }
  }

  Future<AppFailure?> refresh() async {
    final ClaimsWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }

    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    final AppFailure? failure = await _refreshQueue();
    if (failure != null) {
      return failure;
    }

    final ClaimsQueueDetail? selected = _currentState?.selectedDetail;
    if (selected != null) {
      return selectItem(selected.item);
    }
    return null;
  }

  Future<AppFailure?> applySearch(String value) async {
    final ClaimsWorkspaceState? current = _currentState;
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
    return _refreshQueue();
  }

  Future<AppFailure?> applyFilter(ClaimsQueueFilter filter) async {
    final ClaimsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          filter: filter,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearSelectedDetail: true,
        clearLastFailure: true,
      ),
    );
    return _refreshQueue();
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final ClaimsWorkspaceState? current = _currentState;
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
    return _refreshQueue();
  }

  Future<Result<List<ClaimsQueueItem>>> loadMatchingQueueItems() {
    final ClaimsWorkspaceState? current = _currentState;
    if (current == null) {
      return Future<Result<List<ClaimsQueueItem>>>.value(
        const Result<List<ClaimsQueueItem>>.success(<ClaimsQueueItem>[]),
      );
    }
    final ClaimsQueueQuery query = current.query;
    return loadMatchingAppPageItems<ClaimsQueueItem>(
      loadPage: (AppPageRequest request) {
        return _repository.listQueue(query.copyWith(pageRequest: request));
      },
    );
  }

  Future<AppFailure?> selectItem(ClaimsQueueItem item) async {
    final ClaimsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<ClaimsQueueDetail> result = await _repository.getDetail(item);

    return result.when(
      success: (ClaimsQueueDetail detail) {
        _emit(
          _currentState!.copyWith(
            selectedDetail: detail,
            isRefreshingDetail: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshingDetail: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  /// Selects a queue row for stage writes without a detail fetch.
  ///
  /// Next-action forms only need the embedded authorization / claim ids;
  /// [selectItem] remains for opening the full detail dialog.
  void focusItem(ClaimsQueueItem item) {
    final ClaimsWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        selectedDetail: ClaimsQueueDetail(
          item: item,
          authorization: item.authorization,
          claim: item.claim,
        ),
        clearLastFailure: true,
      ),
    );
  }

  Future<AppFailure?> requestPreAuthorization({
    required String coveragePlanId,
  }) async {
    final ClaimsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<PreAuthorizationRecord> result = await _repository
        .requestPreAuthorization(<String, Object?>{
          'coverage_plan_id': coveragePlanId,
          'status': 'PENDING',
          'requested_at': _nowIso(),
        });

    return result.when<Future<AppFailure?>>(
      success: (PreAuthorizationRecord authorization) async {
        return _afterMutation(ClaimsQueueItem.authorization(authorization));
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> updateAuthorizationStatus({
    required String status,
    num? approvedAmount,
  }) async {
    final ClaimsQueueDetail? detail = _currentState?.selectedDetail;
    final PreAuthorizationRecord? authorization = detail?.authorization;
    if (authorization == null) {
      return AppFailure.validation(
        validationFields: <String>{'authorization_id'},
      );
    }

    _emit(_currentState!.copyWith(isSaving: true, clearLastFailure: true));
    final Result<PreAuthorizationRecord> result = await _repository
        .updatePreAuthorization(authorization.apiId, <String, Object?>{
          'status': status,
          if (status == 'APPROVED' || status == 'PARTIAL')
            'approved_at': _nowIso(),
          'approved_amount': ?approvedAmount,
        });

    return result.when<Future<AppFailure?>>(
      success: (PreAuthorizationRecord updated) async {
        return _afterMutation(ClaimsQueueItem.authorization(updated));
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> prepareClaim({
    required String coveragePlanId,
    required String invoiceId,
  }) async {
    final ClaimsWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<InsuranceClaimRecord> result = await _repository
        .prepareClaim(<String, Object?>{
          'coverage_plan_id': coveragePlanId,
          'invoice_id': invoiceId,
          'status': 'SUBMITTED',
          'submitted_at': _nowIso(),
        });

    return result.when<Future<AppFailure?>>(
      success: (InsuranceClaimRecord claim) async {
        return _afterMutation(ClaimsQueueItem.claim(claim));
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> submitClaim({required String notes}) async {
    final ClaimsQueueDetail? detail = _currentState?.selectedDetail;
    final InsuranceClaimRecord? claim = detail?.claim;
    if (claim == null) {
      return AppFailure.validation(validationFields: <String>{'claim_id'});
    }

    _emit(_currentState!.copyWith(isSaving: true, clearLastFailure: true));
    final Result<InsuranceClaimRecord> result = await _repository.submitClaim(
      claim.apiId,
      <String, Object?>{'submitted_at': _nowIso(), 'notes': notes},
    );

    return result.when<Future<AppFailure?>>(
      success: (InsuranceClaimRecord updated) async {
        return _afterMutation(ClaimsQueueItem.claim(updated));
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> reconcileClaim({
    required String status,
    required String notes,
    num? settlementAmount,
  }) async {
    final ClaimsQueueDetail? detail = _currentState?.selectedDetail;
    final InsuranceClaimRecord? claim = detail?.claim;
    if (claim == null) {
      return AppFailure.validation(validationFields: <String>{'claim_id'});
    }

    _emit(_currentState!.copyWith(isSaving: true, clearLastFailure: true));
    final Result<InsuranceClaimRecord> result = await _repository
        .reconcileClaim(claim.apiId, <String, Object?>{
          'status': status,
          'notes': notes,
          'settlement_amount': ?settlementAmount,
        });

    return result.when<Future<AppFailure?>>(
      success: (InsuranceClaimRecord updated) async {
        return _afterMutation(ClaimsQueueItem.claim(updated));
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> syncClaimStatus() async {
    final ClaimsQueueDetail? detail = _currentState?.selectedDetail;
    final InsuranceClaimRecord? claim = detail?.claim;
    if (claim == null) {
      return AppFailure.validation(validationFields: <String>{'claim_id'});
    }

    _emit(_currentState!.copyWith(isSaving: true, clearLastFailure: true));
    final Result<InsuranceClaimRecord> result = await _repository
        .syncClaimStatus(claim.apiId);

    return result.when<Future<AppFailure?>>(
      success: (InsuranceClaimRecord updated) async {
        return _afterMutation(ClaimsQueueItem.claim(updated));
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _afterMutation(ClaimsQueueItem selectedItem) async {
    final AppFailure? queueFailure = await _refreshQueue();
    final ClaimsWorkspaceState? current = _currentState;
    if (queueFailure != null || current == null) {
      if (current != null) {
        _emit(current.copyWith(isSaving: false));
      }
      return queueFailure;
    }

    _emit(current.copyWith(isRefreshingDetail: true));
    final Result<ClaimsQueueDetail> detailResult = await _repository.getDetail(
      selectedItem,
    );
    return detailResult.when(
      success: (ClaimsQueueDetail detail) async {
        _emit(
          _currentState!.copyWith(
            selectedDetail: detail,
            isSaving: false,
            isRefreshingDetail: false,
          ),
        );
        await _flushPendingRealtimeRefresh();
        return null;
      },
      failure: (AppFailure failure) async {
        _emit(
          _currentState!.copyWith(
            isSaving: false,
            isRefreshingDetail: false,
            lastFailure: failure,
          ),
        );
        await _flushPendingRealtimeRefresh();
        return failure;
      },
    );
  }

  Future<void> _flushPendingRealtimeRefresh() async {
    if (!_pendingRefresh.refreshPending ||
        _isSyncing ||
        (_currentState?.isSaving ?? false)) {
      return;
    }
    final WorkspaceRefreshPlan pendingPlan = _pendingRefresh.takePending();
    if (!pendingPlan.isEmpty) {
      await _syncVisibleData(plan: pendingPlan);
    }
  }

  Future<AppFailure?> _refreshQueue() async {
    final ClaimsWorkspaceState current = _currentState!;
    final Result<AppPage<ClaimsQueueItem>> result = await _repository.listQueue(
      current.query,
    );

    return result.when<Future<AppFailure?>>(
      success: (AppPage<ClaimsQueueItem> queue) async {
        final ClaimsWorkspaceSummary? summary = await _loadSummary();
        _emit(
          _currentState!.copyWith(
            queue: queue,
            summary: summary,
            isRefreshing: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) async {
        _emit(
          _currentState!.copyWith(isRefreshing: false, lastFailure: failure),
        );
        return failure;
      },
    );
  }

  ClaimsWorkspaceState? get _currentState {
    final Result<ClaimsWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<ClaimsWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(ClaimsWorkspaceState nextState) {
    state = AsyncData<Result<ClaimsWorkspaceState>>(
      Result<ClaimsWorkspaceState>.success(nextState),
    );
  }
}

String _nowIso() {
  return DateTime.now().toUtc().toIso8601String();
}
