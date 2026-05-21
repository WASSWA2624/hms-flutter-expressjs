/**
 * Triage routes
 *
 * @module modules/triage/routes
 * @description Triage queue and routing endpoints mounted at /api/v1/triage.
 */

const express = require('express');
const router = express.Router();
const triageController = require('@controllers/triage/triage.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize, denyRoles } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const { STAFF_PATIENT_FLOW_DENIED_ROLES } = require('@config/roles');
const {
  triageIdParamsSchema,
  listTriageQueueQuerySchema,
  recordVitalsSchema,
  assignProviderSchema,
  routeTriageSchema,
  correctStageSchema
} = require('@validations/triage/triage.schema');

const TRIAGE_READ_PERMISSIONS = [
  PERMISSIONS.PATIENT_READ,
  PERMISSIONS.CLINICAL_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.EMERGENCY_READ
];

const TRIAGE_ACTION_PERMISSIONS = [
  PERMISSIONS.PATIENT_WRITE,
  PERMISSIONS.CLINICAL_WRITE,
  PERMISSIONS.OPERATIONS_WRITE,
  PERMISSIONS.EMERGENCY_WRITE
];

const TRIAGE_CLINICAL_ACTION_PERMISSIONS = [PERMISSIONS.CLINICAL_WRITE, PERMISSIONS.EMERGENCY_WRITE];

router.use(authenticate(), denyRoles(STAFF_PATIENT_FLOW_DENIED_ROLES));

router.get(
  '/',
  validateRequest({ query: listTriageQueueQuerySchema }),
  authenticate(),
  authorize(TRIAGE_READ_PERMISSIONS, 'permission'),
  triageController.listTriageQueue
);

router.get(
  '/:id',
  validateRequest({ params: triageIdParamsSchema }),
  authenticate(),
  authorize(TRIAGE_READ_PERMISSIONS, 'permission'),
  triageController.getTriageCase
);

router.post(
  '/:id/record-vitals',
  validateRequest({ params: triageIdParamsSchema, body: recordVitalsSchema }),
  authenticate(),
  authorize(TRIAGE_CLINICAL_ACTION_PERMISSIONS, 'permission'),
  triageController.recordVitals
);

router.post(
  '/:id/assign-provider',
  validateRequest({ params: triageIdParamsSchema, body: assignProviderSchema }),
  authenticate(),
  authorize(TRIAGE_ACTION_PERMISSIONS, 'permission'),
  triageController.assignProvider
);

router.post(
  '/:id/route',
  validateRequest({ params: triageIdParamsSchema, body: routeTriageSchema }),
  authenticate(),
  authorize(TRIAGE_CLINICAL_ACTION_PERMISSIONS, 'permission'),
  triageController.routeFromTriage
);

router.post(
  '/:id/correct-stage',
  validateRequest({ params: triageIdParamsSchema, body: correctStageSchema }),
  authenticate(),
  authorize(TRIAGE_CLINICAL_ACTION_PERMISSIONS, 'permission'),
  triageController.correctStage
);

module.exports = router;
