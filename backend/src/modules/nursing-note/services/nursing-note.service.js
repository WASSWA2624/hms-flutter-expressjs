/**
 * Nursing note service
 *
 * @module modules/nursing-note/services
 * @description Business logic layer for nursing note operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const nursingNoteRepository = require('@repositories/nursing-note/nursing-note.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List nursing notes with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Nursing notes and pagination data
 */
const listNursingNotes = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.admission_id) whereClause.admission_id = filters.admission_id;
    if (filters.nurse_user_id) whereClause.nurse_user_id = filters.nurse_user_id;

    const [nursingNotes, total] = await Promise.all([
      nursingNoteRepository.findMany(whereClause, skip, limit, orderBy),
      nursingNoteRepository.count(whereClause)
    ]);

    return {
      nursingNotes,
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
 * Get nursing note by ID
 *
 * @param {string} id - Nursing note ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Nursing note data
 */
const getNursingNoteById = async (id, userId, ipAddress) => {
  try {
    const nursingNote = await nursingNoteRepository.findById(id);

    if (!nursingNote) {
      throw new HttpError('errors.nursing_note.not_found', 404);
    }

    return nursingNote;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new nursing note
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Nursing note data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created nursing note
 */
const createNursingNote = async (data, userId, ipAddress) => {
  try {
    const nursingNote = await nursingNoteRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'nursing_note',
      entity_id: nursingNote.id,
      diff: { after: nursingNote },
      ip_address: ipAddress
    }).catch(() => {});

    return nursingNote;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update nursing note
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Nursing note ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated nursing note
 */
const updateNursingNote = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await nursingNoteRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.nursing_note.not_found', 404);
    }

    const nursingNote = await nursingNoteRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'nursing_note',
      entity_id: nursingNote.id,
      diff: { before, after: nursingNote },
      ip_address: ipAddress
    }).catch(() => {});

    return nursingNote;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete nursing note (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Nursing note ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteNursingNote = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await nursingNoteRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.nursing_note.not_found', 404);
    }

    await nursingNoteRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'nursing_note',
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
  listNursingNotes,
  getNursingNoteById,
  createNursingNote,
  updateNursingNote,
  deleteNursingNote
};
