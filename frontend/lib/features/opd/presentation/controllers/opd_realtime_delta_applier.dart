import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';
import 'package:hosspi_hms/features/opd/data/dtos/opd_dtos.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Applies OPD workspace realtime deltas without HTTP when payload is sufficient.
abstract final class OpdRealtimeDeltaApplier {
  static OpdWorkspaceState? apply(
    OpdWorkspaceState state,
    RealtimeDelta delta,
  ) {
    if (delta.action == RealtimeSyncAction.remove) {
      return _applyRemove(state, delta);
    }

    final Map<String, Object?>? listEntry = delta.listEntry;
    if (listEntry != null) {
      return _applyFlowListEntry(state, listEntry);
    }

    final Map<String, Object?>? entity = delta.entity;
    if (entity != null) {
      if (delta.resourceType == 'visit_queue' ||
          entity.containsKey('queued_at')) {
        return _applyQueueEntity(state, entity);
      }
      if (entity.containsKey('scheduled_start')) {
        return _applyAppointmentEntity(state, entity);
      }
    }

    if (delta.partialFlowSummary != null && delta.encounterId != null) {
      return _applyPartialFlowSummary(
        state,
        encounterId: delta.encounterId!,
        summary: delta.partialFlowSummary!,
      );
    }

    return null;
  }

  static OpdWorkspaceState? _applyRemove(
    OpdWorkspaceState state,
    RealtimeDelta delta,
  ) {
    final String? id = delta.resourceId;
    if (id == null || id.isEmpty) {
      return null;
    }

    if (delta.resourceType == 'visit_queue') {
      return state.copyWith(
        queueEntries: _removeQueueEntry(state.queueEntries, id),
      );
    }

    final bool clearsSelection =
        state.selectedFlow != null &&
        _flowMatchesId(state.selectedFlow!.summary, id);
    return state.copyWith(
      flows: _removeFlowById(state.flows, id),
      triageQueue: _removeFlowById(state.triageQueue, id),
      selectedFlow: clearsSelection ? null : state.selectedFlow,
      clearSelectedFlow: clearsSelection,
    );
  }

  static OpdWorkspaceState _applyFlowListEntry(
    OpdWorkspaceState state,
    Map<String, Object?> listEntry,
  ) {
    final OpdFlowSummary flow = OpdFlowSummaryDto.fromListEntry(
      listEntry,
    ).toEntity();
    if (flow.id.isEmpty) {
      return state;
    }
    return _applyFlowSummary(state, flow);
  }

  static OpdWorkspaceState? _applyQueueEntity(
    OpdWorkspaceState state,
    Map<String, Object?> entity,
  ) {
    final OpdQueueEntry entry = OpdQueueEntryDto(entity).toEntity();
    if (entry.id.isEmpty) {
      return null;
    }
    return state.copyWith(
      queueEntries: _upsertQueueEntry(state.queueEntries, entry),
    );
  }

  static OpdWorkspaceState? _applyAppointmentEntity(
    OpdWorkspaceState state,
    Map<String, Object?> entity,
  ) {
    final OpdAppointment appointment = OpdAppointmentDto(entity).toEntity();
    if (appointment.id.isEmpty) {
      return null;
    }
    return state.copyWith(
      appointments: _upsertAppointment(state.appointments, appointment),
    );
  }

  static OpdWorkspaceState? _applyPartialFlowSummary(
    OpdWorkspaceState state, {
    required String encounterId,
    required Map<String, Object?> summary,
  }) {
    final OpdFlowSummary? existing = _findFlow(state.flows, encounterId);
    if (existing == null) {
      return null;
    }

    final OpdFlowSummary patched = existing.copyWith(
      stage: _string(summary['stage']) ?? existing.stage,
      nextStep: _string(summary['next_step']) ?? existing.nextStep,
      displayCode: _string(summary['display_code']) ?? existing.displayCode,
      displayStatus:
          _string(summary['display_status']) ?? existing.displayStatus,
      displayNextStep:
          _string(summary['display_next_step']) ??
          _string(summary['next_step']) ??
          existing.displayNextStep,
      assignedStaffRole:
          _string(summary['assigned_staff_role']) ?? existing.assignedStaffRole,
      assignedStaffType:
          _string(summary['assigned_staff_type']) ?? existing.assignedStaffType,
      assignedStaffLabel:
          _string(summary['assigned_staff_label']) ??
          existing.assignedStaffLabel,
    );
    return _applyFlowSummary(state, patched);
  }

  static OpdWorkspaceState _applyFlowSummary(
    OpdWorkspaceState state,
    OpdFlowSummary flow,
  ) {
    final OpdFlowDetail? selected = state.selectedFlow;
    final bool matchesSelected =
        selected != null && _sameFlow(selected.summary, flow);

    return state.copyWith(
      flows: _upsertFlow(state.flows, flow),
      triageQueue: _upsertOrRemoveTriageFlow(state.triageQueue, flow),
      selectedFlow: matchesSelected
          ? (flow.isTerminal ? null : _detailWithSummary(selected, flow))
          : state.selectedFlow,
      clearSelectedFlow: matchesSelected && flow.isTerminal,
    );
  }

