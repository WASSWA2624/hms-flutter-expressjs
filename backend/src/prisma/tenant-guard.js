const loadRolesConfig = () => {
  try {
    return require('@config/roles');
  } catch (error) {
    const isMissingAlias =
      error?.code === 'MODULE_NOT_FOUND' &&
      typeof error?.message === 'string' &&
      error.message.includes("'@config/roles'");

    if (!isMissingAlias) {
      throw error;
    }

    return require('../config/roles');
  }
};

const loadRequestContextStore = () => {
  try {
    return require('@lib/context/request-context-store');
  } catch (error) {
    const isMissingAlias =
      error?.code === 'MODULE_NOT_FOUND' &&
      typeof error?.message === 'string' &&
      error.message.includes("'@lib/context/request-context-store'");

    if (!isMissingAlias) {
      throw error;
    }

    return require('../lib/context/request-context-store');
  }
};

const { ELEVATED_ROLES, normalizeRoleName } = loadRolesConfig();
const { getRequestContext } = loadRequestContextStore();

const ELEVATED_ROLE_SET = new Set(ELEVATED_ROLES);
const LOGICAL_KEYS = ['AND', 'OR', 'NOT'];

const buildTenantGuardModelMetadata = (Prisma) => {
  const metadata = new Map();
  const models = Prisma?.dmmf?.datamodel?.models || [];

  for (const model of models) {
    const fieldNames = new Set((model.fields || []).map((field) => field.name));
    metadata.set(model.name, {
      hasId: fieldNames.has('id'),
      hasTenantId: fieldNames.has('tenant_id'),
      hasDeletedAt: fieldNames.has('deleted_at')
    });
  }

  return metadata;
};

const normalizeRoles = (roles = []) =>
  (Array.isArray(roles) ? roles : [roles])
    .map((role) => normalizeRoleName(role) || String(role || '').trim().toUpperCase())
    .filter(Boolean);

const hasElevatedRole = (roles = []) =>
  normalizeRoles(roles).some((role) => ELEVATED_ROLE_SET.has(role));

const getGuardContext = () => {
  const context = getRequestContext();
  const tenantId = context?.scope?.tenant_id ? String(context.scope.tenant_id) : null;
  const actorRoles = context?.actor?.roles || [];
  const bypass = !tenantId || hasElevatedRole(actorRoles);

  return {
    context,
    tenantId,
    bypass
  };
};

const mentionsField = (where, fieldName) => {
  if (!where || typeof where !== 'object') {
    return false;
  }

  if (Object.prototype.hasOwnProperty.call(where, fieldName)) {
    return true;
  }

  return LOGICAL_KEYS.some((key) => {
    const value = where[key];
    if (Array.isArray(value)) {
      return value.some((entry) => mentionsField(entry, fieldName));
    }
    return mentionsField(value, fieldName);
  });
};

const appendConstraint = (where, constraint) => {
  if (!where || typeof where !== 'object' || Object.keys(where).length === 0) {
    return { ...constraint };
  }

  return {
    AND: [where, constraint]
  };
};

const buildGuardedWhere = (where, metadata, tenantId, options = {}) => {
  let guardedWhere = appendConstraint(where, { tenant_id: tenantId });

  if (
    options.enforceActiveRecord &&
    metadata?.hasDeletedAt &&
    !mentionsField(guardedWhere, 'deleted_at')
  ) {
    guardedWhere = appendConstraint(guardedWhere, { deleted_at: null });
  }

  return guardedWhere;
};

const injectTenantId = (data, tenantId) => {
  if (!data || typeof data !== 'object') {
    return;
  }

  if (Array.isArray(data)) {
    data.forEach((entry) => injectTenantId(entry, tenantId));
    return;
  }

  data.tenant_id = tenantId;
  if (Object.prototype.hasOwnProperty.call(data, 'tenantId')) {
    data.tenantId = tenantId;
  }
};

