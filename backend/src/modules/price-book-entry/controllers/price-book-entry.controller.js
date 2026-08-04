/**
 * Price Book Entry controller
 *
 * @module modules/price-book-entry/controllers
 * @description Request handlers for price book entry endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const priceBookEntryService = require('@services/price-book-entry/price-book-entry.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List price book entries with pagination
 * GET /api/v1/price-book-entries
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPriceBookEntries = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    catalog_type,
    catalog_item_id,
    payment_mode,
    coverage_plan_id,
    insurance_company_id,
    billing_entity,
    is_active,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    catalog_type,
    catalog_item_id,
    payment_mode,
    coverage_plan_id,
    insurance_company_id,
    billing_entity,
    is_active,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await priceBookEntryService.listPriceBookEntries(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(
    res,
    'messages.price_book_entry.list.success',
    result.priceBookEntries,
    result.pagination
  );
});

/**
 * Get price book entry by ID
 * GET /api/v1/price-book-entries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPriceBookEntryById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const priceBookEntry = await priceBookEntryService.getPriceBookEntryById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.price_book_entry.get.success', priceBookEntry);
});

/**
 * Create new price book entry
 * POST /api/v1/price-book-entries
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPriceBookEntry = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const priceBookEntry = await priceBookEntryService.createPriceBookEntry(
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 201, 'messages.price_book_entry.create.success', priceBookEntry);
});

/**
 * Update price book entry
 * PUT /api/v1/price-book-entries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePriceBookEntry = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const priceBookEntry = await priceBookEntryService.updatePriceBookEntry(
    id,
    req.body,
    userId,
    ipAddress,
    req.user || {}
  );

  sendSuccess(res, 200, 'messages.price_book_entry.update.success', priceBookEntry);
});

/**
 * Delete price book entry (soft delete)
 * DELETE /api/v1/price-book-entries/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePriceBookEntry = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await priceBookEntryService.deletePriceBookEntry(
    id,
    userId,
    ipAddress,
    req.user || {}
  );

  sendNoContent(res);
});

/**
 * Resolve unit prices for catalog items
 * POST /api/v1/price-book-entries/resolve
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const resolvePriceBookEntries = asyncHandler(async (req, res) => {
  const result = await priceBookEntryService.resolvePriceBookEntries(req.body);

  sendSuccess(res, 200, 'messages.price_book_entry.resolve.success', result);
});

module.exports = {
  listPriceBookEntries,
  getPriceBookEntryById,
  createPriceBookEntry,
  updatePriceBookEntry,
  deletePriceBookEntry,
  resolvePriceBookEntries
};
