import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_adaptive_polling.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_fast_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final icuWorkspaceControllerProvider =
    AsyncNotifierProvider<IcuWorkspaceController, Result<IcuWorkspaceState>>(
      IcuWorkspaceController.new,
    );

final class IcuWorkspaceController
    extends AsyncNotifier<Result<IcuWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 8);

  IcuRepository get _repository => ref.read(icuRepositoryProvider);

  ClinicalRepository get _clinicalRepository =>
      ref.read(clinicalRepositoryProvider);

  final WorkspaceAdaptivePolling _adaptivePolling = WorkspaceAdaptivePolling();
  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<IcuWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    ref.onDispose(_adaptivePolling.dispose);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.icu,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: _syncFromRealtime,
    );
    final Result<IcuWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      _loadInitialState,
    );
    _startAdaptivePolling();
    return result;
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

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true);
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

  Future<Result<List<IcuPatientSummary>>> loadMatchingBoardItems() {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return Future<Result<List<IcuPatientSummary>>>.value(
        const Result<List<IcuPatientSummary>>.success(<IcuPatientSummary>[]),
      );
    }
    final IcuBoardQuery query = current.query;
    return loadMatchingAppPageItems<IcuPatientSummary>(
      loadPage: (AppPageRequest request) {
        return _repository.listIcuBoard(query.copyWith(pageRequest: request));
      },
    );
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

  Future<AppFailure?> selectPatientByDisplayId(String displayId) async {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return AppFailure.validation();
    }
    final String needle = displayId.trim().toLowerCase();
    if (needle.isEmpty) {
      return AppFailure.validation();
    }

    IcuPatientSummary? match;
    for (final IcuPatientSummary item in current.board.items) {
      if (<String?>[item.displayId, item.admissionId, item.patientId, item.id]
          .whereType<String>()
          .any((String value) => value.toLowerCase() == needle)) {
        match = item;
        break;
      }
    }

    if (match == null) {
      // Patient not on the current page — search the board for them.
      _emit(
        current.copyWith(
          query: current.query.copyWith(
            search: displayId.trim(),
            pageRequest: current.query.pageRequest.first(),
          ),
          isRefreshingBoard: true,
        ),
      );
      await _refreshBoard(showLoading: true);
      final IcuWorkspaceState? latest = _currentState;
      for (final IcuPatientSummary item
          in latest?.board.items ?? const <IcuPatientSummary>[]) {
        if (<String?>[item.displayId, item.admissionId, item.patientId, item.id]
            .whereType<String>()
            .any((String value) => value.toLowerCase() == needle)) {
          match = item;
          break;
        }
      }
    }

    if (match == null) {
      return const AppFailure.notFound();
    }
    return selectPatient(match);
  }

  void setView(IcuBoardView view) {
    final IcuWorkspaceState? current = _currentState;
    if (current == null || current.view == view) {
      return;
    }
    _emit(current.copyWith(view: view));
    if (view == IcuBoardView.bedBoard && current.bedBoard.beds.isEmpty) {
      unawaited(loadBedBoard());
    }
  }

  void selectBedWard(String? wardId) {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        bedBoard: current.bedBoard.copyWith(
          selectedWardId: wardId,
          clearSelectedWard: wardId == null,
        ),
      ),
    );
  }

  void selectBedStatus(String? status) {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        bedBoard: current.bedBoard.copyWith(
          selectedStatus: status,
          clearSelectedStatus: status == null,
        ),
      ),
    );
  }

  void applyBedSearch(String search) {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    final String next = search.trim();
    if (current.bedBoard.search == next) {
      return;
    }
    _emit(
      current.copyWith(bedBoard: current.bedBoard.copyWith(search: next)),
    );
  }

  Future<AppFailure?> loadBedBoard() async {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    _emit(current.copyWith(isRefreshingBeds: true, clearLastFailure: true));
    final Result<IcuBedBoard> result = await _repository.loadBedBoard();
    return result.when(
      success: (IcuBedBoard board) {
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              bedBoard: board.copyWith(
                selectedWardId: latest.bedBoard.selectedWardId,
                selectedStatus: latest.bedBoard.selectedStatus,
                search: latest.bedBoard.search,
              ),
              isRefreshingBeds: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshingBeds: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> startIcuStay({
    DateTime? startedAt,
    Map<String, Object?>? billing,
  }) {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.startIcuStay(
        detail: detail,
        startedAt: startedAt,
        billing: billing,
      ),
      refreshBoardAfter: true,
    );
  }

  Future<AppFailure?> assignBed(String bedId) async {
    final AppFailure? failure = await _mutateSelected(
      (IcuPatientDetail detail) =>
          _repository.assignBed(detail: detail, bedId: bedId),
      refreshBoardAfter: true,
    );
    if (failure == null) {
      unawaited(loadBedBoard());
    }
    return failure;
  }

  Future<AppFailure?> updateTransfer({
    required String transferRequestId,
    required IcuTransferAction action,
    String? toBedId,
  }) {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.updateTransfer(
        detail: detail,
        transferRequestId: transferRequestId,
        action: action,
        toBedId: toBedId,
      ),
      refreshBoardAfter: true,
    );
  }

  Future<ClinicalReferenceData> clinicalReferenceData() async {
    final Result<ClinicalReferenceData> result = await _clinicalRepository
        .loadReferenceData();
    return result.when(
      success: (ClinicalReferenceData value) => value,
      failure: (_) => const ClinicalReferenceData(),
    );
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

  Future<AppFailure?> orderLab({
    required List<String> labTestIds,
    required List<String> labPanelIds,
    ClinicalRequestBillingSubmit? billing,
  }) {
    return _mutateClinical((IcuPatientDetail detail) {
      return _clinicalRepository.createLabOrder(
        mergeClinicalRequestBilling(<String, Object?>{
          ..._clinicalAnchor(detail),
          'requested_tests': <Map<String, Object?>>[
            for (final String id in labTestIds)
              <String, Object?>{'lab_test_id': id},
          ],
          'requested_panels': <Map<String, Object?>>[
            for (final String id in labPanelIds)
              <String, Object?>{'lab_panel_id': id},
          ],
        }, billing),
      );
    }, isValid: (_) => labTestIds.isNotEmpty || labPanelIds.isNotEmpty);
  }

  Future<AppFailure?> orderRadiology({
    required List<ClinicalRadiologyRequest> requests,
    ClinicalRequestBillingSubmit? billing,
  }) {
    return _mutateClinical((IcuPatientDetail detail) {
      return _clinicalRepository.createRadiologyOrder(<String, Object?>{
        ..._clinicalAnchor(detail),
        'requested_tests': <Map<String, Object?>>[
          for (final ClinicalRadiologyRequest request in requests)
            <String, Object?>{
              'radiology_test_id': request.radiologyTestId,
              'clinical_note': request.clinicalNote,
              'request_details': mergeClinicalRequestBillingIntoRequestDetails(
                <String, Object?>{
                  'modality': request.modality,
                  'body_region': request.bodyRegion,
                  'laterality': request.laterality,
                  'priority': request.priority,
                },
                billing,
                lineAmount: clinicalRequestBillingLineAmount(
                  billing,
                  request.radiologyTestId,
                ),
              ),
            },
        ],
      });
    }, isValid: (_) => requests.isNotEmpty);
  }

  Future<AppFailure?> prescribeMedication({
    required List<Map<String, Object?>> items,
    ClinicalRequestBillingSubmit? billing,
  }) {
    return _mutateClinical((IcuPatientDetail detail) {
      return _clinicalRepository.createPharmacyOrder(
        mergeClinicalRequestBilling(<String, Object?>{
          ..._clinicalAnchor(detail),
          'items': items,
        }, billing),
      );
    }, isValid: (_) => items.isNotEmpty);
  }

  Map<String, Object?> _clinicalAnchor(IcuPatientDetail detail) {
    return <String, Object?>{
      'encounter_id': detail.summary.encounterId,
      'patient_id': detail.summary.patientId,
      'ordered_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<AppFailure?> _mutateClinical(
    Future<Result<void>> Function(IcuPatientDetail detail) action, {
    required bool Function(IcuPatientDetail detail) isValid,
  }) {
    return _mutateSelected((IcuPatientDetail detail) async {
      final String? encounterId = detail.summary.encounterId?.trim();
      final String? patientId = detail.summary.patientId?.trim();
      if (encounterId == null ||
          encounterId.isEmpty ||
          patientId == null ||
          patientId.isEmpty ||
          !isValid(detail)) {
        return Result<IcuPatientDetail>.failure(AppFailure.validation());
      }
      final Result<void> result = await action(detail);
      return result.when<Future<Result<IcuPatientDetail>>>(
        success: (_) => _repository.loadIcuDetail(detail.summary),
        failure: (AppFailure failure) async =>
            Result<IcuPatientDetail>.failure(failure),
      );
    });
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

  Future<AppFailure?> addRoundNote({
    required String notes,
    DateTime? roundAt,
    Map<String, Object?>? billing,
  }) {
    return _mutateSelected(
      (IcuPatientDetail detail) => _repository.addRoundNote(
        detail: detail,
        notes: notes,
        roundAt: roundAt,
        billing: billing,
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
      refreshBoardAfter: true,
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
    final IcuScopeCounts seed = IcuScopeCounts.empty.withScope(
      query.scope,
      board.totalItemCount ?? board.items.length,
    );
    final IcuWorkspaceState initial = IcuWorkspaceState(
      query: query,
      board: board,
      referenceData: referenceData,
      scopeCounts: seed,
    );
    // Warm sibling counts after the first frame so the desk paints quickly.
    Future<void>.microtask(() async {
      final IcuScopeCounts counts = await _loadScopeCounts(
        seed: seed,
        currentScope: query.scope,
      );
      final IcuWorkspaceState? latest = _currentState;
      if (latest != null) {
        _emit(latest.copyWith(scopeCounts: counts));
      }
    });
    return Result<IcuWorkspaceState>.success(initial);
  }

  Future<IcuScopeCounts> _loadScopeCounts({
    required IcuScopeCounts seed,
    IcuBoardScope? currentScope,
  }) async {
    IcuScopeCounts counts = seed;
    final List<IcuBoardScope> scopes = IcuBoardScope.values
        .where((IcuBoardScope scope) => scope != currentScope)
        .toList(growable: false);
    final List<Result<AppPage<IcuPatientSummary>>> results =
        await Future.wait(<Future<Result<AppPage<IcuPatientSummary>>>>[
          for (final IcuBoardScope scope in scopes)
            _repository.listIcuBoard(
              IcuBoardQuery(
                scope: scope,
                pageRequest: const AppPageRequest(pageSize: 1),
              ),
            ),
        ]);
    for (var i = 0; i < scopes.length; i += 1) {
      final AppPage<IcuPatientSummary>? page = _successOrNull(results[i]);
      if (page == null) {
        continue;
      }
      counts = counts.withScope(
        scopes[i],
        page.totalItemCount ?? page.items.length,
      );
    }
    return counts;
  }

  Future<void> _refreshScopeCounts({IcuBoardScope? preferScope}) async {
    final IcuWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    final IcuBoardScope scope = preferScope ?? current.query.scope;
    final int currentTotal =
        current.board.totalItemCount ?? current.board.items.length;
    final IcuScopeCounts next = await _loadScopeCounts(
      seed: current.scopeCounts.withScope(scope, currentTotal),
      currentScope: scope,
    );
    final IcuWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(latest.copyWith(scopeCounts: next));
    }
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
    bool refreshReferenceData = false,
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.admissionManualRefresh,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final IcuWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      _pendingRefresh.defer(plan);
      return null;
    }

    final bool refreshBoard =
        workspacePlanRefreshesPrimaryList(plan) || plan.selectedDetail;
    final bool refreshRefs =
        refreshReferenceData || workspacePlanRefreshesReferenceData(plan);
    if (!refreshBoard && !refreshRefs) {
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
      if (refreshBoard) {
        final AppFailure? failure = await _refreshBoard(
          showLoading: showLoading,
        );
        if (failure != null) {
          return failure;
        }
        if (showLoading) {
          unawaited(_refreshScopeCounts());
        }
      }

      if (refreshRefs) {
        final IcuReferenceData referenceData = await _referenceData();
        final IcuWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(referenceData: referenceData));
        }
      }

      if (plan.selectedDetail) {
        final IcuPatientDetail? selected = _currentState?.selectedDetail;
        if (selected != null) {
          await selectPatient(selected.summary);
        }
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
      if (_pendingRefresh.refreshPending &&
          !(_currentState?.isSaving ?? false)) {
        final WorkspaceRefreshPlan pendingPlan = _pendingRefresh.takePending();
        if (!pendingPlan.isEmpty) {
          unawaited(_syncVisibleData(plan: pendingPlan));
        }
      }
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
          final IcuScopeCounts nextCounts = latest.scopeCounts.withScope(
            latest.query.scope,
            page.totalItemCount ?? page.items.length,
          );
          _emit(
            latest.copyWith(
              board: page,
              scopeCounts: nextCounts,
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
          unawaited(() async {
            await _refreshBoard(showLoading: false);
            await _refreshScopeCounts();
          }());
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
