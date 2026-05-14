/**
 * Department service
 *
 * @module modules/department/services
 * @description Business logic for department operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * Per module-creation.mdc: All mutations must call createAuditLog.
 */

const departmentRepository = require('@repositories/department/department.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * List departments with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {string} [filters.tenant_id] - Filter by tenant ID
 * @param {string} [filters.facility_id] - Filter by facility ID
 * @param {string} [filters.branch_id] - Filter by branch ID
 * @param {string} [filters.department_type] - Filter by department type
 * @param {boolean} [filters.is_active] - Filter by active status
 * @param {string} [filters.search] - Search by name
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} [sort_by] - Field to sort by
 * @param {string} [order] - Sort order (asc/desc)
 * @returns {Promise<Object>} Paginated departments
 */
const listDepartments = async (filters = {}, page = 1, limit = 20, sort_by = 'created_at', order = 'desc') => {
  // Build repository filters
  const repoFilters = {};

  if (filters.tenant_id) {
    repoFilters.tenant_id = filters.tenant_id;
  }

  if (filters.facility_id) {
    repoFilters.facility_id = filters.facility_id;
  }

  if (filters.branch_id) {
    repoFilters.branch_id = filters.branch_id;
  }

  if (filters.department_type) {
    repoFilters.department_type = filters.department_type;
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

  // Fetch departments and count
  const [departments, total] = await Promise.all([
    departmentRepository.findMany(repoFilters, skip, limit, orderBy),
    departmentRepository.count(repoFilters)
  ]);

  // Calculate pagination metadata
  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    departments,
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
 * Get department by ID
 *
 * @param {string} id - Department ID
 * @returns {Promise<Object>} Department data
 */
const getDepartmentById = async (id) => {
  const department = await departmentRepository.findById(id);
  
  if (!department) {
    throw new HttpError('errors.department.not_found', 404);
  }

  return department;
};

/**
 * Create new department
 *
 * @param {Object} data - Department data
 * @param {string} data.tenant_id - Tenant ID
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.branch_id] - Branch ID
 * @param {string} data.name - Department name
 * @param {string} [data.short_name] - Department short name
 * @param {string} data.department_type - Department type
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Created department
 */
const createDepartment = async (data, context = {}) => {
  // Create department
  const department = await departmentRepository.create(data);

  // Create audit log
  await createAuditLog({
    action: 'DEPARTMENT_CREATED',
    entity: 'department',
    entity_id: department.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: department.tenant_id,
      facility_id: department.facility_id,
      branch_id: department.branch_id,
      name: department.name,
      short_name: department.short_name,
      department_type: department.department_type,
      is_active: department.is_active
    }
  });

  return department;
};

/**
 * Update department
 *
 * @param {string} id - Department ID
 * @param {Object} data - Update data
 * @param {string} [data.facility_id] - Facility ID
 * @param {string} [data.branch_id] - Branch ID
 * @param {string} [data.name] - Department name
 * @param {string} [data.short_name] - Department short name
 * @param {string} [data.department_type] - Department type
 * @param {boolean} [data.is_active] - Active status
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<Object>} Updated department
 */
const updateDepartment = async (id, data, context = {}) => {
  // Check if department exists and get before state
  const beforeDepartment = await departmentRepository.findById(id);
  
  if (!beforeDepartment) {
    throw new HttpError('errors.department.not_found', 404);
  }

  // Update department
  const department = await departmentRepository.update(id, data);

  // Create audit log
  await createAuditLog({
    action: 'DEPARTMENT_UPDATED',
    entity: 'department',
    entity_id: id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeDepartment.facility_id,
        branch_id: beforeDepartment.branch_id,
        name: beforeDepartment.name,
        short_name: beforeDepartment.short_name,
        department_type: beforeDepartment.department_type,
        is_active: beforeDepartment.is_active
      },
      after: {
        facility_id: department.facility_id,
        branch_id: department.branch_id,
        name: department.name,
        short_name: department.short_name,
        department_type: department.department_type,
        is_active: department.is_active
      }
    }
  });

  return department;
};

/**
 * Delete department (soft delete)
 *
 * @param {string} id - Department ID
 * @param {Object} context - Request context for audit
 * @param {string} [context.user_id] - User ID performing the action
 * @param {string} [context.tenant_id] - Tenant ID
 * @param {string} [context.facility_id] - Facility ID
 * @param {string} [context.ip_address] - IP address
 * @param {string} [context.user_agent] - User agent
 * @returns {Promise<void>}
 */
const deleteDepartment = async (id, context = {}) => {
  // Check if department exists
  const department = await departmentRepository.findById(id);
  
  if (!department) {
    throw new HttpError('errors.department.not_found', 404);
  }

  // Soft delete department
  await departmentRepository.softDelete(id);

  // Create audit log
  await createAuditLog({
    action: 'DEPARTMENT_DELETED',
    entity: 'department',
    entity_id: id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: department.tenant_id,
      facility_id: department.facility_id,
      branch_id: department.branch_id,
      name: department.name,
      short_name: department.short_name,
      department_type: department.department_type
    }
  });
};

/**
 * Get department units (nested resource)
 *
 * @param {string} departmentId - Department ID
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @returns {Promise<Object>} Paginated units
 */
const getDepartmentUnits = async (departmentId, page = 1, limit = 20) => {
  // Check if department exists
  const department = await departmentRepository.findById(departmentId);
  
  if (!department) {
    throw new HttpError('errors.department.not_found', 404);
  }

  // Import unit service to get units for this department
  const unitService = require('@services/unit/unit.service');
  
  // Get units filtered by department_id
  return await unitService.listUnits(
    { department_id: departmentId },
    page,
    limit
  );
};

module.exports = {
  listDepartments,
  getDepartmentById,
  createDepartment,
  updateDepartment,
  deleteDepartment,
  getDepartmentUnits
};
