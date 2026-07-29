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
      'reception:read' => permissionCatalogReceptionRead,
      'patients:read' => permissionCatalogPatientsRead,
      'opd:read' => permissionCatalogOpdRead,
      'ipd:read' => permissionCatalogIpdRead,
      'rooms_beds:read' => permissionCatalogRoomsBedsRead,
      'icu:read' => permissionCatalogIcuRead,
      'nursing:read' => permissionCatalogNursingRead,
      'physiotherapy:read' => permissionCatalogPhysiotherapyRead,
      'theater:read' => permissionCatalogTheaterRead,
      'discharge:read' => permissionCatalogDischargeRead,
      'claims:read' => permissionCatalogClaimsRead,
      'housekeeping:read' => permissionCatalogHousekeepingRead,
      'setup:read' => permissionCatalogSetupRead,
      'access_admin:read' => permissionCatalogAccessAdminRead,
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

  /// Prefer localized catalog labels; fall back to synced API display names.
  String permissionAssignmentLabelForCode(
    String code, {
    String? displayName,
  }) {
    final String localized = permissionCatalogLabelForCode(code);
    if (localized != code) {
      return localized;
    }
    final String synced = (displayName ?? '').trim();
    if (synced.isNotEmpty) {
      return synced;
    }
    return code;
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
    'reception:read' => 'Open the Reception workspace menu and route.',
    'patients:read' => 'Open the Patients registry menu and route.',
    'opd:read' => 'Open the OPD workspace menu and route.',
    'ipd:read' => 'Open the IPD workspace menu and route.',
    'rooms_beds:read' => 'Open the Rooms & beds workspace menu and route.',
    'icu:read' => 'Open the ICU workspace menu and route.',
    'nursing:read' => 'Open the Nursing workspace menu and route.',
    'physiotherapy:read' => 'Open the Physiotherapy workspace menu and route.',
    'theater:read' => 'Open the Theater workspace menu and route.',
    'discharge:read' => 'Open the Discharge workspace menu and route.',
    'claims:read' => 'Open the Claims workspace menu and route.',
    'housekeeping:read' => 'Open the Housekeeping workspace menu and route.',
    'setup:read' => 'Open Administrative Setup menu and route.',
    'access_admin:read' => 'Open Access Admin menu and route.',
    _ => null,
  };
}

String _humanizePermissionToken(String token) {
  const Map<String, String> known = <String, String>{
    'profile': 'Profile',
    'patient': 'Patient',
    'patients': 'Patients Registry',
    'reception': 'Reception',
    'opd': 'OPD',
    'ipd': 'IPD',
    'rooms_beds': 'Rooms & Beds',
    'icu': 'ICU',
    'nursing': 'Nursing',
    'physiotherapy': 'Physiotherapy',
    'theater': 'Theater',
    'discharge': 'Discharge',
    'claims': 'Claims',
    'housekeeping': 'Housekeeping',
    'setup': 'Administrative Setup',
    'access_admin': 'Access Admin',
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
