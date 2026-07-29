import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum BillingQueueType {
  all(''),
  needsIssue('NEEDS_ISSUE'),
  pendingPayment('PENDING_PAYMENT'),
  claimsPending('CLAIMS_PENDING'),
  approvalRequired('APPROVAL_REQUIRED'),
  overdue('OVERDUE');

  const BillingQueueType(this.serverValue);

  final String serverValue;

  static BillingQueueType fromServer(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
    if (normalized.isEmpty) {
      return BillingQueueType.pendingPayment;
    }
    for (final BillingQueueType queue in values) {
      if (queue.serverValue == normalized) {
        return queue;
      }
    }
    return BillingQueueType.pendingPayment;
  }
}

enum BillingWorkItemKind {
  invoice,
  payment,
  refund,
  claim,
  adjustment,
  approval,
  preAuthorization,
  other,
}

enum BillingClearanceState {
  cleared,
  partiallyPaid,
  deferred,
  insured,
  pendingAuthorization,
  awaitingPayment,
  overdue,
  blocked,
}

@immutable
final class BillingWorkspaceQuery {
  const BillingWorkspaceQuery({
    this.search = '',
    this.queue = BillingQueueType.all,
    this.pageRequest = const AppPageRequest(pageSize: 12),
    this.patientId = '',
    this.invoiceNumber = '',
    this.encounterId = '',
    this.sourceModule = '',
    this.billingStatus = '',
    this.action = '',
    this.from,
    this.to,
  });

  factory BillingWorkspaceQuery.fromUri(Uri uri) {
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

    final String queueRaw = pick(<String>['queue', 'filter']);
    BillingQueueType queue = BillingQueueType.all;
    if (queueRaw.isNotEmpty) {
      for (final BillingQueueType candidate in BillingQueueType.values) {
        if (candidate.name.toLowerCase() == queueRaw.toLowerCase() ||
            candidate.serverValue.toLowerCase() == queueRaw.toLowerCase()) {
          queue = candidate;
          break;
        }
      }
      if (queue == BillingQueueType.all) {
        const Map<String, BillingQueueType> slugMap =
            <String, BillingQueueType>{
              'needs-issue': BillingQueueType.needsIssue,
              'pending-payment': BillingQueueType.pendingPayment,
              'awaiting-payment': BillingQueueType.pendingPayment,
              'claims-pending': BillingQueueType.claimsPending,
              'approval-required': BillingQueueType.approvalRequired,
              'overdue': BillingQueueType.overdue,
            };
        queue = slugMap[queueRaw.toLowerCase()] ?? BillingQueueType.all;
      }
    }

    return BillingWorkspaceQuery(
      search: pick(<String>['search', 'q']),
      queue: queue,
      patientId: pick(<String>['patientId', 'patient_id', 'patient']),
      invoiceNumber: pick(<String>[
        'invoiceNumber',
        'invoice_number',
        'invoice',
      ]),
      encounterId: pick(<String>['encounterId', 'encounter_id', 'encounter']),
      sourceModule: pick(<String>['sourceModule', 'source_module', 'source']),
      billingStatus: pick(<String>[
        'billingStatus',
        'billing_status',
        'status',
      ]),
      action: pick(<String>['action']),
    );
  }

  final String search;
  final BillingQueueType queue;
  final AppPageRequest pageRequest;
  final String patientId;
  final String invoiceNumber;
  final String encounterId;
  final String sourceModule;
  final String billingStatus;

  /// Deep-link action to auto-trigger (e.g. `pay` to open the payment dialog).
  final String action;
  final DateTime? from;
  final DateTime? to;

  bool get hasRouteTargeting {
    return queue != BillingQueueType.all ||
        search.trim().isNotEmpty ||
        patientId.trim().isNotEmpty ||
        invoiceNumber.trim().isNotEmpty ||
        encounterId.trim().isNotEmpty ||
        sourceModule.trim().isNotEmpty ||
        billingStatus.trim().isNotEmpty ||
        action.trim().isNotEmpty;
  }

