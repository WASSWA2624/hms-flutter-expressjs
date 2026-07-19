import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';

const Set<String> receptionPaymentGateStages = <String>{
  'WAITING_CONSULTATION_PAYMENT',
};

/// Whether [flow] belongs in Reception's Active visits worklist.
///
/// Reception is a same-day, in-facility worklist. An encounter with an end
/// timestamp or terminal status is no longer active even if its last stage has
/// not yet been synchronized.
bool isReceptionActiveVisit(OpdFlowSummary flow, {DateTime? now}) {
  if (flow.isTerminal ||
      isOpdTerminalStatus(flow.status ?? flow.stage) ||
      flow.endedAt != null) {
    return false;
  }

  final String encounterType = (flow.encounterType ?? '').trim().toUpperCase();
  if (encounterType.isNotEmpty && encounterType != 'OPD') {
    return false;
  }

  final DateTime? startedAt = flow.startedAt;
  if (startedAt == null) {
    return false;
  }
  final DateTime localStart = startedAt.toLocal();
  final DateTime localNow = (now ?? DateTime.now()).toLocal();
  return localStart.year == localNow.year &&
      localStart.month == localNow.month &&
      localStart.day == localNow.day;
}

bool isReceptionPaymentGateVisit(OpdFlowSummary flow) {
  if (flow.isTerminal ||
      isOpdTerminalStatus(flow.status ?? flow.stage) ||
      flow.endedAt != null) {
    return false;
  }
  return receptionPaymentGateStages.contains(
    (flow.stage ?? '').trim().toUpperCase(),
  );
}

/// Counts distinct patients represented by Reception's four worklists.
///
/// Identity aliases are joined across appointment, queue, and flow records so
/// the same patient is counted once even when some records expose only a
/// linked appointment or queue identifier.
///
/// Pass [sections] to count only authorized worklists. When omitted, all four
/// sections are included.
int receptionUniquePatientCount(
  OpdWorkspaceState state, {
  DateTime? now,
  Set<ReceptionDeskSection>? sections,
}) {
  final Set<ReceptionDeskSection> included =
      sections ?? ReceptionDeskSection.values.toSet();
  final _ReceptionPatientIdentitySet identities =
      _ReceptionPatientIdentitySet();

  if (included.contains(ReceptionDeskSection.appointments)) {
    for (final OpdAppointment appointment in state.appointments.items) {
      if (isOpdTerminalStatus(appointment.status)) {
        continue;
      }
      identities.add(<String>[
        ..._patientAliases(
          patientId: appointment.patientId,
          patientIdentifier: appointment.patientIdentifier,
        ),
        ..._aliases('appointment', <String?>[
          appointment.id,
          appointment.publicId,
        ]),
      ], fallback: 'appointment:${appointment.id}');
    }
  }

  if (included.contains(ReceptionDeskSection.queue)) {
    for (final OpdQueueEntry entry in state.queueEntries.items) {
      if (isOpdTerminalStatus(entry.status)) {
        continue;
      }
      identities.add(<String>[
        ..._patientAliases(
          patientId: entry.patientId,
          patientIdentifier: entry.patientIdentifier,
        ),
        ..._aliases('appointment', <String?>[entry.appointmentId]),
        ..._aliases('queue', <String?>[entry.id, entry.publicId]),
      ], fallback: 'queue:${entry.id}');
    }
  }

  final bool includeActiveVisits = included.contains(
    ReceptionDeskSection.activeVisits,
  );
  final bool includePaymentGate = included.contains(
    ReceptionDeskSection.paymentGate,
  );
  if (includeActiveVisits || includePaymentGate) {
    for (final OpdFlowSummary flow in state.flows.items) {
      final bool matchesActive =
          includeActiveVisits && isReceptionActiveVisit(flow, now: now);
      final bool matchesPayment =
          includePaymentGate && isReceptionPaymentGateVisit(flow);
      if (!matchesActive && !matchesPayment) {
        continue;
      }
      identities.add(<String>[
        ..._patientAliases(
          patientId: flow.patientId,
          patientIdentifier: flow.patientIdentifier,
        ),
        ..._aliases('appointment', <String?>[flow.appointmentId]),
        ..._aliases('queue', <String?>[flow.visitQueueId]),
        ..._aliases('flow', <String?>[flow.id, flow.publicId]),
      ], fallback: 'flow:${flow.id}');
    }
  }

  return identities.count;
}

Iterable<String> _patientAliases({
  required String? patientId,
  required String? patientIdentifier,
}) sync* {
  yield* _aliases('patient', <String?>[patientId]);
  yield* _aliases('patient-identifier', <String?>[patientIdentifier]);
}

Iterable<String> _aliases(String namespace, Iterable<String?> values) sync* {
  for (final String? value in values) {
    final String normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isNotEmpty) {
      yield '$namespace:$normalized';
    }
  }
}

final class _ReceptionPatientIdentitySet {
  final Map<String, int> _groupsByAlias = <String, int>{};
  final List<int> _parents = <int>[];

  void add(Iterable<String> aliases, {required String fallback}) {
    final List<String> normalized = aliases
        .map((String alias) => alias.trim().toLowerCase())
        .where((String alias) => alias.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) {
      normalized.add(fallback.trim().toLowerCase());
    }

    int? group;
    for (final String alias in normalized) {
      final int? existing = _groupsByAlias[alias];
      if (existing != null) {
        group = group == null ? existing : _union(group, existing);
      }
    }
    int resolvedGroup = group ?? _newGroup();
    for (final String alias in normalized) {
      final int? existing = _groupsByAlias[alias];
      if (existing != null) {
        resolvedGroup = _union(resolvedGroup, existing);
      }
      _groupsByAlias[alias] = resolvedGroup;
    }
  }

  int get count => _groupsByAlias.values.map(_find).toSet().length;

  int _newGroup() {
    final int group = _parents.length;
    _parents.add(group);
    return group;
  }

  int _find(int group) {
    final int parent = _parents[group];
    if (parent == group) {
      return group;
    }
    final int root = _find(parent);
    _parents[group] = root;
    return root;
  }

  int _union(int left, int right) {
    final int leftRoot = _find(left);
    final int rightRoot = _find(right);
    if (leftRoot != rightRoot) {
      _parents[rightRoot] = leftRoot;
    }
    return leftRoot;
  }
}

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
