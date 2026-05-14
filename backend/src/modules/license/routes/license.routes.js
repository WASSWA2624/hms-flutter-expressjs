/**
 * License routes
 *
 * @module modules/license/routes
 * @description License endpoints mounted at /api/v1/licenses
 */

const express = require('express');
const licenseController = require('@controllers/license/license.controller');
const { PERMISSIONS } = require('@config/permissions');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const {
  createLicenseSchema,
  updateLicenseSchema,
  licenseIdParamsSchema,
  listLicensesQuerySchema,
} = require('@validations/license/license.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listLicensesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  licenseController.listLicenses
);

router.get(
  '/:id',
  validateRequest({ params: licenseIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  licenseController.getLicenseById
);

router.post(
  '/',
  validateRequest({ body: createLicenseSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  licenseController.createLicense
);

router.put(
  '/:id',
  validateRequest({ params: licenseIdParamsSchema, body: updateLicenseSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  licenseController.updateLicense
);

router.delete(
  '/:id',
  validateRequest({ params: licenseIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_DELETE, 'permission'),
  licenseController.deleteLicense
);

module.exports = router;
