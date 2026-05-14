/**
 * Supplier service
 *
 * @module modules/supplier/services
 * @description Business logic layer for supplier operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * All mutations must create audit logs.
 */

const supplierRepository = require('@repositories/supplier/supplier.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveScopedUserContext,
  buildTenantScopeWhere,
} = require('@services/pharmacy-workspace/pharmacy.shared');

const findScopedSupplierOrThrow = async (id, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const supplier = await supplierRepository.findById(id);

  if (
    !supplier ||
    (!scope.can_manage_all_tenants &&
      String(supplier.tenant_id || '') !== String(scope.tenant_id || ''))
  ) {
    throw new HttpError('errors.supplier.not_found', 404);
  }

  return { scope, supplier };
};

/**
 * Get supplier by ID
 *
 * @param {string} id - Supplier ID
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} Supplier object
 * @throws {HttpError} If supplier not found
 */
const getSupplierById = async (id, user = {}) => {
  const { supplier } = await findScopedSupplierOrThrow(id, user);
  return supplier;
};

/**
 * List suppliers with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {Object} pagination - Pagination options {page, limit}
 * @param {Object} sort - Sort options {sort_by, order}
 * @param {Object} user - Authenticated request user context
 * @returns {Promise<Object>} { data, total, page, limit }
 */
const listSuppliers = async (filters, pagination, sort, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const { page = 1, limit = 20 } = pagination;
  const { sort_by = 'created_at', order = 'desc' } = sort;
  
  const skip = (page - 1) * limit;
  const orderBy = { [sort_by]: order };
  
  // Build filter object
  const whereFilters = {
    ...buildTenantScopeWhere(scope),
  };

  if (scope.can_manage_all_tenants && filters.tenant_id) {
    whereFilters.tenant_id = filters.tenant_id;
  }
  
  if (filters.name) {
    whereFilters.name = { contains: filters.name };
  }
  
  if (filters.contact_email) {
    whereFilters.contact_email = { contains: filters.contact_email };
  }
  
  if (filters.search) {
    whereFilters.OR = [
      { name: { contains: filters.search } },
      { contact_email: { contains: filters.search } },
      { phone: { contains: filters.search } }
    ];
  }
  
  const [data, total] = await Promise.all([
    supplierRepository.findMany(whereFilters, skip, limit, orderBy),
    supplierRepository.count(whereFilters)
  ]);
  
  return { data, total, page, limit };
};

/**
 * Create new supplier
 *
 * @param {Object} supplierData - Supplier data
 * @param {Object} auditContext - Audit context {user_id, ip_address, user}
 * @returns {Promise<Object>} Created supplier
 */
const createSupplier = async (supplierData, auditContext) => {
  const scope = resolveScopedUserContext(auditContext?.user || {});
  const payload = {
    ...supplierData,
    ...(!scope.can_manage_all_tenants ? { tenant_id: scope.tenant_id } : {}),
  };
  const supplier = await supplierRepository.create(payload);
  
  // Create audit log
  await createAuditLog({
    tenant_id: payload.tenant_id || supplier.tenant_id,
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'supplier',
    entity_id: supplier.id,
    diff: { after: supplier },
    ip_address: auditContext.ip_address
  });
  
  return supplier;
};

/**
 * Update supplier
 *
 * @param {string} id - Supplier ID
 * @param {Object} updateData - Update data
 * @param {Object} auditContext - Audit context {user_id, ip_address, user}
 * @returns {Promise<Object>} Updated supplier
 * @throws {HttpError} If supplier not found
 */
const updateSupplier = async (id, updateData, auditContext) => {
  const { scope, supplier: existingSupplier } = await findScopedSupplierOrThrow(
    id,
    auditContext?.user || {}
  );
  const payload = {
    ...updateData,
    ...(!scope.can_manage_all_tenants ? { tenant_id: scope.tenant_id } : {}),
  };
  const updatedSupplier = await supplierRepository.update(id, payload);
  
  // Create audit log
  await createAuditLog({
    tenant_id: existingSupplier.tenant_id || updatedSupplier.tenant_id,
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'supplier',
    entity_id: id,
    diff: { before: existingSupplier, after: updatedSupplier },
    ip_address: auditContext.ip_address
  });
  
  return updatedSupplier;
};

/**
 * Delete supplier (soft delete)
 *
 * @param {string} id - Supplier ID
 * @param {Object} auditContext - Audit context {user_id, ip_address, user}
 * @returns {Promise<Object>} Deleted supplier
 * @throws {HttpError} If supplier not found
 */
const deleteSupplier = async (id, auditContext) => {
  const { supplier: existingSupplier } = await findScopedSupplierOrThrow(id, auditContext?.user || {});
  
  const deletedSupplier = await supplierRepository.softDelete(id);
  
  // Create audit log
  await createAuditLog({
    tenant_id: existingSupplier.tenant_id,
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'supplier',
    entity_id: id,
    diff: { before: existingSupplier },
    ip_address: auditContext.ip_address
  });
  
  return deletedSupplier;
};

module.exports = {
  getSupplierById,
  listSuppliers,
  createSupplier,
  updateSupplier,
  deleteSupplier
};
