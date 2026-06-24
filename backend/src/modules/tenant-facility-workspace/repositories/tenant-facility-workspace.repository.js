const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { ROLES } = require('@config/roles');

const SETUP_LIST_LIMIT = 100;

const mapError = (error) => {
  if (error instanceof HttpError) throw error;
  throw new HttpError('errors.database.unexpected', 500, [{ originalError: error?.message }]);
};

const isSuperAdmin = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [user.role];
  return roles.some((entry) => String(entry || '').trim().toUpperCase() === ROLES.SUPER_ADMIN);
};

const tenantScopedWhere = (scope = {}, options = {}) => {
  const { includeFacility = false } = options;
  const where = { deleted_at: null };

  if (scope.tenant_id) {
    where.tenant_id = scope.tenant_id;
  }

  if (includeFacility && scope.facility_id) {
    where.facility_id = scope.facility_id;
  }

  return where;
};

const resolveWorkspaceScope = async ({ filters = {}, user = {} }) => {
  try {
    const requestedTenantId = filters.tenant_id || filters.tenantId;
    const requestedFacilityId = filters.facility_id || filters.facilityId;

    const userTenantId = user.tenant_id || user.tenantId || null;
    const userFacilityId = user.facility_id || user.facilityId || null;

    if (isSuperAdmin(user)) {
      const tenantId = await resolveIdentifierForFilter({
        value: requestedTenantId || userTenantId,
        model: 'tenant',
      });

      if (!tenantId) {
        return { state: 'tenant_context_required', scope: null };
      }

      const facilityId = await resolveIdentifierForFilter({
        value: requestedFacilityId || userFacilityId,
        model: 'facility',
        where: { tenant_id: tenantId },
      });

      if (facilityId === null) {
        throw new HttpError('errors.validation.invalid', 400, [{ field: 'facility_id' }]);
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
        facility_id: facilityId || userFacilityId || null,
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
      });
      return tenant ? [tenant] : [];
    }

    if (includeAllTenants) {
      return prisma.tenant.findMany({
        where: { deleted_at: null },
        orderBy: { name: 'asc' },
        take: 25,
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

const findFacilityRecords = async (scope = {}) => {
  try {
    if (!scope.tenant_id || !scope.facility_id) {
      return {
        branches: [],
        departments: [],
        units: [],
        wards: [],
        rooms: [],
        beds: [],
        contacts: [],
        addresses: [],
      };
    }

    const baseWhere = tenantScopedWhere(scope, { includeFacility: true });

    const [branches, departments, units, wards, rooms, beds, contacts, addresses] =
      await Promise.all([
        prisma.branch.findMany({
          where: baseWhere,
          orderBy: { name: 'asc' },
          take: SETUP_LIST_LIMIT,
        }),
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
      branches,
      departments,
      units,
      wards,
      rooms,
      beds,
      contacts,
      addresses,
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
  findFacilityRecords,
  findFacilities,
  findSubscriptionSummary,
  findTenants,
  resolveWorkspaceScope,
};
