import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';

/// Platform infrastructure module for the Reports workspace (all packages).
const String reportsActiveModule = 'reporting-analytics';

/// Admin keys documented in `screens/reports.md` write/export gates.
const List<AppPermission> _reportsAdminPermissions = <AppPermission>[
  AppPermissions.tenantAdmin,
  AppPermissions.facilityAdmin,
  AppPermissions.systemAdmin,
];

/// Route / workspace entry (matrix ∪): `reports:read` or `compliance:read`.
/// Module is platform infrastructure — not package-gated.
const AccessRequirement reportsWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.reportsRead,
    AppPermissions.complianceRead,
  ],
);

/// Catalog / delivery / dashboards / monitor / activity / schedules / timeline.
const AccessRequirement reportsCatalogReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.reportsRead],
);

/// Compliance panels (audit / PHI / processing): `compliance:read` or review.
const AccessRequirement reportsComplianceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.complianceRead,
    AppPermissions.complianceReview,
  ],
);

/// Create/update (run, schedule, retry, cancel). Matrix ∩: `reports:write`.
/// Source inventory also allows tenant/facility/system admin (see [canWriteReports]).
const AccessRequirement reportsWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.reportsWrite],
);

/// Hard-delete of definitions/schedules/runs. Matrix ∩: `reports:delete`.
/// No delete affordance on this tab yet; reserved for nested delete entry points.
const AccessRequirement reportsDeleteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.reportsDelete],
);

/// Export / download / print. Source: `evidence:export` (or admin).
/// Matrix prose also mentions `reports:write`; inventory + backend download use
/// `evidence:export` — keep source and note that mapping in tests.
const AccessRequirement reportsExportRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.evidenceExport],
);

bool _isReportsAdmin(AppAccessPolicy policy) {
  return policy.grantsAny(_reportsAdminPermissions);
}

bool canReadReportsWorkspace(AppAccessPolicy policy) {
  return reportsWorkspaceReadRequirement.isAllowed(policy) ||
      _isReportsAdmin(policy);
}

bool canReadReportsCatalog(AppAccessPolicy policy) {
  return reportsCatalogReadRequirement.isAllowed(policy) ||
      _isReportsAdmin(policy);
}

bool canReadReportsCompliance(AppAccessPolicy policy) {
  return reportsComplianceReadRequirement.isAllowed(policy) ||
      _isReportsAdmin(policy);
}

/// Write gate from `screens/reports.md`: `reports:write` or admin.
bool canWriteReports(AppAccessPolicy policy) {
  return reportsWriteRequirement.isAllowed(policy) || _isReportsAdmin(policy);
}

/// Delete gate (matrix ∩ `reports:delete`); admins also qualify.
bool canDeleteReports(AppAccessPolicy policy) {
  return reportsDeleteRequirement.isAllowed(policy) || _isReportsAdmin(policy);
}

/// Export gate from `screens/reports.md`: `evidence:export` or admin.
bool canExportEvidence(AppAccessPolicy policy) {
  return reportsExportRequirement.isAllowed(policy) || _isReportsAdmin(policy);
}

AccessRequirement reportsPanelReadRequirement(ReportsWorkspacePanel panel) {
  return panel.isCompliance
      ? reportsComplianceReadRequirement
      : reportsCatalogReadRequirement;
}

bool canAccessReportsPanel(
  AppAccessPolicy policy,
  ReportsWorkspacePanel panel,
) {
  return panel.isCompliance
      ? canReadReportsCompliance(policy)
      : canReadReportsCatalog(policy);
}

/// Panels the user may open; empty when neither catalog nor compliance read.
List<ReportsWorkspacePanel> reportsAllowedPanels(AppAccessPolicy policy) {
  return ReportsWorkspacePanel.values
      .where((ReportsWorkspacePanel panel) => canAccessReportsPanel(policy, panel))
      .toList(growable: false);
}

ReportsWorkspacePanel? reportsFallbackPanel(AppAccessPolicy policy) {
  final List<ReportsWorkspacePanel> allowed = reportsAllowedPanels(policy);
  if (allowed.isEmpty) {
    return null;
  }
  return allowed.first;
}
