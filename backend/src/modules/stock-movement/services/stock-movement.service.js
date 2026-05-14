/**
 * Stock movement service
 *
 * @module modules/stock-movement/services
 * @description Business logic layer for stock movement operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const stockMovementRepository = require('@repositories/stock-movement/stock-movement.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List stock movements with pagination and filtering
 */
const listStockMovements = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { occurred_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.inventory_item_id) whereClause.inventory_item_id = filters.inventory_item_id;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.movement_type) whereClause.movement_type = filters.movement_type;
    if (filters.reason) whereClause.reason = filters.reason;
    
    // Date range filters
    if (filters.from_date || filters.to_date) {
      whereClause.occurred_at = {};
      if (filters.from_date) whereClause.occurred_at.gte = new Date(filters.from_date);
      if (filters.to_date) whereClause.occurred_at.lte = new Date(filters.to_date);
    }

    const [stockMovements, total] = await Promise.all([
      stockMovementRepository.findMany(whereClause, skip, limit, orderBy),
      stockMovementRepository.count(whereClause)
    ]);

    return {
      stockMovements,
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
 * Get stock movement by ID
 */
const getStockMovementById = async (id, userId, ipAddress) => {
  try {
    const stockMovement = await stockMovementRepository.findById(id);

    if (!stockMovement) {
      throw new HttpError('errors.stock_movement.not_found', 404);
    }

    return stockMovement;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new stock movement
 * Per prisma.mdc: Mutations must create audit logs
 */
const createStockMovement = async (data, userId, ipAddress) => {
  try {
    const stockMovement = await stockMovementRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'stock_movement',
      entity_id: stockMovement.id,
      diff: { after: stockMovement },
      ip_address: ipAddress
    }).catch(() => {});

    return stockMovement;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update stock movement
 * Per prisma.mdc: Mutations must create audit logs
 */
const updateStockMovement = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await stockMovementRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.stock_movement.not_found', 404);
    }

    const stockMovement = await stockMovementRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'stock_movement',
      entity_id: stockMovement.id,
      diff: { before, after: stockMovement },
      ip_address: ipAddress
    }).catch(() => {});

    return stockMovement;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete stock movement (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 */
const deleteStockMovement = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await stockMovementRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.stock_movement.not_found', 404);
    }

    await stockMovementRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'stock_movement',
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
  listStockMovements,
  getStockMovementById,
  createStockMovement,
  updateStockMovement,
  deleteStockMovement
};
