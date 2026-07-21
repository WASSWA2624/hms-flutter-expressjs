import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Primary reception/OPD appointment action derived from status + open visit.
enum OpdAppointmentPrimaryAction {
  /// Patient may start a new OPD encounter.
  startEncounter,

  /// An open OPD/Emergency encounter already exists; continue that visit.
  continueEncounter,

  /// Add the appointment to the desk queue.
  queue,

  /// Reschedule the appointment.
  reschedule,

  /// No appointment action (terminal or empty).
  none,
}

bool isOpdAppointmentStatusTerminal(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}

/// Resolves an open OPD/Emergency flow linked to [appointment], when present.
///
/// Match order: appointment id → unique patient id among active flows.
OpdFlowSummary? findActiveOpdFlowForAppointment({
  required OpdAppointment appointment,
  required Iterable<OpdFlowSummary> flows,
}) {
  final List<OpdFlowSummary> activeFlows = flows
      .where((OpdFlowSummary flow) => !flow.isTerminal)
      .toList(growable: false);

  final Set<String> appointmentIds = <String>{
    appointment.id,
    appointment.apiId,
    if (appointment.publicId case final String publicId) publicId,
  }.map(_normalizeId).where((String id) => id.isNotEmpty).toSet();

  if (appointmentIds.isNotEmpty) {
    for (final OpdFlowSummary flow in activeFlows) {
      final String flowAppointmentId = _normalizeId(flow.appointmentId);
      if (flowAppointmentId.isNotEmpty &&
          appointmentIds.contains(flowAppointmentId)) {
        return flow;
      }
    }
  }

  final String patientId = _normalizeId(appointment.patientId);
  if (patientId.isEmpty) {
    return null;
  }

  final List<OpdFlowSummary> patientFlows = activeFlows
      .where(
        (OpdFlowSummary flow) =>
            _normalizeId(flow.patientId) == patientId ||
            _normalizeId(flow.patientIdentifier) == patientId,
      )
      .toList(growable: false);
  return patientFlows.length == 1 ? patientFlows.single : null;
}

/// Derives the primary next action for an appointment row or actions hub.
OpdAppointmentPrimaryAction resolveOpdAppointmentPrimaryAction({
  required OpdAppointment appointment,
  OpdFlowSummary? linkedFlow,
  bool alreadyQueued = false,
}) {
  final String status = (appointment.status ?? '').toUpperCase();
  if (isOpdAppointmentStatusTerminal(status)) {
    return OpdAppointmentPrimaryAction.none;
  }

  if (linkedFlow != null) {
    return OpdAppointmentPrimaryAction.continueEncounter;
  }

  if (status != 'IN_PROGRESS' && status != 'COMPLETED') {
    return OpdAppointmentPrimaryAction.startEncounter;
  }

  if (!alreadyQueued &&
      status != 'IN_PROGRESS' &&
      appointment.patientId != null) {
    return OpdAppointmentPrimaryAction.queue;
  }

  return OpdAppointmentPrimaryAction.reschedule;
}

/// Localized next-action label for [resolveOpdAppointmentPrimaryAction].
String? opdAppointmentPrimaryActionLabel(
  AppLocalizations l10n,
  OpdAppointmentPrimaryAction action,
) {
  return switch (action) {
    OpdAppointmentPrimaryAction.startEncounter => l10n.opdCheckInAction,
    OpdAppointmentPrimaryAction.continueEncounter =>
      l10n.opdContinueEncounterAction,
    OpdAppointmentPrimaryAction.queue => l10n.opdQueueAction,
    OpdAppointmentPrimaryAction.reschedule => l10n.opdRescheduleAction,
    OpdAppointmentPrimaryAction.none => null,
  };
}

/// Current-step label: prefer linked open-flow stage over appointment status.
String opdAppointmentCurrentStepLabel(
  AppLocalizations l10n, {
  required OpdAppointment appointment,
  OpdFlowSummary? linkedFlow,
}) {
  if (linkedFlow != null) {
    return opdStatusDisplayLabel(l10n, linkedFlow);
  }
  return opdStageDisplayLabel(l10n, appointment.status ?? '');
}

String _normalizeId(String? value) => (value ?? '').trim().toUpperCase();
