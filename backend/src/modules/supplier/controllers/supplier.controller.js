/**
 * Supplier controller
 *
 * @module modules/supplier/controllers
 * @description HTTP request handlers for supplier endpoints.
 * Per module-creation.mdc: Controllers handle HTTP, call services, return responses.
 * All handlers must be wrapped with asyncHandler.
 */

const supplierService = require('@services/supplier/supplier.service');
const { asyncHandler } = require('@lib/async');
const {
  sendSuccess,
  sendPaginated,
  sendCreated,
  sendNoContent,
} = require('@lib/response');

/**
 * Get supplier by ID
 * GET /api/v1/suppliers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getSupplier = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const supplier = await supplierService.getSupplierById(id, req.user || {});

  sendSuccess(res, 200, 'messages.supplier.retrieved', supplier);
});

/**
 * List suppliers with pagination
 * GET /api/v1/suppliers
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listSuppliers = asyncHandler(async (req, res) => {
  const { page, limit, sort_by, order, ...filters } = req.query;
  const pageNumber = parseInt(page, 10) || 1;
  const pageLimit = parseInt(limit, 10) || 20;

  const result = await supplierService.listSuppliers(
    filters,
    { page: pageNumber, limit: pageLimit },
    { sort_by, order },
    req.user || {}
  );

  const totalPages = Math.ceil(result.total / result.limit) || 0;
  sendPaginated(res, 'messages.supplier.list_retrieved', result.data, {
    page: result.page,
    limit: result.limit,
    total: result.total,
    totalPages,
    hasNextPage: result.page < totalPages,
    hasPreviousPage: result.page > 1,
  });
});

/**
 * Preview supplier similarity
 * POST /api/v1/suppliers/similarity-check
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const checkSupplierSimilarity = asyncHandler(async (req, res) => {
  const data = await supplierService.checkSupplierSimilarity(
    req.body,
    req.user || {}
  );

  sendSuccess(
    res,
    200,
    'messages.supplier.similarity.success',
    data
  );
});

/**
 * Create new supplier
 * POST /api/v1/suppliers
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createSupplier = asyncHandler(async (req, res) => {
  const supplierData = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip_address: req.ip,
    user: req.user || {},
  };

  const supplier = await supplierService.createSupplier(
    supplierData,
    auditContext
  );

  sendCreated(res, supplier, 'messages.supplier.created');
});

/**
 * Update supplier
 * PUT /api/v1/suppliers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateSupplier = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const updateData = req.body;
  const auditContext = {
    user_id: req.user?.id,
    ip_address: req.ip,
    user: req.user || {},
  };

  const supplier = await supplierService.updateSupplier(
    id,
    updateData,
    auditContext
  );

  sendSuccess(res, 200, 'messages.supplier.updated', supplier);
});

/**
 * Delete supplier (soft delete)
 * DELETE /api/v1/suppliers/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteSupplier = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const auditContext = {
    user_id: req.user?.id,
    ip_address: req.ip,
    user: req.user || {},
  };

  await supplierService.deleteSupplier(id, auditContext);

  sendNoContent(res);
});

module.exports = {
  getSupplier,
  listSuppliers,
  checkSupplierSimilarity,
  createSupplier,
  updateSupplier,
  deleteSupplier,
};
