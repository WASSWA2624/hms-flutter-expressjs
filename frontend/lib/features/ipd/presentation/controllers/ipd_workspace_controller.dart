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
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final ipdWorkspaceControllerProvider =
    AsyncNotifierProvider<IpdWorkspaceController, Result<IpdWorkspaceState>>(
      IpdWorkspaceController.new,
    );

final class IpdWorkspaceController
    extends AsyncNotifier<Result<IpdWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 8);

  IpdRepository get _repository => ref.read(ipdRepositoryProvider);

  ClinicalRepository get _clinicalRepository =>
      ref.read(clinicalRepositoryProvider);

  PatientRepository get _patientRepository =>
      ref.read(patientRepositoryProvider);

  final WorkspaceAdaptivePolling _adaptivePolling = WorkspaceAdaptivePolling();
  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<IpdWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    ref.onDispose(_adaptivePolling.dispose);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.ipd,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: _syncFromRealtime,
    );
    final Result<IpdWorkspaceState> result = await runWorkspaceInitialLoad(
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

  Future<AppFailure?> applyRouteQuery(IpdAdmissionQuery query) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      _emitLoading(query);
      final Result<IpdWorkspaceState> result = await _loadInitialState(query);
      state = AsyncData<Result<IpdWorkspaceState>>(result);
      _startAdaptivePolling();
      return result.when(success: (_) => null, failure: (failure) => failure);
    }

    _emit(
      current.copyWith(
        query: query,
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
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
          section: switch (scope) {
            IpdQueueScope.admissionQueue => IpdWorkspaceSection.admissionQueue,
            IpdQueueScope.activePatients => IpdWorkspaceSection.activePatients,
            IpdQueueScope.transferPending =>
              IpdWorkspaceSection.transferPending,
            IpdQueueScope.dischargePlanned =>
              IpdWorkspaceSection.dischargePlanned,
            _ => current.query.section,
          },
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

  Future<AppFailure?> applyFilters(IpdAdmissionQuery query) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: query.copyWith(pageRequest: query.pageRequest.first()),
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

  Future<AppFailure?> selectAdmissionById(String admissionId) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<IpdAdmissionDetail> result = await _repository.getAdmission(
      admissionId,
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

  /// Patient lookup for start-admission dialog search fields.
  ///
  /// Keeps repository access out of widgets per instant-UI sync rules.
  Future<Result<AppPage<Patient>>> searchPatients(PatientListQuery query) {
    return _patientRepository.listPatients(query);
  }

  Future<AppFailure?> startAdmission(Map<String, Object?> payload) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final bool assignedBed = _payloadHasBedId(payload);
    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<IpdAdmissionDetail> result = await _repository.startAdmission(
      payload,
    );
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
        final IpdReferenceData referenceData = await _referenceData();
        final IpdWorkspaceState? refreshed = _currentState;
        if (refreshed != null) {
          _emit(refreshed.copyWith(referenceData: referenceData));
        }
        unawaited(_refreshWorklist(showLoading: false));
        unawaited(_refreshSummaryCounts());
        unawaited(_loadBedBoardIfActive());
        // Bed occupancy also appears on rooms & beds boards; realtime excludes
        // the mutating user, so reconcile from HTTP success when a bed was set.
        if (assignedBed || detail.summary.hasActiveBed) {
          _reconcileRoomsBedsWorkspace();
        }
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

  bool _payloadHasBedId(Map<String, Object?> payload) {
    final Object? bedId = payload['bed_id'];
    if (bedId is! String) {
      return false;
    }
    return bedId.trim().isNotEmpty;
  }

  Future<AppFailure?> loadBedBoard({bool force = false}) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    if (current.isLoadingBedBoard) {
      return null;
    }
    if (current.bedBoardLoaded && !force) {
      return null;
    }

    _emit(current.copyWith(isLoadingBedBoard: true, clearLastFailure: true));
    final Result<List<IpdBedBoardEntry>> result = await _repository
        .listBedBoard(
          wardId: current.bedBoardWardId,
          status: current.bedBoardStatus,
        );
    return result.when(
      success: (List<IpdBedBoardEntry> beds) {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              bedBoard: beds,
              isLoadingBedBoard: false,
              bedBoardLoaded: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isLoadingBedBoard: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> applyBedBoardWard(String? wardId) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        bedBoardWardId: wardId,
        clearBedBoardWard: wardId == null,
        bedBoardLoaded: false,
      ),
    );
    return loadBedBoard(force: true);
  }

  Future<AppFailure?> applyBedBoardStatus(String? status) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        bedBoardStatus: status,
        clearBedBoardStatus: status == null,
        bedBoardLoaded: false,
      ),
    );
    return loadBedBoard(force: true);
  }

  Future<AppFailure?> updateBedStatus(
    IpdBedBoardEntry entry,
    String status,
  ) async {
    final IpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await _repository.updateBedStatus(
      bedId: entry.id,
      status: status,
    );
    return result.when(
      success: (_) async {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false));
        }
        await loadBedBoard(force: true);
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

  Future<void> _loadBedBoardIfActive() async {
    final IpdWorkspaceState? current = _currentState;
    if (current != null && current.bedBoardLoaded) {
      await loadBedBoard(force: true);
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

  Future<AppFailure?> startIcuStay(IpdAdmissionSummary admission) {
    return _mutateAdmission(
      admission,
      () => _repository.startIcuStay(admission.apiId, <String, Object?>{
        'started_at': DateTime.now().toUtc().toIso8601String(),
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
      reconcileRoomsBeds: true,
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

  Future<AppFailure?> approveAdmission(IpdAdmissionSummary admission) {
    return _mutateAdmission(
      admission,
      () => _repository.approveAdmission(
        admission.apiId,
        const <String, Object?>{},
      ),
      refreshReferenceData: true,
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

  Future<AppFailure?> requestTherapy({
    required IpdAdmissionSummary admission,
    required String clinicalIndication,
    String? notes,
  }) {
    return _mutateAdmission(
      admission,
      () => _repository.requestTherapy(admission.apiId, <String, Object?>{
        'clinical_indication': clinicalIndication,
        'notes': notes,
      }),
    );
  }

  Future<AppFailure?> updateTransfer({
    required IpdAdmissionSummary admission,
    required String action,
    String? transferRequestId,
    String? toBedId,
    Map<String, Object?>? billing,
  }) {
    return _mutateAdmission(
      admission,
      () => _repository.updateTransfer(admission.apiId, <String, Object?>{
        'transfer_request_id': transferRequestId,
        'action': action,
        'to_bed_id': toBedId,
        'billing': ?billing,
      }),
      refreshReferenceData: action == 'COMPLETE',
      // Transfer status / bed occupancy also appear on rooms & beds boards.
      reconcileRoomsBeds: true,
    );
  }

  Future<AppFailure?> addWardRound(
    IpdAdmissionSummary admission,
    String notes, {
    Map<String, Object?>? billing,
  }) {
    return _mutateAdmission(
      admission,
      () => _repository.addWardRound(admission.apiId, <String, Object?>{
        'round_at': DateTime.now().toUtc().toIso8601String(),
        'notes': notes,
        'billing': ?billing,
      }),
    );
  }

  Future<AppFailure?> addNursingNote(
    IpdAdmissionSummary admission,
    String note, {
    Map<String, Object?>? billing,
  }) {
    return _mutateAdmission(
      admission,
      () => _repository.addNursingNote(admission.apiId, <String, Object?>{
        'note': note,
        'billing': ?billing,
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
    String summary, {
    String? overrideReason,
  }) {
    return _mutateAdmission(
      admission,
      () => _repository.finalizeDischarge(admission.apiId, <String, Object?>{
        'summary': summary,
        'discharged_at': DateTime.now().toUtc().toIso8601String(),
        if ((overrideReason ?? '').trim().isNotEmpty)
          'override_reason': overrideReason,
      }),
      refreshReferenceData: true,
    );
  }

  Future<AppFailure?> updateDischargeClearance(
    IpdAdmissionSummary admission,
    IpdDischargeClearance clearance,
  ) {
    return _mutateAdmission(
      admission,
      () => _repository.updateDischargeClearance(
        admission.apiId,
        clearance.toPayload(),
      ),
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
    return _mutateClinical((IpdAdmissionDetail detail) {
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
    return _mutateClinical((IpdAdmissionDetail detail) {
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
    return _mutateClinical((IpdAdmissionDetail detail) {
      return _clinicalRepository.createPharmacyOrder(
        mergeClinicalRequestBilling(<String, Object?>{
          ..._clinicalAnchor(detail),
          'items': items,
        }, billing),
      );
    }, isValid: (_) => items.isNotEmpty);
  }

  Map<String, Object?> _clinicalAnchor(IpdAdmissionDetail detail) {
    return <String, Object?>{
      'encounter_id': detail.summary.encounterId,
      'patient_id': detail.summary.patientId,
      'ordered_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<AppFailure?> _mutateClinical(
    Future<Result<void>> Function(IpdAdmissionDetail detail) action, {
    required bool Function(IpdAdmissionDetail detail) isValid,
  }) async {
    final IpdAdmissionDetail? detail = _currentState?.selectedAdmission;
    if (detail == null) {
      return AppFailure.validation();
    }
    final String? encounterId = detail.summary.encounterId?.trim();
    final String? patientId = detail.summary.patientId?.trim();
    if (encounterId == null ||
        encounterId.isEmpty ||
        patientId == null ||
        patientId.isEmpty ||
        !isValid(detail)) {
      return AppFailure.validation();
    }

    _emit(_currentState!.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await action(detail);
    return result.when(
      success: (_) async {
        final AppFailure? refreshFailure = await selectAdmission(
          detail.summary,
        );
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false));
        }
        return refreshFailure;
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

  Future<Result<IpdWorkspaceState>> _loadInitialState([
    IpdAdmissionQuery query = const IpdAdmissionQuery(),
  ]) async {
    final List<Object> bootstrapResults = await Future.wait<Object>(<Future<Object>>[
      _repository.listAdmissions(query),
      _repository.getSummaryCounts(),
    ]);
    final Result<AppPage<IpdAdmissionSummary>> admissionsResult =
        bootstrapResults[0]! as Result<AppPage<IpdAdmissionSummary>>;
    final Result<IpdFlowAggregateCounts> summaryResult =
        bootstrapResults[1]! as Result<IpdFlowAggregateCounts>;
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
        summaryCounts:
            _successOrNull(summaryResult) ?? IpdFlowAggregateCounts.empty,
      ),
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
    bool refreshReferenceData = false,
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.admissionManualRefresh,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final IpdWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      _pendingRefresh.defer(plan);
      return null;
    }

    final bool refreshWorklist =
        workspacePlanRefreshesPrimaryList(plan) || plan.selectedDetail;
    final bool refreshRefs =
        refreshReferenceData || workspacePlanRefreshesReferenceData(plan);
    if (!refreshWorklist && !refreshRefs) {
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
      if (refreshWorklist) {
        final AppFailure? failure = await _refreshWorklist(
          showLoading: showLoading,
        );
        if (failure != null) {
          return failure;
        }
      }

      if (plan.summaryCounts) {
        final Result<IpdFlowAggregateCounts> countsResult = await _repository
            .getSummaryCounts();
        countsResult.when(
          success: (IpdFlowAggregateCounts counts) {
            final IpdWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(latest.copyWith(summaryCounts: counts));
            }
          },
          failure: (_) {},
        );
      }

      if (refreshRefs) {
        final IpdReferenceData referenceData = await _referenceData();
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(referenceData: referenceData));
        }
      }

      if (plan.selectedDetail) {
        final IpdAdmissionSummary? selected =
            _currentState?.selectedAdmission?.summary;
        if (selected != null) {
          await selectAdmission(selected);
        }
      }

      return null;
    } finally {
      final IpdWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
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
    bool reconcileRoomsBeds = false,
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
          unawaited(_loadBedBoardIfActive());
        }
        if (reconcileRoomsBeds) {
          _reconcileRoomsBedsWorkspace();
        }
        unawaited(_refreshWorklist(showLoading: false));
        unawaited(_refreshSummaryCounts());
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

  Future<void> _refreshSummaryCounts() async {
    final Result<IpdFlowAggregateCounts> result = await _repository
        .getSummaryCounts();
    result.when(
      success: (IpdFlowAggregateCounts counts) {
        final IpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(summaryCounts: counts));
        }
      },
      failure: (_) {},
    );
  }

  /// Acting-user rooms/beds sync after bed occupancy mutations.
  ///
  /// Realtime excludes the mutating user, so an already-mounted rooms/beds
  /// workspace must refresh from HTTP success rather than waiting on WS.
  void _reconcileRoomsBedsWorkspace() {
    if (!ref.exists(roomsBedsWorkspaceControllerProvider)) {
      return;
    }
    unawaited(
      ref.read(roomsBedsWorkspaceControllerProvider.notifier).refresh(),
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

  void _emitLoading(IpdAdmissionQuery query) {
    final IpdWorkspaceState? current = _currentState;
    if (current != null) {
      _emit(
        current.copyWith(
          query: query,
          isRefreshing: true,
          clearLastFailure: true,
        ),
      );
      return;
    }
    state = const AsyncValue<Result<IpdWorkspaceState>>.loading();
  }

  void _emit(IpdWorkspaceState nextState) {
    state = AsyncData<Result<IpdWorkspaceState>>(
      Result<IpdWorkspaceState>.success(nextState),
    );
  }
}
