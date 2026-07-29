import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_atom_permissions.dart';

/// Tab-level and atom [AccessRequirement] helpers for the home dashboard.
///
/// Matrix (`prompts/ui-permissions/_screens/home.md`):
/// - View / read UI (∩): [AppPermissions.profileRead]
/// - Create / update / delete / nested cross-module: _(n/a)_ at tab level
///
/// Per-atom KPI, queue, alert, chart, shortcut, and action gates remain those
/// documented in `prompts/dashboard.md` / [HomeDashboardAtomPermissions]
/// (all-of within each atom; union across grants filters the visible set).
const AccessRequirement homeTabReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileRead],
);

/// Charts / trend / distribution blocks (`reports:read`, Dashboard.md).
const AccessRequirement homeChartsRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.reportsRead],
);

/// Builds an all-of requirement for a home atom permission list.
///
/// Empty lists are never treated as public — evaluate with [homeAllows]
/// (or [HomeDashboardAtomPermissions.isGranted]), not bare [AccessRequirement.isAllowed].
AccessRequirement homeAtomRequirement(
  Iterable<AppPermission> allPermissions,
) {
  return AccessRequirement(
    allPermissions: List<AppPermission>.unmodifiable(allPermissions),
  );
}

/// Home-atom gate: denies empty permission lists, then applies [requirement].
///
/// Prefer this (or catalog helpers below) at presentation call sites so KPI /
/// queue / alert / shortcut atoms never render as public when unresolved.
bool homeAllows(AppAccessPolicy policy, AccessRequirement requirement) {
  final List<AppPermission> all = requirement.allPermissions.toList(
    growable: false,
  );
  final List<AppPermission> any = requirement.anyPermissions.toList(
    growable: false,
  );
  if (all.isEmpty && any.isEmpty) {
    return false;
  }
  return requirement.isAllowed(policy);
}

/// Convenience: all-of list via [homeAtomRequirement] + [homeAllows].
bool homeAllowsAll(
  AppAccessPolicy policy,
  Iterable<AppPermission> allPermissions,
) {
  return homeAllows(policy, homeAtomRequirement(allPermissions));
}

/// Status / KPI card requirement from catalog or declared permissions.
AccessRequirement homeStatusCardRequirement({
  required String id,
  List<AppPermission> declared = const <AppPermission>[],
}) {
  return homeAtomRequirement(
    HomeDashboardAtomPermissions.resolveStatusCard(
      id: id,
      declared: declared,
    ),
  );
}

/// Shortcut requirement from catalog or declared permissions.
AccessRequirement homeShortcutRequirement({
  required String id,
  List<AppPermission> declared = const <AppPermission>[],
}) {
  if (declared.isNotEmpty) {
    return homeAtomRequirement(declared);
  }
  return homeAtomRequirement(HomeDashboardAtomPermissions.forShortcut(id));
}

/// Queue / results / follow-up row requirement from catalog or declared list.
AccessRequirement homeQueueItemRequirement({
  required String id,
  String? moduleSlug,
  List<AppPermission> declared = const <AppPermission>[],
}) {
  if (declared.isNotEmpty) {
    return homeAtomRequirement(declared);
  }
  return homeAtomRequirement(
    HomeDashboardAtomPermissions.forQueueItem(id: id, moduleSlug: moduleSlug),
  );
}

/// Alert row requirement from catalog or declared list.
AccessRequirement homeAlertRequirement({
  required String id,
  String? moduleSlug,
  List<AppPermission> declared = const <AppPermission>[],
}) {
  if (declared.isNotEmpty) {
    return homeAtomRequirement(declared);
  }
  return homeAtomRequirement(
    HomeDashboardAtomPermissions.forAlert(id: id, moduleSlug: moduleSlug),
  );
}
