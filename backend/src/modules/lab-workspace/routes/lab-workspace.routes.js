/**
 * Lab workspace routes
 *
 * @module modules/lab-workspace/routes
 * @description Lab workspace endpoints mounted at /api/v1/lab
 */

const express = require('express');
const { z } = require('zod');
const labWorkspaceController = require('@controllers/lab-workspace/lab-workspace.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const { uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');
const {
  collectLabOrderSchema,
  getLabWorkbenchQuerySchema,
  orderItemWorkflowParamsSchema,
  orderWorkflowParamsSchema,
  receiveLabSampleSchema,
  rejectLabSampleSchema,
  releaseLabOrderItemSchema,
  reverseLabOrderWorkflowSchema,
  sampleWorkflowParamsSchema,
} = require('@validations/lab-workspace/lab-workspace.schema');

const router = express.Router();

const LAB_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LAB_TECH,
];

const LAB_MUTATION_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.LAB_TECH,
];

const resolveLegacyRouteParamsSchema = z.object({
  resource: z.enum([
    'lab-orders',
    'lab-order-items',
    'lab-samples',
    'lab-results',
    'lab-tests',
    'lab-panels',
    'lab-qc-logs',
  ]),
  id: uuidOrFriendlyIdentifierSchema,
});

router.get(
  '/workbench',
  validateRequest({ query: getLabWorkbenchQuerySchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labWorkspaceController.getLabWorkbench
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyRouteParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labWorkspaceController.resolveLegacyRoute
);

router.get(
  '/orders/:id/workflow',
  validateRequest({ params: orderWorkflowParamsSchema }),
  authenticate(),
  authorize(LAB_READ_ROLES, 'role'),
  labWorkspaceController.getLabOrderWorkflow
);

router.post(
  '/orders/:id/collect',
  validateRequest({ params: orderWorkflowParamsSchema, body: collectLabOrderSchema }),
  authenticate(),
  authorize(LAB_MUTATION_ROLES, 'role'),
  labWorkspaceController.collectLabOrder
);

router.post(
  '/samples/:id/receive',
  validateRequest({ params: sampleWorkflowParamsSchema, body: receiveLabSampleSchema }),
  authenticate(),
  authorize(LAB_MUTATION_ROLES, 'role'),
  labWorkspaceController.receiveLabSample
);

router.post(
  '/samples/:id/reject',
  validateRequest({ params: sampleWorkflowParamsSchema, body: rejectLabSampleSchema }),
  authenticate(),
  authorize(LAB_MUTATION_ROLES, 'role'),
  labWorkspaceController.rejectLabSample
);

router.post(
  '/order-items/:id/release',
  validateRequest({
    params: orderItemWorkflowParamsSchema,
    body: releaseLabOrderItemSchema,
  }),
  authenticate(),
  authorize(LAB_MUTATION_ROLES, 'role'),
  labWorkspaceController.releaseLabOrderItem
);

router.post(
  '/orders/:id/reverse',
  validateRequest({
    params: orderWorkflowParamsSchema,
    body: reverseLabOrderWorkflowSchema,
  }),
  authenticate(),
  authorize(LAB_MUTATION_ROLES, 'role'),
  labWorkspaceController.reverseLabOrderWorkflow
);

module.exports = router;
