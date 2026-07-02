import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

String accessRequirementDenialMessage(
  AppLocalizations l10n,
  AccessRequirement requirement,
  AppAccessPolicy policy,
) {
  if (requirement.isAllowed(policy)) {
    return l10n.accessDeniedPermissionRequired;
  }

  if (requirement.anyRoles.isNotEmpty && !policy.hasAnyRole(requirement.anyRoles)) {
    return l10n.accessDeniedRoleRequired;
  }

  if (requirement.allPermissions.isNotEmpty &&
      !policy.grantsAll(requirement.allPermissions)) {
    return l10n.accessDeniedPermissionRequired;
  }

  if (requirement.anyPermissions.isNotEmpty &&
      !policy.grantsAny(requirement.anyPermissions)) {
    return l10n.accessDeniedPermissionRequired;
  }

  if (requirement.requiresTenantContext &&
      !policy.hasTenantContext &&
      !policy.isElevated) {
    return l10n.accessDeniedTenantContextRequired;
  }

  if (requirement.requiresFacilityContext &&
      !policy.hasFacilityContext &&
      !policy.isElevated) {
    return l10n.accessDeniedFacilityContextRequired;
  }

  for (final String moduleCode in requirement.activeModules) {
    if (!policy.hasActiveModule(moduleCode)) {
      return l10n.accessDeniedModuleRequired(
        accessRequirementModuleLabel(l10n, moduleCode),
      );
    }
  }

  return l10n.accessDeniedPermissionRequired;
}

String accessRequirementModuleLabel(AppLocalizations l10n, String moduleCode) {
  return switch (moduleCode.trim().toLowerCase()) {
    'inpatient-bed-management' => l10n.accessDeniedModuleInpatientLabel,
    'lab' => l10n.accessDeniedModuleLabLabel,
    'radiology' => l10n.accessDeniedModuleRadiologyLabel,
    'theater' => l10n.accessDeniedModuleTheaterLabel,
    'physiotherapy' => l10n.accessDeniedModulePhysiotherapyLabel,
    _ => AppDisplay.apiLabel(moduleCode),
  };
}
