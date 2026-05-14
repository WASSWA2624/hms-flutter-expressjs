/**
 * Branch service
 *
 * @module modules/branch/services
 * @description Business logic for branch operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const branchRepository = require('@repositories/branch/branch.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List branches with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.tenant_id] - Filter by tenant ID
 * @param {string} [filters.facility_id] - Filter by facility ID
 * @param {boolean} [filters.is_active] - Filter by active status
 * @param {string} [filters.search] - Search by name
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated branches
 */
const listBranches = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  // Build repository filters
  const repoFilters = {};

  if (filters.tenant_id) {
    repoFilters.tenant_id = filters.tenant_id;
  }

  if (filters.facility_id) {
    repoFilters.facility_id = filters.facility_id;
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

  // Fetch branches and count
  const [branches, total] = await Promise.all([
    branchRepository.findMany(repoFilters, skip, limit, orderBy),
    branchRepository.count(repoFilters)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    branches,
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
 * Get branch by ID
 *
 * @param {string} id - Branch ID
 * @returns {Promise<Object>} Branch data
 */
const getBranchById = async (id) => {
  const branch = await branchRepository.findById(id);
  
  if (!branch) {
    throw new HttpError('errors.branch.not_found', 404);
  }

  return branch;
};

/**
 * Create new branch
 *
 * @param {Object} data - Branch data
 * @param {string} data.tenant_id - Tenant ID
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} data.name - Branch name
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created branch
 */
const createBranch = async (data, context = {}) => {
  // Create branch
  const branch = await branchRepository.create(data);

  // Create audit log
  await createAuditLog({
    action: 'BRANCH_CREATED',
    entity: 'branch',
    entity_id: branch.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: branch.tenant_id,
      facility_id: branch.facility_id,
      name: branch.name,
      is_active: branch.is_active
    }
  });

  return branch;
};

/**
 * Update branch
 *
 * @param {string} id - Branch ID
 * @param {Object} data - Update data
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.name] - Branch name
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated branch
 */
const updateBranch = async (id, data, context = {}) => {
  // Check if branch exists and get before state
  const beforeBranch = await branchRepository.findById(id);
  
  if (!beforeBranch) {
    throw new HttpError('errors.branch.not_found', 404);
  }

  // Update branch
  const branch = await branchRepository.update(id, data);

  // Create audit log
  await createAuditLog({
    action: 'BRANCH_UPDATED',
    entity: 'branch',
    entity_id: id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeBranch.facility_id,
        name: beforeBranch.name,
        is_active: beforeBranch.is_active
      },
      after: {
        facility_id: branch.facility_id,
        name: branch.name,
        is_active: branch.is_active
      }
    }
  });

  return branch;
};

/**
 * Delete branch (soft delete)
 *
 * @param {string} id - Branch ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteBranch = async (id, context = {}) => {
  // Check if branch exists
  const branch = await branchRepository.findById(id);
  
  if (!branch) {
    throw new HttpError('errors.branch.not_found', 404);
  }

  // Soft delete branch
  await branchRepository.softDelete(id);

  // Create audit log
  await createAuditLog({
    action: 'BRANCH_DELETED',
    entity: 'branch',
    entity_id: id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: branch.tenant_id,
      facility_id: branch.facility_id,
      name: branch.name
    }
  });
};

module.exports = {
  listBranches,
  getBranchById,
  createBranch,
  updateBranch,
  deleteBranch
};
