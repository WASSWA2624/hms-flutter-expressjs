import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

/// View / read UI for the Profile account surface (`profile:read` ∩).
///
/// Profile rights are core/platform (not plan-module mapped); subscription
/// stripping does not apply to these keys. The surface is inherently own-scoped
/// via the current-user profile API.
const AccessRequirement profileReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileRead],
);

/// Update mutations on the Profile account surface (`profile:update` ∩):
/// edit profile and change password.
const AccessRequirement profileUpdateRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileUpdate],
);
