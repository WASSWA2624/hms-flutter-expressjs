import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
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

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<ClinicalWorkspaceState>> build() async {
    ref.onDispose(() {
      _syncTimer?.cancel();
    });
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.clinical,
      shouldRefresh: _clinicalRealtimeEventTouchesVisibleData,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<ClinicalWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
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
  }) {
    return _repository.searchClinicalTerms(
      termType: termType,
      query: query,
      limit: limit,
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

  Future<AppFailure?> addDiagnosis({
    required String diagnosisType,
    required String description,
    String? code,
  }) {
    final String normalizedCode = code?.trim() ?? '';
    final String normalizedDescription = description.trim();
    return _mutateSelectedEncounter(() async {
      final Result<void> diagnosisResult = await _repository
          .createDiagnosis(<String, Object?>{
            'encounter_id': _selectedEntry!.encounterId,
            'diagnosis_type': diagnosisType,
            'code': normalizedCode,
            'description': normalizedDescription,
          });
      final AppFailure? diagnosisFailure = _failureOrNull(diagnosisResult);
      if (diagnosisFailure != null) {
        return Result<void>.failure(diagnosisFailure);
      }

      await _repository.createClinicalTermFavorite(<String, Object?>{
        'term_type': 'DIAGNOSIS',
        'scope': 'SHARED',
        'code': normalizedCode,
        'description': normalizedDescription,
      });
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

    return _mutateSelectedEncounter(() async {
      final String encounterId = _selectedEntry!.encounterId;
      for (final ClinicalCatalogOption procedure in normalizedProcedures) {
        final String description = _procedureDescription(procedure);
        final String? code = _normalizedOptionalText(procedure.code);
        final Result<void> procedureResult = await _repository.createProcedure(
          <String, Object?>{
            'encounter_id': encounterId,
            'code': code,
            'description': description,
            'performed_at': performedAtIso,
          },
        );
        final AppFailure? failure = _failureOrNull(procedureResult);
        if (failure != null) {
          return Result<void>.failure(failure);
        }
      }

      for (final ClinicalCatalogOption procedure in normalizedProcedures) {
        await _repository.createClinicalTermFavorite(<String, Object?>{
          'term_type': 'PROCEDURE',
          'scope': 'SHARED',
          'code': _normalizedOptionalText(procedure.code),
          'description': _procedureDescription(procedure),
        });
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
  }) {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null || entry.apiPatientId == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(
      () => _repository.createLabOrder(<String, Object?>{
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
      }),
    );
  }

  Future<AppFailure?> updateLabOrder({
    required String labOrderId,
    required List<String> labTestIds,
    required List<String> labPanelIds,
  }) {
    return _mutateSelectedEncounter(
      () => _repository.updateLabOrder(labOrderId, <String, Object?>{
        'requested_tests': <Map<String, Object?>>[
          for (final String id in labTestIds)
            <String, Object?>{'lab_test_id': id},
        ],
        'requested_panels': <Map<String, Object?>>[
          for (final String id in labPanelIds)
            <String, Object?>{'lab_panel_id': id},
        ],
      }),
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
  }) {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null || entry.apiPatientId == null || requests.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(
      () => _repository.createRadiologyOrder(<String, Object?>{
        'encounter_id': entry.encounterId,
        'patient_id': entry.apiPatientId,
        'ordered_at': DateTime.now().toUtc().toIso8601String(),
        'requested_tests': <Map<String, Object?>>[
          for (final ClinicalRadiologyRequest request in requests)
            <String, Object?>{
              'radiology_test_id': request.radiologyTestId,
              'clinical_note': request.clinicalNote,
              'request_details': <String, Object?>{
                'body_region': request.bodyRegion,
                'laterality': request.laterality,
                'priority': request.priority,
              },
            },
        ],
      }),
    );
  }

  Future<AppFailure?> prescribe({
    required List<Map<String, Object?>> items,
  }) {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    if (entry == null || entry.apiPatientId == null || items.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(
      () => _repository.createPharmacyOrder(<String, Object?>{
        'encounter_id': entry.encounterId,
        'patient_id': entry.apiPatientId,
        'ordered_at': DateTime.now().toUtc().toIso8601String(),
        'items': items,
      }),
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
        'encounter_id': _selectedEntry!.encounterId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'SCHEDULED',
        'notes': notes,
      }),
    );
  }

  Future<AppFailure?> requestAdmission(ClinicalCatalogOption bed) {
    final ClinicalWorklistEntry? entry = _selectedEntry;
    final String bedStatus = (bed.status ?? 'AVAILABLE').trim().toUpperCase();
    if (entry == null ||
        entry.tenantId == null ||
        entry.patientId == null ||
        bed.parentId == null ||
        bed.secondaryId == null ||
        (bedStatus.isNotEmpty && bedStatus != 'AVAILABLE')) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelectedEncounter(
      () => _repository.createAdmission(<String, Object?>{
        'tenant_id': entry.tenantId,
        'facility_id': entry.facilityId,
        'patient_id': entry.apiPatientId,
        'encounter_id': entry.apiEncounterId,
        'ward_id': bed.parentId,
        'room_id': bed.secondaryId,
        'bed_id': bed.apiId,
        'admitted_at': DateTime.now().toUtc().toIso8601String(),
      }),
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
    if (opdFlowApiId != null) {
      return _mutateSelectedEncounter(
        () async {
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
        },
        removeSelectedOnSuccess: true,
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

  Future<Result<ClinicalWorkspaceState>> _loadInitialState() async {
    const ClinicalWorklistQuery query = ClinicalWorklistQuery();
    final Result<AppPage<ClinicalWorklistEntry>> worklistResult =
        await _loadWorklist(query);
    final AppPage<ClinicalWorklistEntry>? worklist = _successOrNull(
      worklistResult,
    );
    if (worklist == null) {
      return Result<ClinicalWorkspaceState>.failure(
        _failureOrNull(worklistResult)!,
      );
    }

    final ClinicalReferenceData referenceData = await _referenceData();

    return Result<ClinicalWorkspaceState>.success(
      ClinicalWorkspaceState(
        query: query,
        worklist: worklist,
        referenceData: referenceData,
      ),
    );
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
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
  }) async {
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingDetail: current.selectedBundle != null,
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
        final ClinicalReferenceData referenceData = await _referenceData();
        final ClinicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(referenceData: referenceData));
        }
      }

      final ClinicalWorklistEntry? selected = _selectedEntry;
      if (selected != null) {
        await _refreshSelectedEntry(selected, showLoading: showLoading);
      }

      return null;
    } finally {
      final ClinicalWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshWorklist({required bool showLoading}) async {
    final ClinicalWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    final Result<AppPage<ClinicalWorklistEntry>> result = await _loadWorklist(
      current.query,
    );
    return result.when(
      success: (AppPage<ClinicalWorklistEntry> page) {
        final ClinicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              worklist: page,
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

  Future<Result<AppPage<ClinicalWorklistEntry>>> _loadWorklist(
    ClinicalWorklistQuery query,
  ) async {
    final results =
        await Future.wait(<Future<Result<AppPage<ClinicalWorklistEntry>>>>[
          _repository.listEncounters(query),
          _repository.listAdmissions(query),
          _opdFlows(query),
          _triageFlows(query),
        ]);

    final AppFailure? failure = _firstFailure(results);
    if (failure != null) {
      return Result<AppPage<ClinicalWorklistEntry>>.failure(failure);
    }

    final List<ClinicalWorklistEntry> items =
        <ClinicalWorklistEntry>[
              for (final Result<AppPage<ClinicalWorklistEntry>> result
                  in results)
                ..._successOrEmpty(result).items,
            ]
            .where((ClinicalWorklistEntry item) {
              return item.matchesSearch(query.search, filters: query.filters) &&
                  item.matchesFilters(query.filters) &&
                  clinicalWorklistEntryMatchesScope(item, query.scope);
            })
            .toList(growable: false);

    final List<ClinicalWorklistEntry> sorted = items.toList(growable: true)
      ..sort(_compareEntries);
    final int start = query.pageRequest.pageIndex * query.pageRequest.pageSize;
    final List<ClinicalWorklistEntry> paged = start >= sorted.length
        ? const <ClinicalWorklistEntry>[]
        : sorted
              .skip(start)
              .take(query.pageRequest.pageSize)
              .toList(growable: false);

    return Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: paged,
        request: query.pageRequest,
        totalItemCount: sorted.length,
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
      status: item.status,
      stage: item.stage,
      nextStep: item.nextStep,
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
          (item.stage ?? '').toUpperCase().contains('RESULT') ||
          (item.nextStep ?? '').toUpperCase().contains('RESULT'),
    );
  }

  Future<ClinicalEncounterBundle> _withTriageHandoff(
    ClinicalEncounterBundle bundle,
  ) async {
    final String? opdFlowApiId = bundle.entry.opdFlowApiId;
    if (opdFlowApiId == null || opdFlowApiId.trim().isEmpty) {
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
    final Iterable<ClinicalAlertSummary> activeAlerts = alerts.where(
      (ClinicalAlertSummary alert) =>
          alert.vitalSignId == vital.id &&
          (alert.status ?? '').toUpperCase() != 'RESOLVED',
    );
    if (activeAlerts.any(
      (ClinicalAlertSummary alert) =>
          (alert.severity ?? '').toUpperCase() == 'CRITICAL',
    )) {
      return 'CRITICAL';
    }
    if (activeAlerts.isNotEmpty) {
      return 'ABNORMAL';
    }
    return 'RECORDED';
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
            final ClinicalWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(latest.copyWith(isSaving: false, lastFailure: failure));
            }
            return failure;
          },
        );
      },
      failure: (AppFailure failure) async {
        final ClinicalWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
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

  AppPage<ClinicalWorklistEntry> _successOrEmpty(
    Result<AppPage<ClinicalWorklistEntry>> result,
  ) {
    return result.when(
      success: (AppPage<ClinicalWorklistEntry> page) => page,
      failure: (_) => AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request: _currentState?.query.pageRequest ?? const AppPageRequest(),
      ),
    );
  }

  T? _successOrNull<T>(Result<T> result) {
    return result.when(success: (T value) => value, failure: (_) => null);
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

  String _dispositionReviewNote({required String reason, required String notes}) {
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
    final Result<ClinicalWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<ClinicalWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(ClinicalWorkspaceState nextState) {
    state = AsyncData<Result<ClinicalWorkspaceState>>(
      Result<ClinicalWorkspaceState>.success(nextState),
    );
  }
}
