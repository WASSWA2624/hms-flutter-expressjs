import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Applies billing mutation results to local workspace state without HTTP.
abstract final class BillingWorkspaceMutationApplier {
  static BillingWorkspaceState apply(
    BillingWorkspaceState state,
    BillingMutationResult mutation,
  ) {
    if (!mutation.hasImmediatePatch) {
      return state;
    }

    final BillingWorkItem? previous = _findExistingItem(
      state,
      mutation.claim ?? mutation.approval ?? mutation.invoice,
    );
    // Prefer claim/pre-auth patch on claims queues so remittance invoice+payment
    // siblings do not replace claim rows in the Claims pending list.
    BillingWorkItem? patchItem =
        mutation.claim ?? mutation.approval ?? mutation.invoice;
    if (patchItem == null) {
      return state;
    }

    if (mutation.invoice != null &&
        mutation.payment != null &&
        patchItem.isInvoice) {
      patchItem = _mergePaymentIntoInvoice(patchItem, mutation.payment!);
    }

    final bool wasPendingPayment = previous != null && isPendingPaymentItem(previous);
    final bool isPendingPayment = isPendingPaymentItem(patchItem);
    final bool wasOverdue = previous != null && isOverdueItem(previous);
    final bool isOverdue = isOverdueItem(patchItem);
    final bool wasPendingApproval =
        previous != null && isPendingApprovalItem(previous);
    final bool isPendingApproval = isPendingApprovalItem(patchItem);
    final bool wasNeedsIssue = previous != null && isNeedsIssueItem(previous);
    final bool isNeedsIssue = isNeedsIssueItem(patchItem);
    final bool wasClaimsPending =
        previous != null && isClaimsPendingItem(previous);
    final bool isClaimsPending = isClaimsPendingItem(patchItem);

    AppPage<BillingWorkItem> workItems = state.workItems;
    if (_shouldRemoveFromVisibleQueue(state.query.queue, patchItem)) {
      workItems = _removeWorkItem(workItems, patchItem.id);
    } else {
      workItems = _upsertWorkItem(workItems, patchItem);
    }

    BillingWorkItem? selected = state.selectedItem;
    if (selected?.id == patchItem.id) {
      // Keep the mutated invoice selected so open detail dialogs can resolve
      // live paid/balance state even when the row leaves the active queue.
      selected = patchItem;
    } else if (selected == null && workItems.items.isNotEmpty) {
      selected = workItems.items.first;
    }

    final BillingSummary summary = _adjustSummary(
      state.overview.summary,
      wasNeedsIssue: wasNeedsIssue,
      isNeedsIssue: isNeedsIssue,
      wasPendingPayment: wasPendingPayment,
      isPendingPayment: isPendingPayment,
      wasOverdue: wasOverdue,
      isOverdue: isOverdue,
      wasPendingApproval: wasPendingApproval,
      isPendingApproval: isPendingApproval,
      wasClaimsPending: wasClaimsPending,
      isClaimsPending: isClaimsPending,
      paymentAmount: mutation.payment?.amount,
    );

    return state.copyWith(
      overview: state.overview.copyWith(
        summary: summary,
        queues: _queuesFromSummary(state.overview.queues, summary),
      ),
      workItems: workItems,
      selectedItem: selected,
      clearSelectedItem: selected == null && state.selectedItem != null,
      clearLastFailure: true,
      isSaving: false,
      isRefreshing: false,
      lastActionPendingApproval: mutation.approvalRequired,
    );
  }

  static bool isPendingPaymentItem(BillingWorkItem item) {
    if (!item.isInvoice || item.balanceDue <= 0) {
      return false;
    }
    final String billingStatus = (item.billingStatus ?? '').trim().toUpperCase();
    final String status = (item.status ?? '').trim().toUpperCase();
    return <String>{'ISSUED', 'PARTIAL'}.contains(billingStatus) &&
        <String>{'SENT', 'OVERDUE', ''}.contains(status);
  }

  static bool isOverdueItem(BillingWorkItem item) {
    if (!item.isInvoice) {
      return false;
    }
    final String billingStatus = (item.billingStatus ?? '').trim().toUpperCase();
    final String status = (item.status ?? '').trim().toUpperCase();
    return status == 'OVERDUE' && billingStatus != 'CANCELLED';
  }

  static bool isPendingApprovalItem(BillingWorkItem item) {
    return item.isApproval && item.canApproveOrReject;
  }

  /// Matches `NEEDS_ISSUE` queue membership (DRAFT invoices only).
  static bool isNeedsIssueItem(BillingWorkItem item) {
    if (!item.isInvoice) {
      return false;
    }
    return (item.billingStatus ?? '').trim().toUpperCase() == 'DRAFT';
  }