  String get signature =>
      '$search|${queue.name}|$patientId|$invoiceNumber|$encounterId|$sourceModule|$billingStatus|$action';

  /// Advanced list filters only (queue is owned by the tab strip).
  bool get hasActiveFilters {
    return patientId.trim().isNotEmpty ||
        invoiceNumber.trim().isNotEmpty ||
        encounterId.trim().isNotEmpty ||
        sourceModule.trim().isNotEmpty ||
        billingStatus.trim().isNotEmpty ||
        from != null ||
        to != null;
  }

  BillingWorkspaceQuery copyWith({
    String? search,
    BillingQueueType? queue,
    AppPageRequest? pageRequest,
    String? patientId,
    String? invoiceNumber,
    String? encounterId,
    String? sourceModule,
    String? billingStatus,
    String? action,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return BillingWorkspaceQuery(
      search: search ?? this.search,
      queue: queue ?? this.queue,
      pageRequest: pageRequest ?? this.pageRequest,
      patientId: patientId ?? this.patientId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      encounterId: encounterId ?? this.encounterId,
      sourceModule: sourceModule ?? this.sourceModule,
      billingStatus: billingStatus ?? this.billingStatus,
      action: action ?? this.action,
      from: clearFrom ? null : from ?? this.from,
      to: clearTo ? null : to ?? this.to,
    );
  }
}

@immutable
final class BillingSummary {
  const BillingSummary({
    this.needsIssue = 0,
    this.pendingPayment = 0,
    this.claimsPending = 0,
    this.approvalRequired = 0,
    this.overdue = 0,
    this.paymentsTodayTotal = 0,
    this.refundsTodayTotal = 0,
  });

  final int needsIssue;
  final int pendingPayment;
  final int claimsPending;
  final int approvalRequired;
  final int overdue;
  final num paymentsTodayTotal;
  final num refundsTodayTotal;

  int get workloadCount {
    return needsIssue +
        pendingPayment +
        claimsPending +
        approvalRequired +
        overdue;
  }

  int countFor(BillingQueueType queue) {
    return switch (queue) {
      BillingQueueType.all => workloadCount,
      BillingQueueType.needsIssue => needsIssue,
      BillingQueueType.pendingPayment => pendingPayment,
      BillingQueueType.claimsPending => claimsPending,
      BillingQueueType.approvalRequired => approvalRequired,
      BillingQueueType.overdue => overdue,
    };
  }

  BillingSummary copyWith({
    int? needsIssue,
    int? pendingPayment,
    int? claimsPending,
    int? approvalRequired,
    int? overdue,
    num? paymentsTodayTotal,
    num? refundsTodayTotal,
  }) {
    return BillingSummary(
      needsIssue: needsIssue ?? this.needsIssue,
      pendingPayment: pendingPayment ?? this.pendingPayment,
      claimsPending: claimsPending ?? this.claimsPending,
      approvalRequired: approvalRequired ?? this.approvalRequired,
      overdue: overdue ?? this.overdue,
      paymentsTodayTotal: paymentsTodayTotal ?? this.paymentsTodayTotal,
      refundsTodayTotal: refundsTodayTotal ?? this.refundsTodayTotal,
    );
  }
}

@immutable
final class BillingQueueSummary {
  const BillingQueueSummary({
    required this.queue,
    required this.label,
    required this.count,
  });

  final BillingQueueType queue;
  final String label;
  final int count;
}

@immutable
final class BillingFinancials {
  const BillingFinancials({
    this.invoiceTotal = 0,
    this.adjustmentTotal = 0,
    this.effectiveTotal = 0,
    this.grossPaidTotal = 0,
    this.refundedTotal = 0,
    this.netPaidTotal = 0,
    this.balanceDue = 0,
  });

