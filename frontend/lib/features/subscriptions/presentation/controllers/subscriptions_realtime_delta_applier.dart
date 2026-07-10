import 'package:hosspi_hms/core/workspace/primary_list_page_sync.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';
import 'package:hosspi_hms/features/subscriptions/data/dtos/subscription_dtos.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Applies subscriptions workspace realtime deltas without HTTP when possible.
abstract final class SubscriptionsRealtimeDeltaApplier {
  static SubscriptionsWorkspaceState? apply(
    SubscriptionsWorkspaceState state,
    RealtimeDelta delta,
  ) {
    final SubscriptionResource? resource = _resourceForDelta(delta);
    if (resource == null) {
      return null;
    }

    if (delta.action == RealtimeSyncAction.remove) {
      return _applyRemove(state, delta, resource);
    }

    final Map<String, Object?>? entity = delta.entity;
    if (entity == null) {
      return null;
    }

    final SubscriptionItem item = SubscriptionItemDto(
      Map<String, dynamic>.from(entity),
      resource: resource,
    ).toEntity();
    if (item.id.isEmpty) {
      return null;
    }
    if (state.query.resource != resource) {
      return null;
    }
    if (!_matchesScope(state, item)) {
      return null;
    }

    return _upsertItem(state, item);
  }

  static SubscriptionsWorkspaceState? _applyRemove(
    SubscriptionsWorkspaceState state,
    RealtimeDelta delta,
    SubscriptionResource resource,
  ) {
    final String? id = delta.resourceId;
    if (id == null || id.isEmpty || state.query.resource != resource) {
      return null;
    }

    final AppPage<SubscriptionItem> page =
        PrimaryListPageSync.remove<SubscriptionItem>(
          page: state.data.items,
          id: id,
          matchesId: (SubscriptionItem item, String targetId) =>
              item.id == targetId || item.effectiveDisplayId == targetId,
        );
    SubscriptionItem? selected = state.selectedItem;
    if (selected != null &&
        !page.items.any((SubscriptionItem item) => item.id == selected!.id)) {
      selected = null;
    }

    return state.copyWith(
      data: state.data.copyWith(items: page),
      selectedItem: selected,
      isRefreshing: false,
    );
  }

  static SubscriptionsWorkspaceState _upsertItem(
    SubscriptionsWorkspaceState state,
    SubscriptionItem item,
  ) {
    final AppPage<SubscriptionItem> page =
        PrimaryListPageSync.upsert<SubscriptionItem>(
          page: state.data.items,
          item: item,
          matches: (SubscriptionItem left, SubscriptionItem right) =>
              left.id == right.id ||
              left.effectiveDisplayId == right.effectiveDisplayId,
        );
    SubscriptionItem? selected = state.selectedItem;
    if (selected != null && selected.id == item.id) {
      selected = item;
    }

    return state.copyWith(
      data: state.data.copyWith(items: page),
      selectedItem: selected,
      isRefreshing: false,
    );
  }

  static bool _matchesScope(
    SubscriptionsWorkspaceState state,
    SubscriptionItem item,
  ) {
    final String? tenantId = state.query.tenantId;
    if (tenantId != null &&
        item.tenantId != null &&
        tenantId != item.tenantId) {
      return false;
    }
    return true;
  }

  static SubscriptionResource? _resourceForDelta(RealtimeDelta delta) {
    final String? type = delta.resourceType?.toLowerCase();
    return switch (type) {
      'subscription' => SubscriptionResource.subscriptions,
      'subscription_plan' || 'plan' => SubscriptionResource.subscriptionPlans,
      'module_subscription' => SubscriptionResource.moduleSubscriptions,
      'license' => SubscriptionResource.licenses,
      'subscription_invoice' ||
      'invoice' => SubscriptionResource.subscriptionInvoices,
      _ => null,
    };
  }
}
