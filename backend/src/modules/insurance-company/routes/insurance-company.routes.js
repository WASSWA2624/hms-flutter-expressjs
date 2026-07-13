/**
 * Insurance Company routes
 *
 * @module modules/insurance-company/routes
 * @description Insurance Company endpoints mounted at /api/v1/insurance-companies
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const insuranceCompanyController = require('@controllers/insurance-company/insurance-company.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createInsuranceCompanySchema,
  updateInsuranceCompanySchema,
  insuranceCompanyIdParamsSchema,
  listInsuranceCompaniesQuerySchema
} = require('@validations/insurance-company/insurance-company.schema');

/**
 * @description List insurance companies with pagination and filters
 * @method GET
 * @route /api/v1/insurance-companies/
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/',
  validateRequest({ query: listInsuranceCompaniesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  insuranceCompanyController.listInsuranceCompanies
);

/**
 * @description List schemes (coverage plans) for an insurance company
 * @method GET
 * @route /api/v1/insurance-companies/:id/schemes
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/:id/schemes',
  validateRequest({ params: insuranceCompanyIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  insuranceCompanyController.listInsuranceCompanySchemes
);

/**
 * @description Get insurance company by ID
 * @method GET
 * @route /api/v1/insurance-companies/:id
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/:id',
  validateRequest({ params: insuranceCompanyIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  insuranceCompanyController.getInsuranceCompanyById
);

/**
 * @description Create new insurance company
 * @method POST
 * @route /api/v1/insurance-companies/
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.post(
  '/',
  validateRequest({ body: createInsuranceCompanySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insuranceCompanyController.createInsuranceCompany
);

/**
 * @description Update insurance company
 * @method PUT
 * @route /api/v1/insurance-companies/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.put(
  '/:id',
  validateRequest({ params: insuranceCompanyIdParamsSchema, body: updateInsuranceCompanySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insuranceCompanyController.updateInsuranceCompany
);

/**
 * @description Delete insurance company (soft delete)
 * @method DELETE
 * @route /api/v1/insurance-companies/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.delete(
  '/:id',
  validateRequest({ params: insuranceCompanyIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insuranceCompanyController.deleteInsuranceCompany
);

module.exports = router;
