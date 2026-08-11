import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';

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

const Set<String> receptionOpdBillingSources = <String>{
  'CONSULTATION',
  'LABORATORY',
  'RADIOLOGY',
  'PHARMACY',
  'PROCEDURE',
  'CONSUMABLE',
  'THERAPY',
  'SERVICE',
  'NURSING',
};

/// Scheduled patient callback row for the Reception Follow-ups worklist.
@immutable
final class ReceptionFollowUpEntry {
  const ReceptionFollowUpEntry({
    required this.id,
    required this.encounterId,
    required this.patientId,
    required this.patientIdentifier,
    required this.scheduledAt,
    this.patientDisplayName,
    this.patientPhone,
    this.patientEmail,
    this.encounterType,
    this.notes,
    this.status = 'SCHEDULED',
  });

  factory ReceptionFollowUpEntry.fromJson(Map<String, Object?> json) {
    final String id =
        _nonEmpty(json['human_friendly_id']) ?? _nonEmpty(json['id']) ?? '';
    final String patientId = _nonEmpty(json['patient_id']) ?? '';
    return ReceptionFollowUpEntry(
      id: id,
      encounterId: _nonEmpty(json['encounter_id']) ?? '',
      patientId: patientId,
      patientIdentifier:
          _nonEmpty(json['patient_id']) ??
          _nonEmpty(json['patient_identifier']) ??
          patientId,
      patientDisplayName: _nonEmpty(json['patient_display_name']),
      patientPhone: _nonEmpty(json['patient_primary_phone']),
      patientEmail: _nonEmpty(json['patient_primary_email']),
      encounterType: _nonEmpty(json['encounter_type']),
      scheduledAt: _dateTime(json['scheduled_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      notes: _nonEmpty(json['notes']),
      status: _nonEmpty(json['status']) ?? 'SCHEDULED',
    );
  }

  final String id;
  final String encounterId;
  final String patientId;
  final String patientIdentifier;
  final String? patientDisplayName;
  final String? patientPhone;
  final String? patientEmail;
  final String? encounterType;
  final DateTime scheduledAt;
  final String? notes;
  final String status;

  bool get isScheduled => status.trim().toUpperCase() == 'SCHEDULED';
}

String? _nonEmpty(Object? value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _dateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  final String? text = _nonEmpty(value);
  if (text == null) {
    return null;
  }
  return DateTime.tryParse(text);
}

@immutable
final class ReceptionPaymentGateEntry {
  const ReceptionPaymentGateEntry({
    required this.id,
    required this.patientId,
    required this.patientIdentifier,
    required this.patientName,
    required this.encounterId,
    required this.encounterIdentifier,
    required this.invoices,
    required this.services,
    required this.outstandingByCurrency,
    this.issuedAt,
  });

  final String id;
  final String? patientId;
  final String? patientIdentifier;
  final String patientName;
  final String? encounterId;
  final String encounterIdentifier;
  final List<BillingWorkItem> invoices;
  final Set<String> services;
  final Map<String, num> outstandingByCurrency;

  /// Latest invoice `timelineAt` for desk date filtering (issued / outstanding-as-of).
  final DateTime? issuedAt;

  int get invoiceCount => invoices.length;

  BillingClearanceState get clearanceState {
    if (invoices.any(
      (BillingWorkItem invoice) =>
          invoice.clearanceState == BillingClearanceState.overdue,
    )) {
      return BillingClearanceState.overdue;
    }
    if (invoices.any(
      (BillingWorkItem invoice) =>
          invoice.clearanceState == BillingClearanceState.partiallyPaid,
    )) {
      return BillingClearanceState.partiallyPaid;
    }
    return BillingClearanceState.awaitingPayment;
  }
}

bool isReceptionOutstandingOpdInvoice(BillingWorkItem item) {
  if (!item.isInvoice || item.balanceDue <= 0) {
    return false;
  }
  final String billingStatus = (item.billingStatus ?? '').trim().toUpperCase();
  if (!<String>{'ISSUED', 'PARTIAL', 'OVERDUE'}.contains(billingStatus)) {
    return false;
  }
  if (!<BillingClearanceState>{
    BillingClearanceState.awaitingPayment,
    BillingClearanceState.partiallyPaid,
    BillingClearanceState.overdue,
  }.contains(item.clearanceState)) {
    return false;
  }
  if (_firstNonEmpty(<String?>[item.encounterId, item.encounterDisplayId]) ==
      null) {
    return false;
  }
  if (_firstNonEmpty(<String?>[
        item.patientId,
        item.patientDisplayId,
        item.patientDisplayName,
      ]) ==
      null) {
    return false;
  }
  if (_billingSources(item).any(receptionOpdBillingSources.contains)) {
    return true;
  }
  // Mismatch recovery: consultation invoices may briefly lack source_module
  // after OPD start while still belonging on the Payment gate.
  return item.items.any((BillingInvoiceItem line) {
    final String description = (line.description ?? '').trim().toUpperCase();
    return description.contains('CONSULT');
  });
}

List<ReceptionPaymentGateEntry> aggregateReceptionPaymentGateEntries(
  Iterable<BillingWorkItem> items,
) {
  final Map<String, List<BillingWorkItem>> grouped =
      <String, List<BillingWorkItem>>{};
  for (final BillingWorkItem item in items) {
    if (!isReceptionOutstandingOpdInvoice(item)) {
      continue;
    }
    final String patientKey = _firstNonEmpty(<String?>[
      item.patientId,
      item.patientDisplayId,
      item.patientDisplayName,
    ])!.toLowerCase();
    final String encounterKey = _firstNonEmpty(<String?>[
      item.encounterId,
      item.encounterDisplayId,
    ])!.toLowerCase();
    grouped
        .putIfAbsent('$patientKey|$encounterKey', () => <BillingWorkItem>[])
        .add(item);
  }

  final List<ReceptionPaymentGateEntry> entries = <ReceptionPaymentGateEntry>[];
  for (final MapEntry<String, List<BillingWorkItem>> group in grouped.entries) {
    final List<BillingWorkItem> invoices = group.value
      ..sort(
        (BillingWorkItem a, BillingWorkItem b) =>
            (b.timelineAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.timelineAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
      );
    final BillingWorkItem first = invoices.first;
    final Set<String> services = <String>{};
    final Map<String, num> totals = <String, num>{};
    for (final BillingWorkItem invoice in invoices) {
      final Set<String> invoiceSources = _billingSources(invoice);
      if (invoiceSources.isEmpty &&
          invoice.items.any(
            (BillingInvoiceItem line) =>
                (line.description ?? '').toUpperCase().contains('CONSULT'),
          )) {
        services.add('CONSULTATION');
      } else {
        services.addAll(invoiceSources);
      }
      final String currency = (invoice.currency ?? '').trim().toUpperCase();
      totals.update(
        currency,
        (num current) => current + invoice.balanceDue,
        ifAbsent: () => invoice.balanceDue,
      );
    }
    DateTime? issuedAt;
    for (final BillingWorkItem invoice in invoices) {
      final DateTime? at = invoice.timelineAt;
      if (at == null) {
        continue;
      }
      if (issuedAt == null || at.isAfter(issuedAt)) {
        issuedAt = at;
      }
    }
    entries.add(
      ReceptionPaymentGateEntry(
        id: group.key,
        patientId: first.patientId,
        patientIdentifier: first.patientDisplayId ?? first.patientId,
        patientName: first.patientDisplayName?.trim().isNotEmpty == true
            ? first.patientDisplayName!.trim()
            : first.patientDisplayId ?? first.patientId ?? '',
        encounterId: first.encounterId,
        encounterIdentifier:
            first.encounterDisplayId ?? first.encounterId ?? '',
        invoices: List<BillingWorkItem>.unmodifiable(invoices),
        services: Set<String>.unmodifiable(services),
        outstandingByCurrency: Map<String, num>.unmodifiable(totals),
        issuedAt: issuedAt,
      ),
    );
  }
  entries.sort(
    (ReceptionPaymentGateEntry a, ReceptionPaymentGateEntry b) =>
        a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase()),
  );
  return List<ReceptionPaymentGateEntry>.unmodifiable(entries);
}

Set<String> _billingSources(BillingWorkItem item) {
  return <String>{
    if ((item.sourceModule ?? '').trim().isNotEmpty)
      item.sourceModule!.trim().toUpperCase(),
    for (final String module in item.sourceModules)
      if (module.trim().isNotEmpty) module.trim().toUpperCase(),
    for (final BillingInvoiceItem line in item.items)
      if ((line.sourceModule ?? '').trim().isNotEmpty)
        line.sourceModule!.trim().toUpperCase(),
  };
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

/// Counts distinct patients represented by Reception worklists.
///
/// Identity aliases are joined across appointment, queue, and flow records so
/// the same patient is counted once even when some records expose only a
/// linked appointment or queue identifier.
///
/// Pass [sections] to count only authorized worklists. When omitted, all
/// sections are included. High priority is a subset of desk queue and is not
/// recounted when desk queue is already included.
int receptionUniquePatientCount(
  OpdWorkspaceState state, {
  DateTime? now,
  Set<ReceptionDeskSection>? sections,
  Iterable<ReceptionPaymentGateEntry> paymentGateEntries =
      const <ReceptionPaymentGateEntry>[],
  Iterable<ReceptionFollowUpEntry> followUpEntries =
      const <ReceptionFollowUpEntry>[],
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

  final bool includeQueue = included.contains(ReceptionDeskSection.queue);
  final bool includeHighPriority = included.contains(
    ReceptionDeskSection.highPriority,
  );
  if (includeQueue || includeHighPriority) {
    for (final OpdQueueEntry entry in state.queueEntries.items) {
      if (isOpdTerminalStatus(entry.status)) {
        continue;
      }
      if (!includeQueue && includeHighPriority && !entry.isPrioritized) {
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
  if (includeActiveVisits) {
    for (final OpdFlowSummary flow in state.flows.items) {
      if (!isReceptionActiveVisit(flow, now: now)) {
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
  if (included.contains(ReceptionDeskSection.paymentGate)) {
    for (final ReceptionPaymentGateEntry entry in paymentGateEntries) {
      identities.add(<String>[
        ..._patientAliases(
          patientId: entry.patientId,
          patientIdentifier: entry.patientIdentifier,
        ),
      ], fallback: 'payment-gate:${entry.id}');
    }
  }
  if (included.contains(ReceptionDeskSection.followUps)) {
    for (final ReceptionFollowUpEntry entry in followUpEntries) {
      identities.add(<String>[
        ..._patientAliases(
          patientId: entry.patientId,
          patientIdentifier: entry.patientIdentifier,
        ),
      ], fallback: 'follow-up:${entry.id}');
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
    this.action = '',
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
      action: pick(<String>['action', 'dialog', 'open']),
    );
  }

  final String section;
  final String search;
  final String patientId;
  final String flowId;

  /// Home / deep-link modal intent (`register`, `schedule`, `route`, …).
  final String action;

  bool get hasRouteTargeting =>
      section.isNotEmpty ||
      search.isNotEmpty ||
      patientId.isNotEmpty ||
      flowId.isNotEmpty ||
      action.isNotEmpty;

  String get signature => '$section|$search|$patientId|$flowId|$action';
}

/// Desk worklist sections for high-volume reception workflows.
enum ReceptionDeskSection {
  appointments,
  queue,
  highPriority,
  activeVisits,
  followUps,
  paymentGate,
}

/// Canonical `section` query value written by the Reception workspace URL.
String receptionDeskSectionToQueryValue(ReceptionDeskSection section) {
  return switch (section) {
    ReceptionDeskSection.appointments => 'appointments',
    ReceptionDeskSection.queue => 'desk-queue',
    ReceptionDeskSection.highPriority => 'high-priority',
    ReceptionDeskSection.activeVisits => 'active',
    ReceptionDeskSection.followUps => 'follow-ups',
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
    case 'high-priority':
    case 'high_priority':
    case 'priority':
      return ReceptionDeskSection.highPriority;
    case 'in-progress':
    case 'active':
    case 'active-visits':
    case 'active_visits':
    case 'visits':
    case 'turnaround_pressure':
      return ReceptionDeskSection.activeVisits;
    case 'follow-ups':
    case 'follow_ups':
    case 'followups':
    case 'follow-up':
    case 'no_show_pressure':
      return ReceptionDeskSection.followUps;
    case 'payment':
    case 'payment-gate':
    case 'pending_balance_amount':
    case 'pending-payments':
      return ReceptionDeskSection.paymentGate;
    default:
      return null;
  }
}
