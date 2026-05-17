import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum BillingQueueType {
  needsIssue('NEEDS_ISSUE'),
  pendingPayment('PENDING_PAYMENT'),
  claimsPending('CLAIMS_PENDING'),
  approvalRequired('APPROVAL_REQUIRED'),
  overdue('OVERDUE');

  const BillingQueueType(this.serverValue);

  final String serverValue;

  static BillingQueueType fromServer(String? value) {
    final String normalized = (value ?? '').trim().toUpperCase();
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
  blocked,
}

@immutable
final class BillingWorkspaceQuery {
  const BillingWorkspaceQuery({
    this.search = '',
    this.queue = BillingQueueType.pendingPayment,
    this.pageRequest = const AppPageRequest(pageSize: 12),
  });

  final String search;
  final BillingQueueType queue;
  final AppPageRequest pageRequest;

  BillingWorkspaceQuery copyWith({
    String? search,
    BillingQueueType? queue,
    AppPageRequest? pageRequest,
  }) {
    return BillingWorkspaceQuery(
      search: search ?? this.search,
      queue: queue ?? this.queue,
      pageRequest: pageRequest ?? this.pageRequest,
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
      BillingQueueType.needsIssue => needsIssue,
      BillingQueueType.pendingPayment => pendingPayment,
      BillingQueueType.claimsPending => claimsPending,
      BillingQueueType.approvalRequired => approvalRequired,
      BillingQueueType.overdue => overdue,
    };
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
  });

  final String id;
  final String description;
  final int quantity;
  final num unitPrice;
  final num totalPrice;
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
  });

  final String id;
  final BillingWorkItemKind kind;
  final String? displayId;
  final String? tenantId;
  final String? facilityId;
  final String? patientId;
  final String? patientDisplayId;
  final String? patientDisplayName;
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
    return BillingClearanceState.blocked;
  }

  String get _normalizedBillingStatus {
    return (billingStatus ?? status ?? '').trim().toUpperCase();
  }

  bool get _isCancelled {
    return (status ?? '').trim().toUpperCase() == 'CANCELLED' ||
        (billingStatus ?? '').trim().toUpperCase() == 'CANCELLED';
  }
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
  });

  final BillingWorkspaceQuery query;
  final BillingWorkspaceOverview overview;
  final AppPage<BillingWorkItem> workItems;
  final BillingWorkItem? selectedItem;
  final Object? lastFailure;
  final bool isRefreshing;
  final bool isSaving;

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
