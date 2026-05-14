/**
 * Purchase request service
 *
 * @module modules/purchase-request/services
 * @description Business logic layer for purchase request operations.
 * Per module-creation.mdc: Services contain business logic and call repositories.
 * All mutations must create audit logs.
 */

const purchaseRequestRepository = require('@repositories/purchase-request/purchase-request.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

/**
 * Get purchase request by ID
 *
 * @param {string} id - Purchase request ID
 * @returns {Promise<Object>} Purchase request object
 * @throws {HttpError} If purchase request not found
 */
const getPurchaseRequestById = async (id) => {
  const purchaseRequest = await purchaseRequestRepository.findById(id);
  
  if (!purchaseRequest) {
    throw new HttpError('errors.purchase_request.not_found', 404);
  }
  
  return purchaseRequest;
};

/**
 * List purchase requests with pagination and filters
 *
 * @param {Object} filters - Filter criteria
 * @param {Object} pagination - Pagination options {page, limit}
 * @param {Object} sort - Sort options {sort_by, order}
 * @returns {Promise<Object>} { data, total, page, limit }
 */
const listPurchaseRequests = async (filters, pagination, sort) => {
  const { page = 1, limit = 20 } = pagination;
  const { sort_by = 'created_at', order = 'desc' } = sort;
  
  const skip = (page - 1) * limit;
  const orderBy = { [sort_by]: order };
  
  const whereFilters = {};
  
  if (filters.tenant_id) {
    whereFilters.tenant_id = filters.tenant_id;
  }
  
  if (filters.facility_id) {
    whereFilters.facility_id = filters.facility_id;
  }
  
  if (filters.requested_by_user_id) {
    whereFilters.requested_by_user_id = filters.requested_by_user_id;
  }
  
  if (filters.status) {
    whereFilters.status = filters.status;
  }
  
  if (filters.search) {
    whereFilters.OR = [
      { status: { contains: filters.search } }
    ];
  }
  
  const [data, total] = await Promise.all([
    purchaseRequestRepository.findMany(whereFilters, skip, limit, orderBy),
    purchaseRequestRepository.count(whereFilters)
  ]);
  
  return { data, total, page, limit };
};

/**
 * Create new purchase request
 *
 * @param {Object} purchaseRequestData - Purchase request data
 * @param {Object} auditContext - Audit context {user_id, ip_address}
 * @returns {Promise<Object>} Created purchase request
 */
const createPurchaseRequest = async (purchaseRequestData, auditContext) => {
  const purchaseRequest = await purchaseRequestRepository.create(purchaseRequestData);
  
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'CREATE',
    entity: 'purchase_request',
    entity_id: purchaseRequest.id,
    diff: { after: purchaseRequest },
    ip_address: auditContext.ip_address
  });
  
  return purchaseRequest;
};

/**
 * Update purchase request
 *
 * @param {string} id - Purchase request ID
 * @param {Object} updateData - Update data
 * @param {Object} auditContext - Audit context {user_id, ip_address}
 * @returns {Promise<Object>} Updated purchase request
 * @throws {HttpError} If purchase request not found
 */
const updatePurchaseRequest = async (id, updateData, auditContext) => {
  const existingPurchaseRequest = await purchaseRequestRepository.findById(id);
  
  if (!existingPurchaseRequest) {
    throw new HttpError('errors.purchase_request.not_found', 404);
  }
  
  const updatedPurchaseRequest = await purchaseRequestRepository.update(id, updateData);
  
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'UPDATE',
    entity: 'purchase_request',
    entity_id: id,
    diff: { before: existingPurchaseRequest, after: updatedPurchaseRequest },
    ip_address: auditContext.ip_address
  });
  
  return updatedPurchaseRequest;
};

/**
 * Delete purchase request (soft delete)
 *
 * @param {string} id - Purchase request ID
 * @param {Object} auditContext - Audit context {user_id, ip_address}
 * @returns {Promise<Object>} Deleted purchase request
 * @throws {HttpError} If purchase request not found
 */
const deletePurchaseRequest = async (id, auditContext) => {
  const existingPurchaseRequest = await purchaseRequestRepository.findById(id);
  
  if (!existingPurchaseRequest) {
    throw new HttpError('errors.purchase_request.not_found', 404);
  }
  
  const deletedPurchaseRequest = await purchaseRequestRepository.softDelete(id);
  
  await createAuditLog({
    user_id: auditContext.user_id,
    action: 'DELETE',
    entity: 'purchase_request',
    entity_id: id,
    diff: { before: existingPurchaseRequest },
    ip_address: auditContext.ip_address
  });
  
  return deletedPurchaseRequest;
};

module.exports = {
  getPurchaseRequestById,
  listPurchaseRequests,
  createPurchaseRequest,
  updatePurchaseRequest,
  deletePurchaseRequest
};
