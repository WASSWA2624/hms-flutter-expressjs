import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/idempotency.dart';
import 'package:hosspi_hms/core/network/network_failure_mapper.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/realtime/realtime_service.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/core/workspace/workspace_adaptive_polling.dart';
import 'package:hosspi_hms/core/workspace/workspace_bootstrap_helpers.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_realtime_sync.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_realtime_delta_applier.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_follow_up_controller.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_payment_gate_controller.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';

final opdWorkspaceControllerProvider =
    AsyncNotifierProvider<OpdWorkspaceController, Result<OpdWorkspaceState>>(
      OpdWorkspaceController.new,
    );

final class OpdWorkspaceController
    extends AsyncNotifier<Result<OpdWorkspaceState>> {
  static const Duration _syncInterval = Duration(seconds: 6);

  OpdRepository get _repository => ref.read(opdRepositoryProvider);

  final WorkspaceAdaptivePolling _adaptivePolling = WorkspaceAdaptivePolling();
  bool _isSyncing = false;
  bool _refreshPending = false;
  bool _queueProviderOptionsLoaded = false;
  WorkspaceRefreshPlan? _pendingRefreshPlan;
  Future<AppFailure?>? _manualRefreshInFlight;

  @override
  Future<Result<OpdWorkspaceState>> build() async {
    watchSessionEpoch(ref);
    ref.onDispose(() {
      _adaptivePolling.dispose();
    });
    listenForRealtimeRefresh(
      ref: ref,
      events: RealtimeEventGroups.opd,
      includeCrudMutations: true,
      shouldDefer: () => _isSyncing || (_currentState?.isSaving ?? false),
      onRefresh: _syncFromRealtime,
    );
    ref.listen<AsyncValue<RealtimeConnectionState>>(
      realtimeConnectionStateProvider,
      (_, _) => _adaptivePolling.onConnectionStateChanged(),
    );
    final Result<OpdWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      _loadInitialState,
    );
    _startAdaptivePolling();
    return result;
  }

  Future<void> _syncFromRealtime(RealtimeMessage message) async {
    if (_isSyncing || (_currentState?.isSaving ?? false)) {
      _refreshPending = true;
      _pendingRefreshPlan = _mergePendingPlan(
        WorkspaceEventRefreshPlan.forMessage(
          message,
          profile: WorkspaceRefreshProfile.clinicalFlow,
        ),
      );
      return;
    }

    final OpdWorkspaceState? current = _currentState;
    final WorkspaceSyncOutcome outcome =
        resolveWorkspaceRealtime<OpdWorkspaceState>(
          message: message,
          profile: WorkspaceRefreshProfile.clinicalFlow,
          currentState: current,
          applyDelta: OpdRealtimeDeltaApplier.apply,
        );

    if (outcome is WorkspaceSyncIgnored) {
      return;
    }
    if (outcome is WorkspaceSyncPatched<OpdWorkspaceState>) {
      _emit(outcome.state);
      if (!outcome.residualPlan.isEmpty) {
        await _syncVisibleData(plan: outcome.residualPlan);
      }
      return;
    }
    if (outcome is WorkspaceSyncNeedsHttp) {
      if (outcome.plan.isEmpty) {
        return;
      }
      await _syncVisibleData(plan: outcome.plan);
    }
  }

  WorkspaceRefreshPlan _mergePendingPlan(WorkspaceRefreshPlan plan) {
    final WorkspaceRefreshPlan? pending = _pendingRefreshPlan;
    if (pending == null) {
      return plan;
    }
    return pending.merge(plan);
  }

  Future<AppFailure?> refresh() => _startManualRefresh(
    plan: WorkspaceRefreshPlan.full,
    refreshProviders: true,
  );

  /// Refreshes only the OPD slices rendered by Reception.
  ///
  /// The refresh is silent at controller level so a shared OPD controller does
  /// not expose page-level loading chrome in either workspace.
  Future<AppFailure?> refreshReceptionData() =>
      _startManualRefresh(plan: WorkspaceRefreshPlan.receptionDesk);

  Future<AppFailure?> _startManualRefresh({
    required WorkspaceRefreshPlan plan,
    bool refreshProviders = false,
  }) {
    // Manual refresh is intentionally single-flight. Realtime refreshes use
    // the pending-plan path below, but repeated toolbar taps must not enqueue
    // another identical HTTP reload behind the active one.
    final Future<AppFailure?>? active = _manualRefreshInFlight;
    if (active != null) {
      return active;
    }
    if (_isSyncing || (_currentState?.isSaving ?? false)) {
      return Future<AppFailure?>.value();
    }
    late final Future<AppFailure?> operation;
    operation =
        (_currentState == null
                ? _retryInitialLoad()
                : _syncVisibleData(
                    showLoading: refreshProviders,
                    refreshProviders: refreshProviders,
                    plan: plan,
                  ))
            .whenComplete(() {
              if (identical(_manualRefreshInFlight, operation)) {
                _manualRefreshInFlight = null;
              }
            });
    _manualRefreshInFlight = operation;
    return operation;
  }

  Future<AppFailure?> _retryInitialLoad() async {
    final Result<OpdWorkspaceState> result = await runWorkspaceInitialLoad(
      ref,
      _loadInitialState,
    );
    state = AsyncData<Result<OpdWorkspaceState>>(result);
    return result.when<AppFailure?>(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
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

    return _refreshVisiblePages(
      showLoading: true,
      plan: WorkspaceRefreshPlan.full,
    );
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
    OpdWorkspaceState? current = _currentState;
    if (current == null) {
      final AppFailure? bootstrapFailure = await refresh();
      current = _currentState;
      if (bootstrapFailure != null || current == null) {
        return bootstrapFailure;
      }
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

  /// Resolves an OPD flow summary by encounter identifier for deep-linking.
  ///
  /// Prefers an already-loaded summary (worklist or triage queue) and falls
  /// back to fetching the detail snapshot. Returns `null` when the encounter
  /// cannot be resolved (for example an unknown or completed identifier).
  Future<OpdFlowSummary?> resolveFlowById(String identifier) async {
    final String target = identifier.trim();
    if (target.isEmpty) {
      return null;
    }

    bool matches(OpdFlowSummary flow) {
      return flow.id == target ||
          flow.publicId == target ||
          flow.apiId == target;
    }

    final OpdWorkspaceState? current = _currentState;
    if (current != null) {
      for (final OpdFlowSummary flow in <OpdFlowSummary>[
        ...current.flows.items,
        ...current.triageQueue.items,
      ]) {
        if (matches(flow)) {
          return flow;
        }
      }
    }

    final Result<OpdFlowDetail> result = await _repository.getOpdFlow(target);
    return result.when(
      success: (OpdFlowDetail detail) => detail.summary,
      failure: (_) => null,
    );
  }

  Future<AppFailure?> startOpdEncounter(Map<String, Object?> payload) {
    return submitOpdEncounter(payload).then(
      (Result<OpdFlowDetail> result) => result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      ),
    );
  }

  Future<AppFailure?> checkInAppointment(OpdAppointment appointment) async {
    final String key = createIdempotencyKey();
    final AppFailure? failure = await _mutateFlow(
      () => _repository.startOpdFlow(<String, Object?>{
        'arrival_mode': 'ONLINE_APPOINTMENT',
        'appointment_id': appointment.apiId,
        'facility_id': appointment.facilityId,
        'provider_user_id': appointment.providerUserId,
        'queued_at': DateTime.now().toUtc().toIso8601String(),
        'reuse_open_encounter': true,
      }, idempotencyKey: key),
    );
    if (failure != null) {
      return failure;
    }
    // Backend marks the appointment IN_PROGRESS; patch local appointments so
    // reception/OPD desks stay in sync without a full reload.
    markAppointmentInProgress(appointment);
    return null;
  }

  /// Patches the appointment row to [IN_PROGRESS] after a successful check-in /
  /// start-OPD flow that the backend already persisted with that status.
  void markAppointmentInProgress(OpdAppointment appointment) {
    final OpdWorkspaceState? latest = _currentState;
    if (latest == null) {
      return;
    }
    _emit(
      latest.copyWith(
        appointments: _upsertAppointment(
          latest.appointments,
          appointment.copyWith(status: 'IN_PROGRESS'),
        ),
      ),
    );
  }

  Future<AppFailure?> createAppointment(Map<String, Object?> payload) {
    return _mutateAppointment(() => _repository.createAppointment(payload));
  }

  Future<AppFailure?> rescheduleAppointment(
    OpdAppointment appointment,
    DateTime scheduledStart,
    DateTime scheduledEnd, {
    String? providerUserId,
    bool updateProvider = false,
  }) {
    final Map<String, Object?> payload = <String, Object?>{
      'scheduled_start': scheduledStart.toUtc().toIso8601String(),
      'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
      'status': appointment.status == 'CANCELLED'
          ? 'SCHEDULED'
          : appointment.status,
    };
    if (updateProvider) {
      final String? normalized = providerUserId?.trim();
      payload['provider_user_id'] = (normalized == null || normalized.isEmpty)
          ? null
          : normalized;
    }
    return _mutateAppointment(
      () => _repository.updateAppointment(appointment.apiId, payload),
    );
  }

  Future<AppFailure?> cancelAppointment(
    OpdAppointment appointment,
    String? reason,
  ) {
    final String? normalizedReason = reason == null || reason.trim().isEmpty
        ? null
        : reason.trim();
    return _mutateAppointment(
      () => _repository.cancelAppointment(appointment.apiId, normalizedReason),
    );
  }

  /// Ensures provider options (and workspace schedules) are available for
  /// appointment scheduling forms opened outside the OPD desk.
  Future<AppFailure?> ensureAppointmentFormOptionsLoaded() async {
    if (_currentState == null) {
      final AppFailure? failure = await refresh();
      if (failure != null) {
        return failure;
      }
    }
    return ensureQueueProviderOptionsLoaded();
  }

  Future<AppFailure?> assignAppointmentToQueue(
    OpdAppointment appointment,
  ) async {
    final String? tenantId = appointment.tenantId;
    final String? patientId = appointment.patientId;
    if (tenantId == null || patientId == null) {
      return AppFailure.validation();
    }

    final String key = createIdempotencyKey();
    return _mutateQueue(
      () => _repository.createVisitQueue(<String, Object?>{
        'tenant_id': tenantId,
        'facility_id': appointment.facilityId,
        'patient_id': patientId,
        'appointment_id': appointment.apiId,
        'provider_user_id': appointment.providerUserId,
        'status': 'CONFIRMED',
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      }, idempotencyKey: key),
    );
  }

  Future<AppFailure?> ensureQueueProviderOptionsLoaded() async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null ||
        current.isRefreshingQueueProviders ||
        _queueProviderOptionsLoaded) {
      return null;
    }

    _emit(
      current.copyWith(
        isRefreshingQueueProviders: true,
        clearLastFailure: true,
      ),
    );
    final Result<List<OpdProviderOption>> result = await _repository
        .listProviders();
    return result.when(
      success: (List<OpdProviderOption> providers) {
        _queueProviderOptionsLoaded = true;
        final OpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              queueProviderOptions: List<OpdProviderOption>.unmodifiable(
                providers,
              ),
              isRefreshingQueueProviders: false,
            ),
          );
        }
        return null;
      },
      failure: (AppFailure failure) {
        final OpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              isRefreshingQueueProviders: false,
              lastFailure: failure,
            ),
          );
        }
        return failure;
      },
    );
  }

  Future<AppFailure?> moveQueueEntry(
    OpdQueueEntry entry,
    Map<String, Object?> payload,
  ) {
    final String key = createIdempotencyKey();
    return _mutateQueue(
      () => _repository.updateVisitQueue(
        entry.apiId,
        payload,
        idempotencyKey: key,
      ),
      refreshFlowsAfter: true,
    );
  }

  Future<AppFailure?> prioritizeQueueEntry(
    OpdQueueEntry entry,
    String? reason,
  ) {
    final String key = createIdempotencyKey();
    return _mutateQueue(
      () => _repository.prioritizeVisitQueue(entry.apiId, <String, Object?>{
        'reason': reason,
      }, idempotencyKey: key),
    );
  }

  Future<AppFailure?> startOpdFromQueue(OpdQueueEntry entry) async {
    final String key = createIdempotencyKey();
    final AppFailure? failure = await _mutateFlow(
      () => _repository.startOpdFlow(<String, Object?>{
        'arrival_mode': 'WALK_IN',
        'visit_queue_id': entry.apiId,
        'provider_user_id': entry.providerUserId,
        'reuse_open_encounter': true,
      }, idempotencyKey: key),
    );
    if (failure != null) {
      return failure;
    }
    // Backend marks the linked visit queue IN_PROGRESS; patch local queue
    // immediately so reception/OPD desks stay in sync without a full reload.
    final OpdWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(
        latest.copyWith(
          queueEntries: _upsertQueueEntry(
            latest.queueEntries,
            entry.copyWith(status: 'IN_PROGRESS'),
          ),
        ),
      );
    }
    return null;
  }

  Future<AppFailure?> assignDoctor(
    OpdFlowSummary flow,
    String providerUserId,
  ) async {
    final String key = createIdempotencyKey();
    final AppFailure? failure = await _mutateFlow(
      () => _repository.assignDoctor(flow.apiId, <String, Object?>{
        'provider_user_id': providerUserId,
      }, idempotencyKey: key),
    );
    if (failure != null) {
      return failure;
    }
    final OpdWorkspaceState? latest = _currentState;
    final OpdFlowSummary? patched = latest?.selectedFlow?.summary;
    final OpdFlowSummary syncSource =
        patched != null && _isSameFlow(patched, flow)
        ? patched.copyWith(
            visitQueueId: patched.visitQueueId ?? flow.visitQueueId,
          )
        : flow.copyWith(providerUserId: providerUserId);
    _syncQueueProviderFromFlow(syncSource);
    return null;
  }

  /// After assign-doctor persistence, keep the linked queue row's provider
  /// fields aligned with the patched encounter summary (status is already
  /// synced by [_patchLinkedEncounterSources]).
  void _syncQueueProviderFromFlow(OpdFlowSummary flow) {
    final OpdWorkspaceState? latest = _currentState;
    final String? queueId = flow.visitQueueId;
    if (latest == null || queueId == null || queueId.trim().isEmpty) {
      return;
    }
    final String? providerUserId = flow.providerUserId;
    if (providerUserId == null || providerUserId.trim().isEmpty) {
      return;
    }
    final String? providerDisplayName =
        flow.assignedStaffLabel ?? flow.providerDisplayName;
    _emit(
      latest.copyWith(
        queueEntries: _patchLinkedQueueProvider(
          latest.queueEntries,
          queueId,
          providerUserId: providerUserId,
          providerDisplayName: providerDisplayName,
        ),
      ),
    );
  }

  Future<AppFailure?> payConsultation(
    OpdFlowSummary flow,
    Map<String, Object?> payload,
  ) {
    return _mutateFlow(() => _repository.payConsultation(flow.apiId, payload));
  }

  Future<AppFailure?> recordVitals(
    OpdFlowSummary flow,
    Map<String, Object?> payload,
  ) {
    return _mutateFlow(() => _repository.recordVitals(flow.apiId, payload));
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
    );
  }

  Future<AppFailure?> doctorReview(
    OpdFlowSummary flow,
    Map<String, Object?> payload,
  ) {
    return _mutateFlow(() => _repository.doctorReview(flow.apiId, payload));
  }

  Future<AppFailure?> updateLabOrder({
    required OpdFlowSummary flow,
    required String labOrderId,
    required List<String> labTestIds,
    required List<String> labPanelIds,
  }) {
    return _mutateRelatedFlowRecord(
      flow,
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
        'notes': notes,
        'provider_user_id': providerUserId,
        'triage_level': triageLevel,
        'emergency': emergency,
      }),
    );
  }

  Future<AppFailure?> completeDisposition(
    OpdFlowSummary flow,
    Map<String, Object?> payload,
  ) {
    return _mutateFlow(() async {
      if ((flow.stage ?? '').toUpperCase() == 'WAITING_DOCTOR_REVIEW') {
        final Result<OpdFlowDetail> reviewResult = await _repository
            .doctorReview(flow.apiId, <String, Object?>{
              'note': _dispositionReviewNote(payload),
            });
        final AppFailure? reviewFailure = _failureOrNull(reviewResult);
        if (reviewFailure != null) {
          return Result<OpdFlowDetail>.failure(reviewFailure);
        }
      }
      return _repository.disposition(flow.apiId, payload);
    });
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
        'encounter_id': flow.apiId,
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
    final AppFailure? failure = await _mutateRelatedFlowRecord(
      flow,
      () => _repository.createFollowUp(<String, Object?>{
        'encounter_id': flow.apiId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'SCHEDULED',
        'notes': notes,
      }),
    );
    if (failure == null) {
      ref.invalidate(scopedFollowUpControllerProvider);
      unawaited(ref.read(receptionFollowUpControllerProvider.notifier).refresh());
    }
    return failure;
  }

  Future<AppFailure?> _flushPendingRefresh() async {
    if (!_refreshPending || _isSyncing || (_currentState?.isSaving ?? false)) {
      return null;
    }
    _refreshPending = false;
    final WorkspaceRefreshPlan plan =
        _pendingRefreshPlan ??
        WorkspaceDisconnectPollPlan.forProfile(
          WorkspaceRefreshProfile.clinicalFlow,
        );
    _pendingRefreshPlan = null;
    if (plan.isEmpty) {
      return null;
    }
    return _syncVisibleData(plan: plan);
  }

  Future<Result<OpdWorkspaceState>> _loadInitialState() async {
    const OpdAppointmentQuery appointmentQuery = OpdAppointmentQuery();
    const OpdQueueQuery queueQuery = OpdQueueQuery();
    const OpdFlowQuery flowQuery = OpdFlowQuery();
    const OpdTriageQueueQuery triageQueueQuery = OpdTriageQueueQuery();

    final List<Object?> bootstrapResults =
        await Future.wait<Object?>(<Future<Object?>>[
          _repository.listAppointments(appointmentQuery),
          _repository.listVisitQueues(queueQuery),
          _repository.listOpdFlows(flowQuery),
          _repository.getOpdSummaryCounts(),
          _repository.listTriageQueue(triageQueueQuery),
        ]);

    final Result<AppPage<OpdAppointment>> appointmentsResult =
        bootstrapResults[0]! as Result<AppPage<OpdAppointment>>;
    final Result<AppPage<OpdQueueEntry>> queueResult =
        bootstrapResults[1]! as Result<AppPage<OpdQueueEntry>>;
    final Result<AppPage<OpdFlowSummary>> flowsResult =
        bootstrapResults[2]! as Result<AppPage<OpdFlowSummary>>;
    final Result<OpdFlowAggregateCounts> summaryCountsResult =
        bootstrapResults[3]! as Result<OpdFlowAggregateCounts>;
    final Result<AppPage<OpdFlowSummary>> triageQueueResult =
        bootstrapResults[4]! as Result<AppPage<OpdFlowSummary>>;

    final AppPage<OpdAppointment> appointments = workspacePageOrEmptyOnFailure(
      appointmentsResult,
      appointmentQuery.pageRequest,
    );
    final AppFailure? appointmentsFailure = _failureOrNull(appointmentsResult);

    final AppPage<OpdQueueEntry> queue = workspacePageOrEmptyOnFailure(
      queueResult,
      queueQuery.pageRequest,
    );
    final AppFailure? queueFailure = _failureOrNull(queueResult);

    final AppPage<OpdFlowSummary> flows = workspacePageOrEmptyOnFailure(
      flowsResult,
      flowQuery.pageRequest,
    );
    final AppFailure? flowsFailure = _failureOrNull(flowsResult);

    final OpdFlowAggregateCounts summaryCounts =
        _successOrNull(summaryCountsResult) ?? OpdFlowAggregateCounts.empty;

    final AppPage<OpdFlowSummary> triageQueue = workspacePageOrEmptyOnFailure(
      triageQueueResult,
      triageQueueQuery.pageRequest,
    );
    final AppFailure? triageQueueFailure = _failureOrNull(triageQueueResult);

    final bool hasAnySuccess =
        appointmentsResult.isSuccess ||
        queueResult.isSuccess ||
        flowsResult.isSuccess ||
        triageQueueResult.isSuccess;

    AppFailure? firstFailure;
    for (final AppFailure? failure in <AppFailure?>[
      appointmentsFailure,
      queueFailure,
      flowsFailure,
      triageQueueFailure,
    ]) {
      if (failure == null || isWorkspaceAccessDeniedFailure(failure)) {
        continue;
      }
      firstFailure ??= failure;
      break;
    }
    if (!hasAnySuccess && firstFailure != null) {
      return Result<OpdWorkspaceState>.failure(firstFailure);
    }

    final List<Object?> referenceResults = await Future.wait<Object?>(
      <Future<Object?>>[_clinicalAlertThresholds(), _providerSchedules()],
    );
    final List<OpdClinicalAlertThreshold> thresholds =
        referenceResults[0]! as List<OpdClinicalAlertThreshold>;
    final List<OpdProviderSchedule> schedules =
        referenceResults[1]! as List<OpdProviderSchedule>;
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
        summaryCounts: summaryCounts,
        clinicalAlertThresholds: thresholds,
        providerSchedules: schedules,
        availabilitySlots: slots,
        lastFailure: firstFailure,
      ),
    );
  }

  void _startAdaptivePolling() {
    _adaptivePolling.start(
      intervalWhenDisconnected: _syncInterval,
      isRealtimeConnected: () => ref.read(realtimeServiceProvider).isConnected,
      onTick: () => unawaited(
        _syncVisibleData(
          plan: WorkspaceDisconnectPollPlan.forProfile(
            WorkspaceRefreshProfile.clinicalFlow,
          ),
        ),
      ),
    );
  }

  Future<AppFailure?> _syncVisibleData({
    bool showLoading = false,
    bool refreshProviders = false,
    WorkspaceRefreshPlan plan = WorkspaceRefreshPlan.full,
  }) async {
    if (plan.isEmpty) {
      return null;
    }
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }
    if (_isSyncing || current.isSaving) {
      _refreshPending = true;
      _pendingRefreshPlan = _mergePendingPlan(plan);
      return null;
    }

    _isSyncing = true;
    if (showLoading) {
      _emit(
        current.copyWith(
          isRefreshingAppointments: plan.appointments,
          isRefreshingQueue: plan.queue,
          isRefreshingFlows: plan.flows,
          isRefreshingTriageQueue: plan.triage,
          isRefreshingDetail:
              plan.selectedDetail && current.selectedFlow != null,
          clearLastFailure: true,
        ),
      );
    }

    try {
      final AppFailure? failure = await _refreshVisiblePages(
        showLoading: showLoading,
        plan: plan,
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
      if (_refreshPending && !(_currentState?.isSaving ?? false)) {
        unawaited(_flushPendingRefresh());
      }
    }
  }

  Future<AppFailure?> _refreshVisiblePages({
    required bool showLoading,
    required WorkspaceRefreshPlan plan,
  }) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      return null;
    }

    AppFailure? firstFailure;
    final List<Future<void>> refreshTasks = <Future<void>>[];

    if (plan.appointments) {
      refreshTasks.add(() async {
        final Result<AppPage<OpdAppointment>> result = await _repository
            .listAppointments(current.appointmentQuery);
        result.when(
          success: (AppPage<OpdAppointment> page) {
            final OpdWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(latest.copyWith(appointments: page));
            }
          },
          failure: (AppFailure failure) {
            firstFailure ??= failure;
          },
        );
      }());
    }

    if (plan.queue) {
      refreshTasks.add(() async {
        final Result<AppPage<OpdQueueEntry>> result = await _repository
            .listVisitQueues(current.queueQuery);
        result.when(
          success: (AppPage<OpdQueueEntry> page) {
            final OpdWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(latest.copyWith(queueEntries: page));
            }
          },
          failure: (AppFailure failure) {
            firstFailure ??= failure;
          },
        );
      }());
    }

    if (plan.flows) {
      refreshTasks.add(() async {
        final Result<AppPage<OpdFlowSummary>> result = await _repository
            .listOpdFlows(current.flowQuery);
        result.when(
          success: (AppPage<OpdFlowSummary> page) {
            final OpdWorkspaceState? latest = _currentState;
            if (latest == null) {
              return;
            }
            final AppPage<OpdFlowSummary> stablePage = _stableFlowPage(
              page,
              latest.flows,
            );
            final OpdFlowDetail? selected = _selectedAfterFlowRefresh(
              stablePage,
              latest.selectedFlow,
            );
            _emit(
              latest.copyWith(
                flows: stablePage,
                selectedFlow: selected,
                clearSelectedFlow: selected == null,
              ),
            );
          },
          failure: (AppFailure failure) {
            firstFailure ??= failure;
          },
        );
      }());
    }

    if (plan.triage) {
      refreshTasks.add(() async {
        final Result<AppPage<OpdFlowSummary>> result = await _repository
            .listTriageQueue(current.triageQueueQuery);
        result.when(
          success: (AppPage<OpdFlowSummary> page) {
            final OpdWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(
                latest.copyWith(
                  triageQueue: _stableFlowPage(page, latest.triageQueue),
                ),
              );
            }
          },
          failure: (AppFailure failure) {
            firstFailure ??= failure;
          },
        );
      }());
    }

    if (plan.summaryCounts) {
      refreshTasks.add(() async {
        final Result<OpdFlowAggregateCounts> result = await _repository
            .getOpdSummaryCounts();
        result.when(
          success: (OpdFlowAggregateCounts counts) {
            final OpdWorkspaceState? latest = _currentState;
            if (latest != null) {
              _emit(latest.copyWith(summaryCounts: counts));
            }
          },
          failure: (AppFailure failure) {
            firstFailure ??= failure;
          },
        );
      }());
    }

    if (plan.selectedDetail && current.selectedFlow != null) {
      final String flowId = current.selectedFlow!.summary.apiId;
      refreshTasks.add(() async {
        final Result<OpdFlowDetail> result = await _repository.getOpdFlow(
          flowId,
        );
        result.when(
          success: (OpdFlowDetail detail) {
            final OpdWorkspaceState? latest = _currentState;
            if (latest == null) {
              return;
            }
            _emit(
              latest.copyWith(
                selectedFlow: detail.summary.isTerminal ? null : detail,
                clearSelectedFlow: detail.summary.isTerminal,
                flows: _upsertOrRemoveFlow(latest.flows, detail.summary),
                triageQueue: _upsertOrRemoveTriageFlow(
                  latest.triageQueue,
                  detail.summary,
                ),
              ),
            );
          },
          failure: (_) {},
        );
      }());
    }

    if (refreshTasks.isNotEmpty) {
      await Future.wait<void>(refreshTasks);
    }

    final OpdWorkspaceState? latest = _currentState;
    if (latest != null && firstFailure != null) {
      _emit(latest.copyWith(lastFailure: firstFailure));
    }

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
    final List<Result<List<OpdAvailabilitySlot>>> results = await Future.wait(
      schedules
          .take(4)
          .map(
            (OpdProviderSchedule schedule) =>
                _repository.listAvailabilitySlots(schedule.apiId),
          ),
    );
    final List<OpdAvailabilitySlot> slots = <OpdAvailabilitySlot>[];
    for (final Result<List<OpdAvailabilitySlot>> result in results) {
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
      final AppFailure? failure = await refresh();
      if (failure != null) {
        return failure;
      }
      return _mutateAppointment(action);
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    final Result<OpdAppointment> result = await action();
    return result.when(
      success: (OpdAppointment appointment) async {
        final OpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(
            latest.copyWith(
              appointments: _upsertAppointment(
                latest.appointments,
                appointment,
              ),
              isSaving: false,
            ),
          );
        }
        await _flushPendingRefresh();
        return null;
      },
      failure: (AppFailure failure) async {
        final OpdWorkspaceState? latest = _currentState;
        if (latest != null) {
          _emit(latest.copyWith(isSaving: false, lastFailure: failure));
        }
        await _flushPendingRefresh();
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
        await _flushPendingRefresh();
        if (refreshFlowsAfter) {
          return _syncVisibleData(plan: WorkspaceRefreshPlan.flowWorkspace);
        }
        return null;
      },
      failure: (AppFailure failure) async {
        _emit(_currentState!.copyWith(isSaving: false, lastFailure: failure));
        await _flushPendingRefresh();
        return failure;
      },
    );
  }

  Future<AppFailure?> _mutateFlow(
    Future<Result<OpdFlowDetail>> Function() action,
  ) async {
    final Result<OpdFlowDetail> result = await _mutateFlowDetail(action);
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }

  Future<Result<OpdFlowDetail>> submitOpdEncounter(
    Map<String, Object?> payload,
  ) async {
    final String key = createIdempotencyKey();
    final bool forceNewEncounter = payload['force_new_encounter'] == true;
    final Object? existingEncounterId = payload['existing_encounter_id'];
    if (!forceNewEncounter &&
        existingEncounterId is String &&
        existingEncounterId.trim().isNotEmpty) {
      return _mutateFlowDetail(
        () => _repository.updateActiveEncounter(
          existingEncounterId.trim(),
          Map<String, Object?>.from(payload)
            ..remove('existing_encounter_id')
            ..remove('reuse_open_encounter'),
          idempotencyKey: key,
        ),
      );
    }

    return _mutateFlowDetail(
      () => _repository.startOpdFlow(<String, Object?>{
        'arrival_mode': 'WALK_IN',
        'queued_at': DateTime.now().toUtc().toIso8601String(),
        ...payload,
        'reuse_open_encounter': !forceNewEncounter,
      }, idempotencyKey: key),
    );
  }

  Future<Result<OpdFlowDetail>> cancelOpdEncounter(
    String flowId,
    Map<String, Object?> payload,
  ) {
    return _mutateFlowDetail(
      () => _repository.cancelEncounter(flowId, payload),
    );
  }

  Future<Result<OpdFlowDetail>> closeOpdEncounter(
    String flowId,
    Map<String, Object?> payload,
  ) {
    return _mutateFlowDetail(() => _repository.closeEncounter(flowId, payload));
  }

  /// Patches flows/triage from an already-persisted detail when this workspace
  /// is loaded. No-op when unloaded so patient-registry callers do not bootstrap
  /// OPD solely to sync.
  void applyFlowDetailPatchIfLoaded(OpdFlowDetail detail) {
    final OpdWorkspaceState? latest = _currentState;
    if (latest == null) {
      return;
    }
    _emit(
      _patchLinkedEncounterSources(
        latest.copyWith(
          selectedFlow: detail.summary.isTerminal ? null : detail,
          clearSelectedFlow: detail.summary.isTerminal,
          flows: _upsertOrRemoveFlow(latest.flows, detail.summary),
          triageQueue: _upsertOrRemoveTriageFlow(
            latest.triageQueue,
            detail.summary,
          ),
        ),
        detail.summary,
      ),
    );
  }

  /// Refresh Reception Payment gate when Start/Edit/Cancel OPD changes payables.
  /// Billing workspace follows via BILLING_EVENTS (avoids an OPD↔Billing import cycle).
  void _syncLinkedBillingSurfacesAfterConsultationChange(OpdFlowSummary summary) {
    final bool affectsBilling =
        summary.consultationInvoiceId != null ||
        summary.consultationPaymentRequired ||
        summary.isTerminal;
    if (!affectsBilling) {
      return;
    }
    if (!ref.exists(receptionPaymentGateControllerProvider)) {
      return;
    }
    unawaited(
      ref.read(receptionPaymentGateControllerProvider.notifier).refresh(),
    );
  }

  /// Clears Payment-due consultation fields when Billing settles the invoice.
  void applyConsultationInvoicePaidIfLoaded(BillingWorkItem invoice) {
    final OpdWorkspaceState? latest = _currentState;
    if (latest == null || invoice.balanceDue > 0) {
      return;
    }

    OpdFlowSummary? match;
    for (final OpdFlowSummary flow in latest.flows.items) {
      if (_flowMatchesConsultationInvoice(flow, invoice)) {
        match = flow;
        break;
      }
    }
    if (match == null) {
      for (final OpdFlowSummary flow in latest.triageQueue.items) {
        if (_flowMatchesConsultationInvoice(flow, invoice)) {
          match = flow;
          break;
        }
      }
    }
    if (match == null &&
        latest.selectedFlow != null &&
        _flowMatchesConsultationInvoice(latest.selectedFlow!.summary, invoice)) {
      match = latest.selectedFlow!.summary;
    }
    if (match == null) {
      return;
    }

    final bool advanceFromPaymentDue =
        (match.stage ?? '').toUpperCase() == 'WAITING_CONSULTATION_PAYMENT' ||
        (match.displayCode ?? '').toUpperCase() == 'PAYMENT_DUE';
    final OpdFlowSummary patched = match.copyWith(
      consultationPaid: true,
      consultationPaymentStatus: 'PAID',
      consultationPaidAmount:
          invoice.paidAmount > 0 ? invoice.paidAmount : match.consultationFee,
      consultationInvoiceId:
          match.consultationInvoiceId ?? invoice.displayId ?? invoice.id,
      stage: advanceFromPaymentDue ? 'WAITING_VITALS' : match.stage,
      nextStep: advanceFromPaymentDue ? 'RECORD_VITALS' : match.nextStep,
      displayCode: advanceFromPaymentDue ? 'VITALS_NEEDED' : match.displayCode,
      displayStatus: advanceFromPaymentDue
          ? 'Vitals needed'
          : match.displayStatus,
      displayNextStep: advanceFromPaymentDue
          ? 'Record vitals'
          : match.displayNextStep,
    );

    OpdFlowDetail? selected = latest.selectedFlow;
    if (selected != null &&
        _matchesPublicIdentifier(patched.id, <String?>[
          selected.summary.id,
          selected.summary.publicId,
          selected.summary.apiId,
        ])) {
      selected = OpdFlowDetail(
        summary: patched,
        consultationInvoiceId: patched.consultationInvoiceId,
        consultationPaymentId: patched.consultationPaymentId,
        consultationPaymentStatus: patched.consultationPaymentStatus,
        consultationPaid: true,
        consultationPaymentRequired: selected.consultationPaymentRequired,
        consultationPaidAmount: patched.consultationPaidAmount,
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

    _emit(
      _patchLinkedEncounterSources(
        latest.copyWith(
          selectedFlow: selected,
          flows: _upsertOrRemoveFlow(latest.flows, patched),
          triageQueue: _upsertOrRemoveTriageFlow(latest.triageQueue, patched),
        ),
        patched,
      ),
    );
  }

  bool _flowMatchesConsultationInvoice(
    OpdFlowSummary flow,
    BillingWorkItem invoice,
  ) {
    final Set<String> invoiceKeys = <String>{
      invoice.id,
      if (invoice.displayId != null) invoice.displayId!,
      if (invoice.invoiceDisplayId != null) invoice.invoiceDisplayId!,
    }
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final String? linked = flow.consultationInvoiceId?.trim().toLowerCase();
    if (linked != null && linked.isNotEmpty && invoiceKeys.contains(linked)) {
      return true;
    }
    final Set<String> encounterKeys = <String>{
      if (invoice.encounterId != null) invoice.encounterId!,
      if (invoice.encounterDisplayId != null) invoice.encounterDisplayId!,
    }
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    if (encounterKeys.isEmpty) {
      return false;
    }
    return encounterKeys.contains(flow.id.trim().toLowerCase()) ||
        encounterKeys.contains((flow.publicId ?? '').trim().toLowerCase()) ||
        encounterKeys.contains(flow.apiId.trim().toLowerCase());
  }

  OpdWorkspaceState _patchLinkedEncounterSources(
    OpdWorkspaceState state,
    OpdFlowSummary flow,
  ) {
    final bool terminal =
        flow.isTerminal || isOpdTerminalStatus(flow.status ?? flow.stage);
    final bool cancelled = (flow.status ?? '').toUpperCase() == 'CANCELLED';
    final String appointmentStatus = terminal
        ? cancelled
              ? 'NO_SHOW'
              : 'COMPLETED'
        : 'IN_PROGRESS';
    final String queueStatus = terminal
        ? cancelled
              ? 'CANCELLED'
              : 'COMPLETED'
        : 'IN_PROGRESS';

    return state.copyWith(
      appointments: _patchLinkedAppointment(
        state.appointments,
        flow.appointmentId,
        appointmentStatus,
      ),
      queueEntries: _patchLinkedQueueEntry(
        state.queueEntries,
        flow.visitQueueId,
        queueStatus,
      ),
    );
  }

  AppPage<OpdAppointment> _patchLinkedAppointment(
    AppPage<OpdAppointment> page,
    String? appointmentId,
    String status,
  ) {
    if (appointmentId == null || appointmentId.trim().isEmpty) {
      return page;
    }
    var changed = false;
    final List<OpdAppointment> items = page.items
        .map((appointment) {
          if (!_matchesPublicIdentifier(appointmentId, <String?>[
            appointment.id,
            appointment.publicId,
            appointment.apiId,
          ])) {
            return appointment;
          }
          changed = true;
          return appointment.copyWith(status: status);
        })
        .toList(growable: false);
    return changed
        ? AppPage<OpdAppointment>(
            items: items,
            request: page.request,
            totalItemCount: page.totalItemCount,
          )
        : page;
  }

  AppPage<OpdQueueEntry> _patchLinkedQueueEntry(
    AppPage<OpdQueueEntry> page,
    String? queueId,
    String status,
  ) {
    if (queueId == null || queueId.trim().isEmpty) {
      return page;
    }
    var changed = false;
    final List<OpdQueueEntry> items = page.items
        .map((entry) {
          if (!_matchesPublicIdentifier(queueId, <String?>[
            entry.id,
            entry.publicId,
            entry.apiId,
          ])) {
            return entry;
          }
          changed = true;
          return entry.copyWith(status: status);
        })
        .toList(growable: false);
    return changed
        ? AppPage<OpdQueueEntry>(
            items: items,
            request: page.request,
            totalItemCount: page.totalItemCount,
          )
        : page;
  }

  AppPage<OpdQueueEntry> _patchLinkedQueueProvider(
    AppPage<OpdQueueEntry> page,
    String queueId, {
    required String providerUserId,
    String? providerDisplayName,
  }) {
    var changed = false;
    final List<OpdQueueEntry> items = page.items
        .map((OpdQueueEntry entry) {
          if (!_matchesPublicIdentifier(queueId, <String?>[
            entry.id,
            entry.publicId,
            entry.apiId,
          ])) {
            return entry;
          }
          changed = true;
          return entry.copyWith(
            providerUserId: providerUserId,
            providerDisplayName: providerDisplayName,
          );
        })
        .toList(growable: false);
    return changed
        ? AppPage<OpdQueueEntry>(
            items: items,
            request: page.request,
            totalItemCount: page.totalItemCount,
          )
        : page;
  }

  bool _matchesPublicIdentifier(String expected, Iterable<String?> values) {
    final String normalized = expected.trim().toUpperCase();
    return values.any((value) => value?.trim().toUpperCase() == normalized);
  }

  Future<Result<OpdFlowDetail>> _mutateFlowDetail(
    Future<Result<OpdFlowDetail>> Function() action,
  ) async {
    final OpdWorkspaceState? current = _currentState;
    if (current == null) {
      final AppFailure? failure = await refresh();
      if (failure != null) {
        return Result<OpdFlowDetail>.failure(failure);
      }
      return _mutateFlowDetail(action);
    }

    _emit(current.copyWith(isSaving: true, clearLastFailure: true));
    try {
      final Result<OpdFlowDetail> result = await action();
      return result.when(
        success: (OpdFlowDetail detail) async {
          final OpdWorkspaceState? latest = _currentState;
          if (latest != null) {
            _emit(
              _patchLinkedEncounterSources(
                latest.copyWith(
                  selectedFlow: detail.summary.isTerminal ? null : detail,
                  clearSelectedFlow: detail.summary.isTerminal,
                  flows: _upsertOrRemoveFlow(latest.flows, detail.summary),
                  triageQueue: _upsertOrRemoveTriageFlow(
                    latest.triageQueue,
                    detail.summary,
                  ),
                  isSaving: false,
                  clearLastFailure: true,
                ),
                detail.summary,
              ),
            );
          }
          _syncLinkedBillingSurfacesAfterConsultationChange(detail.summary);
          // Background refresh must not turn a persisted mutation into a
          // user-visible failure (e.g. after assign-doctor succeeds).
          try {
            await _flushPendingRefresh();
          } catch (_) {}
          final OpdWorkspaceState? afterFlush = _currentState;
          if (afterFlush?.lastFailure != null) {
            _emit(afterFlush!.copyWith(clearLastFailure: true));
          }
          return Result<OpdFlowDetail>.success(detail);
        },
        failure: (AppFailure failure) async {
          _emitMutationFailure(failure);
          try {
            await _flushPendingRefresh();
          } catch (_) {}
          if (failure.category == AppFailureCategory.notFound) {
            unawaited(
              _syncVisibleData(
                showLoading: true,
                plan: WorkspaceRefreshPlan.flowWorkspace,
              ),
            );
          }
          return Result<OpdFlowDetail>.failure(failure);
        },
      );
    } catch (error, stackTrace) {
      final AppFailure failure = mapToFailure(error, stackTrace);
      _emitMutationFailure(failure);
      try {
        await _flushPendingRefresh();
      } catch (_) {}
      return Result<OpdFlowDetail>.failure(failure);
    }
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
    try {
      final Result<void> result = await action();
      return result.when(
        success: (_) async {
          final Result<OpdFlowDetail> detailResult = await _repository
              .getOpdFlow(flow.apiId);
          return detailResult.when(
            success: (OpdFlowDetail detail) async {
              final OpdWorkspaceState? latest = _currentState;
              if (latest != null) {
                _emit(
                  latest.copyWith(
                    selectedFlow: detail,
                    flows: _replaceFlow(latest.flows, detail.summary),
                    isSaving: false,
                  ),
                );
              }
              await _flushPendingRefresh();
              return null;
            },
            failure: (AppFailure failure) async {
              _emitMutationFailure(failure);
              await _flushPendingRefresh();
              return failure;
            },
          );
        },
        failure: (AppFailure failure) async {
          _emitMutationFailure(failure);
          await _flushPendingRefresh();
          return failure;
        },
      );
    } catch (error, stackTrace) {
      final AppFailure failure = mapToFailure(error, stackTrace);
      _emitMutationFailure(failure);
      await _flushPendingRefresh();
      return failure;
    }
  }

  void _emitMutationFailure(AppFailure failure) {
    final OpdWorkspaceState? latest = _currentState;
    if (latest != null) {
      _emit(latest.copyWith(isSaving: false, lastFailure: failure));
    }
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
          summary: _mergeFlowSummaryPreferringAssignedStaff(
            previous: selected.summary,
            next: flow,
          ),
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

  /// List/realtime snapshots sometimes omit provider relations and fall back to
  /// placeholder assigned-staff labels. Keep richer detail values in that case.
  OpdFlowSummary _mergeFlowSummaryPreferringAssignedStaff({
    required OpdFlowSummary previous,
    required OpdFlowSummary next,
  }) {
    final bool nextLabelIsPlaceholder = _isAssignedStaffPlaceholder(
      next.assignedStaffLabel,
    );
    final bool previousHasStaff =
        _hasAssignedStaffSignal(previous) &&
        !_isAssignedStaffPlaceholder(previous.assignedStaffLabel);

    if (!nextLabelIsPlaceholder || !previousHasStaff) {
      return next.copyWith(
        providerUserId: next.providerUserId ?? previous.providerUserId,
        providerDisplayName:
            next.providerDisplayName ?? previous.providerDisplayName,
        assignedStaffDisplayName:
            next.assignedStaffDisplayName ?? previous.assignedStaffDisplayName,
        assignedStaffRole: next.assignedStaffRole ?? previous.assignedStaffRole,
        assignedStaffType: next.assignedStaffType ?? previous.assignedStaffType,
        assignedStaffLabel: nextLabelIsPlaceholder
            ? previous.assignedStaffLabel
            : (next.assignedStaffLabel ?? previous.assignedStaffLabel),
        visitQueueId: next.visitQueueId ?? previous.visitQueueId,
      );
    }

    return next.copyWith(
      providerUserId: next.providerUserId ?? previous.providerUserId,
      providerDisplayName:
          previous.providerDisplayName ?? next.providerDisplayName,
      assignedStaffDisplayName:
          previous.assignedStaffDisplayName ?? next.assignedStaffDisplayName,
      assignedStaffRole: previous.assignedStaffRole ?? next.assignedStaffRole,
      assignedStaffType: previous.assignedStaffType ?? next.assignedStaffType,
      assignedStaffLabel:
          previous.assignedStaffLabel ?? next.assignedStaffLabel,
      visitQueueId: next.visitQueueId ?? previous.visitQueueId,
    );
  }

  bool _hasAssignedStaffSignal(OpdFlowSummary flow) {
    return (flow.providerUserId ?? '').trim().isNotEmpty ||
        (flow.providerDisplayName ?? '').trim().isNotEmpty ||
        (flow.assignedStaffDisplayName ?? '').trim().isNotEmpty ||
        (flow.assignedStaffLabel ?? '').trim().isNotEmpty;
  }

  bool _isAssignedStaffPlaceholder(String? label) {
    final String normalized = (label ?? '').trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'assigned staff unknown' ||
        normalized == 'doctor needed' ||
        normalized == 'with doctor' ||
        normalized == 'doctor assigned';
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
    final bool existed = page.items.any(
      (OpdAppointment item) => _sameAppointment(item, appointment),
    );
    final List<OpdAppointment> items = page.items
        .where((OpdAppointment item) => !_sameAppointment(item, appointment))
        .toList(growable: true);
    items.insert(0, appointment);
    return AppPage<OpdAppointment>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! + (existed ? 0 : 1),
    );
  }

  bool _sameAppointment(OpdAppointment left, OpdAppointment right) {
    if (left.id.isNotEmpty && left.id == right.id) {
      return true;
    }
    final String? leftPublic = left.publicId?.trim();
    final String? rightPublic = right.publicId?.trim();
    if (leftPublic != null &&
        leftPublic.isNotEmpty &&
        rightPublic != null &&
        rightPublic.isNotEmpty &&
        leftPublic.toUpperCase() == rightPublic.toUpperCase()) {
      return true;
    }
    return left.apiId.isNotEmpty &&
        left.apiId.toUpperCase() == right.apiId.toUpperCase();
  }

  AppPage<OpdQueueEntry> _upsertQueueEntry(
    AppPage<OpdQueueEntry> page,
    OpdQueueEntry entry,
  ) {
    final List<OpdQueueEntry> items = page.items
        .where((OpdQueueEntry item) => item.id != entry.id)
        .toList(growable: true);
    items.add(entry);
    items.sort(_compareQueueEntries);
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

  static int _compareQueueEntries(OpdQueueEntry a, OpdQueueEntry b) {
    if (a.isPrioritized != b.isPrioritized) {
      return a.isPrioritized ? -1 : 1;
    }
    final DateTime? aQueued = a.queuedAt;
    final DateTime? bQueued = b.queuedAt;
    if (aQueued == null && bQueued == null) {
      return 0;
    }
    if (aQueued == null) {
      return 1;
    }
    if (bQueued == null) {
      return -1;
    }
    return aQueued.compareTo(bQueued);
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

  String _dispositionReviewNote(Map<String, Object?> payload) {
    final String decision = (payload['decision'] ?? '').toString().trim();
    final String reason = (payload['reason'] ?? '').toString().trim();
    final String notes = (payload['notes'] ?? '').toString().trim();
    final List<String> parts = <String>[
      if (decision.isNotEmpty) decision,
      if (reason.isNotEmpty) reason,
      if (notes.isNotEmpty) notes,
    ];
    return parts.isEmpty ? 'Disposition review' : parts.join(' - ');
  }

  AppFailure? _failureOrNull<T>(Result<T> result) {
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
  }
}