  /// Matches backend CLAIMS_PENDING queue: claims SUBMITTED|REJECTED and
  /// pre-auths PENDING|DENIED.
  static bool isClaimsPendingItem(BillingWorkItem item) {
    final String status = (item.status ?? '').trim().toUpperCase();
    if (item.isClaim) {
      return status == 'SUBMITTED' || status == 'REJECTED';
    }
    if (item.isPreAuthorization) {
      return status == 'PENDING' || status == 'DENIED';
    }
    return false;
  }

  static bool _shouldRemoveFromVisibleQueue(
    BillingQueueType queue,
    BillingWorkItem item,
  ) {
    return switch (queue) {
      BillingQueueType.pendingPayment => !isPendingPaymentItem(item),
      BillingQueueType.overdue => !isOverdueItem(item),
      BillingQueueType.needsIssue => !isNeedsIssueItem(item),
      BillingQueueType.approvalRequired => !isPendingApprovalItem(item),
      BillingQueueType.claimsPending => !isClaimsPendingItem(item),
      _ => false,
    };
  }

  static BillingWorkItem? _findExistingItem(
    BillingWorkspaceState state,
    BillingWorkItem? candidate,
  ) {
    if (candidate == null) {
      return null;
    }
    if (state.selectedItem?.id == candidate.id) {
      return state.selectedItem;
    }
    for (final BillingWorkItem item in state.workItems.items) {
      if (item.id == candidate.id) {
        return item;
      }
    }
    return null;
  }

  static BillingWorkItem _mergePaymentIntoInvoice(
    BillingWorkItem invoice,
    BillingPayment payment,
  ) {
    final List<BillingPayment> payments = invoice.payments
        .where((BillingPayment existing) => existing.id != payment.id)
        .toList(growable: true);
    payments.insert(0, payment);

    final BillingFinancials recomputed = _recomputeFinancials(
      invoiceTotal: invoice.financials.invoiceTotal != 0
          ? invoice.financials.invoiceTotal
          : invoice.amount,
      adjustmentTotal: invoice.financials.adjustmentTotal,
      payments: payments,
    );
    final BillingFinancials financials =
        _preferAuthoritativeFinancials(invoice.financials, recomputed);
    final bool fullyPaid = financials.balanceDue <= 0.009;
    final bool partiallyPaid = financials.netPaidTotal > 0 && !fullyPaid;
    final String billingStatus = (invoice.billingStatus ?? '')
        .trim()
        .toUpperCase();

    return invoice.copyWith(
      payments: payments,
      financials: financials,
      billingStatus: fullyPaid && billingStatus != 'CANCELLED'
          ? 'PAID'
          : partiallyPaid && billingStatus != 'CANCELLED'
          ? 'PARTIAL'
          : invoice.billingStatus,
      status: fullyPaid && billingStatus != 'CANCELLED'
          ? 'PAID'
          : invoice.status,
    );
  }

  /// Prefer API financials when they already reflect at least as much paid.
  static BillingFinancials _preferAuthoritativeFinancials(
    BillingFinancials fromMutation,
    BillingFinancials recomputed,
  ) {
    if (fromMutation.netPaidTotal >= recomputed.netPaidTotal &&
        fromMutation.balanceDue <= recomputed.balanceDue) {
      return fromMutation;
    }
    return recomputed;
  }

  static BillingFinancials _recomputeFinancials({
    required num invoiceTotal,
    required num adjustmentTotal,
    required List<BillingPayment> payments,
  }) {
    final num grossPaid = payments.fold<num>(0, (
      num total,
      BillingPayment payment,
    ) {
      final String status = (payment.status ?? '').trim().toUpperCase();
      if (status != 'COMPLETED' && status != 'REFUNDED') {
        return total;
      }
      return total + payment.amount;
    });
    final num effectiveTotal = invoiceTotal + adjustmentTotal;
    final num balanceDue = effectiveTotal - grossPaid;
    return BillingFinancials(
      invoiceTotal: invoiceTotal,
      adjustmentTotal: adjustmentTotal,
      effectiveTotal: effectiveTotal,
      grossPaidTotal: grossPaid,
      netPaidTotal: grossPaid,
      balanceDue: balanceDue < 0 ? 0 : balanceDue,
    );
  }

