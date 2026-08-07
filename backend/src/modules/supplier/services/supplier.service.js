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
  buildTenantScopeWhere} = require('@services/pharmacy-workspace/pharmacy.shared');
const { checkSupplierDuplicates } = require('@lib/supplier/supplier-similarity');

const SUPPLIER_SIMILARITY_LOOKUP_LIMIT = 200;

const supplierAddressInclude = Object.freeze({
  addresses: {
    where: { deleted_at: null },
    orderBy: { created_at: 'asc' },
  },
});

const toText = (value) => {
  const trimmed = String(value ?? '').trim();
  return trimmed || null;
};

const stripSimilarityPayloadFields = (data = {}) => {
  const {
    confirm_similar: _confirmSimilar,
    location: _location,
    exclude_supplier_id: _excludeSupplierId,
    ...payload
  } = data;
  return payload;
};

const findScopedSupplierOrThrow = async (id, user = {}) => {
  const scope = resolveScopedUserContext(user);
  const supplier = await supplierRepository.findById(id, supplierAddressInclude);

  if (
    !supplier ||
    (!scope.can_manage_all_tenants &&
      String(supplier.tenant_id || '') !== String(scope.tenant_id || ''))
  ) {
    throw new HttpError('errors.supplier.not_found', 404);
  }

  return { scope, supplier };
};

const assertSupplierUniqueness = async ({
  tenantId,
  name,
  contactEmail,
  phone,
  location,
  confirmSimilar = false,
  excludeSupplierId = null,
}) => {
  if (!tenantId) {
    return null;
  }

  const existing = await supplierRepository.findMany(
    { tenant_id: tenantId },
    0,
    SUPPLIER_SIMILARITY_LOOKUP_LIMIT,
    { name: 'asc' },
    supplierAddressInclude
  );

  const duplicateCheck = checkSupplierDuplicates({
    name,
    contactEmail,
    phone,
    location,
    existing,
    excludeSupplierId,
  });

  if (!confirmSimilar && duplicateCheck.exactNameConflict) {
    throw new HttpError('errors.supplier.duplicate_name', 409, [
      {
        field: 'name',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exact_name_conflict)
          .slice(0, 5),
      },
    ]);
  }

  if (!confirmSimilar && duplicateCheck.exactEmailConflict) {
    throw new HttpError('errors.supplier.duplicate_email', 409, [
      {
        field: 'contact_email',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exact_email_conflict)
          .slice(0, 5),
      },
    ]);
  }

  if (!confirmSimilar && duplicateCheck.exactPhoneConflict) {
    throw new HttpError('errors.supplier.duplicate_phone', 409, [
      {
        field: 'phone',
        matches: duplicateCheck.similarMatches
          .filter((match) => match.exact_phone_conflict)
          .slice(0, 5),
      },
    ]);
  }

  const reviewMatches = duplicateCheck.similarMatches
    .filter((match) => !match.is_exact)
    .slice(0, 8);

  if (!confirmSimilar && reviewMatches.length > 0) {
    throw new HttpError('errors.supplier.similar_exists', 409, [
      {
        field: 'name',
        matches: reviewMatches,
        closest_score: duplicateCheck.closestScore,
      },
    ]);
  }

  return duplicateCheck;
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
    ...buildTenantScopeWhere(scope)};

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
    supplierRepository.findMany(
      whereFilters,
      skip,
      limit,
      orderBy,
      supplierAddressInclude
    ),
    supplierRepository.count(whereFilters)
  ]);
  
  return { data, total, page, limit };
};

/**
 * Preview supplier similarity for create/edit review dialogs.
 */
