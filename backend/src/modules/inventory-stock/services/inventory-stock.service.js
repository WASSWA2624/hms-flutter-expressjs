/**
 * Inventory stock service
 *
 * @module modules/inventory-stock/services
 * @description Business logic layer for inventory stock operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const inventoryStockRepository = require('@repositories/inventory-stock/inventory-stock.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const prisma = require('@prisma/client');
const {
  resolveModelIdOrThrow,
  resolveScopedUserContext,
  buildTenantScopeWhere,
  buildInventoryItemScopeWhere,
  buildInventoryStockScopeWhere,
  matchesInventoryStockScope,
} = require('@services/pharmacy-workspace/pharmacy.shared');

const INVENTORY_STOCK_SCOPE_INCLUDE = {
  inventory_item: {
    select: {
      tenant_id: true,
    },
  },
};

const resolveScopedInventoryItemId = async (identifier, scope, allowNull = false) =>
  resolveModelIdOrThrow({
    identifier,
    model: 'inventory_item',
    where: {
      deleted_at: null,
      ...buildInventoryItemScopeWhere(scope),
    },
    errorKey: 'errors.inventory_item.not_found',
    allowNull,
  });

const resolveScopedFacilityId = async (identifier, scope, allowNull = false) =>
  resolveModelIdOrThrow({
    identifier: scope?.facility_id || identifier || null,
    model: 'facility',
    where: {
      deleted_at: null,
      ...buildTenantScopeWhere(scope),
    },
    errorKey: 'errors.facility.not_found',
    allowNull,
  });

const findScopedInventoryStockOrThrow = async (id, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const inventoryStock = await inventoryStockRepository.findById(id, INVENTORY_STOCK_SCOPE_INCLUDE);

  if (!inventoryStock || !matchesInventoryStockScope(inventoryStock, scope)) {
    throw new HttpError('errors.inventory_stock.not_found', 404);
  }

  return { scope, inventoryStock };
};

/**
 * List inventory stocks with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Inventory stocks and pagination data
 */
const listInventoryStocks = async (filters, page, limit, sortBy, order, userId, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {
      ...buildInventoryStockScopeWhere(scope),
    };

    if (filters.inventory_item_id) {
      whereClause.inventory_item_id = await resolveScopedInventoryItemId(filters.inventory_item_id, scope);
    }
    if (filters.facility_id) {
      whereClause.facility_id = await resolveScopedFacilityId(filters.facility_id, scope);
    } else if (scope?.facility_id && !scope?.can_manage_all_tenants) {
      whereClause.facility_id = scope.facility_id;
    }
    
    // Quantity filters
    if (filters.min_quantity !== undefined || filters.max_quantity !== undefined) {
      whereClause.quantity = {};
      if (filters.min_quantity !== undefined) whereClause.quantity.gte = filters.min_quantity;
      if (filters.max_quantity !== undefined) whereClause.quantity.lte = filters.max_quantity;
    }
    
    // Below reorder level filter
    if (filters.below_reorder === true) {
      whereClause.quantity = { ...whereClause.quantity, lt: prisma.inventory_stock.fields.reorder_level };
    }

    const [inventoryStocks, total] = await Promise.all([
      inventoryStockRepository.findMany(whereClause, skip, limit, orderBy),
      inventoryStockRepository.count(whereClause)
    ]);

    return {
      inventoryStocks,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get inventory stock by ID
 *
 * @param {string} id - Inventory stock ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Inventory stock data
 */
const getInventoryStockById = async (id, userId, ipAddress, user = {}) => {
  try {
    const { inventoryStock } = await findScopedInventoryStockOrThrow(id, user);
    return inventoryStock;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new inventory stock
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Inventory stock data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Created inventory stock
 */
const createInventoryStock = async (data, userId, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const payload = {
      ...data,
      inventory_item_id: await resolveScopedInventoryItemId(data.inventory_item_id, scope),
      facility_id: await resolveScopedFacilityId(data.facility_id || null, scope, true),
    };
    const inventoryStock = await inventoryStockRepository.create(payload);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: scope.tenant_id || null,
      user_id: userId,
      action: 'CREATE',
      entity: 'inventory_stock',
      entity_id: inventoryStock.id,
      diff: { after: inventoryStock },
      ip_address: ipAddress
    }).catch(() => {});

    return inventoryStock;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update inventory stock
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Inventory stock ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Updated inventory stock
 */
const updateInventoryStock = async (id, data, userId, ipAddress, user = {}) => {
  try {
    // Get current state for audit
    const { scope, inventoryStock: before } = await findScopedInventoryStockOrThrow(id, user);
    const payload = { ...data };

    if (data.inventory_item_id !== undefined) {
      payload.inventory_item_id = await resolveScopedInventoryItemId(data.inventory_item_id, scope);
    }
    if (data.facility_id !== undefined) {
      payload.facility_id = await resolveScopedFacilityId(data.facility_id, scope, true);
    }

    const inventoryStock = await inventoryStockRepository.update(id, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before?.inventory_item?.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'UPDATE',
      entity: 'inventory_stock',
      entity_id: inventoryStock.id,
      diff: { before, after: inventoryStock },
      ip_address: ipAddress
    }).catch(() => {});

    return inventoryStock;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete inventory stock (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Inventory stock ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<void>}
 */
const deleteInventoryStock = async (id, userId, ipAddress, user = {}) => {
  try {
    // Get current state for audit
    const { scope, inventoryStock: before } = await findScopedInventoryStockOrThrow(id, user);

    await inventoryStockRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before?.inventory_item?.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'DELETE',
      entity: 'inventory_stock',
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
  listInventoryStocks,
  getInventoryStockById,
  createInventoryStock,
  updateInventoryStock,
  deleteInventoryStock
};
