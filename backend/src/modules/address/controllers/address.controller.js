/**
 * Address controller
 *
 * @module modules/address/controllers
 * @description Request handlers for address endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const addressService = require('@services/address/address.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List addresses with pagination
 * GET /api/v1/addresses
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listAddresses = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    address_type,
    facility_id,
    branch_id,
    patient_id,
    user_profile_id,
    staff_profile_id,
    supplier_id,
    city,
    state,
    country,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    address_type,
    facility_id,
    branch_id,
    patient_id,
    user_profile_id,
    staff_profile_id,
    supplier_id,
    city,
    state,
    country,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await addressService.listAddresses(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.address.list.success', result.addresses, result.pagination);
});

/**
 * Get address by ID
 * GET /api/v1/addresses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getAddressById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const address = await addressService.getAddressById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.address.get.success', address);
});

/**
 * Create new address
 * POST /api/v1/addresses
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createAddress = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const address = await addressService.createAddress(req.body, userId, ipAddress);

  sendSuccess(res, 201, 'messages.address.create.success', address);
});

/**
 * Update address
 * PUT /api/v1/addresses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateAddress = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const address = await addressService.updateAddress(id, req.body, userId, ipAddress);

  sendSuccess(res, 200, 'messages.address.update.success', address);
});

/**
 * Delete address (soft delete)
 * DELETE /api/v1/addresses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteAddress = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await addressService.deleteAddress(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listAddresses,
  getAddressById,
  createAddress,
  updateAddress,
  deleteAddress
};
