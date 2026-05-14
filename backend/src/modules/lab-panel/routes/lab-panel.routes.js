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
const { ROLES } = require('@config/roles');
const {
  createLabPanelSchema,
  updateLabPanelSchema,
  labPanelIdParamsSchema,
  listLabPanelsQuerySchema,
} = require('@validations/lab-panel/lab-panel.schema');

const router = express.Router();

const LAB_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
];

const LAB_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.LAB_TECH,
];

router.get(
  '/',
  validateRequest({ query: listLabPanelsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labPanelController.listLabPanels
);

router.get(
  '/:id',
  validateRequest({ params: labPanelIdParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labPanelController.getLabPanelById
);

router.post(
  '/',
  validateRequest({ body: createLabPanelSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labPanelController.createLabPanel
);

router.put(
  '/:id',
  validateRequest({ params: labPanelIdParamsSchema, body: updateLabPanelSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labPanelController.updateLabPanel
);

router.delete(
  '/:id',
  validateRequest({ params: labPanelIdParamsSchema }),
  authenticate(),
  authorize(LAB_WRITE_ROLES, 'role'),
  labPanelController.deleteLabPanel
);

module.exports = router;
