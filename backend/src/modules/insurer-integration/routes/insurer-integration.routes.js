/**
 * Insurer Integration routes
 *
 * @module modules/insurer-integration/routes
 * @description Insurer Integration endpoints mounted at /api/v1/insurer-integrations
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const insurerIntegrationController = require('@controllers/insurer-integration/insurer-integration.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createInsurerIntegrationSchema,
  updateInsurerIntegrationSchema,
  insurerIntegrationIdParamsSchema,
  listInsurerIntegrationsQuerySchema
} = require('@validations/insurer-integration/insurer-integration.schema');

/**
 * @description List insurer integrations with pagination and filters
 * @method GET
 * @route /api/v1/insurer-integrations/
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/',
  validateRequest({ query: listInsurerIntegrationsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  insurerIntegrationController.listInsurerIntegrations
);

/**
 * @description Get insurer integration by ID
 * @method GET
 * @route /api/v1/insurer-integrations/:id
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/:id',
  validateRequest({ params: insurerIntegrationIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  insurerIntegrationController.getInsurerIntegrationById
);

/**
 * @description Create new insurer integration
 * @method POST
 * @route /api/v1/insurer-integrations/
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.post(
  '/',
  validateRequest({ body: createInsurerIntegrationSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insurerIntegrationController.createInsurerIntegration
);

/**
 * @description Update insurer integration
 * @method PUT
 * @route /api/v1/insurer-integrations/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.put(
  '/:id',
  validateRequest({
    params: insurerIntegrationIdParamsSchema,
    body: updateInsurerIntegrationSchema
  }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insurerIntegrationController.updateInsurerIntegration
);

/**
 * @description Delete insurer integration (soft delete)
 * @method DELETE
 * @route /api/v1/insurer-integrations/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.delete(
  '/:id',
  validateRequest({ params: insurerIntegrationIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  insurerIntegrationController.deleteInsurerIntegration
);

module.exports = router;
