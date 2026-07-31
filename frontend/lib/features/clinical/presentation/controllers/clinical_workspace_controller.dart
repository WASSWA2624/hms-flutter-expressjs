import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
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
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final clinicalWorkspaceControllerProvider =
    AsyncNotifierProvider<
      ClinicalWorkspaceController,
      Result<ClinicalWorkspaceState>
    >(ClinicalWorkspaceController.new);

final class ClinicalWorkspaceController
    extends AsyncNotifier<Result<ClinicalWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 8);
  ClinicalRepository get _repository => ref.read(clinicalRepositoryProvider);
  OpdRepository get _opdRepository => ref.read(opdRepositoryProvider);
  IpdRepository get _ipdRepository => ref.read(ipdRepositoryProvider);

  final WorkspaceAdaptivePolling _adaptivePolling = WorkspaceAdaptivePolling();
  final WorkspacePendingRefresh _pendingRefresh = WorkspacePendingRefresh();
  bool _isSyncing = false;

  @override
  Future<Result<ClinicalWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.clinical,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: _syncFromRealtime,
    );
    final Result<ClinicalWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      _loadInitialState,
    );
    _startAdaptivePolling();
    return result;
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (RealtimeEventGroups.diagnostics.contains(message.event)) {
      _maybeSetRealtimeNotice(message);
    }
    if (_isSyncing || (_currentState?.isSaving ?? false)) {
      _pendingRefresh.defer(
        WorkspaceEventRefreshPlan.forMessage(
          message,
          profile: WorkspaceRefreshProfile.clinicalFlow,
        ),
      );
      return;
    }
    final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forMessage(
      message,
      profile: WorkspaceRefreshProfile.clinicalFlow,
    );
    if (plan.isEmpty) {
      return;
    }
    await _syncVisibleData(plan: plan);
  }

  void _maybeSetRealtimeNotice(RealtimeMessage message) {
    if (!RealtimeEventGroups.diagnostics.contains(message.event)) {
      return;
    }
    if (!_clinicalRealtimeEventTouchesVisibleData(message)) {
      return;
    }
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    final Map<String, Object?> payload = message.payload;
    final String patientName =
        _stringValue(payload['patient_display_name']) ??
        current.selectedBundle?.entry.patientDisplayName ??
        'patient';
    final String? notice = switch (message.event) {
      RealtimeEvents.labResultCritical => _labResultCriticalNotice(patientName),
      RealtimeEvents.labResultReady => _labResultReadyNotice(patientName),
      RealtimeEvents.labResultUpdated => _labResultUpdatedNotice(patientName),
      _ => null,
    };
    if (notice == null) {
      return;
    }
    _emit(current.copyWith(realtimeNotice: notice));
  }

  String _labResultReadyNotice(String patientName) =>
      'LAB_RESULT_READY::$patientName';

  String _labResultUpdatedNotice(String patientName) =>
      'LAB_RESULT_UPDATED::$patientName';

  String _labResultCriticalNotice(String patientName) =>
      'LAB_RESULT_CRITICAL::$patientName';

  void clearRealtimeNotice() {
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null || current.realtimeNotice == null) {
      return;
    }
    _emit(current.copyWith(clearRealtimeNotice: true));
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshReferenceData: true);
  }

  Future<AppFailure?> applySearch(
    String search, {
    bool showLoading = true,
  }) async {
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(
          search: search.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: showLoading ? true : current.isRefreshing,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: showLoading);
  }

  Future<AppFailure?> applyScope(ClinicalQueueScope scope) async {
    final ClinicalWorkspaceState? current = _currentState;
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

  Future<AppFailure?> applyWorklistFilters({
    required ClinicalQueueScope scope,
    required ClinicalWorklistFilters filters,
    String? search,
  }) async {
    final ClinicalWorkspaceState? current = _currentState;
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

  Future<AppFailure?> applyFilters(ClinicalWorklistFilters filters) async {
    final ClinicalWorkspaceState? current = _currentState;
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

  Future<AppFailure?> changePage(AppPageRequest pageRequest) async {
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        query: current.query.copyWith(pageRequest: pageRequest),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> selectEntry(ClinicalWorklistEntry entry) async {
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    return _refreshSelectedEntry(entry, showLoading: true);
  }

  Future<AppFailure?> _refreshSelectedEntry(
    ClinicalWorklistEntry entry, {
    required bool showLoading,
  }) async {
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    if (showLoading) {
      _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    }

    final Result<ClinicalEncounterBundle> result = await _repository
        .loadEncounterBundle(entry);
    return switch (result) {
      ResultSuccess<ClinicalEncounterBundle>(value: final bundle) => () async {
        final ClinicalEncounterBundle hydrated = await _withTriageHandoff(
          bundle,
        );
        final ClinicalWorkspaceState? latest = _currentState;
        if (latest == null) {
          return null;
        }
        _emit(
          latest.copyWith(
            selectedBundle: hydrated,
            worklist: _replaceEntry(latest.worklist, hydrated.entry),
            isRefreshingDetail: showLoading ? false : latest.isRefreshingDetail,
          ),
        );
        return null;
      }(),
      ResultFailure<ClinicalEncounterBundle>(failure: final failure) =>
        () async {
          final ClinicalWorkspaceState? latest = _currentState;
          if (latest != null) {
            _emit(
              latest.copyWith(
                isRefreshingDetail: showLoading
                    ? false
                    : latest.isRefreshingDetail,
                lastFailure: failure,
              ),
            );
          }
          return failure;
        }(),
    };
  }

  void clearSelection() {
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return;
    }
    _emit(
      current.copyWith(
        clearSelectedBundle: true,
        isRefreshingDetail: false,
        clearLastFailure: true,
      ),
    );
  }

  Future<Result<List<ClinicalCatalogOption>>> searchClinicalTerms({
    required String termType,
    String? query,
    int limit = 25,
    String source = 'ALL',
    String? facilityId,
  }) {
    final bool offeredOnly =
        termType == 'LAB_TEST' ||
        termType == 'LAB_PANEL' ||
        termType == 'RADIOLOGY_TEST';
    final String? resolvedFacilityId =
        facilityId ??
        _selectedEntry?.facilityId ??
        ref.read(sessionStateProvider).session?.user?.facilityId;
    return _repository.searchClinicalCatalog(
      termType: termType,
      query: query,
      limit: limit,
      source: source,
      offeredOnly: offeredOnly,
      facilityId: resolvedFacilityId,
    );
  }

  Future<AppFailure?> addClinicalNote(String note) {
    final String? authorUserId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.id;
    if (authorUserId == null || authorUserId.trim().isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(
      () => _repository.createClinicalNote(<String, Object?>{
        'encounter_id': _selectedEntry!.encounterId,
        'author_user_id': authorUserId,
        'note': note,
      }),
    );
  }

  Future<AppFailure?> updateClinicalNote({
    required String noteId,
    required String note,
  }) {
    final String normalizedId = noteId.trim();
    final String normalizedNote = note.trim();
    if (normalizedId.isEmpty || normalizedNote.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(
      () => _repository.updateClinicalNote(normalizedId, <String, Object?>{
        'note': normalizedNote,
      }),
    );
  }

  Future<Result<OpdFlowDetail>> loadSelectedOpdFlowDetail() async {
    final String? opdFlowApiId = _selectedOpdFlowApiId();
    if (opdFlowApiId == null) {
      return Result<OpdFlowDetail>.failure(AppFailure.validation());
    }
    return _opdRepository.getOpdFlow(opdFlowApiId);
  }

  Future<AppFailure?> recordEncounterVitals({
    required List<Map<String, Object?>> vitals,
    bool updateExisting = false,
  }) {
    final String? opdFlowApiId = _selectedOpdFlowApiId();
    if (opdFlowApiId == null || vitals.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(
      () => _opdRepository
          .recordVitals(opdFlowApiId, <String, Object?>{
            'vitals': vitals,
            if (updateExisting) 'update_existing': true,
          })
          .then((Result<OpdFlowDetail> result) => result.map<void>((_) {})),
    );
  }

  String? _selectedOpdFlowApiId() {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null) {
      return null;
    }
    return clinicalOpdFlowApiId(entry);
  }

  Future<AppFailure?> addDiagnosis({
    required String diagnosisType,
    required List<ClinicalCatalogOption> diagnoses,
  }) {
    final List<ClinicalCatalogOption> normalizedDiagnoses = diagnoses
        .where(
          (ClinicalCatalogOption diagnosis) =>
              _diagnosisDescription(diagnosis).isNotEmpty,
        )
        .toList(growable: false);
    if (normalizedDiagnoses.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(() async {
      final Set<String> existingDiagnosisKeys =
          (_currentState?.selectedBundle?.diagnoses ??
                  const <ClinicalRelatedRecord>[])
              .map(_diagnosisRecordDedupKey)
              .where((String key) => key.isNotEmpty)
              .toSet();

      for (final ClinicalCatalogOption diagnosis in normalizedDiagnoses) {
        final String description = _diagnosisDescription(diagnosis);
        final String? code = _normalizedOptionalText(diagnosis.code);
        final String dedupeKey = _diagnosisOptionDedupKey(
          code: code,
          description: description,
          fallbackId: diagnosis.id,
        );
        if (existingDiagnosisKeys.contains(dedupeKey)) {
          return Result<void>.failure(
            AppFailure.validation(
              validationFields: const <String>{'diagnosis'},
            ),
          );
        }

        final Result<void> diagnosisResult = await _repository
            .createDiagnosis(<String, Object?>{
              'encounter_id': _selectedEntry!.encounterId,
              'diagnosis_type': diagnosisType,
              'code': code,
              'description': description,
            });
        final AppFailure? diagnosisFailure = _failureOrNull(diagnosisResult);
        if (diagnosisFailure != null) {
          return Result<void>.failure(diagnosisFailure);
        }

        existingDiagnosisKeys.add(dedupeKey);

        await _recordCatalogFavorite(
          termType: 'DIAGNOSIS',
          itemId: diagnosis.id,
          code: code,
          description: description,
        );
      }
      return const Result<void>.success(null);
    });
  }

  Future<AppFailure?> deleteDiagnosis(String diagnosisId) {
    return _mutateSelectedEncounter(
      () => _repository.deleteDiagnosis(diagnosisId),
    );
  }

  Future<AppFailure?> updateDiagnosis({
    required String diagnosisId,
    required String diagnosisType,
    String? description,
    String? code,
  }) {
    final String normalizedType = diagnosisType.trim().toUpperCase();
    if (normalizedType.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(() {
      return _repository.updateDiagnosis(diagnosisId, <String, Object?>{
        'diagnosis_type': normalizedType,
        if (description != null) 'description': description,
        if (code != null) 'code': code,
      });
    });
  }

  Future<AppFailure?> updateDiagnosesType({
    required List<ClinicalRelatedRecord> diagnoses,
    required String diagnosisType,
  }) {
    final String normalizedType = diagnosisType.trim().toUpperCase();
    final List<ClinicalRelatedRecord> targets = diagnoses
        .where((ClinicalRelatedRecord item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    if (normalizedType.isEmpty || targets.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(() async {
      for (final ClinicalRelatedRecord diagnosis in targets) {
        final Result<void> result = await _repository.updateDiagnosis(
          diagnosis.id,
          <String, Object?>{
            'diagnosis_type': normalizedType,
            if ((diagnosis.title ?? '').trim().isNotEmpty)
              'description': diagnosis.title!.trim(),
            if ((diagnosis.code ?? '').trim().isNotEmpty)
              'code': diagnosis.code!.trim(),
          },
        );
        final AppFailure? failure = _failureOrNull(result);
        if (failure != null) {
          return Result<void>.failure(failure);
        }
      }
      return const Result<void>.success(null);
    });
  }

  Future<AppFailure?> addProcedure({
    required String description,
    String? code,
    DateTime? performedAt,
  }) {
    final String normalizedDescription = description.trim();
    final String? normalizedCode = _normalizedOptionalText(code);
    if (normalizedDescription.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return addProcedures(
      procedures: <ClinicalCatalogOption>[
        ClinicalCatalogOption(
          id: _joinProcedureKey(normalizedCode, normalizedDescription),
          code: normalizedCode,
          name: normalizedDescription,
        ),
      ],
      performedAt: performedAt,
    );
  }

  Future<AppFailure?> addProcedures({
    required List<ClinicalCatalogOption> procedures,
    DateTime? performedAt,
    ClinicalRequestBillingSubmit? billing,
  }) {
    final List<ClinicalCatalogOption> normalizedProcedures = procedures
        .where(
          (ClinicalCatalogOption procedure) =>
              _procedureDescription(procedure).isNotEmpty,
        )
        .toList(growable: false);
    if (normalizedProcedures.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    final String performedAtIso = (performedAt ?? DateTime.now())
        .toUtc()
        .toIso8601String();
    // Auto bill-later when caller omitted billing (request-time charge hook).
    final ClinicalRequestBillingSubmit effectiveBilling =
        billing ??
        buildPendingClinicalRequestBillingSubmit(
          options: normalizedProcedures,
          catalogType: 'SERVICE',
          billingEntity: 'FACILITY',
        );

    return _mutateSelectedEncounter(() async {
      final String encounterId = _selectedEntry!.encounterId;
      var paymentAttached = false;
      for (final ClinicalCatalogOption procedure in normalizedProcedures) {
        final String description = _procedureDescription(procedure);
        final String? code = _normalizedOptionalText(procedure.code);
        final String catalogKey = procedure.apiId.trim().isNotEmpty
            ? procedure.apiId
            : procedure.id;
        final bool includePayment = !paymentAttached;
        final ClinicalRequestBillingSubmit? sliced =
            sliceClinicalRequestBillingForCatalogItem(
              effectiveBilling,
              catalogKey,
              includePayment: includePayment,
            );
        if (sliced != null &&
            sliced.paidAmount != null &&
            sliced.paidAmount! > 0) {
          paymentAttached = true;
        }
        final Result<void> procedureResult = await _repository.createProcedure(
          mergeClinicalRequestBilling(<String, Object?>{
            'encounter_id': encounterId,
            'code': code,
            'description': description,
            'performed_at': performedAtIso,
          }, sliced ?? effectiveBilling),
        );
        final AppFailure? failure = _failureOrNull(procedureResult);
        if (failure != null) {
          return Result<void>.failure(failure);
        }
      }

      for (final ClinicalCatalogOption procedure in normalizedProcedures) {
        await _recordCatalogFavorite(
          termType: 'PROCEDURE',
          itemId: procedure.id,
          code: _normalizedOptionalText(procedure.code),
          description: _procedureDescription(procedure),
        );
      }

      return const Result<void>.success(null);
    });
  }

  Future<AppFailure?> addCarePlan({
    required String plan,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _mutateSelectedEncounter(
      () => _repository.createCarePlan(<String, Object?>{
        'encounter_id': _selectedEntry!.encounterId,
        'plan': plan,
        'start_date': startDate?.toUtc().toIso8601String(),
        'end_date': endDate?.toUtc().toIso8601String(),
      }),
    );
  }

  Future<AppFailure?> requestLab({
    required List<String> labTestIds,
    required List<String> labPanelIds,
    ClinicalRequestBillingSubmit? billing,
  }) {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null || entry.apiPatientId == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(() async {
      final Result<void> orderResult = await _repository.createLabOrder(
        mergeClinicalRequestBilling(<String, Object?>{
          'encounter_id': entry.encounterId,
          'patient_id': entry.apiPatientId,
          'ordered_at': DateTime.now().toUtc().toIso8601String(),
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
      final AppFailure? failure = _failureOrNull(orderResult);
      if (failure != null) {
        return Result<void>.failure(failure);
      }
      for (final String id in labTestIds) {
        await _recordCatalogFavorite(
          termType: 'LAB_TEST',
          itemId: id,
          description: id,
        );
      }
      return const Result<void>.success(null);
    });
  }

  Future<AppFailure?> updateLabOrder({
    required String labOrderId,
    required List<String> labTestIds,
    required List<String> labPanelIds,
    ClinicalRequestBillingSubmit? billing,
  }) {
    return _mutateSelectedEncounter(
      () => _repository.updateLabOrder(
        labOrderId,
        mergeClinicalRequestBilling(<String, Object?>{
          'requested_tests': <Map<String, Object?>>[
            for (final String id in labTestIds)
              <String, Object?>{'lab_test_id': id},
          ],
          'requested_panels': <Map<String, Object?>>[
            for (final String id in labPanelIds)
              <String, Object?>{'lab_panel_id': id},
          ],
        }, billing),
      ),
    );
  }

  Future<AppFailure?> cancelLabOrder(String labOrderId) {
    return _mutateSelectedEncounter(
      () => _repository.updateLabOrder(labOrderId, <String, Object?>{
        'status': 'CANCELLED',
      }),
    );
  }

  Future<AppFailure?> deleteLabOrder(String labOrderId) {
    return _mutateSelectedEncounter(
      () => _repository.deleteLabOrder(labOrderId),
    );
  }

  Future<AppFailure?> requestRadiology({
    required List<ClinicalRadiologyRequest> requests,
    ClinicalRequestBillingSubmit? billing,
  }) {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null || entry.apiPatientId == null || requests.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(() async {
      final Result<void> orderResult = await _repository.createRadiologyOrder(
        <String, Object?>{
          'encounter_id': entry.encounterId,
          'patient_id': entry.apiPatientId,
          'ordered_at': DateTime.now().toUtc().toIso8601String(),
          'requested_tests': <Map<String, Object?>>[
            for (final ClinicalRadiologyRequest request in requests)
              <String, Object?>{
                'radiology_test_id': request.radiologyTestId,
                'clinical_note': request.clinicalNote,
                'request_details':
                    mergeClinicalRequestBillingIntoRequestDetails(
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
        },
      );
      final AppFailure? failure = _failureOrNull(orderResult);
      if (failure != null) {
        return Result<void>.failure(failure);
      }
      for (final ClinicalRadiologyRequest request in requests) {
        final String testId = request.radiologyTestId.trim();
        if (testId.isEmpty) {
          continue;
        }
        await _recordCatalogFavorite(
          termType: 'RADIOLOGY_TEST',
          itemId: testId,
          description: <String?>[
            testId,
            request.modality,
            request.bodyRegion,
          ].whereType<String>().join(' '),
        );
      }
      return const Result<void>.success(null);
    });
  }

  Future<AppFailure?> cancelRadiologyOrder(String radiologyOrderId) {
    return _mutateSelectedEncounter(
      () => _repository.updateRadiologyOrder(
        radiologyOrderId,
        <String, Object?>{'status': 'CANCELLED'},
      ),
    );
  }

  Future<AppFailure?> deleteRadiologyOrder(String radiologyOrderId) {
    return _mutateSelectedEncounter(
      () => _repository.deleteRadiologyOrder(radiologyOrderId),
    );
  }

  Future<AppFailure?> prescribe({
    required List<Map<String, Object?>> items,
    ClinicalRequestBillingSubmit? billing,
  }) {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null || entry.apiPatientId == null || items.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(() async {
      final Result<void> orderResult = await _repository.createPharmacyOrder(
        mergeClinicalRequestBilling(<String, Object?>{
          'encounter_id': entry.encounterId,
          'patient_id': entry.apiPatientId,
          'ordered_at': DateTime.now().toUtc().toIso8601String(),
          'items': items,
        }, billing),
      );
      final AppFailure? failure = _failureOrNull(orderResult);
      if (failure != null) {
        return Result<void>.failure(failure);
      }
      for (final Map<String, Object?> item in items) {
        final String? drugId = _normalizedOptionalText(
          item['drug_id']?.toString(),
        );
        final String? description = _normalizedOptionalText(
          item['drug_name']?.toString() ?? item['instructions']?.toString(),
        );
        if (drugId == null && description == null) {
          continue;
        }
        await _recordCatalogFavorite(
          termType: 'PRESCRIPTION',
          itemId: drugId,
          description: description ?? drugId ?? '',
        );
      }
      return const Result<void>.success(null);
    });
  }

  Future<AppFailure?> cancelPharmacyOrder(String pharmacyOrderId) {
    return _mutateSelectedEncounter(
      () => _repository.updatePharmacyOrder(pharmacyOrderId, <String, Object?>{
        'status': 'CANCELLED',
      }),
    );
  }

  Future<AppFailure?> deletePharmacyOrder(String pharmacyOrderId) {
    return _mutateSelectedEncounter(
      () => _repository.deletePharmacyOrder(pharmacyOrderId),
    );
  }

  Future<AppFailure?> refer({
    required String externalFacilityName,
    required String reason,
    String? notes,
  }) {
    return _mutateSelectedEncounter(
      () => _repository.createReferral(<String, Object?>{
        'encounter_id': _selectedEntry!.apiEncounterId,
        'external_facility_name': externalFacilityName,
        'reason': reason,
        'notes': notes,
      }),
    );
  }

  Future<AppFailure?> scheduleFollowUp({
    required DateTime scheduledAt,
    String? notes,
  }) {
    return _mutateSelectedEncounter(
      () => _repository.createFollowUp(<String, Object?>{
        'encounter_id': _selectedEntry!.apiEncounterId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'SCHEDULED',
        'notes': notes,
      }),
    );
  }

  Future<AppFailure?> requestAdmission({
    ClinicalCatalogOption? bed,
    String? reason,
    String? notes,
  }) {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null || entry.apiPatientId == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    if (bed != null) {
      final String bedStatus = (bed.status ?? 'AVAILABLE').trim().toUpperCase();
      if (bed.parentId == null ||
          bed.secondaryId == null ||
          (bedStatus.isNotEmpty && bedStatus != 'AVAILABLE')) {
        return Future<AppFailure?>.value(AppFailure.validation());
      }
    }

    return _mutateSelectedEncounter(
      () => _ipdRepository
          .requestAdmission(<String, Object?>{
            'tenant_id': entry.tenantId,
            'facility_id': entry.facilityId,
            'patient_id': entry.apiPatientId,
            'encounter_id': entry.apiEncounterId,
            if (reason != null && reason.trim().isNotEmpty)
              'reason': reason.trim(),
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          })
          .then(
            (Result<IpdAdmissionDetail> result) => result.map<void>((_) {}),
          ),
    );
  }

  Future<AppFailure?> completeDisposition({
    required String reason,
    String? notes,
  }) async {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    final String normalizedReason = reason.trim();
    final String normalizedNotes = notes?.trim() ?? '';
    if (entry == null || normalizedReason.isEmpty) {
      return AppFailure.validation();
    }

    final String? opdFlowApiId = entry.opdFlowApiId;
    if (opdFlowApiId != null &&
        isClinicalTriageDischargeContext(
          sourceQueue: entry.sourceQueue,
          stage: entry.stage,
        )) {
      return _mutateSelectedEncounter(
        () => _opdRepository
            .routeTriage(opdFlowApiId, <String, Object?>{
              'route_to': 'DISCHARGE',
              'decision': 'DISCHARGE',
              'notes': _dispositionReviewNote(
                reason: normalizedReason,
                notes: normalizedNotes,
              ),
            })
            .then((Result<OpdFlowDetail> result) => result.map<void>((_) {})),
        removeSelectedOnSuccess: true,
      );
    }

    if (opdFlowApiId != null) {
      if (!isClinicalDoctorDispositionContext(
        sourceQueue: entry.sourceQueue,
        stage: entry.stage,
      )) {
        return AppFailure.validation(validationFields: const <String>{'stage'});
      }

      return _mutateSelectedEncounter(() async {
        if (_requiresOpdDoctorReview(entry)) {
          final Result<OpdFlowDetail> reviewResult = await _opdRepository
              .doctorReview(opdFlowApiId, <String, Object?>{
                'note': _dispositionReviewNote(
                  reason: normalizedReason,
                  notes: normalizedNotes,
                ),
              });
          final AppFailure? reviewFailure = _failureOrNull(reviewResult);
          if (reviewFailure != null) {
            return Result<void>.failure(reviewFailure);
          }
        }

        return _opdRepository
            .disposition(opdFlowApiId, <String, Object?>{
              'decision': 'DISCHARGE',
              'reason': normalizedReason,
              'notes': normalizedNotes,
            })
            .then((Result<OpdFlowDetail> result) => result.map<void>((_) {}));
      }, removeSelectedOnSuccess: true);
    }

    if (_isActiveAdmissionEntry(entry)) {
      final String? admissionId = entry.apiAdmissionId;
      if (admissionId == null || admissionId.trim().isEmpty) {
        return AppFailure.validation();
      }

      final String summary = _dispositionReviewNote(
        reason: normalizedReason,
        notes: normalizedNotes,
      );
      final bool isDischargePlanned =
          (entry.stage ?? '').toUpperCase() == 'DISCHARGE_PLANNED' ||
          (entry.status ?? '').toUpperCase() == 'DISCHARGE_PLANNED';

      if (isDischargePlanned) {
        return _mutateSelectedEncounter(
          () => _ipdRepository
              .finalizeDischarge(admissionId, <String, Object?>{
                'summary': summary,
                'discharged_at': DateTime.now().toUtc().toIso8601String(),
              })
              .then(
                (Result<IpdAdmissionDetail> result) => result.map<void>((_) {}),
              ),
          removeSelectedOnSuccess: true,
        );
      }

      return _mutateSelectedEncounter(
        () => _ipdRepository
            .planDischarge(admissionId, <String, Object?>{'summary': summary})
            .then(
              (Result<IpdAdmissionDetail> result) => result.map<void>((_) {}),
            ),
      );
    }

    final Result<ClinicalWorklistEntry> result = await _repository
        .updateEncounter(entry.encounterId, <String, Object?>{
          'status': 'CLOSED',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        });
    return result.when<Future<AppFailure?>>(
      success: (ClinicalWorklistEntry updated) async {
        final ClinicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedBundle: updated.isTerminal ? null : latest.selectedBundle,
              clearSelectedBundle: updated.isTerminal,
              worklist: updated.isTerminal
                  ? _removeEntry(latest.worklist, updated)
                  : _replaceEntry(latest.worklist, updated),
            ),
          );
        }
        if (updated.isTerminal) {
          return null;
        }
        return selectEntry(updated);
      },
      failure: (AppFailure failure) async => failure,
    );
  }

  Future<AppFailure?> completeConsultation(String notes) {
    return completeDisposition(reason: 'CONSULTATION_COMPLETED', notes: notes);
  }

  bool _isActiveAdmissionEntry(ClinicalWorklistEntry entry) {
    return isClinicalAdmissionDischargeContext(
      sourceQueue: entry.sourceQueue,
      status: entry.status,
      stage: entry.stage,
      location: entry.currentLocation,
      hasAdmission: entry.admissionId?.trim().isNotEmpty ?? false,
    );
  }

  Future<Result<ClinicalWorkspaceState>> _loadInitialState() async {
    const ClinicalWorklistQuery query = ClinicalWorklistQuery();
    final Result<_ClinicalWorklistLoad> worklistResult = await _loadWorklist(
      query,
    );
    final _ClinicalWorklistLoad? loaded = _successOrNull(worklistResult);
    if (loaded == null) {
      return Result<ClinicalWorkspaceState>.failure(
        _failureOrNull(worklistResult)!,
      );
    }

    final ClinicalReferenceData referenceData = await _referenceData();

    return Result<ClinicalWorkspaceState>.success(
      ClinicalWorkspaceState(
        query: query,
        worklist: loaded.page,
        facetCounts: loaded.facets,
        referenceData: referenceData,
      ),
    );
  }

  void _startAdaptivePolling() {
    installWorkspaceAdaptivePolling(
      ref: ref,
      polling: _adaptivePolling,
      intervalWhenDisconnected: _syncInterval,
      disconnectProfile: WorkspaceRefreshProfile.clinicalFlow,
      syncOnDisconnect: (WorkspaceRefreshPlan plan) =>
          _syncVisibleData(plan: plan),
    );
  }

  bool _clinicalRealtimeEventTouchesVisibleData(RealtimeMessage message) {
    final Map<String, Object?> payload = message.payload;
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return false;
    }

    final ClinicalEncounterBundle? selectedBundle = current.selectedBundle;
    if (selectedBundle == null) {
      return true;
    }

    final ClinicalWorklistEntry selected = selectedBundle.entry;
    final Map<String, Object?> workflow = _objectMap(payload['workflow']);
    final Map<String, Object?> order = _objectMap(
      workflow['order'] ?? payload['order'],
    );
    final Map<String, Object?> encounter = _objectMap(
      payload['encounter'] ?? workflow['encounter'],
    );
    final Map<String, Object?> patient = _objectMap(
      payload['patient'] ?? workflow['patient'],
    );
    final Map<String, Object?> admission = _objectMap(
      payload['admission'] ?? workflow['admission'] ?? order['admission'],
    );
    final Map<String, Object?> resource = _objectMap(payload['resource']);

    final Set<String> selectedPatientIds = _normalizedIds(<String?>[
      selected.apiPatientId,
      selected.patientId,
      selected.patientPublicId,
    ]);
    final Set<String> selectedEncounterIds = _normalizedIds(<String?>[
      selected.apiEncounterId,
      selected.encounterId,
      selected.encounterPublicId,
    ]);
    final Set<String> selectedAdmissionIds = _normalizedIds(<String?>[
      selected.apiAdmissionId,
      selected.admissionId,
      selected.admissionPublicId,
    ]);
    final Set<String> selectedLabOrderIds = _relatedRecordIds(
      selectedBundle.labOrders,
    );
    final Set<String> selectedRadiologyOrderIds = _relatedRecordIds(
      selectedBundle.radiologyOrders,
    );
    final Set<String> selectedPharmacyOrderIds = _relatedRecordIds(
      selectedBundle.pharmacyOrders,
    );

    final Set<String> eventPatientIds = _normalizedIds(<String?>[
      _stringValue(payload['patient_id']),
      _stringValue(payload['patient_public_id']),
      _stringValue(order['patient_id']),
      _stringValue(order['patient_public_id']),
      _stringValue(patient['id']),
      _stringValue(patient['public_id']),
      _stringValue(patient['patient_id']),
      _stringValue(encounter['patient_id']),
      _stringValue(admission['patient_id']),
      _stringValue(resource['patient_id']),
    ]);
    final Set<String> eventEncounterIds = _normalizedIds(<String?>[
      _stringValue(payload['encounter_id']),
      _stringValue(payload['encounter_public_id']),
      _stringValue(order['encounter_id']),
      _stringValue(order['encounter_public_id']),
      _stringValue(encounter['id']),
      _stringValue(encounter['public_id']),
      _stringValue(encounter['display_id']),
      _stringValue(encounter['human_friendly_id']),
      _stringValue(admission['encounter_id']),
      _stringValue(resource['encounter_id']),
    ]);
    final Set<String> eventAdmissionIds = _normalizedIds(<String?>[
      _stringValue(payload['admission_id']),
      _stringValue(payload['admission_public_id']),
      _stringValue(order['admission_id']),
      _stringValue(order['admission_public_id']),
      _stringValue(admission['id']),
      _stringValue(admission['public_id']),
      _stringValue(admission['display_id']),
      _stringValue(resource['admission_id']),
    ]);
    final Set<String> eventLabOrderIds = _normalizedIds(<String?>[
      _stringValue(payload['lab_order_id']),
      _stringValue(payload['order_id']),
      _stringValue(payload['order_public_id']),
      _stringValue(payload['resource_id']),
      _stringValue(order['id']),
      _stringValue(order['public_id']),
      _stringValue(order['display_id']),
      _stringValue(resource['lab_order_id']),
    ]);
    final Set<String> eventRadiologyOrderIds = _normalizedIds(<String?>[
      _stringValue(payload['radiology_order_id']),
      _stringValue(payload['order_id']),
      _stringValue(payload['order_public_id']),
      _stringValue(payload['resource_id']),
      _stringValue(order['id']),
      _stringValue(order['public_id']),
      _stringValue(order['display_id']),
      _stringValue(resource['radiology_order_id']),
    ]);
    final Set<String> eventPharmacyOrderIds = _normalizedIds(<String?>[
      _stringValue(payload['pharmacy_order_id']),
      _stringValue(payload['order_id']),
      _stringValue(payload['order_public_id']),
      _stringValue(payload['resource_id']),
      _stringValue(order['id']),
      _stringValue(order['public_id']),
      _stringValue(order['display_id']),
      _stringValue(resource['pharmacy_order_id']),
    ]);

    final bool hasTargetIds = <Set<String>>[
      eventPatientIds,
      eventEncounterIds,
      eventAdmissionIds,
      eventLabOrderIds,
      eventRadiologyOrderIds,
      eventPharmacyOrderIds,
    ].any((Set<String> ids) => ids.isNotEmpty);
    if (!hasTargetIds) {
      return true;
    }

    return _setsIntersect(selectedPatientIds, eventPatientIds) ||
        _setsIntersect(selectedEncounterIds, eventEncounterIds) ||
        _setsIntersect(selectedAdmissionIds, eventAdmissionIds) ||
        _setsIntersect(selectedLabOrderIds, eventLabOrderIds) ||
        _setsIntersect(selectedRadiologyOrderIds, eventRadiologyOrderIds) ||
        _setsIntersect(selectedPharmacyOrderIds, eventPharmacyOrderIds);
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshReferenceData = false,
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.full,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      _pendingRefresh.defer(plan);
      return null;
    }

    final bool refreshWorklist = workspacePlanRefreshesPrimaryList(plan);
    final bool refreshRefs =
        refreshReferenceData || workspacePlanRefreshesReferenceData(plan);
    final bool refreshDetail =
        plan.selectedDetail && current.selectedBundle != null;
    if (!refreshWorklist && !refreshRefs && !refreshDetail) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: refreshWorklist,
          isRefreshingDetail: refreshDetail,
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

      if (refreshRefs) {
        final ClinicalReferenceData referenceData = await _referenceData();
        final ClinicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(referenceData: referenceData));
        }
      }

      if (refreshDetail) {
        final ClinicalWorklistEntry? selected = _selectedEntry;
        if (selected != null) {
          await _refreshSelectedEntry(selected, showLoading: showLoading);
        }
      }

      return null;
    } finally {
      final ClinicalWorkspaceState? latest = _currentState;
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
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<_ClinicalWorklistLoad> result = await _loadWorklist(
      current.query,
    );
    return result.when(
      success: (_ClinicalWorklistLoad loaded) {
        final ClinicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              worklist: loaded.page,
              facetCounts: loaded.facets,
              isRefreshing: showLoading ? false : latest.isRefreshing,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final ClinicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  String? get _currentUserId {
    return ref.read(sessionStateProvider).session?.user?.id?.trim();
  }

  Future<Result<_ClinicalWorklistLoad>> _loadWorklist(
    ClinicalWorklistQuery query,
  ) async {
    final String? currentUserId = _currentUserId;
    // Non-completed scopes still fetch OPEN rows; keep the active scope on the
    // open query so callers/tests can observe tab selection. Always load CLOSED
    // rows in parallel for Completed today facets.
    final ClinicalWorklistQuery openQuery =
        query.scope == ClinicalQueueScope.completed
        ? query.copyWith(scope: ClinicalQueueScope.all)
        : query;
    final ClinicalWorklistQuery completedQuery = query.copyWith(
      scope: ClinicalQueueScope.completed,
    );

    final List<Result<AppPage<ClinicalWorklistEntry>>> openResults =
        await Future.wait(<Future<Result<AppPage<ClinicalWorklistEntry>>>>[
          _repository.listEncounters(openQuery),
          _opdFlows(openQuery),
          _triageFlows(openQuery),
        ]);
    final Result<AppPage<ClinicalWorklistEntry>> completedEncounters =
        await _repository.listEncounters(completedQuery);

    final bool hasOpenSuccess = openResults.any(
      (Result<AppPage<ClinicalWorklistEntry>> result) => result.isSuccess,
    );
    final bool hasCompletedSuccess = completedEncounters.isSuccess;
    if (!hasOpenSuccess && !hasCompletedSuccess) {
      return Result<_ClinicalWorklistLoad>.failure(
        _firstFailure(openResults) ??
            _failureOrNull(completedEncounters) ??
            const AppFailure.network(),
      );
    }

    final List<ClinicalWorklistEntry> openCandidates =
        deduplicateClinicalWorklistEntries(
          <ClinicalWorklistEntry>[
            for (final Result<AppPage<ClinicalWorklistEntry>> result
                in openResults)
              ..._worklistPageOrEmpty(result, query.pageRequest).items,
          ].where((ClinicalWorklistEntry item) {
            return item.matchesSearch(query.search, filters: query.filters) &&
                item.matchesFilters(query.filters);
          }),
        );

    final List<ClinicalWorklistEntry> completedCandidates =
        deduplicateClinicalWorklistEntries(
          _worklistPageOrEmpty(
            completedEncounters,
            query.pageRequest,
          ).items.where((ClinicalWorklistEntry item) {
            return item.matchesSearch(query.search, filters: query.filters) &&
                item.matchesFilters(query.filters);
          }),
        );

    final ClinicalWorklistFacetCounts facets = clinicalWorklistFacetCounts(
      openCandidates,
      completedCandidates,
      currentUserId: currentUserId,
    );

    final Iterable<ClinicalWorklistEntry> scopedSource =
        query.scope == ClinicalQueueScope.completed
        ? completedCandidates
        : openCandidates;

    final List<ClinicalWorklistEntry> scoped =
        deduplicateClinicalWorklistEntries(
          scopedSource.where(
            (ClinicalWorklistEntry item) => clinicalWorklistEntryMatchesScope(
              item,
              query.scope,
              currentUserId: currentUserId,
            ),
          ),
        );

    final List<ClinicalWorklistEntry> sorted = scoped.toList(growable: true)
      ..sort(_compareEntries);
    final int start = query.pageRequest.pageIndex * query.pageRequest.pageSize;
    final List<ClinicalWorklistEntry> paged = start >= sorted.length
        ? const <ClinicalWorklistEntry>[]
        : sorted
              .skip(start)
              .take(query.pageRequest.pageSize)
              .toList(growable: false);

    return Result<_ClinicalWorklistLoad>.success(
      _ClinicalWorklistLoad(
        page: AppPage<ClinicalWorklistEntry>(
          items: paged,
          request: query.pageRequest,
          totalItemCount: sorted.length,
        ),
        facets: facets,
      ),
    );
  }

  Future<Result<AppPage<ClinicalWorklistEntry>>> _opdFlows(
    ClinicalWorklistQuery query,
  ) async {
    final Result<AppPage<OpdFlowSummary>> result = await _opdRepository
        .listOpdFlows(
          OpdFlowQuery(
            search: query.databaseSearch,
            pageRequest: const AppPageRequest(),
          ),
        );

    return result.map(
      (AppPage<OpdFlowSummary> page) => AppPage<ClinicalWorklistEntry>(
        items: page.items
            .map((OpdFlowSummary item) => _entryFromOpd(item, 'OPD'))
            .toList(growable: false),
        request: query.pageRequest,
        totalItemCount: page.totalItemCount,
      ),
    );
  }

  Future<Result<AppPage<ClinicalWorklistEntry>>> _triageFlows(
    ClinicalWorklistQuery query,
  ) async {
    final Result<AppPage<OpdFlowSummary>> result = await _opdRepository
        .listTriageQueue(
          OpdTriageQueueQuery(
            search: query.databaseSearch,
            pageRequest: const AppPageRequest(),
          ),
        );

    return result.map(
      (AppPage<OpdFlowSummary> page) => AppPage<ClinicalWorklistEntry>(
        items: page.items
            .map((OpdFlowSummary item) => _entryFromOpd(item, 'TRIAGE'))
            .toList(growable: false),
        request: query.pageRequest,
        totalItemCount: page.totalItemCount,
      ),
    );
  }

  ClinicalWorklistEntry _entryFromOpd(OpdFlowSummary item, String sourceQueue) {
    final String triageLevel = (item.triageLevel ?? '').toUpperCase();
    final bool hasAssignedProvider =
        _stringValue(item.providerUserId) != null ||
        _stringValue(item.providerDisplayName) != null ||
        _stringValue(item.assignedStaffDisplayName) != null;
    final String? normalizedStage =
        hasAssignedProvider &&
            (item.stage ?? '').toUpperCase() == 'WAITING_DOCTOR_ASSIGNMENT'
        ? 'WAITING_DOCTOR_REVIEW'
        : item.stage;
    final String? normalizedStatus =
        hasAssignedProvider &&
            (item.displayCode ?? item.status ?? '').toUpperCase() ==
                'DOCTOR_NEEDED'
        ? 'WITH_DOCTOR'
        : item.displayCode ?? item.status ?? normalizedStage;
    final String? normalizedNextStep =
        hasAssignedProvider &&
            (item.nextStep ?? '').toUpperCase() == 'ASSIGN_DOCTOR'
        ? 'DOCTOR_REVIEW'
        : item.displayNextStep ?? item.nextStep;

    return ClinicalWorklistEntry(
      id: '${sourceQueue}_${item.id}',
      sourceQueue: sourceQueue,
      encounterId: item.id,
      encounterPublicId: item.publicId,
      tenantId: item.tenantId,
      facilityId: item.facilityId,
      patientId: item.patientId,
      patientPublicId: item.patientIdentifier,
      patientDisplayName: item.patientDisplayName,
      patientPhone: item.patientPhone,
      encounterType: item.encounterType,
      status: normalizedStatus,
      stage: normalizedStage,
      nextStep: normalizedNextStep,
      currentLocation: item.facilityName,
      providerUserId: item.providerUserId,
      providerDisplayName: item.providerDisplayName,
      startedAt: item.startedAt,
      updatedAt: item.endedAt ?? item.startedAt ?? item.queuedAt,
      opdFlowApiId: item.apiId,
      isUrgent:
          item.emergencyIndicator ||
          triageLevel.contains('URGENT') ||
          triageLevel.contains('IMMEDIATE') ||
          triageLevel.contains('LEVEL_1') ||
          triageLevel.contains('LEVEL_2'),
      resultsReady:
          (normalizedStage ?? '').toUpperCase().contains('RESULT') ||
          (normalizedNextStep ?? '').toUpperCase().contains('RESULT'),
    );
  }

  Future<ClinicalEncounterBundle> _withTriageHandoff(
    ClinicalEncounterBundle bundle,
  ) async {
    final String? opdFlowApiId = clinicalOpdFlowApiId(bundle.entry);
    if (opdFlowApiId == null) {
      return bundle;
    }

    final Result<OpdFlowDetail> result = await _opdRepository.getOpdFlow(
      opdFlowApiId,
    );
    final OpdFlowDetail? detail = _successOrNull(result);
    if (detail == null) {
      return bundle;
    }

    return bundle.copyWith(triageHandoff: _handoffFromOpdDetail(detail));
  }

  ClinicalTriageHandoff _handoffFromOpdDetail(OpdFlowDetail detail) {
    final List<ClinicalAlertSummary> alerts = detail.clinicalAlertDetails
        .map(_alertFromOpd)
        .toList(growable: false);
    return ClinicalTriageHandoff(
      triageLevel: detail.summary.triageLevel,
      routeTo: detail.summary.lastRouteTo,
      chiefComplaint: detail.summary.chiefComplaint,
      triageNotes: detail.summary.triageNotes,
      stage: detail.summary.stage,
      nextStep: detail.summary.nextStep,
      emergencyIndicator: detail.summary.emergencyIndicator,
      queuedAt: detail.summary.queuedAt ?? detail.summary.startedAt,
      timeline: detail.timeline
          .map(
            (OpdTimelineItem item) => ClinicalWorkflowTimelineItem(
              action: item.action,
              stage: item.stage,
              notes: item.notes,
              occurredAt: item.occurredAt,
            ),
          )
          .toList(growable: false),
      vitalSigns: detail.vitalMeasurements
          .map(
            (OpdVitalSign vital) => ClinicalVitalSummary(
              id: vital.id,
              vitalType: vital.vitalType,
              displayValue: vital.displayValue,
              recordedAt: vital.recordedAt,
              status: _vitalStatusFromAlerts(vital, alerts),
            ),
          )
          .toList(growable: false),
      alerts: alerts,
    );
  }

  ClinicalAlertSummary _alertFromOpd(OpdClinicalAlert alert) {
    return ClinicalAlertSummary(
      id: alert.id,
      severity: alert.severity,
      status: alert.status,
      message: alert.message,
      vitalSignId: alert.vitalSignId,
      createdAt: alert.createdAt,
    );
  }

  String _vitalStatusFromAlerts(
    OpdVitalSign vital,
    List<ClinicalAlertSummary> alerts,
  ) {
    final String vitalType = vital.vitalType.trim().toUpperCase();
    final Iterable<ClinicalAlertSummary> activeAlerts = alerts.where((
      ClinicalAlertSummary alert,
    ) {
      if ((alert.status ?? '').toUpperCase() == 'RESOLVED') {
        return false;
      }
      if (alert.vitalSignId != null &&
          alert.vitalSignId!.trim().isNotEmpty &&
          alert.vitalSignId == vital.id) {
        return true;
      }
      if (vitalType.isEmpty) {
        return false;
      }
      final String message = (alert.message ?? '').toUpperCase();
      return message.contains(vitalType);
    });

    String? worst;
    for (final ClinicalAlertSummary alert in activeAlerts) {
      final String band = _vitalAlertBand(alert);
      worst = _worseVitalStatus(worst, band);
    }
    return worst ?? 'NORMAL';
  }

  String _vitalAlertBand(ClinicalAlertSummary alert) {
    final String severity = (alert.severity ?? '').trim().toUpperCase();
    if (severity == 'CRITICAL') {
      return 'CRITICAL';
    }
    if (severity == 'HIGH') {
      return 'HIGH';
    }
    if (severity == 'LOW') {
      return 'LOW';
    }

    final String message = (alert.message ?? '').trim().toUpperCase();
    if (message.startsWith('CRITICAL')) {
      return 'CRITICAL';
    }
    if (message.startsWith('HIGH')) {
      return 'HIGH';
    }
    if (message.startsWith('LOW')) {
      return 'LOW';
    }
    if (severity == 'MEDIUM' || severity == 'WARNING' || severity == 'ABNORMAL') {
      return 'HIGH';
    }
    return 'HIGH';
  }

  String _worseVitalStatus(String? current, String candidate) {
    int rank(String? value) {
      return switch ((value ?? '').toUpperCase()) {
        'CRITICAL' => 4,
        'HIGH' || 'ABNORMAL' => 3,
        'LOW' => 2,
        'NORMAL' || 'RECORDED' => 1,
        _ => 0,
      };
    }

    if (current == null) {
      return candidate;
    }
    return rank(candidate) >= rank(current) ? candidate : current;
  }

  Future<ClinicalReferenceData> _referenceData() async {
    final Result<ClinicalReferenceData> result = await _repository
        .loadReferenceData();
    return result.when(
      success: (ClinicalReferenceData data) => data,
      failure: (_) => const ClinicalReferenceData(),
    );
  }

  Future<AppFailure?> _mutateSelectedEncounter(
    Future<Result<void>> Function() action, {
    bool removeSelectedOnSuccess = false,
  }) async {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null) {
      return AppFailure.validation();
    }

    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    try {
      final Result<void> result = await action();
      return result.when(
        success: (_) async {
          if (removeSelectedOnSuccess) {
            final ClinicalWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(
                latest.copyWith(
                  clearSelectedBundle: true,
                  worklist: _removeEntry(latest.worklist, entry),
                  isSaving: false,
                ),
              );
            }
            unawaited(_refreshWorklist(showLoading: false));
            return null;
          }

          final Result<ClinicalEncounterBundle> detailResult = await _repository
              .loadEncounterBundle(entry);
          return detailResult.when<Future<AppFailure?>>(
            success: (ClinicalEncounterBundle bundle) async {
              final ClinicalEncounterBundle hydrated = await _withTriageHandoff(
                bundle,
              );
              final ClinicalWorkspaceState? latest = _currentState;
              if (latest != null) {
                _emit(
                  latest.copyWith(
                    selectedBundle: hydrated.entry.isTerminal ? null : hydrated,
                    clearSelectedBundle: hydrated.entry.isTerminal,
                    worklist: hydrated.entry.isTerminal
                        ? _removeEntry(latest.worklist, hydrated.entry)
                        : _replaceEntry(latest.worklist, hydrated.entry),
                    isSaving: false,
                  ),
                );
              }
              unawaited(_refreshWorklist(showLoading: false));
              return null;
            },
            failure: (AppFailure failure) async {
              _emitMutationFailure(failure);
              return failure;
            },
          );
        },
        failure: (AppFailure failure) async {
          _emitMutationFailure(failure);
          return failure;
        },
      );
    } catch (error, stackTrace) {
      final AppFailure failure = mapToFailure(error, stackTrace);
      _emitMutationFailure(failure);
      return failure;
    }
  }

  void _emitMutationFailure(AppFailure failure) {
    final ClinicalWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(latest.copyWith(isSaving: false, lastFailure: failure));
    }
  }

  int _compareEntries(ClinicalWorklistEntry left, ClinicalWorklistEntry right) {
    if (left.isUrgent != right.isUrgent) {
      return left.isUrgent ? -1 : 1;
    }
    final DateTime leftDate =
        left.updatedAt ??
        left.startedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime rightDate =
        right.updatedAt ??
        right.startedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return rightDate.compareTo(leftDate);
  }

  AppPage<ClinicalWorklistEntry> _removeEntry(
    AppPage<ClinicalWorklistEntry> page,
    ClinicalWorklistEntry entry,
  ) {
    final List<ClinicalWorklistEntry> items = page.items
        .where(
          (ClinicalWorklistEntry item) =>
              item.encounterId != entry.encounterId ||
              item.sourceQueue != entry.sourceQueue,
        )
        .toList(growable: false);
    if (items.length == page.items.length) {
      return page;
    }
    return AppPage<ClinicalWorklistEntry>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! > 0
          ? page.totalItemCount! - 1
          : 0,
    );
  }

  AppPage<ClinicalWorklistEntry> _replaceEntry(
    AppPage<ClinicalWorklistEntry> page,
    ClinicalWorklistEntry entry,
  ) {
    var replaced = false;
    final List<ClinicalWorklistEntry> items = <ClinicalWorklistEntry>[];
    for (final ClinicalWorklistEntry item in page.items) {
      if (item.encounterId == entry.encounterId &&
          item.sourceQueue == entry.sourceQueue) {
        if (!replaced) {
          items.add(entry);
          replaced = true;
        }
      } else {
        items.add(item);
      }
    }

    if (!replaced) {
      items.insert(0, entry);
    }

    return AppPage<ClinicalWorklistEntry>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  AppFailure? _firstFailure<T>(List<Result<T>> results) {
    for (final Result<T> result in results) {
      final AppFailure? failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      if (failure != null) {
        return failure;
      }
    }
    return null;
  }

  AppPage<ClinicalWorklistEntry> _worklistPageOrEmpty(
    Result<AppPage<ClinicalWorklistEntry>> result,
    AppPageRequest request,
  ) {
    return result.when(
      success: (AppPage<ClinicalWorklistEntry> page) => page,
      failure: (_) => AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request: request,
      ),
    );
  }

  T? _successOrNull<T>(Result<T> result) {
    return result.when(success: (T value) => value, failure: (_) => null);
  }

  String _diagnosisDescription(ClinicalCatalogOption diagnosis) {
    return _normalizedOptionalText(diagnosis.name) ??
        _normalizedOptionalText(diagnosis.displayTitle) ??
        '';
  }

  String _diagnosisRecordDedupKey(ClinicalRelatedRecord diagnosis) {
    return _diagnosisOptionDedupKey(
      code: diagnosis.code,
      description: diagnosis.title,
      fallbackId: diagnosis.id,
    );
  }

  String _diagnosisOptionDedupKey({
    required String? code,
    required String? description,
    required String? fallbackId,
  }) {
    final String normalizedCode =
        _normalizedOptionalText(code)?.toUpperCase() ?? '';
    final String normalizedTitle =
        _normalizedOptionalText(description)?.toUpperCase() ?? '';
    if (normalizedCode.isNotEmpty || normalizedTitle.isNotEmpty) {
      return '$normalizedCode::$normalizedTitle';
    }
    return (fallbackId ?? '').trim().toUpperCase();
  }

  Future<void> _recordCatalogFavorite({
    required String termType,
    String? itemId,
    String? code,
    required String description,
  }) async {
    final String normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      return;
    }
    await _repository.createClinicalTermFavorite(<String, Object?>{
      'term_type': termType,
      'scope': 'PERSONAL',
      'item_id': _normalizedOptionalText(itemId),
      'code': _normalizedOptionalText(code),
      'description': normalizedDescription,
    });
  }

  String _procedureDescription(ClinicalCatalogOption procedure) {
    return _normalizedOptionalText(procedure.name) ??
        _normalizedOptionalText(procedure.displayTitle) ??
        '';
  }

  String? _normalizedOptionalText(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String _joinProcedureKey(String? code, String description) {
    return <String?>[code, description]
        .map((String? value) => value?.trim() ?? '')
        .where((String value) => value.isNotEmpty)
        .join('::');
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  String _dispositionReviewNote({
    required String reason,
    required String notes,
  }) {
    final List<String> parts = <String>[
      if (reason.trim().isNotEmpty) reason.trim(),
      if (notes.trim().isNotEmpty) notes.trim(),
    ];
    return parts.join(' — ');
  }

  bool _requiresOpdDoctorReview(ClinicalWorklistEntry entry) {
    return entry.opdFlowApiId != null &&
        (entry.stage ?? '').toUpperCase() == 'WAITING_DOCTOR_REVIEW';
  }

  Map<String, Object?> _objectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map<Object?, Object?>) {
      return Map<String, Object?>.fromEntries(
        value.entries
            .where((MapEntry<Object?, Object?> entry) => entry.key != null)
            .map(
              (MapEntry<Object?, Object?> entry) =>
                  MapEntry<String, Object?>(entry.key.toString(), entry.value),
            ),
      );
    }
    return const <String, Object?>{};
  }

  Set<String> _relatedRecordIds(Iterable<ClinicalRelatedRecord> records) {
    return records
        .map((ClinicalRelatedRecord record) => _normalizeId(record.id))
        .whereType<String>()
        .toSet();
  }

  Set<String> _normalizedIds(Iterable<String?> values) {
    return values.map(_normalizeId).whereType<String>().toSet();
  }

  String? _normalizeId(String? value) {
    final String? normalized = _stringValue(value)?.toUpperCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool _setsIntersect(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    return left.any(right.contains);
  }

  ClinicalWorklistEntry? get _selectedEntry =>
      _currentState?.selectedBundle?.entry;

  ClinicalWorkspaceState? get _currentState {
    if (!ref.mounted) {
      return null;
    }
    final Result<ClinicalWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<ClinicalWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(ClinicalWorkspaceState nextState) {
    if (!ref.mounted) {
      return;
    }
    state = AsyncData<Result<ClinicalWorkspaceState>>(
      Result<ClinicalWorkspaceState>.success(nextState),
    );
  }
}

final class _ClinicalWorklistLoad {
  const _ClinicalWorklistLoad({
    required this.page,
    required this.facets,
  });

  final AppPage<ClinicalWorklistEntry> page;
  final ClinicalWorklistFacetCounts facets;
}