const createNotFoundError = () => {
  const error = new Error('Record not found for tenant scope');
  error.code = 'P2025';
  return error;
};

const findFirstOrThrow = async (delegate, args) => {
  if (typeof delegate.findFirstOrThrow === 'function') {
    return delegate.findFirstOrThrow(args);
  }

  const record = await delegate.findFirst(args);
  if (!record) {
    throw createNotFoundError();
  }
  return record;
};

const createTenantGuardQueryExtension = ({ baseClient, modelMetadata }) => {
  const guardByQuery = (handler) =>
    async ({ model, args = {}, query }) => {
      const metadata = modelMetadata.get(model);
      if (!metadata?.hasTenantId) {
        return query(args);
      }

      const { tenantId, bypass } = getGuardContext();
      if (bypass) {
        return query(args);
      }

      const delegate = baseClient?.[model];
      if (!delegate) {
        return query(args);
      }

      return handler({
        args,
        query,
        delegate,
        metadata,
        tenantId
      });
    };

  return {
    $allModels: {
      findUnique: guardByQuery(async ({ args, delegate, metadata, tenantId }) =>
        delegate.findFirst({
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId, {
            enforceActiveRecord: true
          })
        })
      ),
      findUniqueOrThrow: guardByQuery(async ({ args, delegate, metadata, tenantId }) =>
        findFirstOrThrow(delegate, {
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId, {
            enforceActiveRecord: true
          })
        })
      ),
      findFirst: guardByQuery(async ({ args, query, metadata, tenantId }) =>
        query({
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId, {
            enforceActiveRecord: true
          })
        })
      ),
      findFirstOrThrow: guardByQuery(async ({ args, query, metadata, tenantId }) =>
        query({
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId, {
            enforceActiveRecord: true
          })
        })
      ),
      findMany: guardByQuery(async ({ args, query, metadata, tenantId }) =>
        query({
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId)
        })
      ),
      count: guardByQuery(async ({ args, query, metadata, tenantId }) =>
        query({
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId)
        })
      ),
      aggregate: guardByQuery(async ({ args, query, metadata, tenantId }) =>
        query({
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId)
        })
      ),
      create: guardByQuery(async ({ args, query, tenantId }) => {
        injectTenantId(args.data, tenantId);
        return query(args);
      }),
      createMany: guardByQuery(async ({ args, query, tenantId }) => {
        injectTenantId(args.data, tenantId);
        return query(args);
      }),
      updateMany: guardByQuery(async ({ args, query, metadata, tenantId }) =>
        query({
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId, {
            enforceActiveRecord: true
          })
        })
      ),
      deleteMany: guardByQuery(async ({ args, query, metadata, tenantId }) =>
        query({
          ...args,
          where: buildGuardedWhere(args.where, metadata, tenantId, {
            enforceActiveRecord: true
          })
        })
      ),
      update: guardByQuery(async ({ args, query, delegate, metadata, tenantId }) => {
        const existing = await delegate.findFirst({
          where: buildGuardedWhere(args.where, metadata, tenantId, {
            enforceActiveRecord: true
          }),
          select: { id: true }
        });

        if (!existing) {
          throw createNotFoundError();
        }

        return query(args);
      }),
      delete: guardByQuery(async ({ args, query, delegate, metadata, tenantId }) => {
        const existing = await delegate.findFirst({
          where: buildGuardedWhere(args.where, metadata, tenantId, {
            enforceActiveRecord: true
          }),
          select: { id: true }
        });

        if (!existing) {
          throw createNotFoundError();
        }

        return query(args);
      })
    }
  };
};

const withTenantGuard = (prismaClient, options = {}) =>
  prismaClient.$extends({
    query: createTenantGuardQueryExtension(options)
  });

module.exports = {
  buildTenantGuardModelMetadata,
  buildGuardedWhere,
  createTenantGuardQueryExtension,
  withTenantGuard,
  injectTenantId,
  hasElevatedRole,
  mentionsField
};
