/**
 * Unit service
 *
 * @module modules/unit/services
 * @description Business logic for unit operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const unitRepository = require('@repositories/unit/unit.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List units with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.tenant_id] - Filter by tenant ID
 * @param {string} [filters.facility_id] - Filter by facility ID
 * @param {string} [filters.department_id] - Filter by department ID
 * @param {boolean} [filters.is_active] - Filter by active status
 * @param {string} [filters.search] - Search by name
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated units
 */
const listUnits = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
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

  // Fetch units and count
  const [units, total] = await Promise.all([
    unitRepository.findMany(repoFilters, skip, limit, orderBy),
    unitRepository.count(repoFilters)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    units,
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
 * Get unit by ID
 *
 * @param {string} id - Unit ID
 * @returns {Promise<Object>} Unit data
 */
const getUnitById = async (id) => {
  const unit = await unitRepository.findById(id);
  
  if (!unit) {
    throw new HttpError('errors.unit.not_found', 404);
  }

  return unit;
};

/**
 * Create new unit
 *
 * @param {Object} data - Unit data
 * @param {string} data.tenant_id - Tenant ID
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.department_id] - Department ID
 * @param {string} data.name - Unit name
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created unit
 */
const createUnit = async (data, context = {}) => {
  // Create unit
  const unit = await unitRepository.create(data);

  // Create audit log
  await createAuditLog({
    action: 'UNIT_CREATED',
    entity: 'unit',
    entity_id: unit.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: unit.tenant_id,
      facility_id: unit.facility_id,
      department_id: unit.department_id,
      name: unit.name,
      is_active: unit.is_active
    }
  });

  return unit;
};

/**
 * Update unit
 *
 * @param {string} id - Unit ID
 * @param {Object} data - Update data
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.department_id] - Department ID
 * @param {string} [data.name] - Unit name
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated unit
 */
const updateUnit = async (id, data, context = {}) => {
  // Check if unit exists and get before state
  const beforeUnit = await unitRepository.findById(id);
  
  if (!beforeUnit) {
    throw new HttpError('errors.unit.not_found', 404);
  }

  // Update unit
  const unit = await unitRepository.update(id, data);

  // Create audit log
  await createAuditLog({
    action: 'UNIT_UPDATED',
    entity: 'unit',
    entity_id: id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeUnit.facility_id,
        department_id: beforeUnit.department_id,
        name: beforeUnit.name,
        is_active: beforeUnit.is_active
      },
      after: {
        facility_id: unit.facility_id,
        department_id: unit.department_id,
        name: unit.name,
        is_active: unit.is_active
      }
    }
  });

  return unit;
};

/**
 * Delete unit (soft delete)
 *
 * @param {string} id - Unit ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteUnit = async (id, context = {}) => {
  // Check if unit exists
  const unit = await unitRepository.findById(id);
  
  if (!unit) {
    throw new HttpError('errors.unit.not_found', 404);
  }

  // Soft delete unit
  await unitRepository.softDelete(id);

  // Create audit log
  await createAuditLog({
    action: 'UNIT_DELETED',
    entity: 'unit',
    entity_id: id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: unit.tenant_id,
      facility_id: unit.facility_id,
      department_id: unit.department_id,
      name: unit.name
    }
  });
};

module.exports = {
  listUnits,
  getUnitById,
  createUnit,
  updateUnit,
  deleteUnit
};
