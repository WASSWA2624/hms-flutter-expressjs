import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Primary reception/OPD appointment action derived from status + open visit.
enum OpdAppointmentPrimaryAction {
  /// Patient may start a new OPD encounter.
  startEncounter,

  /// An open OPD/Emergency encounter already exists; continue that visit.
  continueEncounter,

  /// Reschedule the appointment.
  reschedule,

  /// Close the booking out as done. Visitor meetings never become an OPD
  /// encounter, and a desk booking handled off-flow still has to reach a
  /// terminal status instead of sitting on the worklist forever.
  complete,

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

  // Fallback for snapshots whose flow omits the appointment id. Only an
  // appointment the server has already moved to IN_PROGRESS can be the one
  // that flow is serving, so a booking still sitting at SCHEDULED is never
  // hidden behind an unrelated visit the same patient happens to have open.
  if (_normalizeId(appointment.status) != 'IN_PROGRESS') {
    return null;
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
}) {
  final String status = (appointment.status ?? '').toUpperCase();
  if (isOpdAppointmentStatusTerminal(status)) {
    return OpdAppointmentPrimaryAction.none;
  }

  // A visitor has no patient record and so can never be checked into an OPD
  // encounter; closing the meeting out is the only step left for it.
  if (appointment.isVisitorMeeting) {
    return OpdAppointmentPrimaryAction.complete;
  }

  if (linkedFlow != null) {
    return OpdAppointmentPrimaryAction.continueEncounter;
  }

  if (status != 'IN_PROGRESS' && status != 'COMPLETED') {
    return OpdAppointmentPrimaryAction.startEncounter;
  }

  return OpdAppointmentPrimaryAction.reschedule;
}

/// Whether Reception may cancel [appointment] (pre-encounter only).
bool canCancelOpdAppointment({
  required OpdAppointment appointment,
  OpdFlowSummary? linkedFlow,
}) {
  if (isOpdAppointmentStatusTerminal(appointment.status)) {
    return false;
  }
  return linkedFlow == null;
}

/// Whether the desk may close [appointment] out as completed.
///
/// Once an encounter is running, the encounter's own closure is what completes
/// the booking (the server does it), so completing it by hand here would only
/// desync the two. Everything else — visitor meetings, and bookings handled
/// without an OPD flow — has no other way to reach a terminal status.
bool canCompleteOpdAppointment({
  required OpdAppointment appointment,
  OpdFlowSummary? linkedFlow,
}) {
  if (isOpdAppointmentStatusTerminal(appointment.status)) {
    return false;
  }
  return linkedFlow == null;
}

/// Whether [appointment] belongs on Reception's Appointments worklist.
///
/// Pre-encounter bookings only: non-terminal and no linked active encounter.
bool isReceptionPreEncounterAppointment({
  required OpdAppointment appointment,
  required Iterable<OpdFlowSummary> flows,
}) {
  if (isOpdAppointmentStatusTerminal(appointment.status)) {
    return false;
  }
  return findActiveOpdFlowForAppointment(
        appointment: appointment,
        flows: flows,
      ) ==
      null;
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
    OpdAppointmentPrimaryAction.reschedule => l10n.opdRescheduleAction,
    OpdAppointmentPrimaryAction.complete => l10n.opdCompleteAppointmentAction,
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
