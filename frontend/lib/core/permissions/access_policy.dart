import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/commercial_module_tiers.dart';
import 'package:hosspi_hms/core/permissions/permission_module_map.dart';
import 'package:hosspi_hms/core/permissions/plan_permission_caps.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';

enum AppRole {
  superAdmin('SUPER_ADMIN'),
  tenantAdmin('TENANT_ADMIN'),
  facilityAdmin('FACILITY_ADMIN'),
  integrationAdmin('INTEGRATION_ADMIN'),
  doctor('DOCTOR'),
  nurse('NURSE'),
  labTech('LAB_TECH'),
  radiologyTech('RADIOLOGY_TECH'),
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
  static const radiologyRead = AppPermission('radiology:read');
  static const radiologyWrite = AppPermission('radiology:write');
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
  static const integrationRead = AppPermission('integration:read');
  static const integrationWrite = AppPermission('integration:write');
  static const integrationDelete = AppPermission('integration:delete');
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
    radiologyRead,
    radiologyWrite,
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
    integrationRead,
    integrationWrite,
    integrationDelete,
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
    required this.moduleEntitlements,
    this.planTierCode,
  });

  factory AppAccessPolicy.fromSession(AuthSession? session) {
    final AuthUserProfile? user = session?.user;
    final roles = _rolesFrom(user?.roles ?? const <String>[]);
    final explicitPermissions = session?.permissions ?? const <AppPermission>{};
    final rolePermissions = (user?.roles ?? const <String>[])
        .expand(_permissionsForRoleCode)
        .toSet();
    final bool elevated = roles.contains(AppRole.superAdmin);
    final Map<String, AppModuleEntitlement> entitlements =
        session?.moduleEntitlements ?? const <String, AppModuleEntitlement>{};
    final String? tenantId = _nonEmpty(user?.tenantId);
    final String? planTierCode = _resolvePlanTierCode(session);

    // Backend effective permissions are the ceiling. Only expand client role
    // packs when the session has not yet been enriched with an explicit set
    // (JWT-only restore before /auth/me). Never union role packs on top of
    // backend grants — that over-grants UI vs API.
    final Set<AppPermission> merged = <AppPermission>{
      if (elevated) ...AppPermissions.all,
      if (explicitPermissions.isNotEmpty ||
          (session?.isAuthorizationHydrated ?? false))
        ...explicitPermissions
      else
        ...rolePermissions,
    };

    // Plan modules take precedence: strip module-scoped rights the plan does
    // not entitle (platform elevated super admins keep the full set).
    final Set<AppPermission> moduleGated = elevated && tenantId == null
        ? merged
        : merged
              .where(
                (AppPermission permission) => _isPermissionAllowedByPlan(
                  permission,
                  entitlements,
                  hasTenantContext: tenantId != null,
                ),
              )
              .toSet();

    // Mirror backend PLAN_PERMISSION_CAPS so Advanced tenants cannot see Pro
    // shell destinations the API will forbid.
    final Set<AppPermission> planGated = elevated && tenantId == null
        ? moduleGated
        : PlanPermissionCaps.apply(
            moduleGated,
            PlanPermissionCaps.resolveFromSession(session),
          );

    return AppAccessPolicy._(
      roles: roles,
      permissions: Set<AppPermission>.unmodifiable(planGated),
      tenantId: tenantId,
      facilityId: _nonEmpty(user?.facilityId),
      moduleEntitlements: entitlements,
      planTierCode: planTierCode,
    );
  }

  final Set<AppRole> roles;
  final Set<AppPermission> permissions;
  final String? tenantId;
  final String? facilityId;
  final Map<String, AppModuleEntitlement> moduleEntitlements;
  final String? planTierCode;

  AppAccessPolicy copyWithPermissions(Iterable<AppPermission> permissions) {
    return AppAccessPolicy._(
      roles: roles,
      permissions: Set<AppPermission>.unmodifiable(permissions),
      tenantId: tenantId,
      facilityId: facilityId,
      moduleEntitlements: moduleEntitlements,
      planTierCode: planTierCode,
    );
  }

  bool get isElevated => roles.contains(AppRole.superAdmin);
  bool get isPlatformElevated => isElevated && !hasTenantContext;
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
    if (isPlatformElevated) {
      return true;
    }
    // Permissions are already plan-gated in fromSession; still re-check the
    // module so callers stay correct if copyWithPermissions bypasses that.
    if (!permissions.contains(permission)) {
      return false;
    }
    final String? moduleCode = PermissionModuleMap.moduleForPermission(
      permission,
    );
    if (moduleCode == null) {
      return true;
    }
    return hasActiveModule(moduleCode);
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

  bool canCreateTenant() {
    return isElevated || grants(AppPermissions.systemAdmin);
  }

  /// Tenant-wide roles (facility_id null) may be created by super/tenant admins.
  /// Facility admins must create facility-scoped roles only.
  bool canCreateTenantWideRole() {
    return isElevated ||
        hasRole(AppRole.tenantAdmin) ||
        grants(AppPermissions.tenantAdmin);
  }

  bool canManageFacility() {
    return isElevated ||
        grantsAny(const <AppPermission>[
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]);
  }

  /// Who may create, edit/update, or delete global radiology catalog procedures.
  ///
  /// Matches backend `RADIOLOGY_CATALOG_WRITE_SCOPES` on
  /// `/api/v1/radiology-procedures` mutations.
  bool canMutateRadiologyCatalog() {
    return isElevated ||
        grantsAny(const <AppPermission>[
          AppPermissions.radiologyWrite,
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]);
  }

  /// Who may start/complete subscription upgrade or renewal flows.
  ///
  /// Super / tenant / facility admins always qualify (even when the
  /// subscription-controls module is inactive, so expired tenants can renew).
  /// Custom roles qualify when they hold [AppPermissions.subscriptionsWrite]
  /// after plan gating.
  bool canManageSubscriptionBilling() {
    if (isElevated ||
        hasAnyRole(const <AppRole>[
          AppRole.tenantAdmin,
          AppRole.facilityAdmin,
        ])) {
      return true;
    }
    return permissions.contains(AppPermissions.subscriptionsWrite);
  }

  /// Lab technologists and lab-only custom roles see a reduced application shell.
  bool get isLabFocusedShellUser {
    if (isElevated) {
      return false;
    }
    if (hasAnyRole(const <AppRole>[
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.doctor,
      AppRole.nurse,
      AppRole.pharmacist,
      AppRole.radiologyTech,
      AppRole.receptionist,
      AppRole.billing,
      AppRole.hr,
      AppRole.operations,
      AppRole.biomed,
      AppRole.biomedManager,
      AppRole.ambulanceOperator,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.houseKeeper,
      AppRole.mortuaryStaff,
      AppRole.mortuaryManager,
      AppRole.unitManager,
    ])) {
      return false;
    }
    if (hasRole(AppRole.labTech)) {
      return true;
    }
    return grants(AppPermissions.labRead) &&
        !grantsAny(const <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]);
  }

  /// Pharmacists and pharmacy-only custom roles see a reduced application shell.
  bool get isPharmacistFocusedShellUser {
    if (isElevated) {
      return false;
    }
    if (hasAnyRole(const <AppRole>[
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.doctor,
      AppRole.nurse,
      AppRole.labTech,
      AppRole.radiologyTech,
      AppRole.receptionist,
      AppRole.billing,
      AppRole.hr,
      AppRole.operations,
      AppRole.biomed,
      AppRole.biomedManager,
      AppRole.ambulanceOperator,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.houseKeeper,
      AppRole.mortuaryStaff,
      AppRole.mortuaryManager,
      AppRole.unitManager,
    ])) {
      return false;
    }
    if (hasRole(AppRole.pharmacist)) {
      return true;
    }
    return grants(AppPermissions.pharmacyRead) &&
        !grantsAny(const <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.labRead,
          AppPermissions.labWrite,
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]);
  }

  /// Receptionists and front-desk-only custom roles see a reduced application shell.
  bool get isReceptionistFocusedShellUser {
    if (isElevated) {
      return false;
    }
    if (hasAnyRole(const <AppRole>[
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.doctor,
      AppRole.nurse,
      AppRole.labTech,
      AppRole.radiologyTech,
      AppRole.pharmacist,
      AppRole.billing,
      AppRole.hr,
      AppRole.operations,
      AppRole.biomed,
      AppRole.biomedManager,
      AppRole.ambulanceOperator,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.houseKeeper,
      AppRole.mortuaryStaff,
      AppRole.mortuaryManager,
      AppRole.unitManager,
    ])) {
      return false;
    }
    if (hasRole(AppRole.receptionist)) {
      return true;
    }
    return grants(AppPermissions.patientWrite) &&
        grants(AppPermissions.lastOfficeRead) &&
        !grantsAny(const <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.operationsWrite,
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]);
  }

  /// Billing / cashier roles see a reduced application shell.
  bool get isBillingFocusedShellUser {
    if (isElevated) {
      return false;
    }
    if (hasAnyRole(const <AppRole>[
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.doctor,
      AppRole.nurse,
      AppRole.labTech,
      AppRole.radiologyTech,
      AppRole.pharmacist,
      AppRole.receptionist,
      AppRole.hr,
      AppRole.operations,
      AppRole.biomed,
      AppRole.biomedManager,
      AppRole.ambulanceOperator,
      AppRole.wardManager,
      AppRole.icuManager,
      AppRole.theatreManager,
      AppRole.housekeepingManager,
      AppRole.houseKeeper,
      AppRole.mortuaryStaff,
      AppRole.mortuaryManager,
      AppRole.unitManager,
    ])) {
      return false;
    }
    if (hasRole(AppRole.billing)) {
      return true;
    }
    return grants(AppPermissions.billingRead) &&
        !grantsAny(const <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
          AppPermissions.patientWrite,
          AppPermissions.tenantAdmin,
          AppPermissions.facilityAdmin,
          AppPermissions.systemAdmin,
        ]);
  }

  /// Users without a canonical staff role (custom roles / direct grants only).
  ///
  /// Their shell must not leak across workspaces via broad route
  /// `requiredAnyPermissions` lists (e.g. `clinical:read` unlocking OPD/IPD).
  bool get isPermissionScopedShellUser {
    if (isElevated) {
      return false;
    }
    final Set<AppRole> staffRoles = roles.difference(const <AppRole>{
      AppRole.other,
      AppRole.patient,
    });
    return staffRoles.isEmpty;
  }

  /// Default permission pack for the active focused shell, if any.
  ///
  /// Used to decide whether a route outside the focused allow-list was unlocked
  /// by an intentional extra grant (custom role / direct permission) rather than
  /// by overlapping base-pack rights such as `patient:read`.
  Set<AppPermission>? get focusedShellBasePermissions {
    if (isLabFocusedShellUser) {
      return Set<AppPermission>.unmodifiable(
        _permissionsForRole(AppRole.labTech),
      );
    }
    if (isPharmacistFocusedShellUser) {
      return Set<AppPermission>.unmodifiable(
        _permissionsForRole(AppRole.pharmacist),
      );
    }
    if (isReceptionistFocusedShellUser) {
      return Set<AppPermission>.unmodifiable(
        _permissionsForRole(AppRole.receptionist),
      );
    }
    if (isBillingFocusedShellUser) {
      return Set<AppPermission>.unmodifiable(
        _permissionsForRole(AppRole.billing),
      );
    }
    return null;
  }

  /// True when [route] permissions are satisfied by at least one grant that is
  /// outside the focused shell's default pack (custom role / direct permission).
  bool isShellRouteUnlockedByExpandedGrant({
    required Iterable<AppPermission> allPermissions,
    required Iterable<AppPermission> anyPermissions,
  }) {
    final Set<AppPermission>? base = focusedShellBasePermissions;
    if (base == null) {
      return false;
    }

    final Set<AppPermission> satisfying = <AppPermission>{
      for (final AppPermission permission in allPermissions)
        if (grants(permission)) permission,
      for (final AppPermission permission in anyPermissions)
        if (grants(permission)) permission,
    };

    return satisfying.any(
      (AppPermission permission) => !base.contains(permission),
    );
  }

  /// For custom-role users, require a satisfying permission whose domain belongs
  /// to the route's permission-scoped allow-list.
  bool isShellRouteAllowedByPermissionDomain({
    required Iterable<AppPermission> allPermissions,
    required Iterable<AppPermission> anyPermissions,
    required Set<String>? allowedDomains,
  }) {
    if (allowedDomains == null) {
      return true;
    }
    if (allowedDomains.isEmpty) {
      return false;
    }

    final Set<AppPermission> satisfying = <AppPermission>{
      for (final AppPermission permission in allPermissions)
        if (grants(permission)) permission,
      for (final AppPermission permission in anyPermissions)
        if (grants(permission)) permission,
    };
    if (satisfying.isEmpty) {
      return false;
    }

    return satisfying.any((AppPermission permission) {
      final String? domain = _permissionDomain(permission);
      return domain != null && allowedDomains.contains(domain);
    });
  }

  static String? _permissionDomain(AppPermission permission) {
    final String normalized = permission.value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final int separator = normalized.indexOf(':');
    if (separator <= 0) {
      return normalized;
    }
    return normalized.substring(0, separator);
  }

  /// Structure mutate on Admin Setup / facility details — facility manage only.
  bool canEditFacilitySetupStructure() {
    return canManageFacility();
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
    if (isPlatformElevated) {
      return true;
    }
    if (moduleEntitlements.isEmpty) {
      // No plan entitlements loaded: deny commercial modules for tenant users.
      return !hasTenantContext;
    }

    final String normalizedCode = AppModuleEntitlement.normalizeModuleCode(
      moduleCode,
    );
    final String resolvedCode = AppModuleEntitlement.resolveModuleCode(
      moduleCode,
    );
    final bool entitled =
        moduleEntitlements[normalizedCode]?.isAvailable == true ||
        moduleEntitlements[resolvedCode]?.isAvailable == true ||
        moduleEntitlements.entries.any((
          MapEntry<String, AppModuleEntitlement> entry,
        ) {
          if (!entry.value.isAvailable) {
            return false;
          }
          final String entitlementResolved =
              AppModuleEntitlement.resolveModuleCode(entry.key);
          return entitlementResolved == resolvedCode ||
              entitlementResolved == normalizedCode ||
              entry.key == resolvedCode ||
              entry.key == normalizedCode;
        });
    if (!entitled) {
      return false;
    }

    // Fail closed for stale Pro (or higher) module rows on lower plan tiers.
    return CommercialModuleTiers.planMeetsModuleMinimum(
      planTierCode: planTierCode,
      moduleCode: moduleCode,
    );
  }

  static bool _isPermissionAllowedByPlan(
    AppPermission permission,
    Map<String, AppModuleEntitlement> entitlements, {
    required bool hasTenantContext,
  }) {
    final String? moduleCode = PermissionModuleMap.moduleForPermission(
      permission,
    );
    if (moduleCode == null) {
      return true;
    }
    if (entitlements.isEmpty) {
      return !hasTenantContext;
    }

    final String normalizedCode = AppModuleEntitlement.normalizeModuleCode(
      moduleCode,
    );
    final String resolvedCode = AppModuleEntitlement.resolveModuleCode(
      moduleCode,
    );
    if (entitlements[normalizedCode]?.isAvailable == true ||
        entitlements[resolvedCode]?.isAvailable == true) {
      return true;
    }
    for (final MapEntry<String, AppModuleEntitlement> entry
        in entitlements.entries) {
      if (!entry.value.isAvailable) {
        continue;
      }
      final String entitlementResolved = AppModuleEntitlement.resolveModuleCode(
        entry.key,
      );
      if (entitlementResolved == resolvedCode ||
          entitlementResolved == normalizedCode ||
          entry.key == resolvedCode ||
          entry.key == normalizedCode) {
        return true;
      }
    }
    return false;
  }

  bool hasAllActiveModules(Iterable<String> moduleCodes) {
    return moduleCodes.every(hasActiveModule);
  }

  static String? _resolvePlanTierCode(AuthSession? session) {
    if (session == null) {
      return null;
    }
    for (final AppModuleEntitlement entry
        in session.moduleEntitlements.values) {
      final String? tier = entry.planTierCode?.trim();
      if (tier != null && tier.isNotEmpty) {
        return tier.toUpperCase();
      }
    }
    final String? summaryTier = session.subscriptionSummary?.tierCode?.trim();
    if (summaryTier != null && summaryTier.isNotEmpty) {
      return summaryTier.toUpperCase();
    }
    return null;
  }

  static Set<AppRole> _rolesFrom(Iterable<String> values) {
    return values.map(_normalizeRole).whereType<AppRole>().toSet();
  }

  static const Map<String, AppRole> _extendedRolePermissionParents =
      <String, AppRole>{
        'ATTENDING_PHYSICIAN': AppRole.doctor,
        'RESIDENT_PHYSICIAN': AppRole.doctor,
        'SURGEON': AppRole.doctor,
        'ANESTHESIOLOGIST': AppRole.doctor,
        'PHYSICIAN_ASSISTANT': AppRole.doctor,
        'EMERGENCY_PHYSICIAN': AppRole.doctor,
        'NURSE_PRACTITIONER': AppRole.doctor,
        'LICENSED_PRACTICAL_NURSE': AppRole.nurse,
        'TRIAGE_NURSE': AppRole.nurse,
        'MIDWIFE': AppRole.nurse,
        'CHARGE_NURSE': AppRole.wardManager,
        'PHYSIOTHERAPIST': AppRole.nurse,
        'OCCUPATIONAL_THERAPIST': AppRole.nurse,
        'RESPIRATORY_THERAPIST': AppRole.nurse,
        'DIETITIAN': AppRole.nurse,
        'SOCIAL_WORKER': AppRole.receptionist,
        'CLINICAL_PSYCHOLOGIST': AppRole.nurse,
        'MEDICAL_LABORATORY_SCIENTIST': AppRole.labTech,
        'PATHOLOGIST': AppRole.labTech,
        'SONOGRAPHER': AppRole.radiologyTech,
        'PHARMACY_TECHNICIAN': AppRole.pharmacist,
        'PARAMEDIC': AppRole.ambulanceOperator,
        'EMT': AppRole.ambulanceOperator,
        'MEDICAL_RECORDS_CLERK': AppRole.receptionist,
        'ADMISSIONS_COORDINATOR': AppRole.receptionist,
        'MEDICAL_CODER': AppRole.billing,
        'IT_SUPPORT': AppRole.operations,
        'SECURITY_OFFICER': AppRole.houseKeeper,
        'CHAPLAIN': AppRole.other,
        'FOOD_SERVICE_WORKER': AppRole.houseKeeper,
        'PORTER': AppRole.houseKeeper,
        'MAINTENANCE_ENGINEER': AppRole.biomed,
      };

  static Iterable<AppPermission> _permissionsForRoleCode(String value) {
    final AppRole? knownRole = _normalizeRole(value);
    if (knownRole != null) {
      return _permissionsForRole(knownRole);
    }
    final AppRole? parent =
        _extendedRolePermissionParents[value.trim().toUpperCase().replaceAll(
          RegExp(r'[\s-]+'),
          '_',
        )];
    if (parent != null) {
      return _permissionsForRole(parent);
    }
    return const <AppPermission>[];
  }

  static AppRole? _normalizeRole(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final aliased = switch (normalized) {
      'ADMIN' || 'ADMINISTRATOR' || 'OWNER' => AppRole.tenantAdmin.value,
      'APP_ADMIN' ||
      'SUPERADMIN' ||
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
      'HR_STAFF' => AppRole.hr.value,
      'OPERATIONS_STAFF' || 'SUPPORT_STAFF' => AppRole.operations.value,
      'DISCHARGE_PLANNER' => AppRole.nurse.value,
      'DENTIST' => AppRole.doctor.value,
      'RADIOLOGIST' => AppRole.radiologyTech.value,
      'ACCOUNTANT' => AppRole.billing.value,
      'VISITOR_GUEST' => AppRole.other.value,
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
      AppRole.integrationAdmin => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.integrationRead,
        AppPermissions.integrationWrite,
        AppPermissions.integrationDelete,
        AppPermissions.reportsRead,
        AppPermissions.evidenceExport,
      ],
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
        AppPermissions.labRead,
        AppPermissions.radiologyRead,
        AppPermissions.pharmacyRead,
        AppPermissions.reportsRead,
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
        AppPermissions.labRead,
        AppPermissions.reportsRead,
      ],
      AppRole.labTech => const <AppPermission>[
        AppPermissions.labRead,
        AppPermissions.labWrite,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.profileRead,
        AppPermissions.patientRead,
      ],
      AppRole.radiologyTech => const <AppPermission>[
        AppPermissions.radiologyRead,
        AppPermissions.radiologyWrite,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.profileRead,
        AppPermissions.patientRead,
      ],
      AppRole.pharmacist => const <AppPermission>[
        AppPermissions.pharmacyRead,
        AppPermissions.pharmacyWrite,
        AppPermissions.patientRead,
        AppPermissions.reportsRead,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.profileRead,
      ],
      AppRole.receptionist => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.profileUpdate,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
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
        AppPermissions.patientRead,
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
        AppPermissions.reportsRead,
        AppPermissions.profileRead,
      ],
      AppRole.houseKeeper => const <AppPermission>[
        AppPermissions.operationsRead,
        AppPermissions.communicationsRead,
        AppPermissions.reportsRead,
        AppPermissions.profileRead,
      ],
      AppRole.ambulanceOperator => const <AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.communicationsRead,
        AppPermissions.communicationsWrite,
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
        AppPermissions.reportsRead,
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
