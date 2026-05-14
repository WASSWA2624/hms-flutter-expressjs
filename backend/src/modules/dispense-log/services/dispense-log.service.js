/**
 * Dispense Log service
 *
 * @module modules/dispense-log/services
 * @description Business logic for dispense log operations.
 * Per module-creation.mdc: Services contain business logic and call audit logging for mutations.
 * Per coding-standards.mdc: Use try/catch for error translation.
 */

const dispenseLogRepository = require('@repositories/dispense-log/dispense-log.repository');
const { createAuditLog } = require('@lib/audit');

/**
 * List dispense logs with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Dispense logs and pagination metadata
 */
const listDispenseLogs = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  // Build filters
  const where = {};
  if (filters.pharmacy_order_item_id) where.pharmacy_order_item_id = filters.pharmacy_order_item_id;
  if (filters.status) where.status = filters.status;
  
  // Date range filters
  if (filters.dispensed_at_from || filters.dispensed_at_to) {
    where.dispensed_at = {};
    if (filters.dispensed_at_from) where.dispensed_at.gte = new Date(filters.dispensed_at_from);
    if (filters.dispensed_at_to) where.dispensed_at.lte = new Date(filters.dispensed_at_to);
  }

  const [items, total] = await Promise.all([
    dispenseLogRepository.findMany(where, skip, limit, orderBy),
    dispenseLogRepository.count(where)
  ]);

  const totalPages = Math.ceil(total / limit);

  return {
    items,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1
    }
  };
};

/**
 * Get dispense log by ID
 *
 * @param {string} id - Dispense log ID
 * @returns {Promise<Object|null>} Dispense log or null
 */
const getDispenseLogById = async (id) => {
  return await dispenseLogRepository.findById(id);
};

/**
 * Create dispense log
 *
 * @param {Object} data - Dispense log data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Created dispense log
 */
const createDispenseLog = async (data, auditContext) => {
  const dispenseLog = await dispenseLogRepository.create(data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'dispense_log',
    entity_id: dispenseLog.id,
    diff: { after: dispenseLog },
    ip: auditContext.ip
  });

  return dispenseLog;
};

/**
 * Update dispense log
 *
 * @param {string} id - Dispense log ID
 * @param {Object} data - Update data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Updated dispense log
 */
const updateDispenseLog = async (id, data, auditContext) => {
  const before = await dispenseLogRepository.findById(id);
  const dispenseLog = await dispenseLogRepository.update(id, data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'dispense_log',
    entity_id: dispenseLog.id,
    diff: { before, after: dispenseLog },
    ip: auditContext.ip
  });

  return dispenseLog;
};

/**
 * Delete dispense log (soft delete)
 *
 * @param {string} id - Dispense log ID
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Deleted dispense log
 */
const deleteDispenseLog = async (id, auditContext) => {
  const before = await dispenseLogRepository.findById(id);
  const dispenseLog = await dispenseLogRepository.softDelete(id);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'dispense_log',
    entity_id: dispenseLog.id,
    diff: { before, after: dispenseLog },
    ip: auditContext.ip
  });

  return dispenseLog;
};

module.exports = {
  listDispenseLogs,
  getDispenseLogById,
  createDispenseLog,
  updateDispenseLog,
  deleteDispenseLog
};
