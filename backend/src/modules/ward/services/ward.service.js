/**
 * Ward service
 *
 * @module modules/ward/services
 * @description Business logic for ward operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const wardRepository = require('@repositories/ward/ward.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List wards with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.tenant_id] - Filter by tenant ID
 * @param {string} [filters.facility_id] - Filter by facility ID
 * @param {string} [filters.department_id] - Filter by department ID
 * @param {string} [filters.ward_type] - Filter by ward type
 * @param {boolean} [filters.is_active] - Filter by active status
 * @param {string} [filters.search] - Search by name
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated wards
 */
const listWards = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  // Build repository filters
  const repoFilters = {};

  if (filters.tenant_id) {
    repoFilters.tenant_id = filters.tenant_id;
  }

  if (filters.facility_id) {
    repoFilters.facility_id = filters.facility_id;
  }

  if (filters.department_id) {
    repoFilters.department_id = filters.department_id;
  }

  if (filters.ward_type) {
    repoFilters.ward_type = filters.ward_type;
  }

  if (filters.is_active !== undefined) {
    repoFilters.is_active = filters.is_active === true || filters.is_active === 'true';
  }

  // Handle search filter
  if (filters.search) {
    repoFilters.name = { contains: filters.search, mode: 'insensitive' };
  }

  // Calculate pagination
  const skip = (page - 1) * limit;

  // Build sort order
  const orderBy = {};
  orderBy[sort_by] = order;

  // Fetch wards and count
  const [wards, total] = await Promise.all([
    wardRepository.findMany(repoFilters, skip, limit, orderBy),
    wardRepository.count(repoFilters)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    wards,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage
    }
  };
};

/**
 * Get ward by ID
 *
 * @param {string} id - Ward ID
 * @returns {Promise<Object>} Ward data
 */
const getWardById = async (id) => {
  const ward = await wardRepository.findById(id);
  
  if (!ward) {
    throw new HttpError('errors.ward.not_found', 404);
  }

  return ward;
};

/**
 * Get beds for a ward
 *
 * @param {string} wardId - Ward ID
 * @returns {Promise<Object>} Ward with beds
 */
const getWardBeds = async (wardId) => {
  // Verify ward exists
  const ward = await wardRepository.findById(wardId);
  
  if (!ward) {
    throw new HttpError('errors.ward.not_found', 404);
  }

  return ward;
};

/**
 * Create new ward
 *
 * @param {Object} data - Ward data
 * @param {string} data.tenant_id - Tenant ID
 * @param {string} data.facility_id - Facility ID
 * @param {string} [data.department_id] - Department ID
 * @param {string} data.name - Ward name
 * @param {string} data.ward_type - Ward type
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created ward
 */
const createWard = async (data, context = {}) => {
  // Create ward
  const ward = await wardRepository.create(data);

  // Create audit log
  await createAuditLog({
    action: 'WARD_CREATED',
    entity: 'ward',
    entity_id: ward.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: ward.tenant_id,
      facility_id: ward.facility_id,
      department_id: ward.department_id,
      name: ward.name,
      ward_type: ward.ward_type,
      is_active: ward.is_active
    }
  });

  return ward;
};

/**
 * Update ward
 *
 * @param {string} id - Ward ID
 * @param {Object} data - Update data
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.department_id] - Department ID
 * @param {string} [data.name] - Ward name
 * @param {string} [data.ward_type] - Ward type
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated ward
 */
const updateWard = async (id, data, context = {}) => {
  // Check if ward exists and get before state
  const beforeWard = await wardRepository.findById(id);
  
  if (!beforeWard) {
    throw new HttpError('errors.ward.not_found', 404);
  }

  // Update ward
  const ward = await wardRepository.update(id, data);

  // Create audit log
  await createAuditLog({
    action: 'WARD_UPDATED',
    entity: 'ward',
    entity_id: id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeWard.facility_id,
        department_id: beforeWard.department_id,
        name: beforeWard.name,
        ward_type: beforeWard.ward_type,
        is_active: beforeWard.is_active
      },
      after: {
        facility_id: ward.facility_id,
        department_id: ward.department_id,
        name: ward.name,
        ward_type: ward.ward_type,
        is_active: ward.is_active
      }
    }
  });

  return ward;
};

/**
 * Delete ward (soft delete)
 *
 * @param {string} id - Ward ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteWard = async (id, context = {}) => {
  // Check if ward exists
  const ward = await wardRepository.findById(id);
  
  if (!ward) {
    throw new HttpError('errors.ward.not_found', 404);
  }

  // Soft delete ward
  await wardRepository.softDelete(id);

  // Create audit log
  await createAuditLog({
    action: 'WARD_DELETED',
    entity: 'ward',
    entity_id: id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: ward.tenant_id,
      facility_id: ward.facility_id,
      department_id: ward.department_id,
      name: ward.name,
      ward_type: ward.ward_type
    }
  });
};

module.exports = {
  listWards,
  getWardById,
  getWardBeds,
  createWard,
  updateWard,
  deleteWard
};
