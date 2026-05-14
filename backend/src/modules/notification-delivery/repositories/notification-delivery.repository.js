/**
 * NotificationDelivery repository
 *
 * @module modules/notification-delivery/repositories
 * @description Data access layer for notification-delivery operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const normalizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');
const isUuid = (value) => UUID_REGEX.test(normalizeIdentifier(value));
const createPublicId = (prefix = 'NDL') => {
  const now = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `${prefix}-${now}${random}`.slice(0, 32);
};

/**
 * Find notification-delivery by ID
 *
 * @param {string} id - NotificationDelivery ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} NotificationDelivery object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.notification_delivery.findFirst({
      where: {
        id,
        deleted_at: null
      },
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find notification-delivery by UUID or friendly identifier.
 *
 * @param {string} identifier - Identifier
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Delivery or null
 */
const findByIdentifier = async (identifier, include = {}) => {
  try {
    const normalized = normalizeIdentifier(identifier);
    if (!normalized) return null;
    if (isUuid(normalized)) return findById(normalized, include);

    return await prisma.notification_delivery.findFirst({
      where: {
        human_friendly_id: normalized.toUpperCase(),
        deleted_at: null,
      },
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find notification by UUID or friendly identifier.
 *
 * @param {string} identifier - Notification identifier
 * @returns {Promise<Object|null>} Notification or null
 */
const findNotificationByIdentifier = async (identifier) => {
  try {
    const normalized = normalizeIdentifier(identifier);
    if (!normalized) return null;

    const where = isUuid(normalized)
      ? { id: normalized, deleted_at: null }
      : { human_friendly_id: normalized.toUpperCase(), deleted_at: null };

    return await prisma.notification.findFirst({
      where,
      select: {
        id: true,
        tenant_id: true,
        user_id: true,
        human_friendly_id: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many notification-deliveries with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of notification-deliveries
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.notification_delivery.findMany({
      where,
      skip,
      take,
      orderBy,
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count notification-deliveries with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of notification-deliveries
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters
    };

    return await prisma.notification_delivery.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Assign human-friendly id when missing.
 *
 * @param {string} id - Delivery internal id
 * @param {string} humanFriendlyId - Human-friendly id
 * @returns {Promise<Object>} Prisma updateMany result
 */
const assignHumanFriendlyId = async (id, humanFriendlyId) => {
  try {
    return await prisma.notification_delivery.updateMany({
      where: {
        id,
        deleted_at: null,
        human_friendly_id: null,
      },
      data: {
        human_friendly_id: humanFriendlyId,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new notification-delivery
 *
 * @param {Object} data - NotificationDelivery data
 * @returns {Promise<Object>} Created notification-delivery
 */
const create = async (data) => {
  try {
    return await prisma.notification_delivery.create({
      data
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update notification-delivery
 *
 * @param {string} id - NotificationDelivery ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated notification-delivery
 */
const update = async (id, data) => {
  try {
    return await prisma.notification_delivery.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.notification_delivery.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete notification-delivery
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - NotificationDelivery ID
 * @returns {Promise<Object>} Deleted notification-delivery
 */
const softDelete = async (id) => {
  try {
    return await prisma.notification_delivery.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.notification_delivery.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  createPublicId,
  findById,
  findByIdentifier,
  findNotificationByIdentifier,
  findMany,
  count,
  assignHumanFriendlyId,
  create,
  update,
  softDelete
};
