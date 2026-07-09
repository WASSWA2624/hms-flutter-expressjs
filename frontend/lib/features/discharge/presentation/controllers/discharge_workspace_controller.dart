import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final dischargeWorkspaceControllerProvider =
    AsyncNotifierProvider<
      DischargeWorkspaceController,
      Result<DischargeWorkspaceState>
    >(DischargeWorkspaceController.new);

final class DischargeWorkspaceController
    extends AsyncNotifier<Result<DischargeWorkspaceState>> {
  DischargeRepository get _repository => ref.read(dischargeRepositoryProvider);

  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<DischargeWorkspaceState>> build() async {
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.discharge,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: _syncFromRealtime,
    );
    const DischargeWorklistQuery query = DischargeWorklistQuery();
    return runWorkspaceInitialLoad(ref, () => _loadWorkspace(query));
  }

  Future<Result<DischargeWorkspaceState>> _loadWorkspace(
    DischargeWorklistQuery query,
  ) async {
    final Result<AppPage<IpdAdmissionSummary>> queueResult = await _repository
        .listQueue(query);

    return queueResult.when(
      success: (AppPage<IpdAdmissionSummary> queue) async {
        final DischargeReferenceData referenceData = await _repository
            .loadReferenceData()
            .then(
              (Result<DischargeReferenceData> result) => result.when(
                success: (DischargeReferenceData value) => value,
                failure: (_) => const DischargeReferenceData(),
              ),
            );
        return Result<DischargeWorkspaceState>.success(
          DischargeWorkspaceState(
            query: query,
            queue: queue,
            referenceData: referenceData,
          ),
        );
      },
      failure: (AppFailure failure) async {
        return Result<DischargeWorkspaceState>.failure(failure);
      },
    );
  }

  Future<AppFailure?> applyBoardQuery(DischargeWorklistQuery query) async {
    _emit(
      DischargeWorkspaceState(
        query: query.copyWith(pageRequest: query.pageRequest.first()),
        queue: const AppPage<IpdAdmissionSummary>(
          items: <IpdAdmissionSummary>[],
          request: AppPageRequest(pageSize: 12),
        ),
        isRefreshing: true,
      ),
    );
    final Result<DischargeWorkspaceState> result = await _loadWorkspace(query);
    return result.when(
      success: (DischargeWorkspaceState state) {
        _emit(state);
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState?.copyWith(isRefreshing: false, lastFailure: failure) ??
              DischargeWorkspaceState(
                query: query,
                queue: const AppPage<IpdAdmissionSummary>(
                  items: <IpdAdmissionSummary>[],
                  request: AppPageRequest(pageSize: 12),
                ),
                lastFailure: failure,
              ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> selectAdmissionByDisplayId(String displayId) async {
    final DischargeWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final String needle = displayId.trim();
    if (needle.isEmpty) {
      return AppFailure.validation(validationFields: <String>{'admission_id'});
    }

    IpdAdmissionSummary? match;
    for (final IpdAdmissionSummary item in current.queue.items) {
      if (item.displayId == needle || item.id == needle) {
        match = item;
        break;
      }
    }

    if (match != null) {
      return selectAdmission(match);
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<DischargeAdmissionDetail> result = await _repository
        .getAdmissionDetail(needle);
    return result.when(
      success: (DischargeAdmissionDetail detail) {
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

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (_isSyncing || (_currentState?.isSaving ?? false)) {
      _pendingRefresh.defer(
        WorkspaceEventRefreshPlan.forMessage(
          message,
          profile: WorkspaceRefreshProfile.admissions,
        ),
      );
      return;
    }
    final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forMessage(
      message,
      profile: WorkspaceRefreshProfile.admissions,
    );
    if (plan.isEmpty) {
      return;
    }
    await _syncVisibleData(plan: plan);
  }

  Future<AppFailure?> _syncVisibleData({
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.admissionWorkspace,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final DischargeWorkspaceState? current = _currentState;
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
        final DischargeAdmissionDetail? selected =
            _currentState?.selectedDetail;
        if (selected != null) {
          await selectAdmission(selected.summary);
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
    final DischargeWorkspaceState? current = _currentState;
    if (current == null) {
      ref.invalidateSelf();
      return null;
    }

    _emit(current.copyWith(isRefreshing: true, clearLastFailure: true));
    final AppFailure? failure = await _refreshQueue();
    if (failure != null) {
      return failure;
    }

    final DischargeAdmissionDetail? selected = _currentState?.selectedDetail;
    if (selected != null) {
      return selectAdmission(selected.summary);
    }
    return null;
  }

  Future<AppFailure?> applySearch(String value) async {
    final DischargeWorkspaceState? current = _currentState;
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

  Future<AppFailure?> applyStatus(DischargeStatusFilter status) async {
    final DischargeWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          status: status,
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
    final DischargeWorkspaceState? current = _currentState;
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

  Future<AppFailure?> selectAdmission(IpdAdmissionSummary admission) async {
    final DischargeWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<DischargeAdmissionDetail> result = await _repository
        .getAdmissionDetail(admission.apiId);

    return result.when(
      success: (DischargeAdmissionDetail detail) {
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

  Future<AppFailure?> planDischarge({
    required String summary,
    DateTime? targetDate,
  }) {
    return _submitSelectedAction((DischargeAdmissionDetail detail) {
      return _repository.planDischarge(detail.summary.apiId, <String, Object?>{
        'summary': summary,
        'discharged_at': _dateToIso(targetDate),
      });
    });
  }

  Future<AppFailure?> completeDischarge({
    String? summary,
    String? overrideReason,
  }) {
    final String? normalizedSummary = _nonEmpty(summary);
    return _submitSelectedAction((DischargeAdmissionDetail detail) async {
      if (detail.blockingItems.isNotEmpty) {
        return Result<void>.failure(
          AppFailure.validation(
            validationFields: detail.blockingItems
                .map((DischargeClearanceItem item) => item.code.name)
                .toSet(),
          ),
        );
      }

      final Result<void> clearanceResult = await _repository
          .updateDischargeClearance(
            detail.summary.apiId,
            detail.buildSyncClearancePayload(overrideReason: overrideReason),
          );
      return clearanceResult.when(
        success: (_) => _repository
            .finalizeDischarge(detail.summary.apiId, <String, Object?>{
              'summary': normalizedSummary ?? detail.summaryText,
              'discharged_at': DateTime.now().toUtc().toIso8601String(),
              if (_nonEmpty(overrideReason) != null)
                'override_reason': overrideReason!.trim(),
            }),
        failure: (AppFailure failure) => Result<void>.failure(failure),
      );
    });
  }

  Future<AppFailure?> updateDischargeClearance(
    IpdDischargeClearance clearance,
  ) {
    return _submitSelectedAction((DischargeAdmissionDetail detail) {
      return _repository.updateDischargeClearance(
        detail.summary.apiId,
        clearance.toPayload(),
      );
    });
  }

  Future<AppFailure?> requestFinalBilling({
    required String amount,
    required String currency,
  }) {
    return _submitSelectedAction((DischargeAdmissionDetail detail) {
      final String? tenantId = detail.tenantId;
      final String? patientId = detail.patientId;
      if (tenantId == null || patientId == null) {
        return Future<Result<void>>.value(
          Result<void>.failure(
            AppFailure.validation(
              validationFields: <String>{'tenant_id', 'patient_id'},
            ),
          ),
        );
      }

      return _repository.createFinalInvoice(<String, Object?>{
        'tenant_id': tenantId,
        'facility_id': detail.facilityId,
        'patient_id': patientId,
        'status': 'SENT',
        'billing_status': 'ISSUED',
        'total_amount': amount.trim(),
        'currency': currency.trim().toUpperCase(),
        'issued_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<AppFailure?> requestPharmacyMedicines({
    required String drugId,
    required String customPrescription,
    required String instructions,
    required int? quantity,
    required String? route,
    required String? frequency,
  }) {
    return _submitSelectedAction((DischargeAdmissionDetail detail) {
      final String? patientId = detail.patientId;
      if (patientId == null) {
        return Future<Result<void>>.value(
          Result<void>.failure(
            AppFailure.validation(validationFields: <String>{'patient_id'}),
          ),
        );
      }

      return _repository.createPharmacyOrder(<String, Object?>{
        'patient_id': patientId,
        'encounter_id': detail.encounterId,
        'ordered_at': DateTime.now().toUtc().toIso8601String(),
        'items': <Map<String, Object?>>[
          <String, Object?>{
            'drug_id': drugId,
            'quantity': quantity,
            'custom_prescription': customPrescription,
            'instructions': instructions,
            'route': route,
            'frequency': frequency,
          },
        ],
      });
    });
  }

  Future<AppFailure?> _submitSelectedAction(
    Future<Result<void>> Function(DischargeAdmissionDetail detail) submit,
  ) async {
    final DischargeWorkspaceState? current = _currentState;
    final DischargeAdmissionDetail? selected = current?.selectedDetail;
    if (current == null || selected == null) {
      return AppFailure.validation(validationFields: <String>{'admission_id'});
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await submit(selected);
    return result.when<Future<AppFailure?>>(
      success: (_) async {
        await _refreshQueue();
        final DischargeWorkspaceState? afterQueue = _currentState;
        if (afterQueue != null) {
          _emit(afterQueue.copyWith(isRefreshingDetail: true));
          final Result<DischargeAdmissionDetail> detailResult =
              await _repository.getAdmissionDetail(selected.summary.apiId);
          detailResult.when(
            success: (DischargeAdmissionDetail detail) {
              _emit(
                _currentState!.copyWith(
                  selectedDetail: detail,
                  isSaving: false,
                  isRefreshingDetail: false,
                ),
              );
            },
            failure: (AppFailure failure) {
              _emit(
                _currentState!.copyWith(
                  isSaving: false,
                  isRefreshingDetail: false,
                  lastFailure: failure,
                ),
              );
            },
          );
          return detailResult.when(
            success: (_) async {
              await _flushPendingRealtimeRefresh();
              return null;
            },
            failure: (AppFailure failure) => failure,
          );
        }
        await _flushPendingRealtimeRefresh();
        return null;
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
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
    final DischargeWorkspaceState current = _currentState!;
    final Result<AppPage<IpdAdmissionSummary>> result = await _repository
        .listQueue(current.query);
    return result.when(
      success: (AppPage<IpdAdmissionSummary> queue) {
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

  DischargeWorkspaceState? get _currentState {
    final Result<DischargeWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<DischargeWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(DischargeWorkspaceState nextState) {
    state = AsyncData<Result<DischargeWorkspaceState>>(
      Result<DischargeWorkspaceState>.success(nextState),
    );
  }
}

String? _dateToIso(DateTime? value) {
  if (value == null) {
    return null;
  }

  return DateTime(
    value.year,
    value.month,
    value.day,
    12,
  ).toUtc().toIso8601String();
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
