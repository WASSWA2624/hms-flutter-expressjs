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
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: Math.ceil(total / limit),
  hasNextPage: page < Math.ceil(total / limit),
  hasPreviousPage: page > 1
});

const buildEmptyListResult = (page, limit) => ({
  nursingNotes: [],
  pagination: buildPagination(page, limit, 0)
});

const resolveNursingNoteId = (id) =>
  resolveIdentifierForPayload({
    value: id,
    field: 'id',
    model: 'nursing_note',
    where: { deleted_at: null },
  });

const resolveNursingNotePayload = async (input = {}) => {
  const payload = { ...input };
  if (Object.prototype.hasOwnProperty.call(payload, 'admission_id')) {
    payload.admission_id = await resolveIdentifierForPayload({
      value: payload.admission_id,
      field: 'admission_id',
      model: 'admission',
      where: { deleted_at: null },
    });
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'nurse_user_id')) {
    payload.nurse_user_id = await resolveIdentifierForPayload({
      value: payload.nurse_user_id,
      field: 'nurse_user_id',
      model: 'user',
      where: { deleted_at: null },
    });
  }
  return payload;
};

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

    if (filters.admission_id) {
      const admissionId = await resolveIdentifierForFilter({
        value: filters.admission_id,
        model: 'admission',
        where: { deleted_at: null },
      });
      if (admissionId === null) return buildEmptyListResult(page, limit);
      if (admissionId !== undefined) whereClause.admission_id = admissionId;
    }
    if (filters.nurse_user_id) {
      const nurseUserId = await resolveIdentifierForFilter({
        value: filters.nurse_user_id,
        model: 'user',
        where: { deleted_at: null },
      });
      if (nurseUserId === null) return buildEmptyListResult(page, limit);
      if (nurseUserId !== undefined) whereClause.nurse_user_id = nurseUserId;
    }

    const [nursingNotes, total] = await Promise.all([
      nursingNoteRepository.findMany(whereClause, skip, limit, orderBy),
      nursingNoteRepository.count(whereClause)
    ]);

    return {
      nursingNotes,
      pagination: buildPagination(page, limit, total)
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
    const resolvedId = await resolveNursingNoteId(id);
    const nursingNote = await nursingNoteRepository.findById(resolvedId);

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
    const resolvedPayload = await resolveNursingNotePayload(data);
    const nursingNote = await nursingNoteRepository.create(resolvedPayload);

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
    const resolvedId = await resolveNursingNoteId(id);
    const before = await nursingNoteRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.nursing_note.not_found', 404);
    }

    const nursingNote = await nursingNoteRepository.update(resolvedId, data);

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
    const resolvedId = await resolveNursingNoteId(id);
    const before = await nursingNoteRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.nursing_note.not_found', 404);
    }

    await nursingNoteRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'nursing_note',
      entity_id: resolvedId,
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
