import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Human-readable labels and descriptions for canonical [AppPermission] catalog
/// entries. Description generation mirrors
/// `backend/src/config/permission-catalog-metadata.js`.
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

  /// Catalog description for [code], never the display-name label.
  ///
  /// Prefer synced DB descriptions when present on list items; use this when
  /// the API subtitle/description is blank.
  String permissionCatalogDescriptionForCode(String code) {
    final String normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    final String? override = _permissionDescriptionOverride(normalized);
    if (override != null) {
      return override;
    }

    final int separator = normalized.indexOf(':');
    if (separator <= 0 || separator >= normalized.length - 1) {
      return '';
    }

    final String domainLabel = _humanizePermissionToken(
      normalized.substring(0, separator),
    );
    final String actionLabel = _humanizePermissionToken(
      normalized.substring(separator + 1),
    );
    return 'Allows ${actionLabel.toLowerCase()} access within '
        '${domainLabel.toLowerCase()}.';
  }
}

String? _permissionDescriptionOverride(String code) {
  return switch (code) {
    'facility:admin' =>
      'Manage facility configuration, users, and operational settings.',
    'tenant:admin' =>
      'Manage tenant-wide settings, facilities, subscriptions, and access.',
    'system:admin' =>
      'Full platform administration across tenants and global settings.',
    'financial:approve' =>
      'Approve financial transactions, adjustments, and billing exceptions.',
    'evidence:export' =>
      'Export audit evidence and compliance records for review.',
    'break_glass:request' =>
      'Request temporary elevated access to restricted patient records.',
    'break_glass:review' =>
      'Review break-glass access requests submitted by clinical staff.',
    'break_glass:approve' => 'Approve or deny break-glass access requests.',
    _ => null,
  };
}

String _humanizePermissionToken(String token) {
  const Map<String, String> known = <String, String>{
    'profile': 'Profile',
    'patient': 'Patient',
    'clinical': 'Clinical',
    'emergency': 'Emergency',
    'lab': 'Lab',
    'radiology': 'Radiology',
    'pharmacy': 'Pharmacy',
    'billing': 'Billing',
    'operations': 'Operations',
    'hr': 'HR',
    'unit': 'Unit',
    'roster': 'Roster',
    'biomed': 'Biomed',
    'mortuary': 'Mortuary',
    'communications': 'Communications',
    'integration': 'Integration',
    'reports': 'Reports',
    'subscriptions': 'Subscriptions',
    'last_office': 'Last Office',
    'compliance': 'Compliance',
    'break_glass': 'Break Glass',
    'evidence': 'Evidence',
    'financial': 'Financial',
    'facility': 'Facility',
    'tenant': 'Tenant',
    'system': 'System',
    'read': 'Read',
    'write': 'Write',
    'delete': 'Delete',
    'update': 'Update',
    'manage': 'Manage',
    'publish': 'Publish',
    'approve': 'Approve',
    'release': 'Release',
    'manage_storage': 'Manage Storage',
    'post_mortem_request': 'Post-Mortem Request',
    'billing_event': 'Billing Event',
    'export': 'Export',
    'audit': 'Audit',
    'review': 'Review',
    'request': 'Request',
    'admin': 'Admin',
  };

  final String? mapped = known[token];
  if (mapped != null) {
    return mapped;
  }

  return token
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
