/**
 * Formulary item service
 *
 * @module modules/formulary-item/services
 * @description Business logic layer for formulary item operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const formularyItemRepository = require('@repositories/formulary-item/formulary-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List formulary items with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Formulary items and pagination data
 */
const listFormularyItems = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.drug_id) whereClause.drug_id = filters.drug_id;
    if (filters.is_active !== undefined) whereClause.is_active = filters.is_active;

    const [formularyItems, total] = await Promise.all([
      formularyItemRepository.findMany(whereClause, skip, limit, orderBy),
      formularyItemRepository.count(whereClause)
    ]);

    return {
      formularyItems,
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
 * Get formulary item by ID
 *
 * @param {string} id - Formulary item ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Formulary item data
 */
const getFormularyItemById = async (id, userId, ipAddress) => {
  try {
    const formularyItem = await formularyItemRepository.findById(id);

    if (!formularyItem) {
      throw new HttpError('errors.formulary_item.not_found', 404);
    }

    return formularyItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new formulary item
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Formulary item data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created formulary item
 */
const createFormularyItem = async (data, userId, ipAddress) => {
  try {
    const formularyItem = await formularyItemRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'formulary_item',
      entity_id: formularyItem.id,
      diff: { after: formularyItem },
      ip_address: ipAddress
    }).catch(() => {});

    return formularyItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update formulary item
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Formulary item ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated formulary item
 */
const updateFormularyItem = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await formularyItemRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.formulary_item.not_found', 404);
    }

    const formularyItem = await formularyItemRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'formulary_item',
      entity_id: formularyItem.id,
      diff: { before, after: formularyItem },
      ip_address: ipAddress
    }).catch(() => {});

    return formularyItem;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete formulary item (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Formulary item ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteFormularyItem = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await formularyItemRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.formulary_item.not_found', 404);
    }

    await formularyItemRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'formulary_item',
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
  listFormularyItems,
  getFormularyItemById,
  createFormularyItem,
  updateFormularyItem,
  deleteFormularyItem
};
