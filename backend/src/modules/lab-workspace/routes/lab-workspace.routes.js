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
const { PERMISSIONS } = require('@config/permissions');
const { uuidOrFriendlyIdentifierSchema } = require('@lib/validation/zod');
const {
  collectLabOrderSchema,
  getLabWorkbenchQuerySchema,
  labOrderContextPatientParamsSchema,
  orderItemWorkflowParamsSchema,
  orderWorkflowParamsSchema,
  receiveLabSampleSchema,
  rejectLabSampleSchema,
  releaseLabOrderItemSchema,
  searchLabOrderContextPatientsQuerySchema,
  verifyLabOrderResultsSchema,
  rejectLabOrderItemSchema,
  reverseLabOrderWorkflowSchema,
  reopenLabOrderItemResultSchema,
  restoreLabOrderItemSchema,
  deleteLabOrderItemsSchema,
  sampleWorkflowParamsSchema} = require('@validations/lab-workspace/lab-workspace.schema');

const router = express.Router();

const LAB_READ_SCOPES = [PERMISSIONS.LAB_READ];

const LAB_WRITE_SCOPES = [PERMISSIONS.LAB_WRITE];

const resolveLegacyRouteParamsSchema = z.object({
  resource: z.enum([
    'lab-orders',
    'lab-order-items',
    'lab-samples',
    'lab-results',
    'lab-tests',
    'lab-panels',
    'lab-qc-logs']),
  id: uuidOrFriendlyIdentifierSchema});

router.get(
  '/workbench',
  validateRequest({ query: getLabWorkbenchQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labWorkspaceController.getLabWorkbench
);

router.get(
  '/order-context/patients',
  validateRequest({ query: searchLabOrderContextPatientsQuerySchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labWorkspaceController.searchLabOrderContextPatients
);

router.get(
  '/order-context/patients/:id',
  validateRequest({ params: labOrderContextPatientParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labWorkspaceController.getLabOrderPatientContext
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyRouteParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labWorkspaceController.resolveLegacyRoute
);

router.get(
  '/orders/:id/workflow',
  validateRequest({ params: orderWorkflowParamsSchema }),
  authenticate(),
  authorize(LAB_READ_SCOPES, 'permission'),
  labWorkspaceController.getLabOrderWorkflow
);

router.post(
  '/orders/:id/collect',
  validateRequest({ params: orderWorkflowParamsSchema, body: collectLabOrderSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.collectLabOrder
);

router.post(
  '/samples/:id/receive',
  validateRequest({ params: sampleWorkflowParamsSchema, body: receiveLabSampleSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.receiveLabSample
);

router.post(
  '/samples/:id/reject',
  validateRequest({ params: sampleWorkflowParamsSchema, body: rejectLabSampleSchema }),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.rejectLabSample
);

router.post(
  '/order-items/:id/release',
  validateRequest({
    params: orderItemWorkflowParamsSchema,
    body: releaseLabOrderItemSchema}),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.releaseLabOrderItem
);

router.post(
  '/orders/:id/verify-results',
  validateRequest({
    params: orderWorkflowParamsSchema,
    body: verifyLabOrderResultsSchema}),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.verifyLabOrderResults
);

router.post(
  '/order-items/:id/reject',
  validateRequest({
    params: orderItemWorkflowParamsSchema,
    body: rejectLabOrderItemSchema}),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.rejectLabOrderItem
);

router.post(
  '/orders/:id/reverse',
  validateRequest({
    params: orderWorkflowParamsSchema,
    body: reverseLabOrderWorkflowSchema}),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.reverseLabOrderWorkflow
);

router.post(
  '/order-items/:id/reopen-result',
  validateRequest({
    params: orderItemWorkflowParamsSchema,
    body: reopenLabOrderItemResultSchema}),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.reopenLabOrderItemResult
);

router.post(
  '/order-items/:id/restore',
  validateRequest({
    params: orderItemWorkflowParamsSchema,
    body: restoreLabOrderItemSchema}),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.restoreLabOrderItem
);

router.post(
  '/orders/:id/delete-items',
  validateRequest({
    params: orderWorkflowParamsSchema,
    body: deleteLabOrderItemsSchema}),
  authenticate(),
  authorize(LAB_WRITE_SCOPES, 'permission'),
  labWorkspaceController.deleteLabOrderItems
);

module.exports = router;
