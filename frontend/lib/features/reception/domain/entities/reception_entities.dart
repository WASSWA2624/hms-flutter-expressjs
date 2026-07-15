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
