/**
 * Lab panel routes
 *
 * @module modules/lab-panel/routes
 * @description Lab panel endpoints mounted at /api/v1/lab-panels
 */

const express = require('express');
const labPanelController = require('@controllers/lab-panel/lab-panel.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createLabPanelSchema,
  updateLabPanelSchema,
  deleteLabPanelSchema,
  labPanelIdParamsSchema,
  listLabPanelsQuerySchema} = require('@validations/lab-panel/lab-panel.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ];

const LAB_WRITE_SCOPES = [PERMISSIONS.LAB_WRITE];

router.get(
  '/',
  validateRequest({ query: listLabPanelsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labPanelController.listLabPanels
);

router.get(
  '/:id',
  validateRequest({ params: labPanelIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labPanelController.getLabPanelById
);

router.post(
  '/',
  validateRequest({ body: createLabPanelSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labPanelController.createLabPanel
);

router.put(
  '/:id',
  validateRequest({ params: labPanelIdParamsSchema, body: updateLabPanelSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labPanelController.updateLabPanel
);

router.delete(
  '/:id',
  validateRequest({ params: labPanelIdParamsSchema, body: deleteLabPanelSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labPanelController.deleteLabPanel
);

module.exports = router;
