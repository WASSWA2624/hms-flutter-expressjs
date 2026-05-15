import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';

enum AppRole {
  superAdmin('SUPER_ADMIN'),
  tenantAdmin('TENANT_ADMIN'),
  facilityAdmin('FACILITY_ADMIN'),
  doctor('DOCTOR'),
  nurse('NURSE'),
  labTech('LAB_TECH'),
  pharmacist('PHARMACIST'),
  receptionist('RECEPTIONIST'),
  billing('BILLING'),
  operations('OPERATIONS'),
  hr('HR'),
  biomed('BIOMED'),
  houseKeeper('HOUSE_KEEPER'),
  ambulanceOperator('AMBULANCE_OPERATOR'),
  unitManager('UNIT_MANAGER'),
  wardManager('WARD_MANAGER'),
  icuManager('ICU_MANAGER'),
  theatreManager('THEATRE_MANAGER'),
  housekeepingManager('HOUSEKEEPING_MANAGER'),
  biomedManager('BIOMED_MANAGER'),
  mortuaryStaff('MORTUARY_STAFF'),
  mortuaryManager('MORTUARY_MANAGER'),
  patient('PATIENT'),
  other('OTHER');

  const AppRole(this.value);

  final String value;
}

abstract final class AppPermissions {
  static const profileRead = AppPermission('profile:read');
  static const profileUpdate = AppPermission('profile:update');
  static const patientRead = AppPermission('patient:read');
  static const patientWrite = AppPermission('patient:write');
  static const patientDelete = AppPermission('patient:delete');
  static const clinicalRead = AppPermission('clinical:read');
  static const clinicalWrite = AppPermission('clinical:write');
  static const emergencyRead = AppPermission('emergency:read');
  static const emergencyWrite = AppPermission('emergency:write');
  static const emergencyDelete = AppPermission('emergency:delete');
  static const labRead = AppPermission('lab:read');
  static const labWrite = AppPermission('lab:write');
  static const pharmacyRead = AppPermission('pharmacy:read');
  static const pharmacyWrite = AppPermission('pharmacy:write');
  static const billingRead = AppPermission('billing:read');
  static const billingWrite = AppPermission('billing:write');
  static const operationsRead = AppPermission('operations:read');
  static const operationsWrite = AppPermission('operations:write');
  static const hrRead = AppPermission('hr:read');
  static const hrWrite = AppPermission('hr:write');
  static const unitRead = AppPermission('unit:read');
  static const unitManage = AppPermission('unit:manage');
  static const rosterRead = AppPermission('roster:read');
  static const rosterWrite = AppPermission('roster:write');
  static const rosterPublish = AppPermission('roster:publish');
  static const rosterApprove = AppPermission('roster:approve');
  static const biomedRead = AppPermission('biomed:read');
  static const biomedWrite = AppPermission('biomed:write');
  static const mortuaryRead = AppPermission('mortuary:read');
  static const mortuaryWrite = AppPermission('mortuary:write');
  static const mortuaryRelease = AppPermission('mortuary:release');
  static const mortuaryManageStorage = AppPermission('mortuary:manage_storage');
  static const mortuaryPostMortemRequest = AppPermission(
    'mortuary:post_mortem_request',
  );
  static const mortuaryApprove = AppPermission('mortuary:approve');
  static const mortuaryBillingEvent = AppPermission('mortuary:billing_event');
  static const mortuaryExport = AppPermission('mortuary:export');
  static const mortuaryAudit = AppPermission('mortuary:audit');
  static const communicationsRead = AppPermission('communications:read');
  static const communicationsWrite = AppPermission('communications:write');
  static const communicationsDelete = AppPermission('communications:delete');
  static const reportsRead = AppPermission('reports:read');
  static const reportsWrite = AppPermission('reports:write');
  static const reportsDelete = AppPermission('reports:delete');
  static const subscriptionsRead = AppPermission('subscriptions:read');
  static const subscriptionsWrite = AppPermission('subscriptions:write');
  static const subscriptionsDelete = AppPermission('subscriptions:delete');
  static const lastOfficeRead = AppPermission('last_office:read');
  static const lastOfficeWrite = AppPermission('last_office:write');
  static const lastOfficeApprove = AppPermission('last_office:approve');
  static const complianceRead = AppPermission('compliance:read');
  static const complianceReview = AppPermission('compliance:review');
  static const breakGlassRequest = AppPermission('break_glass:request');
  static const breakGlassReview = AppPermission('break_glass:review');
  static const breakGlassApprove = AppPermission('break_glass:approve');
  static const evidenceExport = AppPermission('evidence:export');
  static const financialApprove = AppPermission('financial:approve');
  static const facilityAdmin = AppPermission('facility:admin');
  static const tenantAdmin = AppPermission('tenant:admin');
  static const systemAdmin = AppPermission('system:admin');

