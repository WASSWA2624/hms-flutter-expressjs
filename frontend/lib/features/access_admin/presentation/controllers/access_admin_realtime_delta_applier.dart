import 'package:hosspi_hms/core/workspace/primary_list_page_sync.dart';
import 'package:hosspi_hms/core/workspace/realtime_delta.dart';
import 'package:hosspi_hms/core/workspace/realtime_sync_action.dart';
import 'package:hosspi_hms/features/access_admin/data/dtos/access_admin_dtos.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Applies access-admin workspace realtime deltas without HTTP when possible.
abstract final class AccessAdminRealtimeDeltaApplier {
  static AccessAdminWorkspaceState? apply(
    AccessAdminWorkspaceState state,
    RealtimeDelta delta,
  ) {
    final AccessAdminResource? resource = _resourceForDelta(delta);
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

    final AccessAdminItem item = AccessAdminItemDto.fromJson(
      Map<String, dynamic>.from(entity),
      resource,
    ).toEntity();
    if (item.id.isEmpty) {
      return null;
    }
    if (!_matchesScope(state, item)) {
      return _adjustOverviewOnly(state, resource, delta.action);
    }
    if (state.query.resource != resource) {
      return _adjustOverviewOnly(state, resource, delta.action);
    }

    return _upsertItem(state, item);
  }

  static AccessAdminWorkspaceState? _applyRemove(
    AccessAdminWorkspaceState state,
    RealtimeDelta delta,
    AccessAdminResource resource,
  ) {
    final String? id = delta.resourceId;
    if (id == null || id.isEmpty) {
      return null;
    }
    if (state.query.resource != resource) {
      return _adjustOverviewOnly(state, resource, delta.action);
    }

    final AppPage<AccessAdminItem> page = PrimaryListPageSync.remove<AccessAdminItem>(
      page: state.data.page,
      id: id,
      matchesId: (AccessAdminItem item, String targetId) =>
          item.id == targetId || item.effectiveDisplayId == targetId,
    );
    return _withPage(state, page, resource, delta.action);
  }

  static AccessAdminWorkspaceState _upsertItem(
    AccessAdminWorkspaceState state,
    AccessAdminItem item,
  ) {
    final AppPage<AccessAdminItem> page = PrimaryListPageSync.upsert<AccessAdminItem>(
      page: state.data.page,
      item: item,
      matches: (AccessAdminItem left, AccessAdminItem right) =>
          left.id == right.id || left.effectiveDisplayId == right.effectiveDisplayId,
    );
    return _withPage(state, page, state.query.resource, RealtimeSyncAction.upsert);
  }

  static AccessAdminWorkspaceState _withPage(
    AccessAdminWorkspaceState state,
    AppPage<AccessAdminItem> page,
    AccessAdminResource resource,
    RealtimeSyncAction action,
  ) {
    final AccessAdminOverview overview = _overviewAfterChange(
      state.data.overview,
      resource,
      action,
    );
    AccessAdminItem? selected = state.selectedItem;
    if (selected != null &&
        !page.items.any(
          (AccessAdminItem item) => item.id == selected!.id,
        )) {
      selected = null;
    } else if (action == RealtimeSyncAction.upsert) {
      for (final AccessAdminItem item in page.items) {
        if (selected != null && item.id == selected.id) {
          selected = item;
          break;
        }
      }
    }

    return state.copyWith(
      data: state.data.copyWith(
        overview: overview,
        items: page.items,
        page: page,
      ),
      selectedItem: selected,
      isRefreshing: false,
    );
  }

  static AccessAdminWorkspaceState? _adjustOverviewOnly(
    AccessAdminWorkspaceState state,
    AccessAdminResource resource,
    RealtimeSyncAction action,
  ) {
    final AccessAdminOverview overview = _overviewAfterChange(
      state.data.overview,
      resource,
      action,
    );
    if (overview == state.data.overview) {
      return null;
    }
    return state.copyWith(
      data: state.data.copyWith(overview: overview),
      isRefreshing: false,
    );
  }

  static AccessAdminOverview _overviewAfterChange(
    AccessAdminOverview overview,
    AccessAdminResource resource,
    RealtimeSyncAction action,
  ) {
    final int sign = action == RealtimeSyncAction.remove ? -1 : 1;
    return switch (resource) {
      AccessAdminResource.users => overview.copyWith(
        activeUsers: (overview.activeUsers + sign).clamp(0, 1 << 30),
      ),
      AccessAdminResource.roles => overview.copyWith(
        totalRoles: (overview.totalRoles + sign).clamp(0, 1 << 30),
      ),
      AccessAdminResource.permissions => overview.copyWith(
        totalPermissions: (overview.totalPermissions + sign).clamp(0, 1 << 30),
      ),
      AccessAdminResource.demoUsers => overview.copyWith(
        demoUsers: (overview.demoUsers + sign).clamp(0, 1 << 30),
      ),
      AccessAdminResource.userRoles => overview.copyWith(
        totalAssignments: (overview.totalAssignments + sign).clamp(0, 1 << 30),
      ),
      _ => overview,
    };
  }

  static bool _matchesScope(AccessAdminWorkspaceState state, AccessAdminItem item) {
    final String? tenantId = state.query.tenantId;
    final String? facilityId = state.query.facilityId;
    if (tenantId != null && item.tenantId != null && tenantId != item.tenantId) {
      return false;
    }
    if (facilityId != null &&
        item.facilityId != null &&
        facilityId != item.facilityId) {
      return false;
    }
    return true;
  }

  static AccessAdminResource? _resourceForDelta(RealtimeDelta delta) {
    final String? type = delta.resourceType?.toLowerCase();
    return switch (type) {
      'user' => AccessAdminResource.users,
      'role' => AccessAdminResource.roles,
      'permission' => AccessAdminResource.permissions,
      'user_role' => AccessAdminResource.userRoles,
      'role_permission' => AccessAdminResource.rolePermissions,
      'module_entitlement' => AccessAdminResource.moduleEntitlements,
      _ => null,
    };
  }
}

extension on AccessAdminOverview {
  AccessAdminOverview copyWith({
    int? activeUsers,
    int? inactiveUsers,
    int? totalRoles,
    int? totalPermissions,
    int? totalAssignments,
    int? demoUsers,
    String? subscriptionPlan,
    int? activeModulesCount,
  }) {
    return AccessAdminOverview(
      activeUsers: activeUsers ?? this.activeUsers,
      inactiveUsers: inactiveUsers ?? this.inactiveUsers,
      totalRoles: totalRoles ?? this.totalRoles,
      totalPermissions: totalPermissions ?? this.totalPermissions,
      totalAssignments: totalAssignments ?? this.totalAssignments,
      demoUsers: demoUsers ?? this.demoUsers,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      activeModulesCount: activeModulesCount ?? this.activeModulesCount,
    );
  }
}