  static AppPage<BillingWorkItem> _upsertWorkItem(
    AppPage<BillingWorkItem> page,
    BillingWorkItem item,
  ) {
    final List<BillingWorkItem> items = page.items
        .where((BillingWorkItem existing) => existing.id != item.id)
        .toList(growable: true);
    final bool inserted = items.length == page.items.length;
    items.insert(0, item);
    final int maxItems = page.request.pageSize;
    final List<BillingWorkItem> visible = items.length > maxItems
        ? items.take(maxItems).toList(growable: false)
        : items.toList(growable: false);

    return AppPage<BillingWorkItem>(
      items: visible,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : page.totalItemCount! + (inserted ? 1 : 0),
    );
  }

  static AppPage<BillingWorkItem> _removeWorkItem(
    AppPage<BillingWorkItem> page,
    String id,
  ) {
    final List<BillingWorkItem> items = page.items
        .where((BillingWorkItem existing) => existing.id != id)
        .toList(growable: false);
    if (items.length == page.items.length) {
      return page;
    }
    return AppPage<BillingWorkItem>(
      items: items,
      request: page.request,
      totalItemCount: page.totalItemCount == null
          ? null
          : (page.totalItemCount! - 1).clamp(0, 1 << 30),
    );
  }

  static BillingSummary _adjustSummary(
    BillingSummary summary, {
    required bool wasNeedsIssue,
    required bool isNeedsIssue,
    required bool wasPendingPayment,
    required bool isPendingPayment,
    required bool wasOverdue,
    required bool isOverdue,
    required bool wasPendingApproval,
    required bool isPendingApproval,
    required bool wasClaimsPending,
    required bool isClaimsPending,
    num? paymentAmount,
  }) {
    var needsIssue = summary.needsIssue;
    var pendingPayment = summary.pendingPayment;
    var overdue = summary.overdue;
    var approvalRequired = summary.approvalRequired;
    var claimsPending = summary.claimsPending;
    var paymentsTodayTotal = summary.paymentsTodayTotal;

    if (wasNeedsIssue && !isNeedsIssue) {
      needsIssue = (needsIssue - 1).clamp(0, 1 << 30);
    } else if (!wasNeedsIssue && isNeedsIssue) {
      needsIssue += 1;
    }

    if (wasPendingPayment && !isPendingPayment) {
      pendingPayment = (pendingPayment - 1).clamp(0, 1 << 30);
    } else if (!wasPendingPayment && isPendingPayment) {
      pendingPayment += 1;
    }

    if (wasOverdue && !isOverdue) {
      overdue = (overdue - 1).clamp(0, 1 << 30);
    } else if (!wasOverdue && isOverdue) {
      overdue += 1;
    }

    if (wasPendingApproval && !isPendingApproval) {
      approvalRequired = (approvalRequired - 1).clamp(0, 1 << 30);
    } else if (!wasPendingApproval && isPendingApproval) {
      approvalRequired += 1;
    }

    if (wasClaimsPending && !isClaimsPending) {
      claimsPending = (claimsPending - 1).clamp(0, 1 << 30);
    } else if (!wasClaimsPending && isClaimsPending) {
      claimsPending += 1;
    }

    if (paymentAmount != null && paymentAmount > 0) {
      paymentsTodayTotal += paymentAmount;
    }

    return summary.copyWith(
      needsIssue: needsIssue,
      pendingPayment: pendingPayment,
      overdue: overdue,
      approvalRequired: approvalRequired,
      claimsPending: claimsPending,
      paymentsTodayTotal: paymentsTodayTotal,
    );
  }

  static List<BillingQueueSummary> _queuesFromSummary(
    List<BillingQueueSummary> existing,
    BillingSummary summary,
  ) {
    if (existing.isEmpty) {
      return <BillingQueueSummary>[
        BillingQueueSummary(
          queue: BillingQueueType.needsIssue,
          label: 'To issue',
          count: summary.needsIssue,
        ),
        BillingQueueSummary(
          queue: BillingQueueType.pendingPayment,
          label: 'Pending payment',
          count: summary.pendingPayment,
        ),
        BillingQueueSummary(
          queue: BillingQueueType.claimsPending,
          label: 'Claims pending',
          count: summary.claimsPending,
        ),
        BillingQueueSummary(
          queue: BillingQueueType.approvalRequired,
          label: 'Need approval',
          count: summary.approvalRequired,
        ),
        BillingQueueSummary(
          queue: BillingQueueType.overdue,
          label: 'Overdue',
          count: summary.overdue,
        ),
      ];
    }

    return existing
        .map(
          (BillingQueueSummary queue) => BillingQueueSummary(
            queue: queue.queue,
            label: queue.label,
            count: summary.countFor(queue.queue),
          ),
        )
        .toList(growable: false);
  }
}
