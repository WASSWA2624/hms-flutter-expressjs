import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Human-readable labels for canonical [AppPermission] catalog entries.
extension AppPermissionCatalogLocalizations on AppLocalizations {
  String permissionCatalogLabel(AppPermission permission) {
    return permissionCatalogLabelForCode(permission.value);
  }

  String permissionCatalogLabelForCode(String code) {
    return switch (code) {
      'profile:read' => permissionCatalogProfileRead,
      'profile:update' => permissionCatalogProfileUpdate,
      'patient:read' => permissionCatalogPatientRead,
      'patient:write' => permissionCatalogPatientWrite,
      'patient:delete' => permissionCatalogPatientDelete,
      'clinical:read' => permissionCatalogClinicalRead,
      'clinical:write' => permissionCatalogClinicalWrite,
      'emergency:read' => permissionCatalogEmergencyRead,
      'emergency:write' => permissionCatalogEmergencyWrite,
      'emergency:delete' => permissionCatalogEmergencyDelete,
      'lab:read' => permissionCatalogLabRead,
      'lab:write' => permissionCatalogLabWrite,
      'radiology:read' => permissionCatalogRadiologyRead,
      'radiology:write' => permissionCatalogRadiologyWrite,
      'pharmacy:read' => permissionCatalogPharmacyRead,
      'pharmacy:write' => permissionCatalogPharmacyWrite,
      'billing:read' => permissionCatalogBillingRead,
      'billing:write' => permissionCatalogBillingWrite,
      'operations:read' => permissionCatalogOperationsRead,
      'operations:write' => permissionCatalogOperationsWrite,
      'hr:read' => permissionCatalogHrRead,
      'hr:write' => permissionCatalogHrWrite,
      'unit:read' => permissionCatalogUnitRead,
      'unit:manage' => permissionCatalogUnitManage,
      'roster:read' => permissionCatalogRosterRead,
      'roster:write' => permissionCatalogRosterWrite,
      'roster:publish' => permissionCatalogRosterPublish,
      'roster:approve' => permissionCatalogRosterApprove,
      'biomed:read' => permissionCatalogBiomedRead,
      'biomed:write' => permissionCatalogBiomedWrite,
      'mortuary:read' => permissionCatalogMortuaryRead,
      'mortuary:write' => permissionCatalogMortuaryWrite,
      'mortuary:release' => permissionCatalogMortuaryRelease,
      'mortuary:manage_storage' => permissionCatalogMortuaryManageStorage,
      'mortuary:post_mortem_request' =>
        permissionCatalogMortuaryPostMortemRequest,
      'mortuary:approve' => permissionCatalogMortuaryApprove,
      'mortuary:billing_event' => permissionCatalogMortuaryBillingEvent,
      'mortuary:export' => permissionCatalogMortuaryExport,
      'mortuary:audit' => permissionCatalogMortuaryAudit,
      'communications:read' => permissionCatalogCommunicationsRead,
      'communications:write' => permissionCatalogCommunicationsWrite,
      'communications:delete' => permissionCatalogCommunicationsDelete,
      'integration:read' => permissionCatalogIntegrationRead,
      'integration:write' => permissionCatalogIntegrationWrite,
      'integration:delete' => permissionCatalogIntegrationDelete,
      'reports:read' => permissionCatalogReportsRead,
      'reports:write' => permissionCatalogReportsWrite,
      'reports:delete' => permissionCatalogReportsDelete,
      'subscriptions:read' => permissionCatalogSubscriptionsRead,
      'subscriptions:write' => permissionCatalogSubscriptionsWrite,
      'subscriptions:delete' => permissionCatalogSubscriptionsDelete,
      'last_office:read' => permissionCatalogLastOfficeRead,
      'last_office:write' => permissionCatalogLastOfficeWrite,
      'last_office:approve' => permissionCatalogLastOfficeApprove,
      'compliance:read' => permissionCatalogComplianceRead,
      'compliance:review' => permissionCatalogComplianceReview,
      'break_glass:request' => permissionCatalogBreakGlassRequest,
      'break_glass:review' => permissionCatalogBreakGlassReview,
      'break_glass:approve' => permissionCatalogBreakGlassApprove,
      'evidence:export' => permissionCatalogEvidenceExport,
      'financial:approve' => permissionCatalogFinancialApprove,
      'facility:admin' => permissionCatalogFacilityAdmin,
      'tenant:admin' => permissionCatalogTenantAdmin,
      'system:admin' => permissionCatalogSystemAdmin,
      _ => code,
    };
  }

  String permissionCatalogDescriptionForCode(String code) {
    return permissionCatalogLabelForCode(code);
  }
}
