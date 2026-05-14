/**
 * Clinical note service
 *
 * @module modules/clinical-note/services
 * @description Business logic layer for clinical note operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const clinicalNoteRepository = require('@repositories/clinical-note/clinical-note.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List clinical notes with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Clinical notes and pagination data
 */
const listClinicalNotes = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.encounter_id) whereClause.encounter_id = filters.encounter_id;
    if (filters.author_user_id) whereClause.author_user_id = filters.author_user_id;

    const [clinicalNotes, total] = await Promise.all([
      clinicalNoteRepository.findMany(whereClause, skip, limit, orderBy),
      clinicalNoteRepository.count(whereClause)
    ]);

    return {
      clinicalNotes,
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
 * Get clinical note by ID
 *
 * @param {string} id - Clinical note ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Clinical note data
 */
const getClinicalNoteById = async (id, userId, ipAddress) => {
  try {
    const clinicalNote = await clinicalNoteRepository.findById(id);

    if (!clinicalNote) {
      throw new HttpError('errors.clinical_note.not_found', 404);
    }

    return clinicalNote;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new clinical note
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Clinical note data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created clinical note
 */
const createClinicalNote = async (data, userId, ipAddress) => {
  try {
    const clinicalNote = await clinicalNoteRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'clinical_note',
      entity_id: clinicalNote.id,
      diff: { after: clinicalNote },
      ip_address: ipAddress
    }).catch(() => {});

    return clinicalNote;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update clinical note
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Clinical note ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated clinical note
 */
const updateClinicalNote = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await clinicalNoteRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.clinical_note.not_found', 404);
    }

    const clinicalNote = await clinicalNoteRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'clinical_note',
      entity_id: clinicalNote.id,
      diff: { before, after: clinicalNote },
      ip_address: ipAddress
    }).catch(() => {});

    return clinicalNote;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete clinical note (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Clinical note ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteClinicalNote = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await clinicalNoteRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.clinical_note.not_found', 404);
    }

    await clinicalNoteRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'clinical_note',
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
  listClinicalNotes,
  getClinicalNoteById,
  createClinicalNote,
  updateClinicalNote,
  deleteClinicalNote
};
