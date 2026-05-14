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
const { sendSuccess, sendCreated, sendNoContent } = require('@lib/response');

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
  
  sendSuccess(res, supplier, 'messages.supplier.retrieved', req.locale);
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
  
  const result = await supplierService.listSuppliers(
    filters,
    { page: parseInt(page) || 1, limit: parseInt(limit) || 20 },
    { sort_by, order },
    req.user || {}
  );
  
  sendSuccess(res, result.data, 'messages.supplier.list_retrieved', req.locale, {
    pagination: {
      page: result.page,
      limit: result.limit,
      total: result.total,
      total_pages: Math.ceil(result.total / result.limit)
    }
  });
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
    user: req.user || {}
  };
  
  const supplier = await supplierService.createSupplier(supplierData, auditContext);
  
  sendCreated(res, supplier, 'messages.supplier.created', req.locale);
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
    user: req.user || {}
  };
  
  const supplier = await supplierService.updateSupplier(id, updateData, auditContext);
  
  sendSuccess(res, supplier, 'messages.supplier.updated', req.locale);
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
    user: req.user || {}
  };
  
  await supplierService.deleteSupplier(id, auditContext);
  
  sendNoContent(res);
});

module.exports = {
  getSupplier,
  listSuppliers,
  createSupplier,
  updateSupplier,
  deleteSupplier
};
