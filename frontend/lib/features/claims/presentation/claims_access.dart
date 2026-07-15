import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

/// Write access for claims workspace mutations (request auth, prepare claim).
const AccessRequirement claimsWorkspaceWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.billingWrite],
  activeModules: <String>['insurance-claims'],
);

/// Financial approve access for settlement and close operations.
const AccessRequirement claimsFinancialApproveRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.financialApprove],
  activeModules: <String>['insurance-claims'],
);
