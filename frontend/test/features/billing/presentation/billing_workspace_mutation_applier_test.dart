import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_mutation_applier.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  test('clears pending-payment counts and removes paid rows from that queue', () {
    const BillingWorkItem unpaid = BillingWorkItem(
      id: 'invoice-1',
      displayId: 'INV-001',
      kind: BillingWorkItemKind.invoice,
      tenantId: 'tenant-1',
      billingStatus: 'ISSUED',
      status: 'SENT',
      amount: 500,
      financials: BillingFinancials(
        effectiveTotal: 500,
        balanceDue: 500,
      ),
    );
    final BillingWorkspaceState state = BillingWorkspaceState(
      query: const BillingWorkspaceQuery(queue: BillingQueueType.pendingPayment),
      overview: const BillingWorkspaceOverview(
        summary: BillingSummary(pendingPayment: 1, overdue: 0),
        queues: <BillingQueueSummary>[
          BillingQueueSummary(
            queue: BillingQueueType.pendingPayment,
            label: 'Pending payment',
            count: 1,
          ),
        ],
      ),
      workItems: const AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[unpaid],
        request: AppPageRequest(),
        totalItemCount: 1,
      ),
      selectedItem: unpaid,
    );

    final BillingWorkspaceState patched = BillingWorkspaceMutationApplier.apply(
      state,
      BillingMutationResult(
        invoice: unpaid.copyWith(
          billingStatus: 'PAID',
          financials: const BillingFinancials(
            effectiveTotal: 500,
            grossPaidTotal: 500,
            netPaidTotal: 500,
            balanceDue: 0,
          ),
        ),
        payment: const BillingPayment(
          id: 'pay-1',
          status: 'COMPLETED',
          amount: 500,
        ),
      ),
    );

    expect(patched.overview.summary.pendingPayment, 0);
    expect(patched.overview.queues.single.count, 0);
    expect(patched.workItems.items, isEmpty);
    expect(patched.selectedItem?.id, 'invoice-1');
    expect(patched.selectedItem?.paidAmount, 500);
    expect(patched.selectedItem?.balanceDue, 0);
    expect(patched.selectedItem?.canReceivePayment, isFalse);
    expect(patched.isSaving, isFalse);
    expect(patched.isRefreshing, isFalse);
  });

  test('recomputes paid and balance when mutation financials are stale', () {
    const BillingWorkItem unpaid = BillingWorkItem(
      id: 'invoice-1',
      displayId: 'INV-001',
      kind: BillingWorkItemKind.invoice,
      tenantId: 'tenant-1',
      billingStatus: 'ISSUED',
      status: 'SENT',
      amount: 25000,
      financials: BillingFinancials(
        invoiceTotal: 25000,
        effectiveTotal: 25000,
        balanceDue: 25000,
      ),
    );
    final BillingWorkspaceState state = BillingWorkspaceState(
      query: const BillingWorkspaceQuery(),
      overview: const BillingWorkspaceOverview(
        summary: BillingSummary(pendingPayment: 1),
      ),
      workItems: const AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[unpaid],
        request: AppPageRequest(),
        totalItemCount: 1,
      ),
      selectedItem: unpaid,
    );

    final BillingWorkspaceState patched = BillingWorkspaceMutationApplier.apply(
      state,
      const BillingMutationResult(
        // Nested invoice still looks unpaid (stale financials).
        invoice: unpaid,
        payment: BillingPayment(
          id: 'pay-1',
          status: 'COMPLETED',
          amount: 25000,
        ),
      ),
    );

    expect(patched.selectedItem?.paidAmount, 25000);
    expect(patched.selectedItem?.balanceDue, 0);
    expect(patched.selectedItem?.billingStatus, 'PAID');
    expect(patched.overview.summary.pendingPayment, 0);
    expect(patched.workItems.items.single.paidAmount, 25000);
  });

  test('clears approval-required counts and removes decided rows from that queue', () {
    const BillingWorkItem pendingApproval = BillingWorkItem(
      id: 'approval-1',
      displayId: 'APR-001',
      kind: BillingWorkItemKind.approval,
      status: 'PENDING',
      amount: 100,
    );
    final BillingWorkspaceState state = BillingWorkspaceState(
      query: const BillingWorkspaceQuery(
        queue: BillingQueueType.approvalRequired,
      ),
      overview: const BillingWorkspaceOverview(
        summary: BillingSummary(approvalRequired: 1),
        queues: <BillingQueueSummary>[
          BillingQueueSummary(
            queue: BillingQueueType.approvalRequired,
            label: 'Approval required',
            count: 1,
          ),
        ],
      ),
      workItems: const AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[pendingApproval],
        request: AppPageRequest(),
        totalItemCount: 1,
      ),
      selectedItem: pendingApproval,
    );

    final BillingWorkspaceState patched = BillingWorkspaceMutationApplier.apply(
      state,
      BillingMutationResult(
        approval: pendingApproval.copyWith(status: 'APPROVED'),
      ),
    );

    expect(patched.overview.summary.approvalRequired, 0);
    expect(patched.overview.queues.single.count, 0);
    expect(patched.workItems.items, isEmpty);
    expect(patched.selectedItem?.status, 'APPROVED');
    expect(patched.selectedItem?.canApproveOrReject, isFalse);
  });

  test('clears needs-issue counts and removes issued drafts from that queue', () {
    const BillingWorkItem draft = BillingWorkItem(
      id: 'invoice-draft',
      displayId: 'INV-DRAFT',
      kind: BillingWorkItemKind.invoice,
      tenantId: 'tenant-1',
      billingStatus: 'DRAFT',
      status: 'DRAFT',
      amount: 120,
      financials: BillingFinancials(
        effectiveTotal: 120,
        balanceDue: 120,
      ),
      items: <BillingInvoiceItem>[
        BillingInvoiceItem(
          id: 'line-1',
          description: 'Consult',
          quantity: 1,
          unitPrice: 120,
          totalPrice: 120,
          sourceModule: 'OPD',
        ),
      ],
    );
    final BillingWorkspaceState state = BillingWorkspaceState(
      query: const BillingWorkspaceQuery(queue: BillingQueueType.needsIssue),
      overview: const BillingWorkspaceOverview(
        summary: BillingSummary(needsIssue: 1, pendingPayment: 0),
        queues: <BillingQueueSummary>[
          BillingQueueSummary(
            queue: BillingQueueType.needsIssue,
            label: 'To issue',
            count: 1,
          ),
        ],
      ),
      workItems: const AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[draft],
        request: AppPageRequest(),
        totalItemCount: 1,
      ),
      selectedItem: draft,
    );

    final BillingWorkItem issued = draft.copyWith(
      billingStatus: 'ISSUED',
      status: 'SENT',
    );
    final BillingWorkspaceState patched = BillingWorkspaceMutationApplier.apply(
      state,
      BillingMutationResult(invoice: issued),
    );

    expect(patched.overview.summary.needsIssue, 0);
    expect(patched.overview.queues.single.count, 0);
    expect(patched.workItems.items, isEmpty);
    expect(patched.selectedItem?.billingStatus, 'ISSUED');
    expect(patched.selectedItem?.canIssue, isFalse);
    expect(patched.selectedItem?.items.single.sourceModule, 'OPD');
  });

  test('idempotent re-issue patch does not double-decrement needsIssue', () {
    const BillingWorkItem issued = BillingWorkItem(
      id: 'invoice-issued',
      displayId: 'INV-ISSUED',
      kind: BillingWorkItemKind.invoice,
      tenantId: 'tenant-1',
      billingStatus: 'ISSUED',
      status: 'SENT',
      amount: 80,
      financials: BillingFinancials(effectiveTotal: 80, balanceDue: 80),
    );
    final BillingWorkspaceState state = BillingWorkspaceState(
      query: const BillingWorkspaceQuery(queue: BillingQueueType.needsIssue),
      overview: const BillingWorkspaceOverview(
        summary: BillingSummary(needsIssue: 0),
        queues: <BillingQueueSummary>[
          BillingQueueSummary(
            queue: BillingQueueType.needsIssue,
            label: 'To issue',
            count: 0,
          ),
        ],
      ),
      workItems: const AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[],
        request: AppPageRequest(),
        totalItemCount: 0,
      ),
      selectedItem: issued,
    );

    final BillingWorkspaceState patched = BillingWorkspaceMutationApplier.apply(
      state,
      const BillingMutationResult(invoice: issued),
    );

    expect(patched.overview.summary.needsIssue, 0);
    expect(patched.overview.queues.single.count, 0);
  });

  test('keeps selected paid invoice when it leaves the pending-payment queue', () {
    const BillingWorkItem unpaid = BillingWorkItem(
      id: 'invoice-1',
      displayId: 'INV-001',
      kind: BillingWorkItemKind.invoice,
      tenantId: 'tenant-1',
      billingStatus: 'ISSUED',
      status: 'SENT',
      amount: 210000,
      financials: BillingFinancials(
        invoiceTotal: 210000,
        effectiveTotal: 210000,
        balanceDue: 210000,
      ),
    );
    final BillingWorkspaceState state = BillingWorkspaceState(
      query: const BillingWorkspaceQuery(queue: BillingQueueType.pendingPayment),
      overview: const BillingWorkspaceOverview(
        summary: BillingSummary(pendingPayment: 1),
      ),
      workItems: const AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[unpaid],
        request: AppPageRequest(),
        totalItemCount: 1,
      ),
      selectedItem: unpaid,
    );

    final BillingWorkspaceState patched = BillingWorkspaceMutationApplier.apply(
      state,
      const BillingMutationResult(
        invoice: BillingWorkItem(
          id: 'invoice-1',
          displayId: 'INV-001',
          kind: BillingWorkItemKind.invoice,
          tenantId: 'tenant-1',
          billingStatus: 'PAID',
          status: 'PAID',
          amount: 210000,
          financials: BillingFinancials(
            invoiceTotal: 210000,
            effectiveTotal: 210000,
            grossPaidTotal: 210000,
            netPaidTotal: 210000,
            balanceDue: 0,
          ),
        ),
        payment: BillingPayment(
          id: 'pay-1',
          status: 'COMPLETED',
          amount: 210000,
        ),
      ),
    );

    expect(patched.workItems.items, isEmpty);
    expect(patched.selectedItem?.id, 'invoice-1');
    expect(patched.selectedItem?.balanceDue, 0);
    expect(patched.selectedItem?.paidAmount, 210000);
    expect(patched.selectedItem?.billingStatus, 'PAID');
    expect(patched.overview.summary.pendingPayment, 0);
  });
}
