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
const { resolveEntityId } = require('@lib/billing/identifiers');

const resolveTenantId = async (identifier) =>
  resolveEntityId({ model: 'tenant', identifier });

const resolveFacilityId = async (identifier) =>
  resolveEntityId({ model: 'facility', identifier });

const resolveOptionalEntityId = async (model, identifier) => {
  if (identifier == null || identifier === '') {
    return identifier;
  }
  return resolveEntityId({ model, identifier });
};

const resolveAddressScopeIds = async (data = {}) => {
  const payload = { ...data };
  if (data.tenant_id) {
    payload.tenant_id = await resolveTenantId(data.tenant_id);
  }
  if (data.facility_id) {
    payload.facility_id = await resolveFacilityId(data.facility_id);
  }
  }
  if (Object.prototype.hasOwnProperty.call(data, 'patient_id')) {
    payload.patient_id = await resolveOptionalEntityId('patient', data.patient_id);
  }
  if (Object.prototype.hasOwnProperty.call(data, 'user_profile_id')) {
    payload.user_profile_id = await resolveOptionalEntityId(
      'user_profile',
      data.user_profile_id
    );
  }
  if (Object.prototype.hasOwnProperty.call(data, 'staff_profile_id')) {
    payload.staff_profile_id = await resolveOptionalEntityId(
      'staff_profile',
      data.staff_profile_id
    );
  }
  if (Object.prototype.hasOwnProperty.call(data, 'supplier_id')) {
    payload.supplier_id = await resolveOptionalEntityId('supplier', data.supplier_id);
  }
  return payload;
};

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

    const resolvedFilters = await resolveAddressScopeIds(filters);

    // Build filter object
    const whereClause = {};
    
    if (resolvedFilters.tenant_id) whereClause.tenant_id = resolvedFilters.tenant_id;
    if (filters.address_type) whereClause.address_type = filters.address_type;
    if (resolvedFilters.facility_id) whereClause.facility_id = resolvedFilters.facility_id;
    if (resolvedFilters.patient_id) whereClause.patient_id = resolvedFilters.patient_id;
    if (resolvedFilters.user_profile_id) {
      whereClause.user_profile_id = resolvedFilters.user_profile_id;
    }
    if (resolvedFilters.staff_profile_id) {
      whereClause.staff_profile_id = resolvedFilters.staff_profile_id;
    }
    if (resolvedFilters.supplier_id) whereClause.supplier_id = resolvedFilters.supplier_id;
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
    const payload = await resolveAddressScopeIds(data);
    const address = await addressRepository.create(payload);

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

    const payload = await resolveAddressScopeIds(data);
    const address = await addressRepository.update(id, payload);

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
