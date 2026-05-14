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
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const { ROLES } = require('@config/roles');
const {
  triageIdParamsSchema,
  listTriageQueueQuerySchema,
  recordVitalsSchema,
  assignProviderSchema,
  routeTriageSchema,
  correctStageSchema,
} = require('@validations/triage/triage.schema');

const TRIAGE_READ_PERMISSIONS = [
  PERMISSIONS.PATIENT_READ,
  PERMISSIONS.CLINICAL_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.EMERGENCY_READ,
];

const TRIAGE_ACTION_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.RECEPTIONIST,
  ROLES.NURSE,
  ROLES.DOCTOR,
  ROLES.OPERATIONS,
  ROLES.LAB_TECH,
  ROLES.THEATRE_MANAGER,
];

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
  authorize(TRIAGE_ACTION_ROLES, 'role'),
  triageController.recordVitals
);

router.post(
  '/:id/assign-provider',
  validateRequest({ params: triageIdParamsSchema, body: assignProviderSchema }),
  authenticate(),
  authorize(TRIAGE_ACTION_ROLES, 'role'),
  triageController.assignProvider
);

router.post(
  '/:id/route',
  validateRequest({ params: triageIdParamsSchema, body: routeTriageSchema }),
  authenticate(),
  authorize(TRIAGE_ACTION_ROLES, 'role'),
  triageController.routeFromTriage
);

router.post(
  '/:id/correct-stage',
  validateRequest({ params: triageIdParamsSchema, body: correctStageSchema }),
  authenticate(),
  authorize(TRIAGE_ACTION_ROLES, 'role'),
  triageController.correctStage
);

module.exports = router;
