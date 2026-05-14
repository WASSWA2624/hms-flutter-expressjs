/**
 * PACS link service
 *
 * @module modules/pacs-link/services
 * @description Business logic layer for PACS link operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const pacsLinkRepository = require('@repositories/pacs-link/pacs-link.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  normalizeIdentifier,
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const buildPagination = (page, limit, total) => {
  const totalPages = Math.max(1, Math.ceil(total / limit));
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const buildEmptyListResult = (page, limit) => ({
  pacsLinks: [],
  pagination: buildPagination(page, limit, 0),
});

const resolveResourceId = async (model, identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return normalized;

  const resolved = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where: { deleted_at: null },
  });

  return resolved || normalized;
};

/**
 * List PACS links with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} PACS links and pagination data
 */
const listPacsLinks = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.imaging_study_id !== undefined) {
      const studyId = await resolveIdentifierForFilter({
        value: filters.imaging_study_id,
        model: 'imaging_study',
        where: { deleted_at: null },
      });
      if (studyId === null) return buildEmptyListResult(page, limit);
      if (studyId !== undefined) whereClause.imaging_study_id = studyId;
    }
    if (filters.expires_at) whereClause.expires_at = filters.expires_at;

    const [pacsLinks, total] = await Promise.all([
      pacsLinkRepository.findMany(whereClause, skip, limit, orderBy),
      pacsLinkRepository.count(whereClause)
    ]);

    return {
      pacsLinks,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get PACS link by ID
 *
 * @param {string} id - PACS link ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} PACS link data
 */
const getPacsLinkById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('pacs_link', id);
    const pacsLink = await pacsLinkRepository.findById(resolvedId);

    if (!pacsLink) {
      throw new HttpError('errors.pacs_link.not_found', 404);
    }

    return pacsLink;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new PACS link
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - PACS link data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created PACS link
 */
const createPacsLink = async (data, userId, ipAddress) => {
  try {
    const normalizedData = {
      ...data,
      imaging_study_id: await resolveIdentifierForPayload({
        value: data.imaging_study_id,
        field: 'imaging_study_id',
        model: 'imaging_study',
        where: { deleted_at: null },
      }),
    };
    const pacsLink = await pacsLinkRepository.create(normalizedData);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'pacs_link',
      entity_id: pacsLink.id,
      diff: { after: pacsLink },
      ip_address: ipAddress
    }).catch(() => {});

    return pacsLink;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update PACS link
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - PACS link ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated PACS link
 */
const updatePacsLink = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('pacs_link', id);

    // Get current state for audit
    const before = await pacsLinkRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.pacs_link.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'imaging_study_id')) {
      payload.imaging_study_id = await resolveIdentifierForPayload({
        value: payload.imaging_study_id,
        field: 'imaging_study_id',
        model: 'imaging_study',
        where: { deleted_at: null },
      });
    }

    const pacsLink = await pacsLinkRepository.update(resolvedId, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'pacs_link',
      entity_id: pacsLink.id,
      diff: { before, after: pacsLink },
      ip_address: ipAddress
    }).catch(() => {});

    return pacsLink;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete PACS link (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - PACS link ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deletePacsLink = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('pacs_link', id);

    // Get current state for audit
    const before = await pacsLinkRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.pacs_link.not_found', 404);
    }

    await pacsLinkRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'pacs_link',
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
  listPacsLinks,
  getPacsLinkById,
  createPacsLink,
  updatePacsLink,
  deletePacsLink
};
