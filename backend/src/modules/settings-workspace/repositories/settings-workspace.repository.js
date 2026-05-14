const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { resolveIdentifierForFilter, resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { ROLES } = require('@config/roles');

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const text = (value) => String(value || '').trim();

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

const relationScopedWhere = (scope = {}, relationKey = 'user') => {
  const relationWhere = {
    deleted_at: null,
  };

  if (scope.tenant_id) {
    relationWhere.tenant_id = scope.tenant_id;
  }

  if (scope.facility_id) {
    relationWhere.facility_id = scope.facility_id;
  }

  return {
    deleted_at: null,
    [relationKey]: relationWhere,
  };
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

const findReferenceData = async ({ scope = null, includeTenants = false }) => {
  try {
    const [tenants, facilities] = await Promise.all([
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
            where: {
              tenant_id: scope.tenant_id,
              deleted_at: null,
            },
            select: { id: true, human_friendly_id: true, name: true, facility_type: true },
            orderBy: { name: 'asc' },
            take: 200,
          })
        : Promise.resolve([]),
    ]);

    return { facilities, tenants };
  } catch (error) {
    mapError(error);
  }
};

const findTenantContext = async (scope = {}) => {
  try {
    if (!scope?.tenant_id) return null;

    return await prisma.tenant.findFirst({
      where: {
        id: scope.tenant_id,
        deleted_at: null,
      },
      select: { id: true, human_friendly_id: true, name: true },
    });
  } catch (error) {
    mapError(error);
  }
};

const findFacilityContext = async (scope = {}) => {
  try {
    if (!scope?.tenant_id || !scope?.facility_id) return null;

    return await prisma.facility.findFirst({
      where: {
        id: scope.facility_id,
        tenant_id: scope.tenant_id,
        deleted_at: null,
      },
      select: {
        id: true,
        human_friendly_id: true,
        name: true,
        facility_type: true,
      },
    });
  } catch (error) {
    mapError(error);
  }
};

const countAndLatest = async ({ model, where = {}, dateField = 'updated_at' }) => {
  const [count, latestRecord] = await Promise.all([
    prisma[model].count({ where }),
    prisma[model].findFirst({
      where,
      orderBy: { [dateField]: 'desc' },
      select: { [dateField]: true },
    }),
  ]);

  return {
    count,
    last_updated_at: latestRecord?.[dateField] || null,
  };
};

const findModuleMetrics = async (scope = {}) => {
  try {
    const metricsEntries = await Promise.all([
      countAndLatest({
        model: 'tenant',
        where: {
          deleted_at: null,
          ...(scope.tenant_id ? { id: scope.tenant_id } : {}),
        },
      }).then((value) => ['tenant', value]),
      countAndLatest({
        model: 'facility',
        where: {
          ...tenantScopedWhere(scope),
          ...(scope.facility_id ? { id: scope.facility_id } : {}),
        },
      }).then((value) => ['facility', value]),
      countAndLatest({
        model: 'branch',
        where: {
          ...tenantScopedWhere(scope),
          ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
        },
      }).then((value) => ['branch', value]),
      countAndLatest({
        model: 'department',
        where: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
      }).then((value) => ['department', value]),
      countAndLatest({
        model: 'unit',
        where: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
      }).then((value) => ['unit', value]),
      countAndLatest({
        model: 'room',
        where: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
      }).then((value) => ['room', value]),
      countAndLatest({
        model: 'ward',
        where: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
      }).then((value) => ['ward', value]),
      countAndLatest({
        model: 'bed',
        where: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
      }).then((value) => ['bed', value]),
      countAndLatest({
        model: 'address',
        where: tenantScopedWhere(scope),
      }).then((value) => ['address', value]),
      countAndLatest({
        model: 'contact',
        where: tenantScopedWhere(scope),
      }).then((value) => ['contact', value]),
      countAndLatest({
        model: 'user',
        where: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
      }).then((value) => ['user', value]),
      countAndLatest({
        model: 'user_profile',
        where: {
          deleted_at: null,
          user: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
        },
      }).then((value) => ['user-profile', value]),
      countAndLatest({
        model: 'role',
        where: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
      }).then((value) => ['role', value]),
      countAndLatest({
        model: 'permission',
        where: tenantScopedWhere(scope),
      }).then((value) => ['permission', value]),
      countAndLatest({
        model: 'role_permission',
        where: {
          deleted_at: null,
          role: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
        },
      }).then((value) => ['role-permission', value]),
      countAndLatest({
        model: 'user_role',
        where: tenantScopedWhere(scope, { includeFacility: Boolean(scope.facility_id) }),
      }).then((value) => ['user-role', value]),
      countAndLatest({
        model: 'user_session',
        where: relationScopedWhere(scope, 'user'),
      }).then((value) => ['user-session', value]),
      countAndLatest({
        model: 'api_key',
        where: tenantScopedWhere(scope),
      }).then((value) => ['api-key', value]),
      countAndLatest({
        model: 'api_key_permission',
        where: {
          deleted_at: null,
          api_key: tenantScopedWhere(scope),
        },
      }).then((value) => ['api-key-permission', value]),
      countAndLatest({
        model: 'user_mfa',
        where: relationScopedWhere(scope, 'user'),
      }).then((value) => ['user-mfa', value]),
      countAndLatest({
        model: 'oauth_account',
        where: relationScopedWhere(scope, 'user'),
      }).then((value) => ['oauth-account', value]),
    ]);

    return Object.fromEntries(metricsEntries);
  } catch (error) {
    mapError(error);
  }
};

module.exports = {
  findFacilityContext,
  findModuleMetrics,
  findReferenceData,
  findTenantContext,
  resolveWorkspaceScope,
  safePublicId,
};
