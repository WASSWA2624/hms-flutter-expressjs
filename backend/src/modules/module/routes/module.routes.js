/**
 * Module routes
 *
 * @module modules/module/routes
 * @description Module endpoints mounted at /api/v1/modules
 */

const express = require('express');
const moduleController = require('@controllers/module/module.controller');
const { PERMISSIONS } = require('@config/permissions');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const {
  createModuleSchema,
  updateModuleSchema,
  moduleIdParamsSchema,
  listModulesQuerySchema,
} = require('@validations/module/module.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listModulesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  moduleController.listModules
);

router.get(
  '/:id',
  validateRequest({ params: moduleIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_READ, 'permission'),
  moduleController.getModuleById
);

router.post(
  '/',
  validateRequest({ body: createModuleSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  moduleController.createModule
);

router.put(
  '/:id',
  validateRequest({ params: moduleIdParamsSchema, body: updateModuleSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_WRITE, 'permission'),
  moduleController.updateModule
);

router.delete(
  '/:id',
  validateRequest({ params: moduleIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.SUBSCRIPTIONS_DELETE, 'permission'),
  moduleController.deleteModule
);

module.exports = router;
