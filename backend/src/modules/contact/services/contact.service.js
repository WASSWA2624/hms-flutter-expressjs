/**
 * Contact service
 *
 * @module modules/contact/services
 * @description Business logic layer for contact operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const contactRepository = require('@repositories/contact/contact.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List contacts with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Contacts and pagination data
 */
const listContacts = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.contact_type) whereClause.contact_type = filters.contact_type;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.branch_id) whereClause.branch_id = filters.branch_id;
    if (filters.patient_id) whereClause.patient_id = filters.patient_id;
    if (filters.user_profile_id) whereClause.user_profile_id = filters.user_profile_id;
    if (filters.staff_profile_id) whereClause.staff_profile_id = filters.staff_profile_id;
    if (filters.supplier_id) whereClause.supplier_id = filters.supplier_id;
    if (filters.is_primary !== undefined) {
      whereClause.is_primary = filters.is_primary === 'true';
    }
    
    // Search filter (searches in value field)
    if (filters.search) {
      whereClause.value = { contains: filters.search };
    }

    const [contacts, total] = await Promise.all([
      contactRepository.findMany(whereClause, skip, limit, orderBy),
      contactRepository.count(whereClause)
    ]);

    return {
      contacts,
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
 * Get contact by ID
 *
 * @param {string} id - Contact ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Contact data
 */
const getContactById = async (id, userId, ipAddress) => {
  try {
    const contact = await contactRepository.findById(id);

    if (!contact) {
      throw new HttpError('errors.contact.not_found', 404);
    }

    return contact;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new contact
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Contact data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created contact
 */
const createContact = async (data, userId, ipAddress) => {
  try {
    const contact = await contactRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'contact',
      entity_id: contact.id,
      diff: { after: contact },
      ip_address: ipAddress
    }).catch(() => {});

    return contact;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update contact
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Contact ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated contact
 */
const updateContact = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await contactRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.contact.not_found', 404);
    }

    const contact = await contactRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'contact',
      entity_id: contact.id,
      diff: { before, after: contact },
      ip_address: ipAddress
    }).catch(() => {});

    return contact;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete contact (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Contact ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteContact = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await contactRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.contact.not_found', 404);
    }

    await contactRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'contact',
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
  listContacts,
  getContactById,
  createContact,
  updateContact,
  deleteContact
};