  static const adminAccess = <AppPermission>[
    tenantAdmin,
    facilityAdmin,
    profileRead,
    profileUpdate,
    patientRead,
    patientWrite,
    patientDelete,
    clinicalRead,
    clinicalWrite,
    emergencyRead,
    emergencyWrite,
    emergencyDelete,
    labRead,
    labWrite,
    pharmacyRead,
    pharmacyWrite,
    billingRead,
    billingWrite,
    operationsRead,
    operationsWrite,
    hrRead,
    hrWrite,
    unitRead,
    unitManage,
    rosterRead,
    rosterWrite,
    rosterPublish,
    rosterApprove,
    biomedRead,
    biomedWrite,
    mortuaryRead,
    mortuaryWrite,
    mortuaryRelease,
    mortuaryManageStorage,
    mortuaryPostMortemRequest,
    mortuaryApprove,
    mortuaryBillingEvent,
    mortuaryExport,
    mortuaryAudit,
    communicationsRead,
    communicationsWrite,
    communicationsDelete,
    reportsRead,
    reportsWrite,
    reportsDelete,
    subscriptionsRead,
    subscriptionsWrite,
    subscriptionsDelete,
    lastOfficeRead,
    lastOfficeWrite,
    lastOfficeApprove,
    complianceRead,
    complianceReview,
    breakGlassRequest,
    breakGlassReview,
    breakGlassApprove,
    evidenceExport,
    financialApprove,
  ];

  static final Set<AppPermission> all = <AppPermission>{
    ...adminAccess,
    systemAdmin,
  };
}

final class AppAccessPolicy {
  AppAccessPolicy._({
    required this.roles,
    required this.permissions,
    required this.tenantId,
    required this.facilityId,
    required this.branchId,
    required this.moduleEntitlements,
  });

  factory AppAccessPolicy.fromSession(AuthSession? session) {
    final AuthUserProfile? user = session?.user;
    final roles = _rolesFrom(user?.roles ?? const <String>[]);
    final explicitPermissions = session?.permissions ?? const <AppPermission>{};
    final rolePermissions = roles.expand(_permissionsForRole).toSet();

    return AppAccessPolicy._(
      roles: roles,
      permissions: Set<AppPermission>.unmodifiable(<AppPermission>{
        ...explicitPermissions,
        ...rolePermissions,
        if (roles.contains(AppRole.superAdmin)) ...AppPermissions.all,
      }),
      tenantId: _nonEmpty(user?.tenantId),
      facilityId: _nonEmpty(user?.facilityId),
      branchId: _nonEmpty(user?.branchId),
      moduleEntitlements:
          session?.moduleEntitlements ?? const <String, AppModuleEntitlement>{},
    );
  }

  final Set<AppRole> roles;
  final Set<AppPermission> permissions;
  final String? tenantId;
  final String? facilityId;
  final String? branchId;
  final Map<String, AppModuleEntitlement> moduleEntitlements;

  AppAccessPolicy copyWithPermissions(Iterable<AppPermission> permissions) {
    return AppAccessPolicy._(
      roles: roles,
      permissions: Set<AppPermission>.unmodifiable(permissions),
      tenantId: tenantId,
      facilityId: facilityId,
      branchId: branchId,
      moduleEntitlements: moduleEntitlements,
    );
  }

  bool get isElevated => roles.contains(AppRole.superAdmin);
  bool get hasTenantContext => tenantId != null;
  bool get hasFacilityContext => facilityId != null;

  bool hasRole(AppRole role) => roles.contains(role);

  bool hasAnyRole(Iterable<AppRole> requiredRoles) {
    if (requiredRoles.isEmpty) {
      return true;
    }
    if (isElevated) {
      return true;
    }

    return requiredRoles.any(roles.contains);
  }

  bool grants(AppPermission permission) {
    return isElevated || permissions.contains(permission);
  }

