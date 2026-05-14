/**
 * Pharmacy order item controller
 *
 * @module modules/pharmacy-order-item/controllers
 * @description Request handlers for pharmacy order item endpoints.
 */

const pharmacyOrderItemService = require('@services/pharmacy-order-item/pharmacy-order-item.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List pharmacy order items with pagination
 * GET /api/v1/pharmacy-order-items
 */
const listPharmacyOrderItems = asyncHandler(async (req, res) => {
  const {
    pharmacy_order_id,
    drug_id,
    status,
    route,
    frequency,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    pharmacy_order_id,
    drug_id,
    status,
    route,
    frequency,
    search
  };

  const result = await pharmacyOrderItemService.listPharmacyOrderItems(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user?.id,
    req.ip,
    req.user || {}
  );

  sendPaginated(
    res,
    'messages.pharmacy_order_item.list.success',
    result.pharmacyOrderItems,
    result.pagination
  );
});

/**
 * Get pharmacy order item by ID
 * GET /api/v1/pharmacy-order-items/:id
 */
const getPharmacyOrderItemById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const pharmacyOrderItem = await pharmacyOrderItemService.getPharmacyOrderItemById(
    id,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  sendSuccess(res, 200, 'messages.pharmacy_order_item.get.success', pharmacyOrderItem);
});

/**
 * Create pharmacy order item
 * POST /api/v1/pharmacy-order-items
 */
const createPharmacyOrderItem = asyncHandler(async (req, res) => {
  const pharmacyOrderItem = await pharmacyOrderItemService.createPharmacyOrderItem(
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  sendSuccess(res, 201, 'messages.pharmacy_order_item.create.success', pharmacyOrderItem);
});

/**
 * Update pharmacy order item
 * PUT /api/v1/pharmacy-order-items/:id
 */
const updatePharmacyOrderItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const pharmacyOrderItem = await pharmacyOrderItemService.updatePharmacyOrderItem(
    id,
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  sendSuccess(res, 200, 'messages.pharmacy_order_item.update.success', pharmacyOrderItem);
});

/**
 * Delete pharmacy order item
 * DELETE /api/v1/pharmacy-order-items/:id
 */
const deletePharmacyOrderItem = asyncHandler(async (req, res) => {
  const { id } = req.params;
  await pharmacyOrderItemService.deletePharmacyOrderItem(id, req.user?.id, req.ip, req.user || {});
  sendNoContent(res);
});

module.exports = {
  listPharmacyOrderItems,
  getPharmacyOrderItemById,
  createPharmacyOrderItem,
  updatePharmacyOrderItem,
  deletePharmacyOrderItem
};
