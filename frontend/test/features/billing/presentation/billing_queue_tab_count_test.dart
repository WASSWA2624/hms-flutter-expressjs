import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  const BillingSummary summary = BillingSummary(
    needsIssue: 4,
    pendingPayment: 3,
    claimsPending: 2,
    approvalRequired: 1,
    overdue: 5,
  );

  BillingWorkspaceState state({
    String search = '',
    bool overdueOnly = false,
    int? totalItemCount,
    List<BillingWorkItem> items = const <BillingWorkItem>[],
  }) {
    return BillingWorkspaceState(
      overview: const BillingWorkspaceOverview(summary: summary),
      workItems: AppPage<BillingWorkItem>(
        items: items,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: totalItemCount,
      ),
      query: BillingWorkspaceQuery(
        search: search,
        overdueOnly: overdueOnly,
      ),
    );
  }

  test('sibling tabs use dedicated summary totals', () {
    final BillingWorkspaceState current = state(totalItemCount: 1);
    expect(
      billingQueueTabCount(
        current,
        BillingQueueType.needsIssue,
        activeQueue: BillingQueueType.all,
      ),
      4,
    );
    expect(
      billingQueueTabCount(
        current,
        BillingQueueType.pendingPayment,
        activeQueue: BillingQueueType.all,
      ),
      3,
    );
  });

  test('active tab without filters uses summary total', () {
    final BillingWorkspaceState current = state(totalItemCount: 1);
    expect(
      billingQueueTabCount(
        current,
        BillingQueueType.needsIssue,
        activeQueue: BillingQueueType.needsIssue,
      ),
      4,
    );
  });

  test('active tab with search uses filtered page total', () {
    final BillingWorkspaceState current = state(
      search: 'Ada',
      totalItemCount: 1,
    );
    expect(
      billingQueueTabCount(
        current,
        BillingQueueType.needsIssue,
        activeQueue: BillingQueueType.needsIssue,
      ),
      1,
    );
  });

  test('active tab with advanced filters uses filtered page total', () {
    final BillingWorkspaceState current = state(
      overdueOnly: true,
      totalItemCount: 2,
    );
    expect(
      billingQueueTabCount(
        current,
        BillingQueueType.pendingPayment,
        activeQueue: BillingQueueType.pendingPayment,
      ),
      2,
    );
  });

  test('price book active keeps queue siblings on summary totals', () {
    final BillingWorkspaceState current = state(
      search: 'Ada',
      totalItemCount: 1,
    );
    expect(
      billingQueueTabCount(
        current,
        BillingQueueType.all,
        activeQueue: BillingQueueType.all,
        priceBookActive: true,
      ),
      summary.countFor(BillingQueueType.all),
    );
  });

  test('tones match urgency policy', () {
    expect(billingQueueCountTone(BillingQueueType.all), AppTabCountTone.info);
    expect(
      billingQueueCountTone(BillingQueueType.needsIssue),
      AppTabCountTone.warning,
    );
    expect(
      billingQueueCountTone(BillingQueueType.pendingPayment),
      AppTabCountTone.warning,
    );
    expect(
      billingQueueCountTone(BillingQueueType.claimsPending),
      AppTabCountTone.warning,
    );
    expect(
      billingQueueCountTone(BillingQueueType.approvalRequired),
      AppTabCountTone.warning,
    );
    expect(
      billingQueueCountTone(BillingQueueType.overdue),
      AppTabCountTone.danger,
    );
    expect(billingPriceBookCountTone(), AppTabCountTone.info);
  });
}
