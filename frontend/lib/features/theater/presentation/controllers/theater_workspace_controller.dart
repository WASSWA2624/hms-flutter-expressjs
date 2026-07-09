import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/workspace/workspace_adaptive_polling.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/theater/data/repositories/theater_repository_impl.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/domain/repositories/theater_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final theaterWorkspaceControllerProvider =
    AsyncNotifierProvider<
      TheaterWorkspaceController,
      Result<TheaterWorkspaceState>
    >(TheaterWorkspaceController.new);

final class TheaterWorkspaceController
    extends AsyncNotifier<Result<TheaterWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 10);

  TheaterRepository get _repository => ref.read(theaterRepositoryProvider);

  ClinicalRepository get _clinicalRepository =>
      ref.read(clinicalRepositoryProvider);

  final WorkspaceAdaptivePolling _adaptivePolling = WorkspaceAdaptivePolling();
  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<TheaterWorkspaceState>> build() async {
    ref.onDispose(_adaptivePolling.dispose);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.theater,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isMutating ?? false),
      onRefresh: _syncFromRealtime,
    );
    final Result<TheaterWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      _loadInitialState,
    );
    _startAdaptivePolling();
    return result;
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (_isSyncing || (_currentState?.isMutating ?? false)) {
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

  Future<AppFailure?> refresh() {
    return _syncVisibleData(
      showLoading: true,
      plan: WorkspaceRefreshPlan.admissionManualRefresh,
    );
  }

  Future<AppFailure?> applySearch(String value) async {
    final TheaterWorkspaceState? current = _currentState;
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
    return _refreshCases(showLoading: true);
  }

  Future<AppFailure?> applyStatus(String? status) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          status: status,
          clearStatus: status == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshCases(showLoading: true);
  }

  Future<AppFailure?> applyStage(String? stage) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          stage: stage,
          clearStage: stage == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshCases(showLoading: true);
  }

  Future<AppFailure?> applyScheduledDate(DateTime? date) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          scheduledDate: date,
          clearScheduledDate: date == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshCases(showLoading: true);
  }

  Future<AppFailure?> applyResourceFilters({
    String? roomId,
    String? surgeonUserId,
    String? anesthetistUserId,
  }) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          roomId: roomId,
          surgeonUserId: surgeonUserId,
          anesthetistUserId: anesthetistUserId,
          clearRoomId: roomId == null,
          clearSurgeonUserId: surgeonUserId == null,
          clearAnesthetistUserId: anesthetistUserId == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshCases(showLoading: true);
  }

  Future<AppFailure?> clearFilters() async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: TheaterCaseQuery(pageRequest: current.query.pageRequest.first()),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshCases(showLoading: true);
  }

  Future<AppFailure?> selectCaseByDisplayId(String displayId) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final String normalized = displayId.trim();
    if (normalized.isEmpty) {
      return AppFailure.validation();
    }

    TheaterCase? matched;
    for (final TheaterCase item in current.cases.items) {
      if (item.effectiveDisplayId == normalized || item.id == normalized) {
        matched = item;
        break;
      }
    }

    if (matched != null) {
      return selectCase(matched);
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<TheaterCase> result = await _repository.getCase(normalized);
    return result.when(
      success: (TheaterCase detail) {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedCase: detail,
              cases: _replaceCase(latest.cases, detail),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> applyBoardQuery(TheaterBoardQuery boardQuery) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: boardQuery.toCaseQuery(),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshCases(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) async {
    final TheaterWorkspaceState? current = _currentState;
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
    return _refreshCases(showLoading: true);
  }

  Future<AppFailure?> selectCase(TheaterCase theaterCase) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<TheaterCase> result = await _repository.getCase(
      theaterCase.effectiveDisplayId,
    );
    return result.when(
      success: (TheaterCase detail) {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedCase: detail,
              cases: _replaceCase(latest.cases, detail),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> scheduleCase(Map<String, Object?> payload) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<TheaterCase> result = await _repository.scheduleCase(payload);
    return result.when(
      success: (TheaterCase detail) async {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedCase: detail,
              cases: _replaceCase(latest.cases, detail),
              isMutating: false,
            ),
          );
        }
        await _refreshCases(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<Result<List<TheaterSchedulePatient>>> searchSchedulePatients(
    String query,
  ) {
    return _repository.searchSchedulePatients(query);
  }

  Future<Result<TheaterSchedulePatientDetail>> loadSchedulePatientEncounters(
    String patientId,
  ) {
    return _repository.loadSchedulePatientEncounters(patientId);
  }

  Future<Result<List<TheaterScheduleEmergencyCase>>>
  searchScheduleEmergencyCases(String patientId) {
    return _repository.searchScheduleEmergencyCases(patientId);
  }

  Future<Result<List<TheaterRoomOption>>> searchTheatreRooms(String query) {
    return _repository.searchTheatreRooms(query);
  }

  Future<Result<List<TheaterStaffOption>>> searchTheatreStaff(
    String query, {
    String? role,
  }) {
    return _repository.searchTheatreStaff(query, role: role);
  }

  Future<Result<List<ClinicalCatalogOption>>> searchClinicalTerms({
    required String termType,
    String? query,
    int limit = 80,
    String source = 'ALL',
    String? facilityId,
  }) {
    final String? resolvedFacilityId =
        facilityId ?? ref.read(sessionStateProvider).session?.user?.facilityId;
    return _clinicalRepository.searchClinicalTerms(
      termType: termType,
      query: query,
      limit: limit,
      source: source,
      facilityId: resolvedFacilityId,
    );
  }

  Future<AppFailure?> updateStage(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.updateStage(caseId, payload),
    );
  }

  Future<AppFailure?> updateCaseSchedule(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.updateCaseSchedule(caseId, payload),
    );
  }

  Future<AppFailure?> upsertAnesthesiaRecord(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.upsertAnesthesiaRecord(caseId, payload),
    );
  }

  Future<AppFailure?> addAnesthesiaObservation(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.addAnesthesiaObservation(caseId, payload),
    );
  }

  Future<AppFailure?> upsertPostOpNote(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.upsertPostOpNote(caseId, payload),
    );
  }

  Future<AppFailure?> toggleChecklistItem(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.toggleChecklistItem(caseId, payload),
    );
  }

  Future<AppFailure?> assignResource(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.assignResource(caseId, payload),
    );
  }

  Future<AppFailure?> releaseResource(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.releaseResource(caseId, payload),
    );
  }

  Future<AppFailure?> finalizeRecord(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.finalizeRecord(caseId, payload),
    );
  }

  Future<AppFailure?> reopenRecord(Map<String, Object?> payload) {
    return _mutateSelected(
      (String caseId) => _repository.reopenRecord(caseId, payload),
    );
  }

  Future<Result<TheaterWorkspaceState>> _loadInitialState() async {
    const TheaterCaseQuery query = TheaterCaseQuery();
    final Result<AppPage<TheaterCase>> casesResult = await _repository
        .listCases(query);

    return casesResult.when(
      success: (AppPage<TheaterCase> cases) async {
        TheaterCase? selectedCase;
        if (cases.items.isNotEmpty) {
          final Result<TheaterCase> detailResult = await _repository.getCase(
            cases.items.first.effectiveDisplayId,
          );
          selectedCase = detailResult.when(
            success: (TheaterCase detail) => detail,
            failure: (_) => null,
          );
        }

        return Result<TheaterWorkspaceState>.success(
          TheaterWorkspaceState(
            cases: selectedCase == null
                ? cases
                : _replaceCase(cases, selectedCase),
            query: query,
            selectedCase: selectedCase,
          ),
        );
      },
      failure: (AppFailure failure) =>
          Result<TheaterWorkspaceState>.failure(failure),
    );
  }

  void _startAdaptivePolling() {
    installWorkspaceAdaptivePolling(
      ref: ref,
      polling: _adaptivePolling,
      intervalWhenDisconnected: _syncInterval,
      disconnectProfile: WorkspaceRefreshProfile.admissions,
      syncOnDisconnect: (WorkspaceRefreshPlan plan) =>
          _syncVisibleData(plan: plan),
    );
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.admissionManualRefresh,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final TheaterWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isMutating) {
      _pendingRefresh.defer(plan);
      return null;
    }

    final bool refreshCases =
        workspacePlanRefreshesPrimaryList(plan) || plan.selectedDetail;
    if (!refreshCases) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingDetail: current.selectedCase != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      if (refreshCases) {
        final AppFailure? failure = await _refreshCases(
          showLoading: showLoading,
        );
        if (failure != null) {
          return failure;
        }
      }

      if (plan.selectedDetail) {
        final TheaterCase? selected = _currentState?.selectedCase;
        if (selected != null) {
          final Result<TheaterCase> detailResult = await _repository.getCase(
            selected.effectiveDisplayId,
          );
          detailResult.when(
            success: (TheaterCase detail) {
              final TheaterWorkspaceState? latest = _currentState;
              if (latest != null) {
                _emit(
                  latest.copyWith(
                    selectedCase: detail,
                    cases: _replaceCase(latest.cases, detail),
                  ),
                );
              }
            },
            failure: (_) {},
          );
        }
      }

      return null;
    } finally {
      final TheaterWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
      }
      _isSyncing = false;
      if (_pendingRefresh.refreshPending &&
          !(_currentState?.isMutating ?? false)) {
        final WorkspaceRefreshPlan pendingPlan = _pendingRefresh.takePending();
        if (!pendingPlan.isEmpty) {
          unawaited(_syncVisibleData(plan: pendingPlan));
        }
      }
    }
  }

  Future<AppFailure?> _refreshCases({required bool showLoading}) async {
    final TheaterWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<TheaterCase>> result = await _repository.listCases(
      current.query,
    );
    return result.when(
      success: (AppPage<TheaterCase> page) {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              cases: page,
              isRefreshing: false,
              selectedCase: _selectedAfterRefresh(page, latest.selectedCase),
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<TheaterCase>> Function(String caseId) submit,
  ) async {
    final TheaterWorkspaceState? current = _currentState;
    final TheaterCase? selected = current?.selectedCase;
    if (current == null || selected == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isMutating: true, clearLastFailure: true));
    final Result<TheaterCase> result = await submit(
      selected.effectiveDisplayId,
    );
    return result.when(
      success: (TheaterCase detail) async {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedCase: detail,
              cases: _replaceCase(latest.cases, detail),
              isMutating: false,
            ),
          );
        }
        await _refreshCases(showLoading: false);
        return null;
      },
      failure: (AppFailure failure) {
        final TheaterWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isMutating: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  TheaterCase? _selectedAfterRefresh(
    AppPage<TheaterCase> page,
    TheaterCase? selected,
  ) {
    if (selected == null) {
      return page.items.isEmpty ? null : page.items.first;
    }
    for (final TheaterCase item in page.items) {
      if (_isSameCase(item, selected)) {
        return selected;
      }
    }
    return selected;
  }

  AppPage<TheaterCase> _replaceCase(
    AppPage<TheaterCase> page,
    TheaterCase replacement,
  ) {
    var replaced = false;
    final List<TheaterCase> items = page.items
        .map((TheaterCase item) {
          if (_isSameCase(item, replacement)) {
            replaced = true;
            return replacement;
          }
          return item;
        })
        .toList(growable: true);

    if (!replaced) {
      items.insert(0, replacement);
    }

    return AppPage<TheaterCase>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : replaced
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  bool _isSameCase(TheaterCase left, TheaterCase right) {
    return left.id == right.id ||
        (left.displayId != null && left.displayId == right.displayId);
  }

  TheaterWorkspaceState? get _currentState {
    final Result<TheaterWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<TheaterWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(TheaterWorkspaceState nextState) {
    state = AsyncData<Result<TheaterWorkspaceState>>(
      Result<TheaterWorkspaceState>.success(nextState),
    );
  }
}
