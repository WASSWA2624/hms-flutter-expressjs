import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

/// Worklist Export / Print on `/admin/setup` — ∩ `evidence:export`.
const AccessRequirement tenantFacilitySetupExportRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.evidenceExport],
    );

/// Alias — list Print uses the same desk export gate.
const AccessRequirement tenantFacilitySetupPrintRequirement =
    tenantFacilitySetupExportRequirement;

bool canExportTenantFacilitySetup(AppAccessPolicy policy) {
  return tenantFacilitySetupExportRequirement.isAllowed(policy);
}

bool canPrintTenantFacilitySetup(AppAccessPolicy policy) {
  return tenantFacilitySetupPrintRequirement.isAllowed(policy);
}
