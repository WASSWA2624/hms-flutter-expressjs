const express = require('express');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const { PERMISSIONS } = require('@config/permissions');
const schedulingWorkspaceController = require('@controllers/scheduling-workspace/scheduling-workspace.controller');
const {
  workspaceQuerySchema,
  referenceDataQuerySchema,
  resolveLegacyParamsSchema,
} = require('@validations/scheduling-workspace/scheduling-workspace.schema');

const router = express.Router();

const READ_PERMISSIONS = [
  PERMISSIONS.PATIENT_READ,
  PERMISSIONS.CLINICAL_READ,
  PERMISSIONS.BILLING_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.EMERGENCY_READ,
];

router.use(authenticate());

router.get(
  '/workspace',
  validateRequest({ query: workspaceQuerySchema }),
  authorize(READ_PERMISSIONS, 'permission'),
  schedulingWorkspaceController.getWorkspace
);

router.get(
  '/reference-data',
  validateRequest({ query: referenceDataQuerySchema }),
  authorize(READ_PERMISSIONS, 'permission'),
  schedulingWorkspaceController.getReferenceData
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyParamsSchema }),
  authorize(READ_PERMISSIONS, 'permission'),
  schedulingWorkspaceController.resolveLegacyRoute
);

module.exports = router;
