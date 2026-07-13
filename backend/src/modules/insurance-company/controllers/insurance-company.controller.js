/**
 * Insurance Company controller
 *
 * @module modules/insurance-company/controllers
 * @description Request handlers for insurance company endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const insuranceCompanyService = require('@services/insurance-company/insurance-company.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List insurance companies with pagination
 * GET /api/v1/insurance-companies
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listInsuranceCompanies = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    code,
    is_active,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    code,
    is_active,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await insuranceCompanyService.listInsuranceCompanies(
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
    'messages.insurance_company.list.success',
    result.insuranceCompanies,
    result.pagination
  );
});

/**
 * Get insurance company by ID
 * GET /api/v1/insurance-companies/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getInsuranceCompanyById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insuranceCompany = await insuranceCompanyService.getInsuranceCompanyById(
    id,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.insurance_company.get.success', insuranceCompany);
});

/**
 * List schemes (coverage plans) for an insurance company
 * GET /api/v1/insurance-companies/:id/schemes
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listInsuranceCompanySchemes = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const schemes = await insuranceCompanyService.listInsuranceCompanySchemes(id);

  sendSuccess(res, 200, 'messages.insurance_company.schemes.success', schemes);
});

/**
 * Create new insurance company
 * POST /api/v1/insurance-companies
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createInsuranceCompany = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insuranceCompany = await insuranceCompanyService.createInsuranceCompany(
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 201, 'messages.insurance_company.create.success', insuranceCompany);
});

/**
 * Update insurance company
 * PUT /api/v1/insurance-companies/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateInsuranceCompany = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const insuranceCompany = await insuranceCompanyService.updateInsuranceCompany(
    id,
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.insurance_company.update.success', insuranceCompany);
});

/**
 * Delete insurance company (soft delete)
 * DELETE /api/v1/insurance-companies/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteInsuranceCompany = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await insuranceCompanyService.deleteInsuranceCompany(id, userId, ipAddress);

  sendNoContent(res);
});

module.exports = {
  listInsuranceCompanies,
  getInsuranceCompanyById,
  listInsuranceCompanySchemes,
  createInsuranceCompany,
  updateInsuranceCompany,
  deleteInsuranceCompany
};
