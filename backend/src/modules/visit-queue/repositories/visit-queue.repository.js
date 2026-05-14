/**
 * Visit queue repository
 *
 * @module modules/visit-queue/repositories
 * @description Data access layer for visit queue operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const VISIT_QUEUE_RELATION_INCLUDE = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
      date_of_birth: true,
      gender: true,
      extension_json: true,
      contacts: {
        where: { deleted_at: null },
        orderBy: [{ is_primary: 'desc' }, { updated_at: 'desc' }],
        take: 3,
        select: {
          contact_type: true,
          value: true,
          is_primary: true,
        },
      },
      identifiers: {
        where: { deleted_at: null },
        orderBy: [{ is_primary: 'desc' }, { updated_at: 'desc' }],
        take: 3,
        select: {
          identifier_type: true,
          identifier_value: true,
          is_primary: true,
        },
      },
      invoices: {
        where: { deleted_at: null },
        orderBy: [{ issued_at: 'desc' }, { updated_at: 'desc' }],
        take: 3,
        select: {
          id: true,
          human_friendly_id: true,
          status: true,
          billing_status: true,
          total_amount: true,
          currency: true,
          issued_at: true,
          payments: {
            where: { deleted_at: null },
            orderBy: [{ paid_at: 'desc' }, { created_at: 'desc' }],
            take: 5,
            select: {
              id: true,
              human_friendly_id: true,
              status: true,
              method: true,
              amount: true,
              paid_at: true,
            },
          },
        },
      },
    },
  },
  appointment: {
    select: {
      id: true,
      human_friendly_id: true,
      status: true,
      scheduled_start: true,
      scheduled_end: true,
      reason: true,
      provider_user_id: true,
    },
  },
  provider: {
    select: {
      id: true,
      human_friendly_id: true,
      email: true,
      phone: true,
      profile: {
        select: {
          first_name: true,
          middle_name: true,
          last_name: true,
        },
      },
    },
  },
};

/**
 * Find visit queue entry by ID
 *
 * @param {string} id - Visit queue entry ID
 * @returns {Promise<Object|null>} Visit queue entry object or null
 */
const findById = async (id) => {
  try {
    return await prisma.visit_queue.findFirst({
      where: {
        id,
        deleted_at: null,
      },
      include: VISIT_QUEUE_RELATION_INCLUDE,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many visit queue entries with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @returns {Promise<Array>} Array of visit queue entries
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { queued_at: 'desc' }) => {
  try {
    // Build where clause
    const where = {
      deleted_at: null,
      ...filters,
    };

    return await prisma.visit_queue.findMany({
      where,
      skip,
      take,
      orderBy,
      include: VISIT_QUEUE_RELATION_INCLUDE,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count visit queue entries with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of visit queue entries
 */
const count = async (filters = {}) => {
  try {
    const where = {
      deleted_at: null,
      ...filters,
    };

    return await prisma.visit_queue.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new visit queue entry
 *
 * @param {Object} data - Visit queue entry data
 * @returns {Promise<Object>} Created visit queue entry
 */
const create = async (data) => {
  try {
    return await prisma.visit_queue.create({
      data,
      include: VISIT_QUEUE_RELATION_INCLUDE,
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
 * Update visit queue entry
 *
 * @param {string} id - Visit queue entry ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated visit queue entry
 */
const update = async (id, data) => {
  try {
    return await prisma.visit_queue.update({
      where: { id },
      data,
      include: VISIT_QUEUE_RELATION_INCLUDE,
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.visit_queue.not_found', 404);
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
 * Soft delete visit queue entry
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Visit queue entry ID
 * @returns {Promise<Object>} Deleted visit queue entry
 */
const softDelete = async (id) => {
  try {
    return await prisma.visit_queue.update({
      where: { id },
      data: {
        deleted_at: new Date(),
      },
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.visit_queue.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete,
};
