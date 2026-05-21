import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/shared/data/data.dart';

final opdWorkspaceControllerProvider =
    AsyncNotifierProvider<OpdWorkspaceController, Result<OpdWorkspaceState>>(
      OpdWorkspaceController.new,
    );

final class OpdWorkspaceController
    extends AsyncNotifier<Result<OpdWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 6);

  OpdRepository get _repository => ref.read(opdRepositoryProvider);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  Future<Result<OpdWorkspaceState>> build() async {
    ref.onDispose(() {
      _syncTimer?.cancel();
    });
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.opd,
      onRefresh: (_) => _syncFromRealtime(),
    );
    final Result<OpdWorkspaceState> result = await _loadInitialState();
    _startVisibleDataSync();
    return result;
  }

  Future<void> _syncFromRealtime() async {
    await _syncVisibleData();
  }

  Future<AppFailure?> refresh() {
    return _syncVisibleData(showLoading: true, refreshProviders: true);
  }

  Future<AppFailure?> applySearch(String value) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    final String search = value.trim();
    _emit(
      current.copyWith(
        appointmentQuery: current.appointmentQuery.copyWith(
          search: search,
          pageRequest: current.appointmentQuery.pageRequest.first(),
        ),
        queueQuery: current.queueQuery.copyWith(
          search: search,
          pageRequest: current.queueQuery.pageRequest.first(),
        ),
        flowQuery: current.flowQuery.copyWith(
          search: search,
          pageRequest: current.flowQuery.pageRequest.first(),
        ),
        triageQueueQuery: current.triageQueueQuery.copyWith(
          search: search,
          pageRequest: current.triageQueueQuery.pageRequest.first(),
        ),
        isRefreshingAppointments: true,
        isRefreshingQueue: true,
        isRefreshingFlows: true,
        isRefreshingTriageQueue: true,
        clearLastFailure: true,
      ),
    );

    return _refreshVisiblePages(showLoading: true);
  }

  Future<AppFailure?> applyAppointmentStatus(String? status) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        appointmentQuery: current.appointmentQuery.copyWith(
          status: status,
          clearStatus: status == null,
          pageRequest: current.appointmentQuery.pageRequest.first(),
        ),
        isRefreshingAppointments: true,
        clearLastFailure: true,
      ),
    );

    final Result<AppPage<OpdAppointment>> result = await _repository
        .listAppointments(_currentState!.appointmentQuery);
    return result.when(
      success: (AppPage<OpdAppointment> page) {
        _emit(
          _currentState!.copyWith(
            appointments: page,
            isRefreshingAppointments: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshingAppointments: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> applyQueueStatus(String? status) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        queueQuery: current.queueQuery.copyWith(
          status: status,
          clearStatus: status == null,
          pageRequest: current.queueQuery.pageRequest.first(),
        ),
        isRefreshingQueue: true,
        clearLastFailure: true,
      ),
    );

    final Result<AppPage<OpdQueueEntry>> result = await _repository
        .listVisitQueues(_currentState!.queueQuery);
    return result.when(
      success: (AppPage<OpdQueueEntry> page) {
        _emit(
          _currentState!.copyWith(queueEntries: page, isRefreshingQueue: false),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshingQueue: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> applyFlowStage(String? stage) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        flowQuery: current.flowQuery.copyWith(
          stage: stage,
          clearStage: stage == null,
          pageRequest: current.flowQuery.pageRequest.first(),
        ),
        isRefreshingFlows: true,
        clearLastFailure: true,
      ),
    );

    final Result<AppPage<OpdFlowSummary>> result = await _repository
        .listOpdFlows(_currentState!.flowQuery);
    return result.when(
      success: (AppPage<OpdFlowSummary> page) {
        _emit(_currentState!.copyWith(flows: page, isRefreshingFlows: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshingFlows: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> changeAppointmentPage(AppPageRequest request) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        appointmentQuery: current.appointmentQuery.copyWith(
          pageRequest: request,
        ),
        isRefreshingAppointments: true,
        clearLastFailure: true,
      ),
    );
    final Result<AppPage<OpdAppointment>> result = await _repository
        .listAppointments(_currentState!.appointmentQuery);
    return result.when(
      success: (AppPage<OpdAppointment> page) {
        _emit(
          _currentState!.copyWith(
            appointments: page,
            isRefreshingAppointments: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshingAppointments: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> changeQueuePage(AppPageRequest request) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        queueQuery: current.queueQuery.copyWith(pageRequest: request),
        isRefreshingQueue: true,
        clearLastFailure: true,
      ),
    );
    final Result<AppPage<OpdQueueEntry>> result = await _repository
        .listVisitQueues(_currentState!.queueQuery);
    return result.when(
      success: (AppPage<OpdQueueEntry> page) {
        _emit(
          _currentState!.copyWith(queueEntries: page, isRefreshingQueue: false),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshingQueue: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> changeFlowPage(AppPageRequest request) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(
      current.copyWith(
        flowQuery: current.flowQuery.copyWith(pageRequest: request),
        isRefreshingFlows: true,
        clearLastFailure: true,
      ),
    );
    final Result<AppPage<OpdFlowSummary>> result = await _repository
        .listOpdFlows(_currentState!.flowQuery);
    return result.when(
      success: (AppPage<OpdFlowSummary> page) {
        _emit(_currentState!.copyWith(flows: page, isRefreshingFlows: false));
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            isRefreshingFlows: false,
            lastFailure: failure,
          ),
        );
        return failure;
      },
    );
  }

  Future<AppFailure?> selectFlow(OpdFlowSummary flow) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isRefreshingDetail: true, clearLastFailure: true));
    final Result<OpdFlowDetail> result = await _repository.getOpdFlow(
      flow.apiId,
    );
    return result.when(
      success: (OpdFlowDetail detail) {
        _emit(
          _currentState!.copyWith(
            selectedFlow: detail,
            flows: _replaceFlow(_currentState!.flows, detail.summary),
            triageQueue: _upsertOrRemoveTriageFlow(
              _currentState!.triageQueue,
              detail.summary,
            ),
            isRefreshingDetail: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(
          _currentState!.copyWith(
            lastFailure: failure,
            isRefreshingDetail: false,
          ),
        );
        return failure;
      },
    );
  }

  void clearSelection() {
    final OpdWorkspaceState? current = _currentState;
    if (current != null) {
      _emit(current.copyWith(clearSelectedFlow: true));
    }
  }

  Future<AppFailure?> startOpdEncounter(Map<String, Object?> payload) {
    final Object? existingEncounterId = payload['existing_encounter_id'];
    if (existingEncounterId is String &&
        existingEncounterId.trim().isNotEmpty) {
      return _mutateFlow(
        () => _repository.getOpdFlow(existingEncounterId.trim()),
        refreshAfter: true,
      );
    }

    return _mutateFlow(
      () => _repository.startOpdFlow(<String, Object?>{
        'arrival_mode': 'WALK_IN',
        'queued_at': DateTime.now().toUtc().toIso8601String(),
        ...payload,
      }),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> startWalkIn(Map<String, Object?> payload) {
    return startOpdEncounter(payload);
  }

  Future<AppFailure?> checkInAppointment(OpdAppointment appointment) {
    return _mutateFlow(
      () => _repository.startOpdFlow(<String, Object?>{
        'arrival_mode': 'ONLINE_APPOINTMENT',
        'appointment_id': appointment.apiId,
        'facility_id': appointment.facilityId,
        'provider_user_id': appointment.providerUserId,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      }),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> rescheduleAppointment(
    OpdAppointment appointment,
    DateTime scheduledStart,
    DateTime scheduledEnd,
  ) {
    return _mutateAppointment(
      () => _repository.updateAppointment(appointment.apiId, <String, Object?>{
        'scheduled_start': scheduledStart.toUtc().toIso8601String(),
        'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
        'status': appointment.status == 'CANCELLED'
            ? 'SCHEDULED'
            : appointment.status,
      }),
    );
  }

  Future<AppFailure?> cancelAppointment(
    OpdAppointment appointment,
    String? reason,
  ) {
    return _mutateAppointment(
      () => _repository.cancelAppointment(appointment.apiId, reason),
    );
  }

  Future<AppFailure?> assignAppointmentToQueue(
    OpdAppointment appointment,
  ) async {
    final String? tenantId = appointment.tenantId;
    final String? patientId = appointment.patientId;
    if (tenantId == null || patientId == null) {
      return null;
    }

    return _mutateQueue(
      () => _repository.createVisitQueue(<String, Object?>{
        'tenant_id': tenantId,
        'facility_id': appointment.facilityId,
        'patient_id': patientId,
        'appointment_id': appointment.apiId,
        'provider_user_id': appointment.providerUserId,
        'status': 'CONFIRMED',
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<AppFailure?> moveQueueEntry(
    OpdQueueEntry entry,
    Map<String, Object?> payload,
  ) {
    return _mutateQueue(
      () => _repository.updateVisitQueue(entry.apiId, payload),
      refreshFlowsAfter: true,
    );
  }

  Future<AppFailure?> prioritizeQueueEntry(
    OpdQueueEntry entry,
    String? reason,
  ) {
    return _mutateQueue(
      () => _repository.prioritizeVisitQueue(entry.apiId, <String, Object?>{
        'reason': reason,
        'status': 'CONFIRMED',
      }),
    );
  }

  Future<AppFailure?> startOpdFromQueue(OpdQueueEntry entry) {
    return _mutateFlow(
      () => _repository.startOpdFlow(<String, Object?>{
        'arrival_mode': 'WALK_IN',
        'visit_queue_id': entry.apiId,
        'provider_user_id': entry.providerUserId,
      }),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> assignDoctor(OpdFlowSummary flow, String providerUserId) {
    return _mutateFlow(
      () => _repository.assignDoctor(flow.apiId, <String, Object?>{
        'provider_user_id': providerUserId,
      }),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> payConsultation(
    OpdFlowSummary flow,
    Map<String, Object?> payload,
  ) {
    return _mutateFlow(
      () => _repository.payConsultation(flow.apiId, payload),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> recordVitals(
    OpdFlowSummary flow,
    Map<String, Object?> payload,
  ) {
    return _mutateFlow(
      () => _repository.recordVitals(flow.apiId, payload),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> updateVitals(
    OpdFlowDetail detail,
    List<Map<String, Object?>> vitals,
  ) {
    return _mutateFlow(
      () => _repository.recordVitals(detail.summary.apiId, <String, Object?>{
        'vitals': vitals,
        'update_existing': true,
      }),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> correctStage(
    OpdFlowSummary flow,
    String stage,
    String? reason,
  ) {
    return _mutateFlow(
      () => _repository.correctStage(flow.apiId, <String, Object?>{
        'stage_to': stage,
        'reason': reason,
      }),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> doctorReview(
    OpdFlowSummary flow,
    Map<String, Object?> payload,
  ) {
    return _mutateFlow(
      () => _repository.doctorReview(flow.apiId, payload),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> disposeFlow(
    OpdFlowSummary flow,
    String decision,
    String? notes, {
    String? providerUserId,
    String? triageLevel,
    bool emergency = false,
  }) {
    return _mutateFlow(
      () => _repository.routeTriage(flow.apiId, <String, Object?>{
        'route_to': decision,
        'decision': decision,
        'notes': notes,
        'provider_user_id': providerUserId,
        'triage_level': triageLevel,
        'emergency': emergency,
      }),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> completeDisposition(
    OpdFlowSummary flow,
    Map<String, Object?> payload,
  ) {
    return _mutateFlow(
      () => _repository.disposition(flow.apiId, payload),
      refreshAfter: true,
    );
  }

  Future<AppFailure?> createReferral({
    required OpdFlowSummary flow,
    required String externalFacilityName,
    required String reason,
    String? notes,
  }) async {
    return _mutateRelatedFlowRecord(
      flow,
      () => _repository.createReferral(<String, Object?>{
        'encounter_id': flow.id,
        'external_facility_name': externalFacilityName,
        'reason': reason,
        'notes': notes,
      }),
    );
  }

  Future<AppFailure?> createFollowUp({
    required OpdFlowSummary flow,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    return _mutateRelatedFlowRecord(
      flow,
      () => _repository.createFollowUp(<String, Object?>{
        'encounter_id': flow.id,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'SCHEDULED',
        'notes': notes,
      }),
    );
  }

  Future<Result<OpdWorkspaceState>> _loadInitialState() async {
    const OpdAppointmentQuery appointmentQuery = OpdAppointmentQuery();
    const OpdQueueQuery queueQuery = OpdQueueQuery();
    const OpdFlowQuery flowQuery = OpdFlowQuery();
    const OpdTriageQueueQuery triageQueueQuery = OpdTriageQueueQuery();

    final Result<AppPage<OpdAppointment>> appointmentsResult = await _repository
        .listAppointments(appointmentQuery);
    final AppPage<OpdAppointment>? appointments = _pageOrEmptyOnAccessDenied(
      appointmentsResult,
      appointmentQuery.pageRequest,
    );
    if (appointments == null) {
      return Result<OpdWorkspaceState>.failure(
        _failureOrNull(appointmentsResult)!,
      );
    }

    final Result<AppPage<OpdQueueEntry>> queueResult = await _repository
        .listVisitQueues(queueQuery);
    final AppPage<OpdQueueEntry>? queue = _pageOrEmptyOnAccessDenied(
      queueResult,
      queueQuery.pageRequest,
    );
    if (queue == null) {
      return Result<OpdWorkspaceState>.failure(_failureOrNull(queueResult)!);
    }

    final Result<AppPage<OpdFlowSummary>> flowsResult = await _repository
        .listOpdFlows(flowQuery);
    final AppPage<OpdFlowSummary>? flows = _successOrNull(flowsResult);
    if (flows == null) {
      return Result<OpdWorkspaceState>.failure(_failureOrNull(flowsResult)!);
    }

    final Result<AppPage<OpdFlowSummary>> triageQueueResult = await _repository
        .listTriageQueue(triageQueueQuery);
    final AppPage<OpdFlowSummary>? triageQueue = _pageOrEmptyOnAccessDenied(
      triageQueueResult,
      triageQueueQuery.pageRequest,
    );
    if (triageQueue == null) {
      return Result<OpdWorkspaceState>.failure(
        _failureOrNull(triageQueueResult)!,
      );
    }

    final List<OpdClinicalAlertThreshold> thresholds =
        await _clinicalAlertThresholds();
    final List<OpdProviderSchedule> schedules = await _providerSchedules();
    final List<OpdAvailabilitySlot> slots = await _availabilitySlots(schedules);

    return Result<OpdWorkspaceState>.success(
      OpdWorkspaceState(
        appointmentQuery: appointmentQuery,
        queueQuery: queueQuery,
        flowQuery: flowQuery,
        triageQueueQuery: triageQueueQuery,
        appointments: appointments,
        queueEntries: queue,
        flows: flows,
        triageQueue: triageQueue,
        clinicalAlertThresholds: thresholds,
        providerSchedules: schedules,
        availabilitySlots: slots,
      ),
    );
  }

  void _startVisibleDataSync() {
    _syncTimer ??= Timer.periodic(_syncInterval, (_) {
      unawaited(_syncVisibleData());
    });
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshProviders = false,
  }) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null || _isSyncing || current.isSaving) {
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshingAppointments: true,
          isRefreshingQueue: true,
          isRefreshingFlows: true,
          isRefreshingTriageQueue: true,
          isRefreshingDetail: current.selectedFlow != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? failure = await _refreshVisiblePages(
        showLoading: showLoading,
      );
      if (failure != null) {
        return failure;
      }

      if (refreshProviders) {
        final List<OpdProviderSchedule> schedules = await _providerSchedules();
        final List<OpdAvailabilitySlot> slots = await _availabilitySlots(
          schedules,
        );
        final List<OpdClinicalAlertThreshold> thresholds =
            await _clinicalAlertThresholds();
        final OpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              providerSchedules: schedules,
              availabilitySlots: slots,
              clinicalAlertThresholds: thresholds,
            ),
          );
        }
      }

      return null;
    } finally {
      final OpdWorkspaceState? latest = _currentState;
      if (showLoading && latest != null) {
        _emit(
          latest.copyWith(
            isRefreshingAppointments: false,
            isRefreshingQueue: false,
            isRefreshingFlows: false,
            isRefreshingTriageQueue: false,
            isRefreshingDetail: false,
          ),
        );
      }
      _isSyncing = false;
    }
  }

  Future<AppFailure?> _refreshVisiblePages({required bool showLoading}) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    AppFailure? firstFailure;
    final Future<Result<AppPage<OpdAppointment>>> appointmentsFuture =
        _repository.listAppointments(current.appointmentQuery);
    final Future<Result<AppPage<OpdQueueEntry>>> queueFuture = _repository
        .listVisitQueues(current.queueQuery);
    final Future<Result<AppPage<OpdFlowSummary>>> flowsFuture = _repository
        .listOpdFlows(current.flowQuery);
    final Future<Result<AppPage<OpdFlowSummary>>> triageFuture = _repository
        .listTriageQueue(current.triageQueueQuery);
    final OpdFlowDetail? currentSelectedFlow = current.selectedFlow;
    final Future<Result<OpdFlowDetail>>? selectedDetailFuture =
        currentSelectedFlow == null
        ? null
        : _repository.getOpdFlow(currentSelectedFlow.summary.apiId);

    final Result<AppPage<OpdAppointment>> appointmentsResult =
        await appointmentsFuture;
    final Result<AppPage<OpdQueueEntry>> queueResult = await queueFuture;
    final Result<AppPage<OpdFlowSummary>> flowsResult = await flowsFuture;
    final Result<AppPage<OpdFlowSummary>> triageResult = await triageFuture;
    final Result<OpdFlowDetail>? selectedDetailResult =
        selectedDetailFuture == null ? null : await selectedDetailFuture;

    OpdWorkspaceState nextState = current;

    appointmentsResult.when(
      success: (AppPage<OpdAppointment> page) {
        nextState = nextState.copyWith(appointments: page);
      },
      failure: (AppFailure failure) {
        firstFailure ??= failure;
      },
    );

    queueResult.when(
      success: (AppPage<OpdQueueEntry> page) {
        nextState = nextState.copyWith(queueEntries: page);
      },
      failure: (AppFailure failure) {
        firstFailure ??= failure;
      },
    );

    flowsResult.when(
      success: (AppPage<OpdFlowSummary> page) {
        final AppPage<OpdFlowSummary> stablePage = _stableFlowPage(
          page,
          current.flows,
        );
        final OpdFlowDetail? selected = _selectedAfterFlowRefresh(
          stablePage,
          nextState.selectedFlow,
        );
        nextState = nextState.copyWith(
          flows: stablePage,
          selectedFlow: selected,
          clearSelectedFlow: selected == null,
        );
      },
      failure: (AppFailure failure) {
        firstFailure ??= failure;
      },
    );

    triageResult.when(
      success: (AppPage<OpdFlowSummary> page) {
        nextState = nextState.copyWith(
          triageQueue: _stableFlowPage(page, current.triageQueue),
        );
      },
      failure: (AppFailure failure) {
        firstFailure ??= failure;
      },
    );

    selectedDetailResult?.when(
      success: (OpdFlowDetail detail) {
        nextState = nextState.copyWith(
          selectedFlow: detail.summary.isTerminal ? null : detail,
          clearSelectedFlow: detail.summary.isTerminal,
          flows: _upsertOrRemoveFlow(nextState.flows, detail.summary),
          triageQueue: _upsertOrRemoveTriageFlow(
            nextState.triageQueue,
            detail.summary,
          ),
        );
      },
      failure: (_) {},
    );

    _emit(
      nextState.copyWith(
        isRefreshingAppointments: showLoading
            ? false
            : nextState.isRefreshingAppointments,
        isRefreshingQueue: showLoading ? false : nextState.isRefreshingQueue,
        isRefreshingFlows: showLoading ? false : nextState.isRefreshingFlows,
        isRefreshingTriageQueue: showLoading
            ? false
            : nextState.isRefreshingTriageQueue,
        lastFailure: firstFailure,
      ),
    );

    return firstFailure;
  }

  Future<List<OpdProviderSchedule>> _providerSchedules() async {
    final Result<List<OpdProviderSchedule>> result = await _repository
        .listProviderSchedules();
    return result.when(
      success: (List<OpdProviderSchedule> schedules) => schedules,
      failure: (_) => const <OpdProviderSchedule>[],
    );
  }

  Future<List<OpdAvailabilitySlot>> _availabilitySlots(
    List<OpdProviderSchedule> schedules,
  ) async {
    final List<OpdAvailabilitySlot> slots = <OpdAvailabilitySlot>[];
    for (final OpdProviderSchedule schedule in schedules.take(4)) {
      final Result<List<OpdAvailabilitySlot>> result = await _repository
          .listAvailabilitySlots(schedule.apiId);
      result.when(
        success: (List<OpdAvailabilitySlot> value) {
          slots.addAll(value);
        },
        failure: (_) {},
      );
    }
    return List<OpdAvailabilitySlot>.unmodifiable(slots);
  }

  Future<List<OpdClinicalAlertThreshold>> _clinicalAlertThresholds() async {
    final Result<List<OpdClinicalAlertThreshold>> result = await _repository
        .listClinicalAlertThresholds();
    return result.when(
      success: (List<OpdClinicalAlertThreshold> thresholds) => thresholds,
      failure: (_) => const <OpdClinicalAlertThreshold>[],
    );
  }

  Future<AppFailure?> _mutateAppointment(
    Future<Result<OpdAppointment>> Function() action,
  ) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<OpdAppointment> result = await action();
    return result.when(
      success: (OpdAppointment appointment) async {
        final OpdWorkspaceState latest = _currentState!;
        _emit(
          latest.copyWith(
            appointments: _upsertAppointment(latest.appointments, appointment),
            isSaving: false,
          ),
        );
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateQueue(
    Future<Result<OpdQueueEntry>> Function() action, {
    bool refreshFlowsAfter = false,
  }) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<OpdQueueEntry> result = await action();
    return result.when(
      success: (OpdQueueEntry entry) async {
        final OpdWorkspaceState latest = _currentState!;
        _emit(
          latest.copyWith(
            queueEntries: _upsertQueueEntry(latest.queueEntries, entry),
            isSaving: false,
          ),
        );
        if (refreshFlowsAfter) {
          return _syncVisibleData();
        }
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateFlow(
    Future<Result<OpdFlowDetail>> Function() action, {
    required bool refreshAfter,
  }) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<OpdFlowDetail> result = await action();
    return result.when(
      success: (OpdFlowDetail detail) async {
        final OpdWorkspaceState latest = _currentState!;
        _emit(
          latest.copyWith(
            selectedFlow: detail.summary.isTerminal ? null : detail,
            clearSelectedFlow: detail.summary.isTerminal,
            flows: _upsertOrRemoveFlow(latest.flows, detail.summary),
            triageQueue: _upsertOrRemoveTriageFlow(
              latest.triageQueue,
              detail.summary,
            ),
            isSaving: false,
          ),
        );
        if (refreshAfter) {
          return _syncVisibleData();
        }
        return null;
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        if (failure.category == AppFailureCategory.notFound) {
          unawaited(_syncVisibleData(showLoading: true));
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateRelatedFlowRecord(
    OpdFlowSummary flow,
    Future<Result<void>> Function() action,
  ) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return refresh();
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<void> result = await action();
    return result.when(
      success: (_) async {
        final Result<OpdFlowDetail> detailResult = await _repository.getOpdFlow(
          flow.apiId,
        );
        return detailResult.when(
          success: (OpdFlowDetail detail) {
            _emit(
              _currentState!.copyWith(
                selectedFlow: detail,
                flows: _replaceFlow(_currentState!.flows, detail.summary),
                isSaving: false,
              ),
            );
            return null;
          },
          failure: (AppFailure failure) {
            _emit(
              _currentState!.copyWith(isSaving: false, lastFailure: failure),
            );
            return failure;
          },
        );
      },
      failure: (AppFailure failure) {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        return failure;
      },
    );
  }

  OpdFlowDetail? _selectedAfterFlowRefresh(
    AppPage<OpdFlowSummary> page,
    OpdFlowDetail? selected,
  ) {
    if (selected == null) {
      return null;
    }

    for (final OpdFlowSummary flow in page.items) {
      if (flow.id == selected.summary.id ||
          flow.publicId == selected.summary.publicId) {
        return OpdFlowDetail(
          summary: flow,
          consultationInvoiceId: selected.consultationInvoiceId,
          consultationPaymentId: selected.consultationPaymentId,
          consultationPaymentStatus: selected.consultationPaymentStatus,
          consultationPaid: selected.consultationPaid,
          consultationPaymentRequired: selected.consultationPaymentRequired,
          consultationPaidAmount: selected.consultationPaidAmount,
          timeline: selected.timeline,
          referrals: selected.referrals,
          followUps: selected.followUps,
          clinicalAlerts: selected.clinicalAlerts,
          clinicalAlertDetails: selected.clinicalAlertDetails,
          vitalSigns: selected.vitalSigns,
          vitalMeasurements: selected.vitalMeasurements,
          clinicalNotes: selected.clinicalNotes,
          diagnoses: selected.diagnoses,
          procedures: selected.procedures,
          labOrders: selected.labOrders,
          radiologyOrders: selected.radiologyOrders,
          pharmacyOrders: selected.pharmacyOrders,
          admissions: selected.admissions,
        );
      }
    }

    return selected;
  }

  AppPage<OpdFlowSummary> _stableFlowPage(
    AppPage<OpdFlowSummary> next,
    AppPage<OpdFlowSummary> previous,
  ) {
    final List<OpdFlowSummary> items = next.items
        .map(
          (OpdFlowSummary flow) =>
              _mergeSparseBilling(flow, _matchingPreviousFlow(previous, flow)),
        )
        .toList(growable: true);

    for (final OpdFlowSummary previousFlow in previous.items) {
      if (previousFlow.isTerminal ||
          isOpdTerminalStatus(previousFlow.status ?? previousFlow.stage)) {
        continue;
      }
      if (items.any((OpdFlowSummary item) => _isSameFlow(item, previousFlow))) {
        continue;
      }
      if (!_hasBillingSignal(previousFlow)) {
        continue;
      }
      items.add(previousFlow);
    }

    return AppPage<OpdFlowSummary>(
      items: items.take(next.request.pageSize).toList(growable: false),
      request: next.request,
      totalItemCount: next.totalItemCount,
    );
  }

  OpdFlowSummary? _matchingPreviousFlow(
    AppPage<OpdFlowSummary> previous,
    OpdFlowSummary flow,
  ) {
    for (final OpdFlowSummary item in previous.items) {
      if (_isSameFlow(item, flow)) {
        return item;
      }
    }
    return null;
  }

  OpdFlowSummary _mergeSparseBilling(
    OpdFlowSummary next,
    OpdFlowSummary? previous,
  ) {
    if (previous == null || !_hasBillingSignal(previous)) {
      return next;
    }

    final bool nextHasBillingSignal = _hasBillingSignal(next);
    if (!nextHasBillingSignal) {
      return next.copyWith(
        consultationPaid: previous.consultationPaid,
        consultationPaymentRequired: previous.consultationPaymentRequired,
        consultationFee: previous.consultationFee,
        consultationPaidAmount: previous.consultationPaidAmount,
        consultationCurrency: previous.consultationCurrency,
        consultationInvoiceId: previous.consultationInvoiceId,
        consultationPaymentId: previous.consultationPaymentId,
        consultationPaymentStatus: previous.consultationPaymentStatus,
      );
    }

    return next.copyWith(
      consultationFee: next.consultationFee ?? previous.consultationFee,
      consultationPaidAmount:
          next.consultationPaidAmount ?? previous.consultationPaidAmount,
      consultationCurrency:
          next.consultationCurrency ?? previous.consultationCurrency,
      consultationInvoiceId:
          next.consultationInvoiceId ?? previous.consultationInvoiceId,
      consultationPaymentId:
          next.consultationPaymentId ?? previous.consultationPaymentId,
      consultationPaymentStatus:
          next.consultationPaymentStatus ?? previous.consultationPaymentStatus,
    );
  }

  bool _hasBillingSignal(OpdFlowSummary flow) {
    return flow.consultationPaid ||
        flow.consultationPaymentRequired ||
        flow.consultationFee != null ||
        flow.consultationPaidAmount != null ||
        flow.consultationCurrency != null ||
        flow.consultationInvoiceId != null ||
        flow.consultationPaymentId != null ||
        flow.consultationPaymentStatus != null;
  }

  AppPage<OpdAppointment> _upsertAppointment(
    AppPage<OpdAppointment> page,
    OpdAppointment appointment,
  ) {
    final List<OpdAppointment> items = page.items
        .where((OpdAppointment item) => item.id != appointment.id)
        .toList(growable: true);
    items.insert(0, appointment);
    return AppPage<OpdAppointment>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! +
                (page.items.any(
                      (OpdAppointment item) => item.id == appointment.id,
                    )
                    ? 0
                    : 1),
    );
  }

  AppPage<OpdQueueEntry> _upsertQueueEntry(
    AppPage<OpdQueueEntry> page,
    OpdQueueEntry entry,
  ) {
    final List<OpdQueueEntry> items = page.items
        .where((OpdQueueEntry item) => item.id != entry.id)
        .toList(growable: true);
    items.insert(0, entry);
    return AppPage<OpdQueueEntry>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! +
                (page.items.any((OpdQueueEntry item) => item.id == entry.id)
                    ? 0
                    : 1),
    );
  }

  AppPage<OpdFlowSummary> _upsertFlow(
    AppPage<OpdFlowSummary> page,
    OpdFlowSummary flow,
  ) {
    final List<OpdFlowSummary> items = page.items
        .where((OpdFlowSummary item) => !_isSameFlow(item, flow))
        .toList(growable: true);
    items.insert(0, flow);
    final bool alreadyPresent = page.items.any(
      (OpdFlowSummary item) => _isSameFlow(item, flow),
    );
    return AppPage<OpdFlowSummary>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount == null || alreadyPresent
          ? page.totalItemCount
          : page.totalItemCount! + 1,
    );
  }

  AppPage<OpdFlowSummary> _replaceFlow(
    AppPage<OpdFlowSummary> page,
    OpdFlowSummary flow,
  ) {
    var replaced = false;
    final List<OpdFlowSummary> items = <OpdFlowSummary>[];
    for (final OpdFlowSummary item in page.items) {
      if (_isSameFlow(item, flow)) {
        if (!replaced) {
          items.add(flow);
          replaced = true;
        }
      } else {
        items.add(item);
      }
    }

    if (!replaced) {
      return _upsertFlow(page, flow);
    }

    return AppPage<OpdFlowSummary>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  AppPage<OpdFlowSummary> _upsertOrRemoveFlow(
    AppPage<OpdFlowSummary> page,
    OpdFlowSummary flow,
  ) {
    if (flow.isTerminal || isOpdTerminalStatus(flow.status ?? flow.stage)) {
      return _removeFlow(page, flow);
    }
    return _upsertFlow(page, flow);
  }

  AppPage<OpdFlowSummary> _upsertOrRemoveTriageFlow(
    AppPage<OpdFlowSummary> page,
    OpdFlowSummary flow,
  ) {
    if (!_belongsInTriageQueue(flow)) {
      return _removeFlow(page, flow);
    }
    return _upsertFlow(page, flow);
  }

  AppPage<OpdFlowSummary> _removeFlow(
    AppPage<OpdFlowSummary> page,
    OpdFlowSummary flow,
  ) {
    final List<OpdFlowSummary> items = page.items
        .where((OpdFlowSummary item) => !_isSameFlow(item, flow))
        .toList(growable: false);
    if (items.length == page.items.length) {
      return page;
    }

    return AppPage<OpdFlowSummary>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! > 0
          ? page.totalItemCount! - 1
          : 0,
    );
  }

  bool _belongsInTriageQueue(OpdFlowSummary flow) {
    final String stage = (flow.stage ?? '').toUpperCase();
    return !flow.isTerminal &&
        (stage == 'WAITING_VITALS' || stage == 'WAITING_DOCTOR_ASSIGNMENT') &&
        !isOpdTerminalStatus(flow.status ?? flow.stage);
  }

  bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
    return left.id == right.id ||
        (left.publicId != null && left.publicId == right.publicId);
  }

  OpdWorkspaceState? get _currentState {
    final Result<OpdWorkspaceState>? currentResult = state.asData?.value;
    return switch (currentResult) {
      ResultSuccess<OpdWorkspaceState>(value: final value) => value,
      _ => null,
    };
  }

  void _emit(OpdWorkspaceState nextState) {
    state = AsyncData<Result<OpdWorkspaceState>>(
      Result<OpdWorkspaceState>.success(nextState),
    );
  }

  T? _successOrNull<T>(Result<T> result) {
    return result.when(success: (T value) => value, failure: (_) => null);
  }

  AppPage<T>? _pageOrEmptyOnAccessDenied<T>(
    Result<AppPage<T>> result,
    AppPageRequest request,
  ) {
    return result.when(
      success: (AppPage<T> page) => page,
      failure: (AppFailure failure) {
        if (_isAccessDeniedFailure(failure)) {
          return AppPage<T>(
            items: List<T>.empty(),
            request: request,
            totalItemCount: 0,
          );
        }
        return null;
      },
    );
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  bool _isAccessDeniedFailure(AppFailure failure) {
    return failure.category == AppFailureCategory.unauthorized ||
        failure.category == AppFailureCategory.forbidden;
  }
}
