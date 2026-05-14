/**
 * Inventory item service
 *
 * @module modules/inventory-item/services
 * @description Business logic layer for inventory item operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const inventoryItemRepository = require('@repositories/inventory-item/inventory-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveScopedUserContext,
  buildTenantScopeWhere,
} = require('@services/pharmacy-workspace/pharmacy.shared');

const findScopedInventoryItemOrThrow = async (id, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const inventoryItem = await inventoryItemRepository.findById(id);

  if (
    !inventoryItem ||
    (!scope.can_manage_all_tenants &&
      String(inventoryItem.tenant_id || '') !== String(scope.tenant_id || ''))
  ) {
    throw new HttpError('errors.inventory_item.not_found', 404);
  }

  return { scope, inventoryItem };
};

/**
 * List inventory items with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Inventory items and pagination data
 */
const listInventoryItems = async (filters, page, limit, sortBy, order, userId, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {
      ...buildTenantScopeWhere(scope),
    };

    if (scope.can_manage_all_tenants && filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.name) whereClause.name = { contains: filters.name };
    if (filters.category) whereClause.category = filters.category;
    if (filters.sku) whereClause.sku = { contains: filters.sku };
    if (filters.unit) whereClause.unit = { contains: filters.unit };
    
    // Search filter (searches in name, sku)
    if (filters.search) {
      whereClause.OR = [
        { name: { contains: filters.search } },
        { sku: { contains: filters.search } }
      ];
    }

    const [inventoryItems, total] = await Promise.all([
      inventoryItemRepository.findMany(whereClause, skip, limit, orderBy),
      inventoryItemRepository.count(whereClause)
    ]);

    return {
      inventoryItems,
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
 * Get inventory item by ID
 *
 * @param {string} id - Inventory item ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Inventory item data
 */
const getInventoryItemById = async (id, userId, ipAddress, user = {}) => {
  try {
    const { inventoryItem } = await findScopedInventoryItemOrThrow(id, user);
    return inventoryItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new inventory item
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Inventory item data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Created inventory item
 */
const createInventoryItem = async (data, userId, ipAddress, user = {}) => {
  try {
    const scope = resolveScopedUserContext(user);
    const payload = {
      ...data,
      ...(!scope.can_manage_all_tenants ? { tenant_id: scope.tenant_id } : {}),
    };
    const inventoryItem = await inventoryItemRepository.create(payload);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: payload.tenant_id || inventoryItem.tenant_id || null,
      user_id: userId,
      action: 'CREATE',
      entity: 'inventory_item',
      entity_id: inventoryItem.id,
      diff: { after: inventoryItem },
      ip_address: ipAddress
    }).catch(() => {});

    return inventoryItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update inventory item
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Inventory item ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Updated inventory item
 */
const updateInventoryItem = async (id, data, userId, ipAddress, user = {}) => {
  try {
    // Get current state for audit
    const { scope, inventoryItem: before } = await findScopedInventoryItemOrThrow(id, user);
    const payload = {
      ...data,
      ...(!scope.can_manage_all_tenants ? { tenant_id: scope.tenant_id } : {}),
    };
    const inventoryItem = await inventoryItemRepository.update(id, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'UPDATE',
      entity: 'inventory_item',
      entity_id: inventoryItem.id,
      diff: { before, after: inventoryItem },
      ip_address: ipAddress
    }).catch(() => {});

    return inventoryItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete inventory item (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Inventory item ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<void>}
 */
const deleteInventoryItem = async (id, userId, ipAddress, user = {}) => {
  try {
    // Get current state for audit
    const { scope, inventoryItem: before } = await findScopedInventoryItemOrThrow(id, user);

    await inventoryItemRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before.tenant_id || scope.tenant_id || null,
      user_id: userId,
      action: 'DELETE',
      entity: 'inventory_item',
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
  listInventoryItems,
  getInventoryItemById,
  createInventoryItem,
  updateInventoryItem,
  deleteInventoryItem
};
