const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { ROLES } = require('@config/roles');
const { PERMISSIONS } = require('@config/permissions');
const {
  PRIMARY_TENANT_ADMIN_INCLUDE,
} = require('@lib/tenant/resolve-tenant-contact');

const SETUP_LIST_LIMIT = 100;

const mapError = (error) => {
  if (error instanceof HttpError) throw error;
  throw new HttpError('errors.database.unexpected', 500, [{ originalError: error?.message }]);
};

const isSuperAdmin = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [user.role];
  return roles.some((entry) => String(entry || '').trim().toUpperCase() === ROLES.PLATFORM_ADMIN);
};

const tenantScopedWhere = (scope = {}, options = {}) => {
  const { includeFacility = false, includeDeleted = false } = options;
  const where = {};

  if (!includeDeleted) {
    where.deleted_at = null;
  }

  if (scope.tenant_id) {
    where.tenant_id = scope.tenant_id;
  }

  if (includeFacility && scope.facility_id) {
    where.facility_id = scope.facility_id;
  }

  return where;
};

const roleNames = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [user.role];
  return roles
    .map((entry) => String(entry || '').trim().toUpperCase())
    .filter(Boolean);
};

const permissionNames = (user = {}) => {
  const permissions = Array.isArray(user.permissions) ? user.permissions : [];
  return permissions
    .map((entry) => String(entry || '').trim().toLowerCase())
    .filter(Boolean);
};

const hasAnyPermission = (user = {}, required = []) => {
  const granted = new Set(permissionNames(user));
  return required.some((entry) => granted.has(String(entry).toLowerCase()));
};

const canViewAllFacilitiesInTenant = (user = {}) => {
  const roles = new Set(roleNames(user));
  return (
    roles.has(ROLES.PLATFORM_ADMIN) ||
    roles.has(ROLES.TENANT_ADMIN) ||
    hasAnyPermission(user, [
      PERMISSIONS.PLATFORM_ADMIN,
      PERMISSIONS.TENANT_ADMIN,
    ])
  );
};

const isAllFacilitiesRequested = (filters = {}) => {
  const facilityScope = String(filters.facility_scope || filters.facilityScope || '')
    .trim()
    .toLowerCase();
  return (
    filters.all_facilities === true ||
    filters.all_facilities === 'true' ||
    filters.allFacilities === true ||
    filters.allFacilities === 'true' ||
    facilityScope === 'all'
  );
};

const resolveWorkspaceScope = async ({ filters = {}, user = {} }) => {
  try {
    const requestedTenantId = filters.tenant_id || filters.tenantId;
    const requestedFacilityId = filters.facility_id || filters.facilityId;
    const allFacilities = isAllFacilitiesRequested(filters);

    const userTenantId = user.tenant_id || user.tenantId || null;
    const userFacilityId = user.facility_id || user.facilityId || null;

    if (isSuperAdmin(user)) {
      // No explicit tenant → cross-tenant directory. Requiring allTenants (or a
      // session tenant) previously returned empty lists and hid custom roles.
      if (!requestedTenantId) {
        return {
          state: 'ready',
          scope: {
            tenant_id: null,
            facility_id: null,
          },
        };
      }

      const tenantId = await resolveIdentifierForFilter({
        value: requestedTenantId,
        model: 'tenant',
      });

      if (!tenantId) {
        return { state: 'tenant_context_required', scope: null };
      }

      // Super admins default to tenant-wide lists unless a facility is explicit.
      // Do not fall back to the session facility — that hid newly created users.
      let facilityId = null;
      if (!allFacilities && requestedFacilityId) {
        facilityId = await resolveIdentifierForFilter({
          value: requestedFacilityId,
          model: 'facility',
          where: { tenant_id: tenantId },
        });
        if (facilityId === null) {
          throw new HttpError('errors.validation.invalid', 400, [{ field: 'facility_id' }]);
        }
      }

      return {
        state: 'ready',
        scope: {
          tenant_id: tenantId,
          facility_id: facilityId || null,
        },
      };
    }

    if (!userTenantId) {
      throw new HttpError('errors.auth.scope_mismatch', 403);
    }

    // Tenant admins: default to all facilities in the tenant unless a facility
    // is explicit. Falling back to session facility_id hid custom roles created
    // for other facilities (they exist in DB but never appeared in the list).
    if (canViewAllFacilitiesInTenant(user)) {
      let facilityId = null;
      if (!allFacilities && requestedFacilityId) {
        facilityId = await resolveIdentifierForFilter({
          value: requestedFacilityId,
          model: 'facility',
          where: { tenant_id: userTenantId },
        });
        if (facilityId === null) {
          throw new HttpError('errors.validation.invalid', 400, [{ field: 'facility_id' }]);
        }
      }

      return {
        state: 'ready',
        scope: {
          tenant_id: userTenantId,
          facility_id: facilityId || null,
        },
      };
    }

    const facilityId = await resolveIdentifierForFilter({
      value: requestedFacilityId || userFacilityId,
      model: 'facility',
      where: { tenant_id: userTenantId },
    });

    if (facilityId === null) {
      throw new HttpError('errors.validation.invalid', 400, [{ field: 'facility_id' }]);
    }

    return {
      state: 'ready',
      scope: {
        tenant_id: userTenantId,
        facility_id: facilityId || null,
      },
    };
  } catch (error) {
    mapError(error);
  }
};