const checkSupplierSimilarity = async (payload = {}, user = {}) => {
  const scope = resolveScopedUserContext(user);
  let tenantId = scope.tenant_id;
  if (scope.can_manage_all_tenants && payload.tenant_id) {
    tenantId = String(payload.tenant_id).trim();
  }
  if (!tenantId) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'tenant_id' }]);
  }

  const name = String(payload.name || '').trim();
  if (!name) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'name' }]);
  }

  const contactEmail = toText(payload.contact_email);
  const phone = toText(payload.phone);
  const location = toText(payload.location);
  const excludeSupplierId = toText(payload.exclude_supplier_id);

  const existing = await supplierRepository.findMany(
    {
      ...buildTenantScopeWhere(scope),
      ...(scope.can_manage_all_tenants ? { tenant_id: tenantId } : {}),
    },
    0,
    SUPPLIER_SIMILARITY_LOOKUP_LIMIT,
    { name: 'asc' },
    supplierAddressInclude
  );

  let excludeInternalId = null;
  if (excludeSupplierId) {
    const existingSupplier = await supplierRepository.findById(
      excludeSupplierId,
      supplierAddressInclude
    );
    excludeInternalId = existingSupplier?.id || excludeSupplierId;
  }

  const duplicateCheck = checkSupplierDuplicates({
    name,
    contactEmail,
    phone,
    location,
    existing,
    excludeSupplierId: excludeInternalId,
  });

  return {
    exact_name_conflict: duplicateCheck.exactNameConflict,
    exact_email_conflict: duplicateCheck.exactEmailConflict,
    exact_phone_conflict: duplicateCheck.exactPhoneConflict,
    closest_score: duplicateCheck.closestScore,
    matches: duplicateCheck.similarMatches.slice(0, 8),
  };
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
  const confirmSimilar = supplierData?.confirm_similar === true;
  const location = toText(supplierData?.location);
  const data = stripSimilarityPayloadFields(supplierData);
  const payload = {
    ...data,
    ...(!scope.can_manage_all_tenants ? { tenant_id: scope.tenant_id } : {})};

  if (!payload.tenant_id) {
    throw new HttpError('errors.validation.required', 400, [{ field: 'tenant_id' }]);
  }

  const name = String(payload.name || '').trim();
  await assertSupplierUniqueness({
    tenantId: payload.tenant_id,
    name,
    contactEmail: toText(payload.contact_email),
    phone: toText(payload.phone),
    location,
    confirmSimilar,
  });

  const supplier = await supplierRepository.create({
    ...payload,
    name,
  });
  const created = await supplierRepository.findById(
    supplier.id,
    supplierAddressInclude
  );
  
  // Create audit log
  await createAuditLog({
    tenant_id: payload.tenant_id || supplier.tenant_id,
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'supplier',
    entity_id: supplier.id,
    diff: { after: created || supplier },
    ip_address: auditContext.ip_address
  });
  
  return created || supplier;
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
  const confirmSimilar = updateData?.confirm_similar === true;
  const location =
    updateData?.location !== undefined
      ? toText(updateData.location)
      : pickExistingLocation(existingSupplier);
  const data = stripSimilarityPayloadFields(updateData);
  const payload = {
    ...data,
    ...(!scope.can_manage_all_tenants ? { tenant_id: scope.tenant_id } : {})};

  const nextName =
    payload.name !== undefined
      ? String(payload.name || '').trim()
      : String(existingSupplier.name || '').trim();
  const nextEmail =
    payload.contact_email !== undefined
      ? toText(payload.contact_email)
      : toText(existingSupplier.contact_email);
  const nextPhone =
    payload.phone !== undefined
      ? toText(payload.phone)
      : toText(existingSupplier.phone);

  await assertSupplierUniqueness({
    tenantId: existingSupplier.tenant_id,
    name: nextName,
    contactEmail: nextEmail,
    phone: nextPhone,
    location,
    confirmSimilar,
    excludeSupplierId: existingSupplier.id,
  });

  const updatedSupplier = await supplierRepository.update(id, {
    ...payload,
    ...(payload.name !== undefined ? { name: nextName } : {}),
  });
  const withAddresses = await supplierRepository.findById(
    id,
    supplierAddressInclude
  );
  
  // Create audit log
  await createAuditLog({
    tenant_id: existingSupplier.tenant_id || updatedSupplier.tenant_id,
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'supplier',
    entity_id: id,
    diff: { before: existingSupplier, after: withAddresses || updatedSupplier },
    ip_address: auditContext.ip_address
  });
  
  return withAddresses || updatedSupplier;
};

const pickExistingLocation = (supplier) => {
  const addresses = Array.isArray(supplier?.addresses) ? supplier.addresses : [];
  const active = addresses.filter((entry) => entry?.deleted_at == null);
  if (!active.length) return null;
  return toText(active[0]?.line1);
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
  checkSupplierSimilarity,
  createSupplier,
  updateSupplier,
  deleteSupplier
};
