import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
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

  @override
  Future<Result<ClaimsWorkspaceState>> build() async {
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

        return Result<ClaimsWorkspaceState>.success(
          ClaimsWorkspaceState(
            query: query,
            queue: queue,
            referenceData: referenceData,
          ),
        );
      },
      failure: (AppFailure failure) async {
        return Result<ClaimsWorkspaceState>.failure(failure);
      },
    );
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
          if (status == 'APPROVED') 'approved_at': _nowIso(),
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
      success: (ClaimsQueueDetail detail) {
        _emit(
          _currentState!.copyWith(
            selectedDetail: detail,
            isSaving: false,
            isRefreshingDetail: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isSaving: false,
            isRefreshingDetail: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> _refreshQueue() async {
    final ClaimsWorkspaceState current = _currentState!;
    final Result<AppPage<ClaimsQueueItem>> result = await _repository.listQueue(
      current.query,
    );

    return result.when(
      success: (AppPage<ClaimsQueueItem> queue) {
        _emit(_currentState!.copyWith(queue: queue, isRefreshing: false));
        return null;
      },
      failure: (AppFailure failure) {
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
