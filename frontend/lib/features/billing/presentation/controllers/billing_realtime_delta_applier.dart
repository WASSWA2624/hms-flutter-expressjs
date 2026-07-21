import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';
import 'package:hosspi_hms/features/billing/data/dtos/billing_dtos.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_mutation_applier.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Applies billing workspace realtime deltas without HTTP when payload is enough.
abstract final class BillingRealtimeDeltaApplier {
  static BillingWorkspaceState? apply(
    BillingWorkspaceState state,
    RealtimeDelta delta,
  ) {
    if (delta.action == RealtimeSyncAction.remove) {
      return _applyRemove(state, delta);
    }

    final Map<String, Object?>? entity = delta.entity;
    if (entity == null) {
      return null;
    }

    final BillingWorkItem item = BillingWorkItemDto(
      Map<String, dynamic>.from(entity),
      fallbackQueue: state.query.queue,
    ).toEntity();
    if (item.id.isEmpty) {
      return null;
    }

    return BillingWorkspaceMutationApplier.apply(
      state,
      BillingMutationResult(invoice: item.isInvoice ? item : null),
    );
  }

  static BillingWorkspaceState? _applyRemove(
    BillingWorkspaceState state,
    RealtimeDelta delta,
  ) {
    final String? id = delta.resourceId;
    if (id == null || id.isEmpty) {
      return null;
    }

    BillingWorkItem? previous;
    final List<BillingWorkItem> items = <BillingWorkItem>[];
    for (final BillingWorkItem item in state.workItems.items) {
      if (item.id == id) {
        previous = item;
        continue;
      }
      items.add(item);
    }
    if (previous == null) {
      return null;
    }

    final bool wasPending =
        BillingWorkspaceMutationApplier.isPendingPaymentItem(previous);
    final bool wasOverdue =
        BillingWorkspaceMutationApplier.isOverdueItem(previous);

    final BillingSummary summary = state.overview.summary.copyWith(
      pendingPayment: wasPending
          ? (state.overview.summary.pendingPayment - 1).clamp(0, 1 << 30)
          : state.overview.summary.pendingPayment,
      overdue: wasOverdue
          ? (state.overview.summary.overdue - 1).clamp(0, 1 << 30)
          : state.overview.summary.overdue,
    );

    BillingWorkItem? selected = state.selectedItem;
    if (selected?.id == id) {
      selected = items.isEmpty ? null : items.first;
    }

    return state.copyWith(
      overview: state.overview.copyWith(
        summary: summary,
        queues: state.overview.queues
            .map(
              (BillingQueueSummary queue) => BillingQueueSummary(
                queue: queue.queue,
                label: queue.label,
                count: summary.countFor(queue.queue),
              ),
            )
            .toList(growable: false),
      ),
      workItems: AppPage<BillingWorkItem>(
        items: items,
        request: state.workItems.request,
        totalItemCount: state.workItems.totalItemCount == null
            ? null
            : (state.workItems.totalItemCount! - 1).clamp(0, 1 << 30),
      ),
      selectedItem: selected,
      clearSelectedItem: selected == null && state.selectedItem != null,
      isRefreshing: false,
    );
  }
}
