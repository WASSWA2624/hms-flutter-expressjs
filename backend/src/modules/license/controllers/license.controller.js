/**
 * License controller
 *
 * @module modules/license/controllers
 * @description Request handlers for license endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per api.mdc: Use standard response helpers.
 */

const licenseService = require('@services/license/license.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { getLocale } = require('@lib/i18n');

/**
 * List all licenses
 * GET /api/v1/licenses
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const listLicenses = asyncHandler(async (req, res) => {
  const locale = getLocale(req);
  const { page = 1, limit = 20, sort_by = 'created_at', order = 'desc', tenant_id, license_type, status } = req.query;

  const filters = {};
  if (tenant_id) filters.tenant_id = tenant_id;
  if (license_type) filters.license_type = license_type;
  if (status) filters.status = status;

  const result = await licenseService.listLicenses(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    req.user
  );

  sendPaginated(
    res,
    'messages.license.list.success',
    result.licenses,
    result.pagination,
    locale
  );
});

/**
 * Get license by ID
 * GET /api/v1/licenses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getLicenseById = asyncHandler(async (req, res) => {
  const locale = getLocale(req);
  const { id } = req.params;

  const license = await licenseService.getLicenseById(id, req.user);

  sendSuccess(
    res,
    200,
    'messages.license.get.success',
    license,
    locale
  );
});

/**
 * Create new license
 * POST /api/v1/licenses
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const createLicense = asyncHandler(async (req, res) => {
  const locale = getLocale(req);
  const context = {
    user: req.user,
    ip: req.ip,
    tenant_id: req.user?.tenant_id
  };

  const license = await licenseService.createLicense(req.body, context);

  sendSuccess(
    res,
    201,
    'messages.license.create.success',
    license,
    locale
  );
});

/**
 * Update license
 * PUT /api/v1/licenses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const updateLicense = asyncHandler(async (req, res) => {
  const locale = getLocale(req);
  const { id } = req.params;
  const context = {
    user: req.user,
    ip: req.ip,
    tenant_id: req.user?.tenant_id
  };

  const license = await licenseService.updateLicense(id, req.body, context);

  sendSuccess(
    res,
    200,
    'messages.license.update.success',
    license,
    locale
  );
});

/**
 * Delete license
 * DELETE /api/v1/licenses/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const deleteLicense = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const context = {
    user: req.user,
    ip: req.ip,
    tenant_id: req.user?.tenant_id
  };

  await licenseService.deleteLicense(id, context);

  // Per response-format.mdc: DELETE returns 204 with no body
  res.status(204).send();
});

module.exports = {
  listLicenses,
  getLicenseById,
  createLicense,
  updateLicense,
  deleteLicense
};