  final num invoiceTotal;
  final num adjustmentTotal;
  final num effectiveTotal;
  final num grossPaidTotal;
  final num refundedTotal;
  final num netPaidTotal;
  final num balanceDue;
}

@immutable
final class BillingInvoiceItem {
  const BillingInvoiceItem({
    required this.id,
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.totalPrice = 0,
    this.sourceModule,
    this.sourceOrderDisplayId,
    this.encounterDisplayId,
    this.patientShare,
    this.insurerShare,
    this.coveragePlanName,
    this.insuranceCompanyName,
  });

  final String id;
  final String description;
  final int quantity;
  final num unitPrice;
  final num totalPrice;
  final String? sourceModule;
  final String? sourceOrderDisplayId;
  final String? encounterDisplayId;
  final num? patientShare;
  final num? insurerShare;
  final String? coveragePlanName;
  final String? insuranceCompanyName;

  String? get sourceContextLabel {
    final List<String> parts = <String>[
      if ((sourceModule ?? '').trim().isNotEmpty) sourceModule!.trim(),
      if ((sourceOrderDisplayId ?? '').trim().isNotEmpty)
        sourceOrderDisplayId!.trim(),
      if ((encounterDisplayId ?? '').trim().isNotEmpty)
        encounterDisplayId!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

@immutable
final class BillingPayment {
  const BillingPayment({
    required this.id,
    this.displayId,
    this.status,
    this.method,
    this.amount = 0,
    this.transactionRef,
    this.paidAt,
  });

  final String id;
  final String? displayId;
  final String? status;
  final String? method;
  final num amount;
  final String? transactionRef;
  final DateTime? paidAt;

  bool get isRefundable {
    final String normalized = (status ?? '').trim().toUpperCase();
    return normalized == 'COMPLETED' || normalized == 'REFUNDED';
  }

  String get effectiveDisplayId => displayId ?? id;
}

@immutable
final class BillingAdjustment {
  const BillingAdjustment({
    required this.id,
    this.displayId,
    this.status,
    this.amount = 0,
    this.reason,
    this.adjustedAt,
  });

  final String id;
  final String? displayId;
  final String? status;
  final num amount;
  final String? reason;
  final DateTime? adjustedAt;
}

@immutable
final class BillingWorkItem {
  const BillingWorkItem({
    required this.id,
    required this.kind,
    this.displayId,
    this.tenantId,
    this.facilityId,
    this.patientId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.patientGender,
    this.patientDateOfBirth,
    this.invoiceDisplayId,
    this.coveragePlanDisplayId,
    this.status,
    this.billingStatus,
    this.amount = 0,
    this.currency,
    this.timelineAt,
    this.items = const <BillingInvoiceItem>[],
    this.payments = const <BillingPayment>[],
    this.adjustments = const <BillingAdjustment>[],
    this.financials = const BillingFinancials(),
    this.approvalType,
    this.requestReason,
    this.requestedByDisplayId,
    this.requestedAt,
    this.decidedAt,
    this.targetDisplayId,
    this.linkedInvoiceId,
    this.submittedAt,
    this.approvedAt,
    this.encounterId,
    this.encounterDisplayId,
    this.sourceModule,
    this.sourceModules = const <String>[],
    this.settlementAmount,
    this.decisionNotes,
  });

  final String id;
  final BillingWorkItemKind kind;
  final String? displayId;
  final String? tenantId;
  final String? facilityId;
  final String? patientId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final String? patientGender;
  final DateTime? patientDateOfBirth;
  final String? invoiceDisplayId;
  final String? coveragePlanDisplayId;
  final String? status;
  final String? billingStatus;
  final num amount;
  final String? currency;
  final DateTime? timelineAt;
  final List<BillingInvoiceItem> items;
  final List<BillingPayment> payments;
  final List<BillingAdjustment> adjustments;
  final BillingFinancials financials;
  final String? approvalType;
  final String? requestReason;
  final String? requestedByDisplayId;
  final DateTime? requestedAt;
  final DateTime? decidedAt;
  final String? targetDisplayId;
  final String? linkedInvoiceId;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? encounterId;
  final String? encounterDisplayId;
  final String? sourceModule;
  final List<String> sourceModules;
  final num? settlementAmount;
  final String? decisionNotes;

  bool get isInvoice => kind == BillingWorkItemKind.invoice;

  String get effectiveDisplayId => displayId ?? invoiceDisplayId ?? id;

  String get effectivePatientName {
    final String normalized = patientDisplayName?.trim() ?? '';
    return normalized.isEmpty ? 'Unknown patient' : normalized;
  }

  String? get effectivePatientNumber {
    final String? normalized = _nonEmpty(patientDisplayId);
    return normalized ?? _nonEmpty(patientId);
  }

  num get effectiveTotal {
    if (financials.effectiveTotal != 0) {
      return financials.effectiveTotal;
    }
    return amount;
  }

  num get paidAmount => financials.netPaidTotal;

  num get balanceDue {
    if (financials.balanceDue != 0 || paidAmount != 0) {
      return financials.balanceDue;
    }
    return effectiveTotal;
  }

  String? get invoiceSourceSummary {
    final String? direct = sourceModule?.trim();
    final Set<String> modules = <String>{
      if (direct != null && direct.isNotEmpty) direct,
    };
    modules.addAll(
      sourceModules
          .map((String module) => module.trim())
          .where((String module) => module.isNotEmpty),
    );
    for (final BillingInvoiceItem item in items) {
      final String? module = item.sourceModule?.trim();
      if (module != null && module.isNotEmpty) {
        modules.add(module);
      }
    }
    if (modules.isEmpty) {
      return null;
    }
    return modules.join(', ');
  }

  BillingPayment? get firstRefundablePayment {
    for (final BillingPayment payment in payments) {
      if (payment.isRefundable) {
        return payment;
      }
    }
    return null;
  }

  bool get canReceivePayment {
    return isInvoice &&
        tenantId != null &&
        balanceDue > 0 &&
        !_isCancelled &&
        _normalizedBillingStatus != 'DRAFT';
  }

  bool get canIssue {
    return isInvoice && _normalizedBillingStatus == 'DRAFT' && !_isCancelled;
  }

  bool get canRequestRefund => firstRefundablePayment != null;

  bool get canRequestAdjustment => isInvoice && !_isCancelled;

  bool get canRequestVoid => isInvoice && !_isCancelled;

  bool get isApproval => kind == BillingWorkItemKind.approval;

  bool get isClaim => kind == BillingWorkItemKind.claim;

  bool get isPreAuthorization => kind == BillingWorkItemKind.preAuthorization;

  bool get canApproveOrReject {
    return isApproval && _normalizedStatus == 'PENDING';
  }

  bool get canSubmitClaim {
    return isClaim && _normalizedStatus != 'SUBMITTED';
  }

  bool get canReconcileClaim {
    return isClaim && _normalizedStatus == 'SUBMITTED';
  }

  bool get canUpdatePreAuthorization {
    if (!isPreAuthorization) {
      return false;
    }
    return _normalizedStatus == 'PENDING' || _normalizedStatus == 'DENIED';
  }

  bool get canApprovePreAuthorization {
    return isPreAuthorization && _normalizedStatus == 'PENDING';
  }

  bool get canDenyPreAuthorization {
    return isPreAuthorization && _normalizedStatus == 'PENDING';
  }

  bool get canFinalizeEncounterBilling {
    return isInvoice &&
        (encounterId?.isNotEmpty ?? false) &&
        balanceDue <= 0 &&
        !_isCancelled &&
        _normalizedBillingStatus != 'DRAFT';
  }

  String get _normalizedStatus => (status ?? '').trim().toUpperCase();

  BillingClearanceState get clearanceState {
    if (kind == BillingWorkItemKind.claim ||
        kind == BillingWorkItemKind.preAuthorization) {
      return BillingClearanceState.pendingAuthorization;
    }
    if (payments.any((BillingPayment payment) {
      return (payment.method ?? '').trim().toUpperCase() == 'INSURANCE';
    })) {
      return BillingClearanceState.insured;
    }
    if (_normalizedBillingStatus == 'DRAFT') {
      return BillingClearanceState.deferred;
    }
    if (_normalizedBillingStatus == 'PAID' || balanceDue <= 0) {
      return BillingClearanceState.cleared;
    }
    if (_normalizedBillingStatus == 'PARTIAL' || paidAmount > 0) {
      return BillingClearanceState.partiallyPaid;
    }
    if (_normalizedStatus == 'OVERDUE' && balanceDue > 0) {
      return BillingClearanceState.overdue;
    }
    if (balanceDue > 0 && !_isCancelled) {
      return BillingClearanceState.awaitingPayment;
    }
    return BillingClearanceState.blocked;
  }

  String get _normalizedBillingStatus {
    return (billingStatus ?? status ?? '').trim().toUpperCase();
  }

  bool get _isCancelled {
    return (status ?? '').trim().toUpperCase() == 'CANCELLED' ||
        (billingStatus ?? '').trim().toUpperCase() == 'CANCELLED';
  }

  BillingWorkItem copyWith({
    String? id,
    BillingWorkItemKind? kind,
    String? displayId,
    String? tenantId,
    String? facilityId,
    String? patientId,
    String? patientDisplayId,
    String? patientDisplayName,
    String? patientGender,
    DateTime? patientDateOfBirth,
    String? invoiceDisplayId,
    String? coveragePlanDisplayId,
    String? status,
    String? billingStatus,
    num? amount,
    String? currency,
    DateTime? timelineAt,
    List<BillingInvoiceItem>? items,
    List<BillingPayment>? payments,
    List<BillingAdjustment>? adjustments,
    BillingFinancials? financials,
    String? approvalType,
    String? requestReason,
    String? requestedByDisplayId,
    DateTime? requestedAt,
    DateTime? decidedAt,
    String? targetDisplayId,
    String? linkedInvoiceId,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? encounterId,
    String? encounterDisplayId,
    String? sourceModule,
    List<String>? sourceModules,
    num? settlementAmount,
    String? decisionNotes,
  }) {
    return BillingWorkItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      displayId: displayId ?? this.displayId,
      tenantId: tenantId ?? this.tenantId,
      facilityId: facilityId ?? this.facilityId,
      patientId: patientId ?? this.patientId,
      patientDisplayId: patientDisplayId ?? this.patientDisplayId,
      patientDisplayName: patientDisplayName ?? this.patientDisplayName,
      patientGender: patientGender ?? this.patientGender,
      patientDateOfBirth: patientDateOfBirth ?? this.patientDateOfBirth,
      invoiceDisplayId: invoiceDisplayId ?? this.invoiceDisplayId,
      coveragePlanDisplayId:
          coveragePlanDisplayId ?? this.coveragePlanDisplayId,
      status: status ?? this.status,
      billingStatus: billingStatus ?? this.billingStatus,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      timelineAt: timelineAt ?? this.timelineAt,
      items: items ?? this.items,
      payments: payments ?? this.payments,
      adjustments: adjustments ?? this.adjustments,
      financials: financials ?? this.financials,
      approvalType: approvalType ?? this.approvalType,
      requestReason: requestReason ?? this.requestReason,
      requestedByDisplayId: requestedByDisplayId ?? this.requestedByDisplayId,
      requestedAt: requestedAt ?? this.requestedAt,
      decidedAt: decidedAt ?? this.decidedAt,
      targetDisplayId: targetDisplayId ?? this.targetDisplayId,
      linkedInvoiceId: linkedInvoiceId ?? this.linkedInvoiceId,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      encounterId: encounterId ?? this.encounterId,
      encounterDisplayId: encounterDisplayId ?? this.encounterDisplayId,
      sourceModule: sourceModule ?? this.sourceModule,
      sourceModules: sourceModules ?? this.sourceModules,
      settlementAmount: settlementAmount ?? this.settlementAmount,
      decisionNotes: decisionNotes ?? this.decisionNotes,
    );
  }
}

@immutable
final class BillingMutationResult {
  const BillingMutationResult({
    this.invoice,
    this.payment,
    this.approval,
    this.claim,
    this.approvalRequired = false,
  });

  final BillingWorkItem? invoice;
  final BillingPayment? payment;
  final BillingWorkItem? approval;
  final BillingWorkItem? claim;
  final bool approvalRequired;

  bool get hasImmediatePatch =>
      invoice != null || payment != null || approval != null || claim != null;
}

@immutable
final class BillingTimelineItem {
  const BillingTimelineItem({
    required this.id,
    required this.kind,
    this.action,
    this.status,
    this.displayId,
    this.patientDisplayName,
    this.amount = 0,
    this.currency,
    this.timelineAt,
  });

  final String id;
  final BillingWorkItemKind kind;
  final String? action;
  final String? status;
  final String? displayId;
  final String? patientDisplayName;
  final num amount;
  final String? currency;
  final DateTime? timelineAt;
}

@immutable
final class BillingWorkspaceOverview {
  const BillingWorkspaceOverview({
    this.summary = const BillingSummary(),
    this.queues = const <BillingQueueSummary>[],
    this.timeline = const <BillingTimelineItem>[],
    this.generatedAt,
  });

  final BillingSummary summary;
  final List<BillingQueueSummary> queues;
  final List<BillingTimelineItem> timeline;
  final DateTime? generatedAt;

  BillingWorkspaceOverview copyWith({
    BillingSummary? summary,
    List<BillingQueueSummary>? queues,
    List<BillingTimelineItem>? timeline,
    DateTime? generatedAt,
  }) {
    return BillingWorkspaceOverview(
      summary: summary ?? this.summary,
      queues: queues ?? this.queues,
      timeline: timeline ?? this.timeline,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}

@immutable
final class BillingWorkspaceState {
  const BillingWorkspaceState({
    required this.query,
    required this.overview,
    required this.workItems,
    this.selectedItem,
    this.lastFailure,
    this.isRefreshing = false,
    this.isSaving = false,
    this.lastActionPendingApproval = false,
  });

  final BillingWorkspaceQuery query;
  final BillingWorkspaceOverview overview;
  final AppPage<BillingWorkItem> workItems;
  final BillingWorkItem? selectedItem;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isSaving;
  final bool lastActionPendingApproval;

  int get workloadCount => overview.summary.workloadCount;

  int get partialPaidVisibleCount {
    return workItems.items.where((BillingWorkItem item) {
      return (item.billingStatus ?? '').trim().toUpperCase() == 'PARTIAL';
    }).length;
  }

  int get clearedVisibleCount {
    return workItems.items.where((BillingWorkItem item) {
      return item.clearanceState == BillingClearanceState.cleared;
    }).length;
  }

  BillingWorkspaceState copyWith({
    BillingWorkspaceQuery? query,
    BillingWorkspaceOverview? overview,
    AppPage<BillingWorkItem>? workItems,
    BillingWorkItem? selectedItem,
    Object? lastFailure,
    bool? isRefreshing,
    bool? isSaving,
    bool? lastActionPendingApproval,
    bool clearSelectedItem = false,
    bool clearLastFailure = false,
  }) {
    return BillingWorkspaceState(
      query: query ?? this.query,
      overview: overview ?? this.overview,
      workItems: workItems ?? this.workItems,
      selectedItem: clearSelectedItem
          ? null
          : selectedItem ?? this.selectedItem,
      lastFailure: clearLastFailure ? null : lastFailure ?? this.lastFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      lastActionPendingApproval:
          lastActionPendingApproval ?? this.lastActionPendingApproval,
    );
  }
}

@immutable
final class BillingPaymentDraft {
  const BillingPaymentDraft({
    required this.amount,
    required this.method,
    this.reference,
    this.payer,
    this.issueReceipt = true,
  });

  final String amount;
  final String method;
  final String? reference;
  final String? payer;
  final bool issueReceipt;
}

@immutable
final class BillingRefundDraft {
  const BillingRefundDraft({
    required this.paymentId,
    required this.amount,
    required this.reason,
    this.notes,
  });

  final String paymentId;
  final String amount;
  final String reason;
  final String? notes;
}

@immutable
final class BillingAdjustmentDraft {
  const BillingAdjustmentDraft({
    required this.amount,
    required this.reason,
    this.status,
    this.notes,
  });

  final String amount;
  final String reason;
  final String? status;
  final String? notes;
}

@immutable
final class BillingLedgerQuery {
  const BillingLedgerQuery({
    this.from,
    this.to,
    this.pageRequest = const AppPageRequest(),
  });

  final DateTime? from;
  final DateTime? to;
  final AppPageRequest pageRequest;
}

@immutable
final class BillingLedgerSummary {
  const BillingLedgerSummary({
    this.totalInvoiced = 0,
    this.totalAdjustments = 0,
    this.totalPaid = 0,
    this.totalRefunded = 0,
    this.netPaid = 0,
    this.balanceDue = 0,
  });

  final num totalInvoiced;
  final num totalAdjustments;
  final num totalPaid;
  final num totalRefunded;
  final num netPaid;
  final num balanceDue;
}

@immutable
final class BillingLedgerEntry {
  const BillingLedgerEntry({
    required this.id,
    required this.kind,
    this.action,
    this.status,
    this.displayId,
    this.invoiceDisplayId,
    this.patientDisplayName,
    this.amount = 0,
    this.currency,
    this.timelineAt,
  });

  final String id;
  final BillingWorkItemKind kind;
  final String? action;
  final String? status;
  final String? displayId;
  final String? invoiceDisplayId;
  final String? patientDisplayName;
  final num amount;
  final String? currency;
  final DateTime? timelineAt;
}

@immutable
final class BillingPatientLedger {
  const BillingPatientLedger({
    required this.patientId,
    this.patientDisplayId,
    this.patientDisplayName,
    this.summary = const BillingLedgerSummary(),
    this.entries = const <BillingLedgerEntry>[],
    this.totalEntryCount,
  });

  final String patientId;
  final String? patientDisplayId;
  final String? patientDisplayName;
  final BillingLedgerSummary summary;
  final List<BillingLedgerEntry> entries;
  final int? totalEntryCount;
}

@immutable
final class BillingInvoiceDocument {
  const BillingInvoiceDocument({required this.bytes, required this.fileName});

  final List<int> bytes;
  final String fileName;
}

@immutable
final class BillingApprovalDecisionDraft {
  const BillingApprovalDecisionDraft({this.decisionNotes, this.reason});

  final String? decisionNotes;
  final String? reason;
}

@immutable
final class BillingClaimActionDraft {
  const BillingClaimActionDraft({this.notes, this.status});

  final String? notes;
  final String? status;
}

@immutable
final class BillingCloseDraft {
  const BillingCloseDraft({
    this.expectedAmount,
    this.actualAmount,
    this.notes,
    this.submit = true,
  });

  final String? expectedAmount;
  final String? actualAmount;
  final String? notes;
  final bool submit;
}

const List<String> billingPaymentMethods = <String>[
  'CASH',
  'CREDIT_CARD',
  'DEBIT_CARD',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'INSURANCE',
  'OTHER',
];

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
