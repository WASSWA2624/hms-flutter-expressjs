import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/nursing/data/repositories/nursing_repository_impl.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final nursingWorkspaceControllerProvider =
    AsyncNotifierProvider<
      NursingWorkspaceController,
      Result<NursingWorkspaceState>
    >(NursingWorkspaceController.new);

final class NursingWorkspaceController
    extends AsyncNotifier<Result<NursingWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 10);
  static const Duration _optionalContextTimeout = Duration(seconds: 4);
  static const AppPageRequest _fetchRequest = AppPageRequest(pageSize: 100);

  NursingRepository get _repository => ref.read(nursingRepositoryProvider);
  PatientRepository get _patientRepository => ref.read(patientRepositoryProvider);
  ClinicalRepository get _clinicalRepository => ref.read(clinicalRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<NursingWorkspaceState>> build() async {
    ref.onDispose(() => _syncTimer?.cancel());
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.nursing,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<NursingWorkspaceState> result = await _loadInitialState();
    _startSync();
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData(refreshContext: true);
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshContext: true);
  }

  Future<AppFailure?> applySearch(String value) {
    final NursingWorkspaceState? current = _currentState;
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
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> applyScope(NursingQueueScope scope) {
    final NursingWorkspaceState? current = _currentState;
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

  Future<AppFailure?> applyWard(String ward) {
    final NursingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          ward: ward.trim(),
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> applyAdvancedFilters({
    String? searchField,
    NursingQueueScope? scope,
    String? patient,
    String? admission,
    String? encounter,
    String? ward,
    String? room,
    String? bed,
    String? observation,
    String? taskType,
    String? unit,
    String? shift,
    String? assignedNurse,
    String? careTask,
    String? status,
    String? priority,
    String? admissionStatus,
    String? transferStatus,
    String? handoverStatus,
    String? dischargeStatus,
    String? dischargeReadiness,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final NursingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }
    _emit(
      current.copyWith(
        query: current.query.copyWith(
          searchField: searchField?.trim() ?? '',
          scope: scope ?? NursingQueueScope.all,
          patient: patient?.trim() ?? '',
          admission: admission?.trim() ?? '',
          encounter: encounter?.trim() ?? '',
          ward: ward?.trim() ?? '',
          room: room?.trim() ?? '',
          bed: bed?.trim() ?? '',
          observation: observation?.trim() ?? '',
          taskType: taskType?.trim() ?? '',
          unit: unit?.trim() ?? '',
          shift: shift?.trim() ?? '',
          assignedNurse: assignedNurse?.trim() ?? '',
          careTask: careTask?.trim() ?? '',
          status: status?.trim() ?? '',
          priority: priority?.trim() ?? '',
          admissionStatus: admissionStatus?.trim() ?? '',
          transferStatus: transferStatus?.trim() ?? '',
          handoverStatus: handoverStatus?.trim() ?? '',
          dischargeStatus: dischargeStatus?.trim() ?? '',
          dischargeReadiness: dischargeReadiness?.trim() ?? '',
          dateFrom: dateFrom,
          dateTo: dateTo,
          clearDateFrom: dateFrom == null,
          clearDateTo: dateTo == null,
          pageRequest: current.query.pageRequest.first(),
        ),
        isRefreshing: true,
        clearLastFailure: true,
      ),
    );
    return _refreshWorklist(showLoading: true);
  }

  Future<AppFailure?> changePage(AppPageRequest request) {
    final NursingWorkspaceState? current = _currentState;
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


  Future<List<NursingUserOption>> searchUsers(String query) async {
    final Result<List<NursingUserOption>> result = await _repository.searchUsers(
      query,
    );
    return result.when(
      success: (List<NursingUserOption> value) => value,
      failure: (_) => const <NursingUserOption>[],
    );
  }

  Future<Result<AppPage<NursingPatientSummary>>> previewPatientsForScope(
    NursingQueueScope scope,
  ) {
    final NursingWorkspaceState? current = _currentState;
    if (current == null) {
      return Future<Result<AppPage<NursingPatientSummary>>>.value(
        Result<AppPage<NursingPatientSummary>>.failure(AppFailure.validation()),
      );
    }
    final NursingWorklistQuery query = current.query.copyWith(
      scope: scope,
      search: '',
      pageRequest: const AppPageRequest(pageSize: 100),
    );
    return _loadWorklist(query, current.pendingHandovers);
  }

  Future<AppFailure?> selectPatient(NursingPatientSummary summary) async {
    final NursingWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<NursingPatientDetail> result = await _repository
        .loadPatientDetail(summary);
    return result.when(
      success: (NursingPatientDetail detail) {
        final NursingWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedDetail: detail,
              worklist: _replaceSummary(
                latest.worklist,
                detail.enrichedSummary,
              ),
              isRefreshingDetail: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final NursingWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(isRefreshingDetail: false, lastFailure: failure),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> recordVitals({
    required String vitalType,
    String? value,
    String? unit,
    num? systolicValue,
    num? diastolicValue,
    num? mapValue,
    DateTime? recordedAt,
  }) {
    final NursingPatientDetail? detail = _selectedDetail;
    if (detail == null || detail.summary.encounterDisplayId == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected(
      (NursingPatientSummary summary) =>
          _repository.recordVitals(summary, <String, Object?>{
            'encounter_id': detail.summary.encounterDisplayId,
            'vital_type': vitalType,
            'value': value,
            'unit': unit,
            'systolic_value': systolicValue,
            'diastolic_value': diastolicValue,
            'map_value': mapValue,
            'recorded_at': (recordedAt ?? DateTime.now())
                .toUtc()
                .toIso8601String(),
          }),
    );
  }

  Future<AppFailure?> recordVitalSet(List<Map<String, Object?>> payloads) {
    final NursingPatientDetail? detail = _selectedDetail;
    if (detail == null || detail.summary.encounterDisplayId == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }
    if (payloads.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    final List<Map<String, Object?>> normalized = payloads
        .map(
          (Map<String, Object?> payload) => <String, Object?>{
            'encounter_id': detail.summary.encounterDisplayId,
            ...payload,
          },
        )
        .toList(growable: false);

    return _mutateSelected(
      (NursingPatientSummary summary) =>
          _repository.recordVitalSet(summary, normalized),
    );
  }

  Future<AppFailure?> addNursingNote(String note) {
    final String? currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }
    return _mutateSelected(
      (NursingPatientSummary summary) => _repository.addNursingNote(
        summary,
        <String, Object?>{'nurse_user_id': currentUserId, 'note': note},
      ),
    );
  }

  Future<AppFailure?> completeTask({required String task, String? notes}) {
    final NursingPatientDetail? detail = _selectedDetail;
    if (detail == null || detail.summary.encounterDisplayId == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }
    final String combinedPlan = <String>[
      'Task completed: ${task.trim()}',
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
    ].join(' - ');
    return _mutateSelected(
      (NursingPatientSummary summary) =>
          _repository.addCarePlan(summary, <String, Object?>{
            'encounter_id': detail.summary.encounterDisplayId,
            'plan': combinedPlan,
            'start_date': DateTime.now().toUtc().toIso8601String(),
          }),
    );
  }

  Future<AppFailure?> addMedicationAdministration(
    Map<String, Object?> payload,
  ) {
    return _mutateSelected(
      (NursingPatientSummary summary) =>
          _repository.addMedicationAdministration(summary, payload),
    );
  }

  Future<ClinicalReferenceData> prescriptionReferenceData() async {
    final Result<ClinicalReferenceData> result = await _clinicalRepository
        .loadReferenceData();
    return result.when(
      success: (ClinicalReferenceData value) => value,
      failure: (_) => const ClinicalReferenceData(),
    );
  }

  Future<AppFailure?> prescribeMedication({
    required List<Map<String, Object?>> items,
  }) {
    final NursingPatientDetail? detail = _selectedDetail;
    final String? encounterId = detail?.summary.encounterDisplayId?.trim();
    final String? patientId = detail?.summary.patientId?.trim();
    if (detail == null ||
        encounterId == null ||
        encounterId.isEmpty ||
        patientId == null ||
        patientId.isEmpty ||
        items.isEmpty) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected((NursingPatientSummary summary) async {
      final Result<void> result = await _clinicalRepository
          .createPharmacyOrder(<String, Object?>{
            'encounter_id': encounterId,
            'patient_id': patientId,
            'ordered_at': DateTime.now().toUtc().toIso8601String(),
            'items': items,
          });
      return result.when<Future<Result<NursingPatientDetail>>>(
        success: (_) => _repository.loadPatientDetail(summary),
        failure: (AppFailure failure) async =>
            Result<NursingPatientDetail>.failure(failure),
      );
    });
  }

  Future<AppFailure?> createHandover({
    required String toUserId,
    required String notes,
    String? reason,
    List<PatientDocumentUploadFile> documentFiles =
        const <PatientDocumentUploadFile>[],
  }) {
    final NursingPatientDetail? detail = _selectedDetail;
    if (detail == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected((NursingPatientSummary summary) async {
      final Result<List<Map<String, Object?>>> documentsResult =
          await _uploadHandoverDocuments(detail, documentFiles);
      return documentsResult.when<Future<Result<NursingPatientDetail>>>(
        success: (List<Map<String, Object?>> documents) {
          return _repository.createHandover(summary, <String, Object?>{
            'to_user_id': toUserId,
            'signoff_notes': notes,
            'items_json': <String, Object?>{
              'type': reason ?? 'NURSING_HANDOVER',
              'admission_id': summary.admissionId,
              'patient_id': summary.patientDisplayId,
              'patient_name': summary.patientDisplayName,
              'location': summary.locationLabel,
              'stage': summary.stage,
              if (documents.isNotEmpty) 'documents': documents,
            },
          });
        },
        failure: (AppFailure failure) async {
          return Result<NursingPatientDetail>.failure(failure);
        },
      );
    });
  }

  Future<AppFailure?> escalate({
    required String toUserId,
    required String message,
  }) {
    return createHandover(
      toUserId: toUserId,
      notes: message,
      reason: 'CLINICAL_ESCALATION',
    );
  }

  Future<Result<List<Map<String, Object?>>>> _uploadHandoverDocuments(
    NursingPatientDetail detail,
    List<PatientDocumentUploadFile> files,
  ) async {
    if (files.isEmpty) {
      return const Result<List<Map<String, Object?>>>.success(
        <Map<String, Object?>>[],
      );
    }
    final String? patientId = detail.summary.patientId?.trim();
    if (patientId == null || patientId.isEmpty) {
      return Result<List<Map<String, Object?>>>.failure(
        AppFailure.validation(validationFields: const <String>{'patient_id'}),
      );
    }

    final Map<bool, List<PatientDocumentUploadFile>> groupedFiles =
        <bool, List<PatientDocumentUploadFile>>{
          true: <PatientDocumentUploadFile>[],
          false: <PatientDocumentUploadFile>[],
        };
    for (final PatientDocumentUploadFile file in files) {
      groupedFiles[_isScannedUploadFile(file)]!.add(file);
    }

    final List<Map<String, Object?>> uploadedDocuments =
        <Map<String, Object?>>[];
    for (final MapEntry<bool, List<PatientDocumentUploadFile>> entry
        in groupedFiles.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      final String documentType = entry.key
          ? 'SCANNED_HANDOVER_DOCUMENT'
          : 'HANDOVER_DOCUMENT';
      final Result<List<PatientDocument>> uploadResult = await _patientRepository
          .uploadPatientDocuments(
            patientId: patientId,
            documentType: documentType,
            files: entry.value,
          );
      final AppFailure? failure = uploadResult.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      if (failure != null) {
        return Result<List<Map<String, Object?>>>.failure(failure);
      }

      final List<PatientDocument> documents = uploadResult.when(
        success: (List<PatientDocument> value) => value,
        failure: (_) => const <PatientDocument>[],
      );
      uploadedDocuments.addAll(
        documents.map(
          (PatientDocument document) => <String, Object?>{
            'document_id': document.id,
            'document_type': document.documentType,
            'storage_key': document.storageKey,
            'file_name': document.fileName,
            'content_type': document.contentType,
            'is_scanned': entry.key,
          },
        ),
      );
    }

    return Result<List<Map<String, Object?>>>.success(uploadedDocuments);
  }

  bool _isScannedUploadFile(PatientDocumentUploadFile file) {
    final String name = file.name.toLowerCase();
    final String contentType = file.contentType?.toLowerCase() ?? '';
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        contentType.startsWith('image/');
  }

  Future<AppFailure?> acceptHandover(
    NursingHandover handover,
    String? notes,
  ) async {
    final Result<void> result = await _repository.acceptHandover(
      handover.id,
      <String, Object?>{'accepted_notes': notes},
    );
    return result.when(
      success: (_) => _syncVisibleData(showLoading: true, refreshContext: true),
      failure: (AppFailure failure) {
        final NursingWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> updateTransfer({
    required String action,
    String? toBedId,
  }) {
    final NursingPatientDetail? detail = _selectedDetail;
    if (detail == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected(
      (NursingPatientSummary summary) =>
          _repository.updateTransfer(summary, <String, Object?>{
            'transfer_request_id': detail.activeTransfer?.id,
            'action': action,
            'to_bed_id': toBedId,
          }),
    );
  }

  Future<Result<NursingWorkspaceState>> _loadInitialState() async {
    const NursingWorklistQuery query = NursingWorklistQuery();
    final Future<List<NursingHandover>> handoversFuture =
        _safePendingHandovers();
    final Future<List<NursingRosterAssignment>> rostersFuture =
        _safeCurrentRosters();
    final Result<AppPage<NursingPatientSummary>> worklistResult =
        await _loadWorklist(query, const <NursingHandover>[]);

    return worklistResult.when(
      success: (AppPage<NursingPatientSummary> worklist) async {
        final List<NursingHandover> handovers = await handoversFuture;
        final List<NursingRosterAssignment> rosters = await rostersFuture;
        return Result<NursingWorkspaceState>.success(
          NursingWorkspaceState(
            query: query,
            worklist: _applyPendingHandovers(worklist, handovers, query),
            pendingHandovers: handovers,
            rosters: rosters,
          ),
        );
      },
      failure: (AppFailure failure) {
        return Result<NursingWorkspaceState>.failure(failure);
      },
    );
  }

  void _startSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData(refreshContext: true));
    });
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshContext = false,
  }) async {
    final NursingWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshing: true,
          isRefreshingDetail: current.selectedDetail != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final List<NursingHandover> handovers = refreshContext
          ? await _safePendingHandovers()
          : current.pendingHandovers;
      final List<NursingRosterAssignment> rosters = refreshContext
          ? await _safeCurrentRosters()
          : current.rosters;
      final AppFailure? failure = await _refreshWorklist(
        showLoading: showLoading,
        handovers: handovers,
        rosters: rosters,
      );
      if (failure != null) {
        return failure;
      }

      final NursingPatientDetail? selected = _currentState?.selectedDetail;
      if (selected != null) {
        await selectPatient(selected.enrichedSummary);
      }

      return null;
    } finally {
      final NursingWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(latest.copyWith(isRefreshing: false, isRefreshingDetail: false));
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshWorklist({
    required bool showLoading,
    List<NursingHandover>? handovers,
    List<NursingRosterAssignment>? rosters,
  }) async {
    final NursingWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    final List<NursingHandover> effectiveHandovers =
        handovers ?? current.pendingHandovers;
    final Result<AppPage<NursingPatientSummary>> result = await _loadWorklist(
      current.query,
      effectiveHandovers,
    );

    return result.when(
      success: (AppPage<NursingPatientSummary> worklist) {
        final NursingWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              worklist: worklist,
              pendingHandovers: effectiveHandovers,
              rosters: rosters ?? latest.rosters,
              isRefreshing: showLoading ? false : latest.isRefreshing,
              clearLastFailure: true,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final NursingWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isRefreshing: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  Future<Result<AppPage<NursingPatientSummary>>> _loadWorklist(
    NursingWorklistQuery query,
    List<NursingHandover> handovers,
  ) async {
    final NursingWorklistQuery fetchQuery = query.copyWith(
      pageRequest: _fetchRequest,
    );
    final Result<AppPage<NursingPatientSummary>> result = await _repository
        .listWardPatients(fetchQuery);

    return result.map((AppPage<NursingPatientSummary> source) {
      final List<NursingPatientSummary> filtered = source.items
          .map((NursingPatientSummary item) {
            final int handoverCount = handovers
                .where(
                  (NursingHandover handover) =>
                      handover.isPending &&
                      handover.admissionId != null &&
                      handover.admissionId == item.admissionId,
                )
                .length;
            return item.copyWith(pendingHandoverCount: handoverCount);
          })
          .where(
            (NursingPatientSummary item) => item.matchesWorklistQuery(query),
          )
          .toList(growable: true);

      filtered.sort(_compareSummaries);
      final int start = query.pageRequest.offset;
      final List<NursingPatientSummary> items = start >= filtered.length
          ? const <NursingPatientSummary>[]
          : filtered
                .skip(start)
                .take(query.pageRequest.pageSize)
                .toList(growable: false);

      return AppPage<NursingPatientSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: filtered.length,
      );
    });
  }

  Future<List<NursingHandover>> _pendingHandovers() async {
    final Result<List<NursingHandover>> result = await _repository
        .listPendingHandovers();
    return result.when(
      success: (List<NursingHandover> value) => value,
      failure: (_) => const <NursingHandover>[],
    );
  }

  Future<List<NursingRosterAssignment>> _currentRosters() async {
    final Result<List<NursingRosterAssignment>> result = await _repository
        .listCurrentRosters();
    return result.when(
      success: (List<NursingRosterAssignment> value) => value,
      failure: (_) => const <NursingRosterAssignment>[],
    );
  }

  Future<List<NursingHandover>> _safePendingHandovers() {
    if (!_canReadOperationsContext) {
      return Future<List<NursingHandover>>.value(const <NursingHandover>[]);
    }
    return _optionalList(_pendingHandovers());
  }

  Future<List<NursingRosterAssignment>> _safeCurrentRosters() {
    if (!_canReadOperationsContext) {
      return Future<List<NursingRosterAssignment>>.value(
        const <NursingRosterAssignment>[],
      );
    }
    return _optionalList(_currentRosters());
  }

  Future<List<T>> _optionalList<T>(Future<List<T>> future) {
    return future
        .timeout(_optionalContextTimeout, onTimeout: () => <T>[])
        .catchError((_) => <T>[]);
  }

  AppPage<NursingPatientSummary> _applyPendingHandovers(
    AppPage<NursingPatientSummary> page,
    List<NursingHandover> handovers,
    NursingWorklistQuery query,
  ) {
    if (handovers.isEmpty) {
      return page;
    }

    final List<NursingPatientSummary> filtered = page.items
        .map((NursingPatientSummary item) {
          final int handoverCount = handovers
              .where(
                (NursingHandover handover) =>
                    handover.isPending &&
                    handover.admissionId != null &&
                    handover.admissionId == item.admissionId,
              )
              .length;
          return item.copyWith(pendingHandoverCount: handoverCount);
        })
        .where((NursingPatientSummary item) => item.matchesWorklistQuery(query))
        .toList(growable: false);

    return AppPage<NursingPatientSummary>(
      items: filtered,
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  Future<AppFailure?> _mutateSelected(
    Future<Result<NursingPatientDetail>> Function(NursingPatientSummary summary)
    action,
  ) async {
    final NursingPatientDetail? detail = _selectedDetail;
    final NursingWorkspaceState? current = _currentState;
    if (detail == null || current == null) {
      return AppFailure.validation();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<NursingPatientDetail> result = await action(
      detail.enrichedSummary,
    );
    return result.when(
      success: (NursingPatientDetail updated) async {
        final NursingWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              selectedDetail: updated,
              worklist: _replaceSummary(
                latest.worklist,
                updated.enrichedSummary,
              ),
              isSaving: false,
            ),
          );
        }
        unawaited(_syncVisibleData(refreshContext: true));
        return null;
      },
      failure: (AppFailure failure) {
        final NursingWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        return failure;
      },
    );
  }

  AppPage<NursingPatientSummary> _replaceSummary(
    AppPage<NursingPatientSummary> page,
    NursingPatientSummary summary,
  ) {
    var replaced = false;
    final List<NursingPatientSummary> items = <NursingPatientSummary>[];
    for (final NursingPatientSummary item in page.items) {
      if (item.admissionId == summary.admissionId) {
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

    return AppPage<NursingPatientSummary>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  int _compareSummaries(
    NursingPatientSummary left,
    NursingPatientSummary right,
  ) {
    if (left.isUrgent != right.isUrgent) {
      return left.isUrgent ? -1 : 1;
    }
    if (left.hasMedicationDue != right.hasMedicationDue) {
      return left.hasMedicationDue ? -1 : 1;
    }
    final DateTime leftDate =
        left.lastObservationAt ??
        left.admittedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime rightDate =
        right.lastObservationAt ??
        right.admittedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return rightDate.compareTo(leftDate);
  }

  String? get _currentUserId {
    final String? id = ref.read(sessionStateProvider).session?.user?.id;
    return id == null || id.trim().isEmpty ? null : id;
  }

  bool get _canReadOperationsContext {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.hasActiveModule('hr-rosters') &&
        policy.grantsAny(const <AppPermission>[
          AppPermissions.hrRead,
          AppPermissions.operationsRead,
          AppPermissions.rosterRead,
          AppPermissions.unitRead,
        ]);
  }

  NursingPatientDetail? get _selectedDetail => _currentState?.selectedDetail;

  NursingWorkspaceState? get _currentState {
    final Result<NursingWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<NursingWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(NursingWorkspaceState nextState) {
    state = AsyncData<Result<NursingWorkspaceState>>(
      Result<NursingWorkspaceState>.success(nextState),
    );
  }
}