  static OpdFlowDetail _detailWithSummary(
    OpdFlowDetail detail,
    OpdFlowSummary summary,
  ) {
    return OpdFlowDetail(
      summary: summary,
      consultationInvoiceId: detail.consultationInvoiceId,
      consultationPaymentId: detail.consultationPaymentId,
      consultationPaymentStatus: detail.consultationPaymentStatus,
      consultationPaid: detail.consultationPaid,
      consultationPaymentRequired: detail.consultationPaymentRequired,
      consultationPaidAmount: detail.consultationPaidAmount,
      timeline: detail.timeline,
      referrals: detail.referrals,
      followUps: detail.followUps,
      clinicalAlerts: detail.clinicalAlerts,
      clinicalAlertDetails: detail.clinicalAlertDetails,
      vitalSigns: detail.vitalSigns,
      vitalMeasurements: detail.vitalMeasurements,
      clinicalNotes: detail.clinicalNotes,
      diagnoses: detail.diagnoses,
      procedures: detail.procedures,
      labOrders: detail.labOrders,
      radiologyOrders: detail.radiologyOrders,
      pharmacyOrders: detail.pharmacyOrders,
      admissions: detail.admissions,
    );
  }

  static OpdFlowSummary? _findFlow(AppPage<OpdFlowSummary> page, String id) {
    for (final OpdFlowSummary flow in page.items) {
      if (_flowMatchesId(flow, id)) {
        return flow;
      }
    }
    return null;
  }

  static bool _flowMatchesId(OpdFlowSummary flow, String id) {
    return flow.id == id ||
        flow.apiId == id ||
        (flow.publicId != null && flow.publicId == id);
  }

  static bool _sameFlow(OpdFlowSummary left, OpdFlowSummary right) {
    return left.id == right.id ||
        (left.publicId != null && left.publicId == right.publicId);
  }

  static AppPage<OpdAppointment> _upsertAppointment(
    AppPage<OpdAppointment> page,
    OpdAppointment appointment,
  ) {
    final List<OpdAppointment> items = List<OpdAppointment>.from(page.items);
    final int index = items.indexWhere(
      (OpdAppointment item) => _sameAppointment(item, appointment),
    );
    if (index >= 0) {
      items[index] = appointment;
    } else {
      items.insert(0, appointment);
    }
    return AppPage<OpdAppointment>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  static bool _sameAppointment(OpdAppointment left, OpdAppointment right) {
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

  static AppPage<OpdQueueEntry> _upsertQueueEntry(
    AppPage<OpdQueueEntry> page,
    OpdQueueEntry entry,
  ) {
    final List<OpdQueueEntry> items = List<OpdQueueEntry>.from(page.items);
    final int index = items.indexWhere(
      (OpdQueueEntry item) => item.id == entry.id,
    );
    if (index >= 0) {
      items[index] = entry;
    } else {
      items.insert(0, entry);
    }
    return AppPage<OpdQueueEntry>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  static AppPage<OpdQueueEntry> _removeQueueEntry(
    AppPage<OpdQueueEntry> page,
    String id,
  ) {
    return AppPage<OpdQueueEntry>(
      items: page.items
          .where(
            (OpdQueueEntry item) =>
                item.id != id && item.apiId != id && item.publicId != id,
          )
          .toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  static AppPage<OpdFlowSummary> _upsertFlow(
    AppPage<OpdFlowSummary> page,
    OpdFlowSummary flow,
  ) {
    final List<OpdFlowSummary> items = List<OpdFlowSummary>.from(page.items);
    final int index = items.indexWhere(
      (OpdFlowSummary item) => _sameFlow(item, flow),
    );
    if (index >= 0) {
      items[index] = flow;
    } else {
      items.insert(0, flow);
    }
    return AppPage<OpdFlowSummary>(
      items: items.take(page.request.pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  static AppPage<OpdFlowSummary> _upsertOrRemoveTriageFlow(
    AppPage<OpdFlowSummary> page,
    OpdFlowSummary flow,
  ) {
    if (!_isTriageFlow(flow)) {
      return _removeFlowById(page, flow.id);
    }
    return _upsertFlow(page, flow);
  }

  static bool _isTriageFlow(OpdFlowSummary flow) {
    final String? stage = flow.stage?.toUpperCase();
    return stage == 'WAITING_VITALS' ||
        stage == 'WAITING_DOCTOR_ASSIGNMENT' ||
        flow.triageLevel != null;
  }

  static AppPage<OpdFlowSummary> _removeFlowById(
    AppPage<OpdFlowSummary> page,
    String id,
  ) {
    return AppPage<OpdFlowSummary>(
      items: page.items
          .where((OpdFlowSummary item) => !_flowMatchesId(item, id))
          .toList(growable: false),
      request: page.request,
      totalItemCount: page.totalItemCount,
    );
  }

  static String? _string(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
