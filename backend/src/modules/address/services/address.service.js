/**
 * Address service
 *
 * @module modules/address/services
 * @description Business logic layer for address operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const addressRepository = require('@repositories/address/address.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List addresses with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Addresses and pagination data
 */
const listAddresses = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.address_type) whereClause.address_type = filters.address_type;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.branch_id) whereClause.branch_id = filters.branch_id;
    if (filters.patient_id) whereClause.patient_id = filters.patient_id;
    if (filters.user_profile_id) whereClause.user_profile_id = filters.user_profile_id;
    if (filters.staff_profile_id) whereClause.staff_profile_id = filters.staff_profile_id;
    if (filters.supplier_id) whereClause.supplier_id = filters.supplier_id;
    if (filters.city) whereClause.city = { contains: filters.city };
    if (filters.state) whereClause.state = { contains: filters.state };
    if (filters.country) whereClause.country = { contains: filters.country };
    
    // Search filter (searches in line1, line2, city, state, country)
    if (filters.search) {
      whereClause.OR = [
        { line1: { contains: filters.search } },
        { line2: { contains: filters.search } },
        { city: { contains: filters.search } },
        { state: { contains: filters.search } },
        { country: { contains: filters.search } },
        { postal_code: { contains: filters.search } }
      ];
    }

    const [addresses, total] = await Promise.all([
      addressRepository.findMany(whereClause, skip, limit, orderBy),
      addressRepository.count(whereClause)
    ]);

    return {
      addresses,
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
 * Get address by ID
 *
 * @param {string} id - Address ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Address data
 */
const getAddressById = async (id, userId, ipAddress) => {
  try {
    const address = await addressRepository.findById(id);

    if (!address) {
      throw new HttpError('errors.address.not_found', 404);
    }

    return address;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new address
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Address data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created address
 */
const createAddress = async (data, userId, ipAddress) => {
  try {
    const address = await addressRepository.create(data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'address',
      entity_id: address.id,
      diff: { after: address },
      ip_address: ipAddress
    }).catch(() => {});

    return address;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update address
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Address ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated address
 */
const updateAddress = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await addressRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.address.not_found', 404);
    }

    const address = await addressRepository.update(id, data);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'address',
      entity_id: address.id,
      diff: { before, after: address },
      ip_address: ipAddress
    }).catch(() => {});

    return address;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete address (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Address ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteAddress = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await addressRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.address.not_found', 404);
    }

    await addressRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'address',
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
  listAddresses,
  getAddressById,
  createAddress,
  updateAddress,
  deleteAddress
};
