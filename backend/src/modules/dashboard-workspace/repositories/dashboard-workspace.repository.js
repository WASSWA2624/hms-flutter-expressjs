const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter, resolvePublicIdentifier } = require('@lib/billing/identifiers');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const resolveWorkspaceScope = async ({ filters = {}, user = {}, effectiveRole = null }) => {
  try {
    const requestedTenantId = filters.tenant_id || filters.tenantId;
    const requestedFacilityId = filters.facility_id || filters.facilityId;
    const requestedBranchId = filters.branch_id || filters.branchId;
    const userTenantId = user.tenant_id || user.tenantId || null;
    const userFacilityId = user.facility_id || user.facilityId || null;
    const userBranchId = user.branch_id || user.branchId || null;

    if (effectiveRole === 'SUPER_ADMIN') {
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

      const branchId = await resolveIdentifierForFilter({
        value: requestedBranchId || userBranchId,
        model: 'branch',
        where: { tenant_id: tenantId },
      });

      let resolvedFacilityId = facilityId || null;
      if (branchId) {
        const branch = await prisma.branch.findFirst({
          where: {
            id: branchId,
            tenant_id: tenantId,
            deleted_at: null,
          },
          select: { facility_id: true },
        });
        if (!branch) {
          throw new HttpError('errors.validation.invalid', 400, [{ field: 'branch_id' }]);
        }
        if (!resolvedFacilityId) {
          resolvedFacilityId = branch.facility_id || null;
        }
      }

      return {
        state: 'ready',
        scope: {
          tenant_id: tenantId,
          facility_id: resolvedFacilityId,
          branch_id: branchId || null,
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

    const branchId = await resolveIdentifierForFilter({
      value: requestedBranchId || userBranchId,
      model: 'branch',
      where: { tenant_id: userTenantId },
    });

    return {
      state: 'ready',
      scope: {
        tenant_id: userTenantId,
        facility_id: facilityId || userFacilityId || null,
        branch_id: branchId || userBranchId || null,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findLookups = async ({ scope = null, includeTenants = false }) => {
  try {
    const [tenants, facilities, branches] = await Promise.all([
      includeTenants
        ? prisma.tenant.findMany({
            where: { deleted_at: null },
            select: { id: true, human_friendly_id: true, name: true },
            orderBy: { name: 'asc' },
            take: 200,
          })
        : Promise.resolve([]),
      scope?.tenant_id
        ? prisma.facility.findMany({
            where: { tenant_id: scope.tenant_id, deleted_at: null },
            select: { id: true, human_friendly_id: true, name: true, facility_type: true },
            orderBy: { name: 'asc' },
          })
        : Promise.resolve([]),
      scope?.tenant_id
        ? prisma.branch.findMany({
            where: {
              tenant_id: scope.tenant_id,
              ...(scope?.facility_id ? { facility_id: scope.facility_id } : {}),
              deleted_at: null,
            },
            select: { id: true, human_friendly_id: true, name: true, facility_id: true },
            orderBy: { name: 'asc' },
          })
        : Promise.resolve([]),
    ]);

    return { tenants, facilities, branches };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findFacilityContext = async (scope = {}) => {
  try {
    if (!scope?.tenant_id) return null;

    if (scope.facility_id) {
      return await prisma.facility.findFirst({
        where: {
          id: scope.facility_id,
          tenant_id: scope.tenant_id,
          deleted_at: null,
        },
        select: { id: true, human_friendly_id: true, name: true, facility_type: true },
      });
    }

    return await prisma.facility.findFirst({
      where: { tenant_id: scope.tenant_id, deleted_at: null },
      select: { id: true, human_friendly_id: true, name: true, facility_type: true },
      orderBy: { created_at: 'asc' },
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findCurrentSubscription = async (scope = {}) => {
  try {
    if (!scope?.tenant_id) return null;

    return await prisma.subscription.findFirst({
      where: {
        tenant_id: scope.tenant_id,
        deleted_at: null,
        status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
      },
      include: {
        plan: {
          select: {
            id: true,
            human_friendly_id: true,
            name: true,
            tier_code: true,
            billing_cycle: true,
            max_users: true,
            max_facilities: true,
            max_storage_mb: true,
            max_modules: true,
            plan_fit_warning_percent: true,
          },
        },
        module_subscriptions: {
          where: { deleted_at: null },
          include: {
            module: {
              select: {
                id: true,
                human_friendly_id: true,
                name: true,
                slug: true,
                is_add_on: true,
              },
            },
          },
        },
      },
      orderBy: { updated_at: 'desc' },
    });
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const countRows = async ({ model, where = {} }) => {
  try {
    return await prisma[model].count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const sumRows = async ({ model, where = {}, field }) => {
  try {
    const result = await prisma[model].aggregate({
      where,
      _sum: {
        [field]: true,
      },
    });
    return Number(result?._sum?.[field] || 0);
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findRows = async ({ model, where = {}, select = undefined, orderBy = undefined, take = 20, skip = 0 }) => {
  try {
    return await prisma[model].findMany({
      where,
      select,
      orderBy,
      take,
      skip,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  countRows,
  findCurrentSubscription,
  findFacilityContext,
  findLookups,
  findRows,
  resolveWorkspaceScope,
  safePublicId,
  sumRows,
};