const findTenants = async (scope = null, includeAllTenants = false) => {
  try {
    if (!includeAllTenants && scope?.tenant_id) {
      const tenant = await prisma.tenant.findFirst({
        where: { id: scope.tenant_id, deleted_at: null },
        include: PRIMARY_TENANT_ADMIN_INCLUDE,
      });
      return tenant ? [tenant] : [];
    }

    if (includeAllTenants) {
      return prisma.tenant.findMany({
        where: { deleted_at: null },
        orderBy: { name: 'asc' },
        take: SETUP_LIST_LIMIT,
        include: PRIMARY_TENANT_ADMIN_INCLUDE,
      });
    }

    return [];
  } catch (error) {
    mapError(error);
  }
};

const findFacilities = async (tenantId) => {
  try {
    if (!tenantId) return [];

    return prisma.facility.findMany({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
      },
      orderBy: { name: 'asc' },
      take: SETUP_LIST_LIMIT,
    });
  } catch (error) {
    mapError(error);
  }
};

const findFacilityContactRecords = async (scope = {}) => {
  try {
    if (!scope.tenant_id || !scope.facility_id) {
      return {
        contacts: [],
        addresses: [],
      };
    }

    const [contacts, addresses] = await Promise.all([
      prisma.contact.findMany({
        where: {
          tenant_id: scope.tenant_id,
          facility_id: scope.facility_id,
          deleted_at: null,
        },
        orderBy: { created_at: 'asc' },
        take: 10,
      }),
      prisma.address.findMany({
        where: {
          tenant_id: scope.tenant_id,
          facility_id: scope.facility_id,
          deleted_at: null,
        },
        orderBy: { created_at: 'asc' },
        take: 1,
      }),
    ]);

    return {
      contacts,
      addresses,
    };
  } catch (error) {
    mapError(error);
  }
};

const findFacilityRecords = async (scope = {}, { includeDeleted = false } = {}) => {
  try {
    if (!scope.tenant_id || !scope.facility_id) {
      return {
        departments: [],
        units: [],
        wards: [],
        rooms: [],
        beds: [],
        contacts: [],
        addresses: [],
      };
    }

    const baseWhere = tenantScopedWhere(scope, {
      includeFacility: true,
      includeDeleted,
    });

    const [departments, units, wards, rooms, beds, contactRecords] =
      await Promise.all([
        prisma.department.findMany({
          where: baseWhere,
          orderBy: { name: 'asc' },
          take: SETUP_LIST_LIMIT,
        }),
        prisma.unit.findMany({
          where: baseWhere,
          orderBy: { name: 'asc' },
          take: SETUP_LIST_LIMIT,
        }),
        prisma.ward.findMany({
          where: baseWhere,
          orderBy: { name: 'asc' },
          take: SETUP_LIST_LIMIT,
        }),
        prisma.room.findMany({
          where: baseWhere,
          orderBy: { name: 'asc' },
          take: SETUP_LIST_LIMIT,
        }),
        prisma.bed.findMany({
          where: baseWhere,
          orderBy: { label: 'asc' },
          take: SETUP_LIST_LIMIT,
        }),
        findFacilityContactRecords(scope),
      ]);

    return {
      departments,
      units,
      wards,
      rooms,
      beds,
      contacts: contactRecords.contacts,
      addresses: contactRecords.addresses,
    };
  } catch (error) {
    mapError(error);
  }
};

const findSubscriptionSummary = async (tenantId) => {
  try {
    if (!tenantId) return null;

    const subscription = await prisma.subscription.findFirst({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
        status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
      },
      orderBy: [{ updated_at: 'desc' }],
      include: {
        plan: {
          select: {
            id: true,
            human_friendly_id: true,
            name: true,
            tier_code: true,
          },
        },
        module_subscriptions: {
          where: { deleted_at: null, entitlement_denied: false },
          select: { id: true },
        },
      },
    });

    if (!subscription) return null;

    return {
      subscription,
      active_modules_count: subscription.module_subscriptions?.length || 0,
    };
  } catch (error) {
    mapError(error);
  }
};

module.exports = {
  findFacilityContactRecords,
  findFacilityRecords,
  findFacilities,
  findSubscriptionSummary,
  findTenants,
  resolveWorkspaceScope,
};
