/**
 * Adverse Event service
 *
 * @module modules/adverse-event/services
 * @description Business logic for adverse event operations.
 * Per module-creation.mdc: Services contain business logic and call audit logging for mutations.
 * Per coding-standards.mdc: Use try/catch for error translation.
 */

const adverseEventRepository = require('@repositories/adverse-event/adverse-event.repository');
const { createAuditLog } = require('@lib/audit');

/**
 * List adverse events with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Adverse events and pagination metadata
 */
const listAdverseEvents = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  // Build filters
  const where = {};
  if (filters.patient_id) where.patient_id = filters.patient_id;
  if (filters.drug_id) where.drug_id = filters.drug_id;
  if (filters.severity) where.severity = filters.severity;
  
  // Date range filters
  if (filters.reported_at_from || filters.reported_at_to) {
    where.reported_at = {};
    if (filters.reported_at_from) where.reported_at.gte = new Date(filters.reported_at_from);
    if (filters.reported_at_to) where.reported_at.lte = new Date(filters.reported_at_to);
  }

  // Search in description
  if (filters.search) {
    where.description = {
      contains: filters.search,
      mode: 'insensitive'
    };
  }

  const [items, total] = await Promise.all([
    adverseEventRepository.findMany(where, skip, limit, orderBy),
    adverseEventRepository.count(where)
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
 * Get adverse event by ID
 *
 * @param {string} id - Adverse event ID
 * @returns {Promise<Object|null>} Adverse event or null
 */
const getAdverseEventById = async (id) => {
  return await adverseEventRepository.findById(id);
};

/**
 * Create adverse event
 *
 * @param {Object} data - Adverse event data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Created adverse event
 */
const createAdverseEvent = async (data, auditContext) => {
  const adverseEvent = await adverseEventRepository.create(data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'adverse_event',
    entity_id: adverseEvent.id,
    diff: { after: adverseEvent },
    ip: auditContext.ip
  });

  return adverseEvent;
};

/**
 * Update adverse event
 *
 * @param {string} id - Adverse event ID
 * @param {Object} data - Update data
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Updated adverse event
 */
const updateAdverseEvent = async (id, data, auditContext) => {
  const before = await adverseEventRepository.findById(id);
  const adverseEvent = await adverseEventRepository.update(id, data);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'adverse_event',
    entity_id: adverseEvent.id,
    diff: { before, after: adverseEvent },
    ip: auditContext.ip
  });

  return adverseEvent;
};

/**
 * Delete adverse event (soft delete)
 *
 * @param {string} id - Adverse event ID
 * @param {Object} auditContext - Audit context (user_id, ip)
 * @returns {Promise<Object>} Deleted adverse event
 */
const deleteAdverseEvent = async (id, auditContext) => {
  const before = await adverseEventRepository.findById(id);
  const adverseEvent = await adverseEventRepository.softDelete(id);

  // Audit log
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'adverse_event',
    entity_id: adverseEvent.id,
    diff: { before, after: adverseEvent },
    ip: auditContext.ip
  });

  return adverseEvent;
};

module.exports = {
  listAdverseEvents,
  getAdverseEventById,
  createAdverseEvent,
  updateAdverseEvent,
  deleteAdverseEvent
};
