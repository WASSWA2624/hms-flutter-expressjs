import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';

void main() {
  group('BillingWorkspaceQuery.fromUri', () {
    test('defaults to all when queue is absent', () {
      final BillingWorkspaceQuery query = BillingWorkspaceQuery.fromUri(
        Uri.parse('/billing'),
      );
      expect(query.queue, BillingQueueType.all);
    });

    test('parses kebab-case queue slugs', () {
      expect(
        BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=needs-issue'),
        ).queue,
        BillingQueueType.needsIssue,
      );
      expect(
        BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=pending-payment'),
        ).queue,
        BillingQueueType.pendingPayment,
      );
      expect(
        BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=claims-pending'),
        ).queue,
        BillingQueueType.claimsPending,
      );
      expect(
        BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=approval-required'),
        ).queue,
        BillingQueueType.approvalRequired,
      );
      expect(
        BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=overdue'),
        ).queue,
        BillingQueueType.overdue,
      );
    });

    test('parses enum name and server values', () {
      expect(
        BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=pendingPayment'),
        ).queue,
        BillingQueueType.pendingPayment,
      );
      expect(
        BillingWorkspaceQuery.fromUri(
          Uri.parse('/billing?queue=PENDING_PAYMENT'),
        ).queue,
        BillingQueueType.pendingPayment,
      );
    });
  });

  group('BillingWorkspaceQuery.hasActiveFilters', () {
    test('ignores queue-only selection owned by the tab strip', () {
      expect(
        const BillingWorkspaceQuery(
          queue: BillingQueueType.needsIssue,
        ).hasActiveFilters,
        isFalse,
      );
      expect(
        const BillingWorkspaceQuery(
          queue: BillingQueueType.needsIssue,
          patientId: 'PT-1',
        ).hasActiveFilters,
        isTrue,
      );
    });
  });
}
