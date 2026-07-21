/**
 * Drug service
 *
 * @module modules/drug/services
 * @description Business logic layer for drug operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const drugRepository = require('@repositories/drug/drug.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveScopedUserContext,
  buildTenantScopeWhere,
} = require('@services/pharmacy-workspace/pharmacy.shared');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const hasOwn = (value, key) => Object.prototype.hasOwnProperty.call(value || {}, key);

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: Math.ceil(total / limit),
  hasNextPage: page < Math.ceil(total / limit),
  hasPreviousPage: page > 1,
});

const findScopedDrugOrThrow = async (id, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const drug = await drugRepository.findById(id);

  if (
    !drug ||
    (!scope.can_manage_all_tenants && String(drug.tenant_id || '') !== String(scope.tenant_id || ''))
  ) {
    throw new HttpError('errors.drug.not_found', 404);
  }

  return { scope, drug };
};

const buildDrugStockInclude = (scope = {}) => ({
  inventory_maps: {
    where: { deleted_at: null },
    include: {
      inventory_item: {
        include: {
          stocks: {
            where: {
              deleted_at: null,
              ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
            },
            select: {
              quantity: true,
            },
          },
        },
      },
    },
  },
});

const attachAvailableStock = (drug = {}) => {
  const stockLevel = (drug.inventory_maps || []).reduce((total, map) => {
    const itemStocks = map?.inventory_item?.stocks || [];
    const itemQuantity = itemStocks.reduce(
      (itemTotal, stock) => itemTotal + Number(stock?.quantity || 0),
      0
    );
    return total + itemQuantity;
  }, 0);

  return {
    ...drug,
    quantity_on_hand: stockLevel,
    available_quantity: stockLevel,
    stock_level: stockLevel,
  };
};

/**
 * List drugs with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Drugs and pagination data
 */
const listDrugs = async (filters, page, limit, sortBy, order, userId, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {
      ...buildTenantScopeWhere(scope),
    };

    if (scope.can_manage_all_tenants && filters.tenant_id) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant',
        where: { deleted_at: null },
      });
      if (tenantId === null) {
        return {
          drugs: [],
          pagination: buildPagination(page, limit, 0),
        };
      }
      if (tenantId !== undefined) {
        whereClause.tenant_id = tenantId;
      }
    }
    if (filters.name) whereClause.name = { contains: filters.name };
    if (filters.code) whereClause.code = { contains: filters.code };
    if (filters.form) whereClause.form = { contains: filters.form };
    if (filters.strength) whereClause.strength = { contains: filters.strength };
    
    // Search filter (searches in name, code)
    if (filters.search) {
      whereClause.OR = [
        { name: { contains: filters.search } },
        { code: { contains: filters.search } }
      ];
    }

    const [drugRecords, total] = await Promise.all([
      drugRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        buildDrugStockInclude(scope)
      ),
      drugRepository.count(whereClause)
    ]);

    return {
      drugs: drugRecords.map(attachAvailableStock),
      pagination: buildPagination(page, limit, total)
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get drug by ID
 *
 * @param {string} id - Drug ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Drug data
 */
const getDrugById = async (id, userId, ipAddress, user = {}) => {
  try {
    const { drug } = await findScopedDrugOrThrow(id, user);
    return drug;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new drug
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Drug data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Created drug
 */
const createDrug = async (data, userId, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const payload = { ...data };
    if (!scope.can_manage_all_tenants) {
      payload.tenant_id = scope.tenant_id;
    } else {
      payload.tenant_id = await resolveIdentifierForPayload({
        value: payload.tenant_id,
        field: 'tenant_id',
        model: 'tenant',
        where: { deleted_at: null },
      });
    }
    const drug = await drugRepository.create(payload);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: payload.tenant_id || drug.tenant_id || null,
      user_id: userId,
      action: 'CREATE',
      entity: 'drug',
      entity_id: drug.id,
      diff: { after: drug },
      ip_address: ipAddress
    }).catch(() => {});

    return drug;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update drug
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Drug ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Updated drug
 */
const updateDrug = async (id, data, userId, ipAddress, user = {}) => {
  try {
    // Get current state for audit
    const { scope, drug: before } = await findScopedDrugOrThrow(id, user);
    const payload = { ...data };
    if (!scope.can_manage_all_tenants) {
      payload.tenant_id = scope.tenant_id;
    } else if (hasOwn(payload, 'tenant_id')) {
      payload.tenant_id = await resolveIdentifierForPayload({
        value: payload.tenant_id,
        field: 'tenant_id',
        model: 'tenant',
        where: { deleted_at: null },
      });
    }
    const drug = await drugRepository.update(id, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'UPDATE',
      entity: 'drug',
      entity_id: drug.id,
      diff: { before, after: drug },
      ip_address: ipAddress
    }).catch(() => {});

    return drug;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete drug (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Drug ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<void>}
 */
const deleteDrug = async (id, userId, ipAddress, user = {}) => {
  try {
    // Get current state for audit
    const { scope, drug: before } = await findScopedDrugOrThrow(id, user);

    await drugRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'DELETE',
      entity: 'drug',
      entity_id: id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listDrugs,
  getDrugById,
  createDrug,
  updateDrug,
  deleteDrug
};
