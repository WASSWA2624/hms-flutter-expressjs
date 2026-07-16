import 'package:flutter/foundation.dart';

/// Deep-link / filter targeting for the Reception front-desk workspace.
@immutable
final class ReceptionWorkspaceQuery {
  const ReceptionWorkspaceQuery({
    this.section = '',
    this.search = '',
    this.patientId = '',
    this.flowId = '',
  });

  factory ReceptionWorkspaceQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    String pick(List<String> keys) {
      for (final String key in keys) {
        final String value = (params[key] ?? '').trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    return ReceptionWorkspaceQuery(
      section: pick(<String>['section', 'panel', 'filter', 'queue']),
      search: pick(<String>['search', 'q', 'patient']),
      patientId: pick(<String>['patientId', 'patient_id']),
      flowId: pick(<String>['flowId', 'flow_id', 'encounter', 'id']),
    );
  }

  final String section;
  final String search;
  final String patientId;
  final String flowId;

  bool get hasRouteTargeting =>
      section.isNotEmpty ||
      search.isNotEmpty ||
      patientId.isNotEmpty ||
      flowId.isNotEmpty;

  String get signature => '$section|$search|$patientId|$flowId';
}

/// Desk worklist sections for high-volume reception workflows.
enum ReceptionDeskSection { appointments, queue, activeVisits, paymentGate }

/// Canonical `section` query value written by the Reception workspace URL.
String receptionDeskSectionToQueryValue(ReceptionDeskSection section) {
  return switch (section) {
    ReceptionDeskSection.appointments => 'appointments',
    ReceptionDeskSection.queue => 'desk-queue',
    ReceptionDeskSection.activeVisits => 'active',
    ReceptionDeskSection.paymentGate => 'payment-gate',
  };
}

/// Resolves a deep-link / alias `section` query value to a desk section.
ReceptionDeskSection? receptionDeskSectionFromQuery(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'appointments':
    case 'meetings':
      return ReceptionDeskSection.appointments;
    case 'queue':
    case 'desk_queue':
    case 'desk-queue':
      return ReceptionDeskSection.queue;
    case 'in-progress':
    case 'active':
    case 'visits':
    case 'turnaround_pressure':
      return ReceptionDeskSection.activeVisits;
    case 'payment':
    case 'payment-gate':
    case 'follow-up':
    case 'no_show_pressure':
      return ReceptionDeskSection.paymentGate;
    default:
      return null;
  }
}