  bool grantsAll(Iterable<AppPermission> requiredPermissions) {
    return requiredPermissions.every(grants);
  }

  bool grantsAny(Iterable<AppPermission> requiredPermissions) {
    return requiredPermissions.any(grants);
  }

  bool canManageTenant() {
    return isElevated || grants(AppPermissions.tenantAdmin);
  }

  bool canManageFacility() {
    return isElevated ||
        grantsAny(const <AppPermission>[
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]);
  }

  bool canReadBedManagement() {
    return isElevated ||
        grantsAny(const <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.operationsRead,
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]);
  }

  bool hasActiveModule(String moduleCode) {
    if (isElevated) {
      return true;
    }
    if (moduleEntitlements.isEmpty) {
      return true;
    }

    final normalizedCode = AppModuleEntitlement.normalizeModuleCode(moduleCode);
    return moduleEntitlements[normalizedCode]?.isAvailable == true;
  }

  bool hasAllActiveModules(Iterable<String> moduleCodes) {
    return moduleCodes.every(hasActiveModule);
  }

  static Set<AppRole> _rolesFrom(Iterable<String> values) {
    return values.map(_normalizeRole).whereType<AppRole>().toSet();
  }

  static AppRole? _normalizeRole(String value) {
    final normalized = value.trim().toUpperCase();
    final aliased = switch (normalized) {
      'ADMIN' || 'OWNER' => AppRole.tenantAdmin.value,
      'APP_ADMIN' ||
      'SYSTEM_ADMIN' ||
      'PLATFORM_ADMIN' => AppRole.superAdmin.value,
      'FACILITY_MANAGER' ||
      'HOSPITAL_ADMIN' ||
      'HOSPITAL_MANAGER' => AppRole.facilityAdmin.value,
      'AMBULANCE_DRIVER' ||
      'EMT' ||
      'PARAMEDIC' => AppRole.ambulanceOperator.value,
      'WARD_IN_CHARGE' ||
      'CHARGE_NURSE' ||
      'MATRON' => AppRole.wardManager.value,
      'MORTUARY_OFFICER' || 'MORGUE_ATTENDANT' => AppRole.mortuaryStaff.value,
      'HOUSEKEEPING_SUPERVISOR' => AppRole.housekeepingManager.value,
      'USER' || 'GUEST' => AppRole.other.value,
      _ => normalized,
    };

    for (final role in AppRole.values) {
      if (role.value == aliased) {
        return role;
      }
    }

    return null;
  }

  static Iterable<AppPermission> _permissionsForRole(AppRole role) {
    return switch (role) {
      AppRole.superAdmin => AppPermissions.all,
      AppRole.tenantAdmin => AppPermissions.adminAccess,
      AppRole.facilityAdmin => AppPermissions.adminAccess.where(
        (permission) => permission != AppPermissions.tenantAdmin,
      ),
      AppRole.doctor => const <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.profileRead,
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
        AppPermissions.breakGlassRequest,
        AppPermissions.lastOfficeRead,
      ],
      AppRole.nurse => const <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.profileRead,
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
        AppPermissions.breakGlassRequest,
        AppPermissions.lastOfficeRead,
        AppPermissions.lastOfficeWrite,
      ],
      AppRole.labTech => const <AppPermission>[
        AppPermissions.labRead,
        AppPermissions.labWrite,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.profileRead,
      ],
      AppRole.pharmacist => const <AppPermission>[
        AppPermissions.pharmacyRead,
        AppPermissions.pharmacyWrite,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.profileRead,
      ],
      AppRole.receptionist => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.profileUpdate,
        AppPermissions.operationsRead,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
        AppPermissions.lastOfficeRead,
        AppPermissions.lastOfficeWrite,
      ],
      AppRole.billing => const <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
        AppPermissions.financialApprove,
        AppPermissions.evidenceExport,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.reportsRead,
        AppPermissions.profileRead,
      ],
      AppRole.operations => const <AppPermission>[
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
        AppPermissions.lastOfficeRead,
        AppPermissions.lastOfficeWrite,
        AppPermissions.lastOfficeApprove,
        AppPermissions.complianceRead,
        AppPermissions.complianceReview,
        AppPermissions.breakGlassReview,
        AppPermissions.breakGlassApprove,
        AppPermissions.evidenceExport,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.reportsRead,
        AppPermissions.profileRead,
      ],
      AppRole.hr => const <AppPermission>[
        AppPermissions.hrRead,
        AppPermissions.hrWrite,
        AppPermissions.unitRead,
        AppPermissions.unitManage,
        AppPermissions.rosterRead,
        AppPermissions.rosterWrite,
        AppPermissions.rosterPublish,
        AppPermissions.rosterApprove,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.reportsRead,
        AppPermissions.profileRead,
      ],
      AppRole.unitManager => const <AppPermission>[
        AppPermissions.hrRead,
        AppPermissions.unitRead,
        AppPermissions.unitManage,
        AppPermissions.rosterRead,
        AppPermissions.rosterWrite,
        AppPermissions.rosterPublish,
        AppPermissions.rosterApprove,
        AppPermissions.reportsRead,
        AppPermissions.profileRead,
      ],
      AppRole.wardManager => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.patientRead,
        AppPermissions.clinicalRead,
        AppPermissions.hrRead,
        AppPermissions.unitRead,
        AppPermissions.unitManage,
        AppPermissions.rosterRead,
        AppPermissions.rosterWrite,
        AppPermissions.rosterPublish,
        AppPermissions.rosterApprove,
        AppPermissions.reportsRead,
        AppPermissions.lastOfficeRead,
      ],
      AppRole.icuManager => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.patientRead,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.hrRead,
        AppPermissions.unitRead,
        AppPermissions.unitManage,
        AppPermissions.rosterRead,
        AppPermissions.rosterWrite,
        AppPermissions.rosterPublish,
        AppPermissions.rosterApprove,
        AppPermissions.reportsRead,
        AppPermissions.lastOfficeRead,
      ],
      AppRole.theatreManager => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.patientRead,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.hrRead,
        AppPermissions.unitRead,
        AppPermissions.unitManage,
        AppPermissions.rosterRead,
        AppPermissions.rosterWrite,
        AppPermissions.rosterPublish,
        AppPermissions.rosterApprove,
        AppPermissions.reportsRead,
      ],
      AppRole.housekeepingManager => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.operationsRead,
        AppPermissions.operationsWrite,
        AppPermissions.hrRead,
        AppPermissions.unitRead,
        AppPermissions.unitManage,
        AppPermissions.rosterRead,
        AppPermissions.rosterWrite,
        AppPermissions.reportsRead,
        AppPermissions.lastOfficeRead,
      ],
      AppRole.biomedManager => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.biomedRead,
        AppPermissions.biomedWrite,
        AppPermissions.hrRead,
        AppPermissions.unitRead,
        AppPermissions.unitManage,
        AppPermissions.rosterRead,
        AppPermissions.rosterWrite,
        AppPermissions.reportsRead,
        AppPermissions.evidenceExport,
      ],
      AppRole.biomed => const <AppPermission>[
        AppPermissions.biomedRead,
        AppPermissions.biomedWrite,
        AppPermissions.evidenceExport,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.profileRead,
      ],
      AppRole.houseKeeper => const <AppPermission>[
        AppPermissions.operationsRead,
        AppPermissions.communicationsRead,
        AppPermissions.profileRead,
        AppPermissions.patientRead,
      ],
      AppRole.ambulanceOperator => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      ],
      AppRole.mortuaryStaff => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.patientRead,
        AppPermissions.mortuaryRead,
        AppPermissions.mortuaryWrite,
        AppPermissions.mortuaryManageStorage,
        AppPermissions.mortuaryPostMortemRequest,
        AppPermissions.mortuaryBillingEvent,
        AppPermissions.reportsRead,
      ],
      AppRole.mortuaryManager => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.patientRead,
        AppPermissions.mortuaryRead,
        AppPermissions.mortuaryWrite,
        AppPermissions.mortuaryRelease,
        AppPermissions.mortuaryManageStorage,
        AppPermissions.mortuaryPostMortemRequest,
        AppPermissions.mortuaryApprove,
        AppPermissions.mortuaryBillingEvent,
        AppPermissions.mortuaryExport,
        AppPermissions.mortuaryAudit,
        AppPermissions.reportsRead,
        AppPermissions.evidenceExport,
      ],
      AppRole.patient => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.profileUpdate,
        AppPermissions.patientRead,
      ],
      AppRole.other => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.patientRead,
      ],
    };
  }

  static String? _nonEmpty(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
