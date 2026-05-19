import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/nursing/data/repositories/nursing_repository_impl.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final nursingWorkspaceControllerProvider =
    AsyncNotifierProvider<
      NursingWorkspaceController,
      Result<NursingWorkspaceState>
    >(NursingWorkspaceController.new);

final class NursingWorkspaceController
    extends AsyncNotifier<Result<NursingWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 10);
  static const AppPageRequest _fetchRequest = AppPageRequest(pageSize: 100);

  NursingRepository get _repository => ref.read(nursingRepositoryProvider);

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
    await _syncVisibleData();
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

  Future<AppFailure?> addNursingNote(String note) {
    return _mutateSelected(
      (NursingPatientSummary summary) => _repository.addNursingNote(
        summary,
        <String, Object?>{'nurse_user_id': _currentUserId, 'note': note},
      ),
    );
  }

  Future<AppFailure?> completeTask({required String task, String? notes}) {
    final String combinedNote = <String>[
      '[TASK COMPLETED] ${task.trim()}',
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
    ].join(' - ');
    return addNursingNote(combinedNote);
  }

  Future<AppFailure?> addMedicationAdministration(
    Map<String, Object?> payload,
  ) {
    return _mutateSelected(
      (NursingPatientSummary summary) =>
          _repository.addMedicationAdministration(summary, payload),
    );
  }

  Future<AppFailure?> createHandover({
    required String toUserId,
    required String notes,
    String? reason,
  }) {
    final NursingPatientDetail? detail = _selectedDetail;
    if (detail == null) {
      return Future<AppFailure?>.value(AppFailure.validation());
    }

    return _mutateSelected(
      (NursingPatientSummary summary) =>
          _repository.createHandover(summary, <String, Object?>{
            'to_user_id': toUserId,
            'signoff_notes': notes,
            'items_json': <String, Object?>{
              'type': reason ?? 'NURSING_HANDOVER',
              'admission_id': summary.admissionId,
              'patient_id': summary.patientDisplayId,
              'patient_name': summary.patientDisplayName,
              'location': summary.locationLabel,
              'stage': summary.stage,
            },
          }),
    );
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
    final List<NursingHandover> handovers = await _pendingHandovers();
    final List<NursingRosterAssignment> rosters = await _currentRosters();
    final Result<AppPage<NursingPatientSummary>> worklistResult =
        await _loadWorklist(query, handovers);

    return worklistResult.when(
      success: (AppPage<NursingPatientSummary> worklist) {
        return Result<NursingWorkspaceState>.success(
          NursingWorkspaceState(
            query: query,
            worklist: worklist,
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
      unawaited(_syncVisibleData());
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
          ? await _pendingHandovers()
          : current.pendingHandovers;
      final List<NursingRosterAssignment> rosters = refreshContext
          ? await _currentRosters()
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
            (NursingPatientSummary item) =>
                item.matchesSearch(query.search) &&
                item.matchesWard(query.ward) &&
                item.matchesScope(query.scope),
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
        unawaited(_refreshWorklist(showLoading: false));
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
